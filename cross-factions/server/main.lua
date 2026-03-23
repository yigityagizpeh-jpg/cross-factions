--[[
    server/main.lua — Sunucu Çekirdeği
    QBCore başlatma, cache yönetimi, shared utilities, export'lar,
    kill-tracking event'i ve admin komutları bu dosyada toplanmıştır.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Önbellek (Runtime Cache) ─────────────────────────────────────────────────
-- Sunucu yeniden başlatılana kadar memlerde tutulan veriler
GangCache    = {}   -- gangId → gang verisi
MemberCache  = {}   -- citizenid → { gangId, rank, rankIndex }
TurfCache    = {}   -- turfId → { owner, cooldownUntil }
WarCache     = {}   -- warId → war verisi
AllyCache    = {}   -- "gangA:gangB" → true
SprayCache   = {}   -- sprayId → spray verisi
KillCooldown = {}   -- "killerCid:victimCid" → timestamp (anti-farm)

-- ─── Yardımcı: Oyuncu QBCore objesi al ───────────────────────────────────────
function GetPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

-- ─── Yardımcı: Oyuncunun citizenid'ini al ────────────────────────────────────
function GetCitizenId(source)
    local player = GetPlayer(source)
    if not player then return nil end
    return player.PlayerData.citizenid
end

-- ─── Yardımcı: Admin kontrolü ────────────────────────────────────────────────
function IsAdmin(source)
    local player = GetPlayer(source)
    if not player then return false end
    local group = QBCore.Functions.GetPermission(source)
    for _, g in ipairs(Config.AdminGroups) do
        if group == g then return true end
    end
    return false
end

-- ─── Yardımcı: Debug log ─────────────────────────────────────────────────────
function DebugPrint(msg)
    if Config.Debug then
        print('[cross-factions DEBUG] ' .. tostring(msg))
    end
end

-- ─── Yardımcı: Aktif polis sayısını al ───────────────────────────────────────
function GetActivePoliceCount()
    local count = 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player and player.PlayerData and player.PlayerData.job then
            local job = player.PlayerData.job.name
            if job == 'police' or job == 'sheriff' or job == 'bcso' then
                count = count + 1
            end
        end
    end
    return count
end

-- ─── Yardımcı: Gang üyelerini online say ─────────────────────────────────────
function CountOnlineGangMembers(gangId)
    local count = 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player and player.PlayerData then
            local cid = player.PlayerData.citizenid
            if MemberCache[cid] and MemberCache[cid].gangId == gangId then
                count = count + 1
            end
        end
    end
    return count
end

-- ─── Cache başlatma: Sunucu açıldığında DB'den yükle ─────────────────────────
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DebugPrint('Resource başlatılıyor, cache yükleniyor...')

    -- Gang cache
    MySQL.query('SELECT * FROM cf_gangs', {}, function(gangs)
        if gangs then
            for _, gang in ipairs(gangs) do
                GangCache[gang.id] = gang
                -- JSON alanlarını parse et
                if type(gang.settings) == 'string' then
                    GangCache[gang.id].settings = json.decode(gang.settings) or {}
                end
            end
        end
        DebugPrint(('Gang cache yüklendi: %d gang'):format(#(gangs or {})))
    end)

    -- Member cache
    MySQL.query('SELECT citizenid, gang_id, rank_index FROM cf_gang_members', {}, function(members)
        if members then
            for _, m in ipairs(members) do
                MemberCache[m.citizenid] = {
                    gangId     = m.gang_id,
                    rankIndex  = m.rank_index,
                }
            end
        end
        DebugPrint(('Member cache yüklendi: %d üye'):format(#(members or {})))
    end)

    -- Turf cache
    MySQL.query('SELECT turf_id, owner_gang_id, cooldown_until FROM cf_turf_ownership', {}, function(turfs)
        if turfs then
            for _, t in ipairs(turfs) do
                TurfCache[t.turf_id] = {
                    owner         = t.owner_gang_id,
                    cooldownUntil = t.cooldown_until or 0,
                }
            end
        end
        DebugPrint(('Turf cache yüklendi: %d turf'))
    end)

    -- Alliance cache
    MySQL.query("SELECT gang1_id, gang2_id FROM cf_gang_alliances WHERE status = 'active'", {}, function(alliances)
        if alliances then
            for _, a in ipairs(alliances) do
                local key = math.min(a.gang1_id, a.gang2_id) .. ':' .. math.max(a.gang1_id, a.gang2_id)
                AllyCache[key] = true
            end
        end
    end)

    DebugPrint('Cache yükleme tamamlandı.')
end)

-- ─── Oyuncu Bağlantısı: MemberCache güncelle ─────────────────────────────────
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local cid = player.PlayerData.citizenid
    MySQL.query('SELECT gang_id, rank_index FROM cf_gang_members WHERE citizenid = ?', { cid }, function(rows)
        if rows and rows[1] then
            MemberCache[cid] = {
                gangId    = rows[1].gang_id,
                rankIndex = rows[1].rank_index,
            }
        else
            MemberCache[cid] = nil
        end
    end)
end)

AddEventHandler('QBCore:Server:PlayerUnload', function(source)
    -- Cache'i temizleme, oyuncu tekrar bağlandığında güncellenecek
    -- (Cache performans için tutulur; kaynak israfı değildir)
    local _ = GetCitizenId(source)
end)

-- ─── Kill Tracking: Oyuncu öldürme ───────────────────────────────────────────
-- Client, öldürme gerçekleştiğinde bu eventi tetikler
RegisterNetEvent('cross-factions:server:registerKill', function(victimSrc)
    local killerSrc = source
    local killerCid = GetCitizenId(killerSrc)
    local victimCid = GetCitizenId(victimSrc)
    if not killerCid or not victimCid then return end
    if killerCid == victimCid then return end  -- kendini öldürme

    -- Gang kontrolü
    local killerMember = MemberCache[killerCid]
    local victimMember = MemberCache[victimCid]
    if not killerMember or not victimMember then return end
    if killerMember.gangId == victimMember.gangId then return end  -- aynı gang

    -- Anti-farm: aynı hedefe kısa sürede tekrar kill
    local farmKey = killerCid .. ':' .. victimCid
    local now = os.time()
    if KillCooldown[farmKey] and (now - KillCooldown[farmKey]) < Config.War.KillFarmCooldown then
        DebugPrint(('Kill farm engellendi: %s → %s'):format(killerCid, victimCid))
        return
    end
    KillCooldown[farmKey] = now

    -- Kill logu kaydet
    local killerGangId = killerMember.gangId
    local victimGangId = victimMember.gangId

    MySQL.insert(
        'INSERT INTO cf_kill_logs (killer_cid, victim_cid, killer_gang_id, victim_gang_id, killed_at) VALUES (?, ?, ?, ?, NOW())',
        { killerCid, victimCid, killerGangId, victimGangId },
        function(id)
            DebugPrint(('Kill log eklendi: %s → %s (id=%d)'):format(killerCid, victimCid, id or 0))
        end
    )

    -- Aktif savaş varsa war score güncelle
    TriggerEvent('cross-factions:internal:warKill', killerGangId, victimGangId, killerCid, victimCid)

    -- Kill log Discord
    local killerPlayer = GetPlayer(killerSrc)
    local victimPlayer = GetPlayer(victimSrc)
    if killerPlayer and victimPlayer then
        local killerName = killerPlayer.PlayerData.charinfo.firstname .. ' ' .. killerPlayer.PlayerData.charinfo.lastname
        local victimName = victimPlayer.PlayerData.charinfo.firstname .. ' ' .. victimPlayer.PlayerData.charinfo.lastname
        LogKill(
            '🔫 Kill Logu',
            ('**Öldüren:** %s (Gang ID: %d)\n**Ölen:** %s (Gang ID: %d)'):format(
                killerName, killerGangId, victimName, victimGangId
            )
        )
    end
end)

-- ─── Leaderboard: Haftalık/Aylık sıfırlama ───────────────────────────────────
-- Her gece gece yarısı kontrol edilir
CreateThread(function()
    while true do
        Wait(3600000)  -- Her saat kontrol
        -- Basit günlük kontrol; gerçek sunucuda cron tabanlı yapılabilir
        -- Bu implementasyonda DB'deki created_at ile haftalık/aylık filtre yapılır
        -- Gerçek wipe için ayrı bir scheduled task oluşturulabilir
    end
end)

-- ─── Export: Dışarıya açılan fonksiyonlar ────────────────────────────────────
exports('GetPlayerGang', function(source)
    local cid = GetCitizenId(source)
    if not cid then return nil end
    local m = MemberCache[cid]
    if not m then return nil end
    return GangCache[m.gangId]
end)

exports('IsPlayerInGang', function(source, gangId)
    local cid = GetCitizenId(source)
    if not cid then return false end
    local m = MemberCache[cid]
    if not m then return false end
    if gangId then return m.gangId == gangId end
    return true
end)

exports('GetGangData', function(gangId)
    return GangCache[gangId]
end)

-- ─── Admin Komutları ──────────────────────────────────────────────────────────
QBCore.Commands.Add('cf_creategang', '[Admin] Gang oluştur', {
    { name = 'name',   help = 'Gang adı' },
    { name = 'tag',    help = 'Gang etiketi' },
    { name = 'playerId', help = 'Lider oyuncu ID' },
}, true, function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end
    local name   = args[1]
    local tag    = args[2]
    local target = tonumber(args[3])
    TriggerEvent('cross-factions:internal:adminCreateGang', source, name, tag, target)
end, 'admin')

QBCore.Commands.Add('cf_deletegang', '[Admin] Gangı sil', {
    { name = 'gangId', help = 'Gang ID' },
}, true, function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end
    TriggerEvent('cross-factions:internal:adminDeleteGang', source, tonumber(args[1]))
end, 'admin')

QBCore.Commands.Add('cf_resetturf', '[Admin] Turf sıfırla', {
    { name = 'turfId', help = 'Turf ID' },
}, true, function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end
    TriggerEvent('cross-factions:internal:adminResetTurf', source, tonumber(args[1]))
end, 'admin')

QBCore.Commands.Add('cf_setturf', '[Admin] Turf sahibini değiştir', {
    { name = 'turfId', help = 'Turf ID' },
    { name = 'gangId', help = 'Gang ID' },
}, true, function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end
    TriggerEvent('cross-factions:internal:adminSetTurfOwner', source, tonumber(args[1]), tonumber(args[2]))
end, 'admin')

QBCore.Commands.Add('cf_endwar', '[Admin] Savaşı bitir', {
    { name = 'warId', help = 'War ID' },
}, true, function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end
    TriggerEvent('cross-factions:internal:adminEndWar', source, tonumber(args[1]))
end, 'admin')

QBCore.Commands.Add('cf_addrep', '[Admin] İtibar ekle/çıkar', {
    { name = 'gangId', help = 'Gang ID' },
    { name = 'amount', help = 'Miktar (negatif olabilir)' },
}, true, function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end
    TriggerEvent('cross-factions:internal:adminAddRep', source, tonumber(args[1]), tonumber(args[2]))
end, 'admin')

QBCore.Commands.Add('cf_clearspray', '[Admin] Spray temizle', {
    { name = 'sprayId', help = 'Spray ID (0 = hepsini temizle)' },
}, true, function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end
    TriggerEvent('cross-factions:internal:adminClearSpray', source, tonumber(args[1]))
end, 'admin')

-- ─── Admin Event Handler'ları ─────────────────────────────────────────────────
AddEventHandler('cross-factions:internal:adminResetTurf', function(adminSrc, turfId)
    MySQL.update('UPDATE cf_turf_ownership SET owner_gang_id = NULL, cooldown_until = NULL WHERE turf_id = ?',
        { turfId }, function()
            if TurfCache[turfId] then
                TurfCache[turfId].owner         = nil
                TurfCache[turfId].cooldownUntil = 0
            end
            TriggerClientEvent('cross-factions:client:turfOwnerChanged', -1, turfId, nil)
            local turfName = 'ID:' .. turfId
            for _, t in ipairs(Config.Turfs) do
                if t.id == turfId then turfName = t.name break end
            end
            TriggerClientEvent('QBCore:Notify', adminSrc, T('admin_turf_reset', turfName), 'success')
            LogAdmin('Turf Sıfırlandı', ('Admin [%d] tarafından Turf #%d sıfırlandı.'):format(adminSrc, turfId))
        end)
end)

AddEventHandler('cross-factions:internal:adminSetTurfOwner', function(adminSrc, turfId, gangId)
    MySQL.update('INSERT INTO cf_turf_ownership (turf_id, owner_gang_id, captured_at) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE owner_gang_id = ?, captured_at = NOW()',
        { turfId, gangId, gangId }, function()
            if not TurfCache[turfId] then TurfCache[turfId] = {} end
            TurfCache[turfId].owner = gangId
            TriggerClientEvent('cross-factions:client:turfOwnerChanged', -1, turfId, gangId)
            TriggerClientEvent('QBCore:Notify', adminSrc, T('admin_turf_owner_set', turfId, gangId), 'success')
            LogAdmin('Turf Sahibi Değiştirildi', ('Admin [%d] Turf #%d sahibini Gang #%d yaptı.'):format(adminSrc, turfId, gangId))
        end)
end)

AddEventHandler('cross-factions:internal:adminEndWar', function(adminSrc, warId)
    TriggerEvent('cross-factions:internal:resolveWar', warId, nil) -- beraberlik
    TriggerClientEvent('QBCore:Notify', adminSrc, T('admin_war_ended'), 'success')
    LogAdmin('Savaş Sonlandırıldı', ('Admin [%d] War #%d savaşını sonlandırdı.'):format(adminSrc, warId))
end)

AddEventHandler('cross-factions:internal:adminAddRep', function(adminSrc, gangId, amount)
    MySQL.update('UPDATE cf_gangs SET reputation = reputation + ? WHERE id = ?', { amount, gangId }, function()
        if GangCache[gangId] then
            GangCache[gangId].reputation = (GangCache[gangId].reputation or 0) + amount
        end
        TriggerClientEvent('QBCore:Notify', adminSrc, T('admin_rep_added', amount, gangId), 'success')
        LogAdmin('İtibar Eklendi', ('Admin [%d] Gang #%d\'ye %d itibar ekledi.'):format(adminSrc, gangId, amount))
    end)
end)

AddEventHandler('cross-factions:internal:adminClearSpray', function(adminSrc, sprayId)
    if sprayId == 0 then
        MySQL.update('DELETE FROM cf_gang_sprays', {}, function()
            SprayCache = {}
            TriggerClientEvent('cross-factions:client:clearAllSprays', -1)
        end)
    else
        MySQL.update('DELETE FROM cf_gang_sprays WHERE id = ?', { sprayId }, function()
            SprayCache[sprayId] = nil
            TriggerClientEvent('cross-factions:client:removeSpray', -1, sprayId)
        end)
    end
    TriggerClientEvent('QBCore:Notify', adminSrc, T('admin_spray_cleared'), 'success')
    LogAdmin('Spray Temizlendi', ('Admin [%d] spray temizledi (id=%d).'):format(adminSrc, sprayId))
end)
