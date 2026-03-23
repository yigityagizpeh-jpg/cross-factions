--[[
    server/gang.lua — Gang Yönetim Sistemi
    Gang oluşturma, silme, üye yönetimi, terfi/düşürme,
    kasa işlemleri ve boss menüsü event handler'ları.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Yardımcı: Gang var mı? ───────────────────────────────────────────────────
local function GangExists(gangId)
    return GangCache[gangId] ~= nil
end

-- ─── Yardımcı: Oyuncunun yetki kontrolü ──────────────────────────────────────
local function HasGangPerm(cid, perm)
    local m = MemberCache[cid]
    if not m then return false end
    local rankData = Config.GangRanks[m.rankIndex]
    if not rankData then return false end
    return rankData.perms[perm] == true
end

-- ─── Yardımcı: İsmin benzersiz olup olmadığını kontrol et ────────────────────
local function IsGangNameUnique(name, cb)
    MySQL.scalar('SELECT COUNT(*) FROM cf_gangs WHERE LOWER(name) = LOWER(?)', { name }, function(count)
        cb(tonumber(count) == 0)
    end)
end

-- ─── Callback: Gang bilgisi getir ────────────────────────────────────────────
QBCore.Functions.CreateCallback('cross-factions:cb:getMyGang', function(source, cb)
    local cid = GetCitizenId(source)
    if not cid then cb(nil) return end
    local m = MemberCache[cid]
    if not m then cb(nil) return end
    local gang = GangCache[m.gangId]
    if not gang then cb(nil) return end

    -- Üye listesini DB'den çek
    MySQL.query(
        'SELECT gm.citizenid, gm.rank_index, p.charinfo FROM cf_gang_members gm JOIN players p ON p.citizenid = gm.citizenid WHERE gm.gang_id = ?',
        { m.gangId },
        function(members)
            local memberList = {}
            for _, mem in ipairs(members or {}) do
                local charinfo = type(mem.charinfo) == 'string' and json.decode(mem.charinfo) or mem.charinfo
                memberList[#memberList + 1] = {
                    citizenid  = mem.citizenid,
                    rankIndex  = mem.rank_index,
                    rankLabel  = Config.GangRanks[mem.rank_index] and Config.GangRanks[mem.rank_index].label or '?',
                    name       = charinfo and (charinfo.firstname .. ' ' .. charinfo.lastname) or 'Bilinmiyor',
                }
            end
            cb({
                gang    = gang,
                myRank  = m.rankIndex,
                members = memberList,
                perms   = Config.GangRanks[m.rankIndex] and Config.GangRanks[m.rankIndex].perms or {},
            })
        end
    )
end)

-- ─── Callback: Tüm gang listesi (leaderboard için) ───────────────────────────
QBCore.Functions.CreateCallback('cross-factions:cb:getAllGangs', function(source, cb)
    cb(GangCache)
end)

-- ─── Event: Gang oluştur ──────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:createGang', function(name, tag, color)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid then return end

    -- Zaten gangde mi?
    if MemberCache[cid] then
        TriggerClientEvent('QBCore:Notify', source, T('already_in_gang'), 'error')
        return
    end

    -- İsim uzunluğu kontrolü
    if #name < Config.GangCreation.MinNameLength or #name > Config.GangCreation.MaxNameLength then
        TriggerClientEvent('QBCore:Notify', source, T('gang_name_invalid', Config.GangCreation.MinNameLength, Config.GangCreation.MaxNameLength), 'error')
        return
    end

    -- Tag uzunluğu
    if #tag > Config.GangCreation.MaxTagLength then
        TriggerClientEvent('QBCore:Notify', source, T('gang_tag_invalid', Config.GangCreation.MaxTagLength), 'error')
        return
    end

    -- Maksimum gang sayısı
    local gangCount = 0
    for _ in pairs(GangCache) do gangCount = gangCount + 1 end
    if gangCount >= Config.GangCreation.MaxGangs then
        TriggerClientEvent('QBCore:Notify', source, T('gang_max_reached'), 'error')
        return
    end

    -- Admin izni şartı
    if Config.GangCreation.RequireAdmin and not IsAdmin(source) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    -- Para şartı
    if Config.GangCreation.RequireMoney then
        local player = GetPlayer(source)
        local cash   = player.Functions.GetMoney('cash')
        local bank   = player.Functions.GetMoney('bank')
        if (cash + bank) < Config.GangCreation.MoneyAmount then
            TriggerClientEvent('QBCore:Notify', source, T('not_enough_money', Config.GangCreation.MoneyAmount), 'error')
            return
        end
        -- Önce bankadan çek, yetmezse cash'den
        local fromBank = math.min(bank, Config.GangCreation.MoneyAmount)
        local fromCash = Config.GangCreation.MoneyAmount - fromBank
        player.Functions.RemoveMoney('bank', fromBank, 'gang-creation')
        if fromCash > 0 then
            player.Functions.RemoveMoney('cash', fromCash, 'gang-creation')
        end
    end

    -- Item şartı
    if Config.GangCreation.RequireItem then
        local hasItem = exports.ox_inventory:Search(source, 'count', Config.GangCreation.ItemName)
        if not hasItem or hasItem < 1 then
            TriggerClientEvent('QBCore:Notify', source, T('not_enough_item', Config.GangCreation.ItemName), 'error')
            return
        end
        exports.ox_inventory:RemoveItem(source, Config.GangCreation.ItemName, 1)
    end

    -- İsim benzersizliği
    IsGangNameUnique(name, function(unique)
        if not unique then
            TriggerClientEvent('QBCore:Notify', source, T('gang_name_taken'), 'error')
            return
        end

        -- Gang'i DB'ye ekle
        MySQL.insert(
            'INSERT INTO cf_gangs (name, tag, color, leader_cid, treasury, level, reputation, settings, created_at) VALUES (?, ?, ?, ?, 0, 1, 0, ?, NOW())',
            { name, tag, color or '#FF0000', cid, json.encode({}) },
            function(gangId)
                if not gangId then
                    TriggerClientEvent('QBCore:Notify', source, T('gang_create_fail'), 'error')
                    return
                end

                -- Lideri üye tablosuna ekle (rank 5 = Leader)
                MySQL.insert(
                    'INSERT INTO cf_gang_members (gang_id, citizenid, rank_index, joined_at) VALUES (?, ?, 5, NOW())',
                    { gangId, cid },
                    function()
                        -- Cache güncelle
                        GangCache[gangId] = {
                            id         = gangId,
                            name       = name,
                            tag        = tag,
                            color      = color or '#FF0000',
                            leader_cid = cid,
                            treasury   = 0,
                            level      = 1,
                            reputation = 0,
                            settings   = {},
                        }
                        MemberCache[cid] = { gangId = gangId, rankIndex = 5 }

                        TriggerClientEvent('QBCore:Notify', source, T('gang_created', name), 'success')
                        LogGang('Gang Oluşturuldu', ('**%s** [%s] gangı oluşturuldu. Lider CID: %s'):format(name, tag, cid))
                    end
                )
            end
        )
    end)
end)

-- ─── Admin: Gang oluştur ──────────────────────────────────────────────────────
AddEventHandler('cross-factions:internal:adminCreateGang', function(adminSrc, name, tag, targetSrc)
    local targetCid = GetCitizenId(targetSrc)
    if not targetCid then
        TriggerClientEvent('QBCore:Notify', adminSrc, T('player_not_found'), 'error')
        return
    end
    if MemberCache[targetCid] then
        TriggerClientEvent('QBCore:Notify', adminSrc, T('already_in_gang'), 'error')
        return
    end
    IsGangNameUnique(name, function(unique)
        if not unique then
            TriggerClientEvent('QBCore:Notify', adminSrc, T('gang_name_taken'), 'error')
            return
        end
        MySQL.insert(
            'INSERT INTO cf_gangs (name, tag, color, leader_cid, treasury, level, reputation, settings, created_at) VALUES (?, ?, ?, ?, 0, 1, 0, ?, NOW())',
            { name, tag or name:sub(1, 4), '#FF0000', targetCid, json.encode({}) },
            function(gangId)
                if not gangId then return end
                MySQL.insert('INSERT INTO cf_gang_members (gang_id, citizenid, rank_index, joined_at) VALUES (?, ?, 5, NOW())',
                    { gangId, targetCid }, function()
                        GangCache[gangId] = { id = gangId, name = name, tag = tag, color = '#FF0000', leader_cid = targetCid, treasury = 0, level = 1, reputation = 0, settings = {} }
                        MemberCache[targetCid] = { gangId = gangId, rankIndex = 5 }
                        TriggerClientEvent('QBCore:Notify', adminSrc, T('admin_gang_created', name), 'success')
                        LogAdmin('Gang Oluşturuldu (Admin)', ('Admin [%d] tarafından %s gangı oluşturuldu. Lider: %s'):format(adminSrc, name, targetCid))
                    end)
            end
        )
    end)
end)

-- ─── Admin: Gang sil ──────────────────────────────────────────────────────────
AddEventHandler('cross-factions:internal:adminDeleteGang', function(adminSrc, gangId)
    if not GangExists(gangId) then
        TriggerClientEvent('QBCore:Notify', adminSrc, 'Gang bulunamadı.', 'error')
        return
    end
    local gangName = GangCache[gangId].name
    -- Tüm üyelerin cache'ini temizle
    for cid, m in pairs(MemberCache) do
        if m.gangId == gangId then
            MemberCache[cid] = nil
        end
    end
    GangCache[gangId] = nil
    MySQL.update('DELETE FROM cf_gangs WHERE id = ?', { gangId }, function()
        TriggerClientEvent('QBCore:Notify', adminSrc, T('admin_gang_deleted', gangName), 'success')
        LogAdmin('Gang Silindi', ('Admin [%d] tarafından Gang #%d (%s) silindi.'):format(adminSrc, gangId, gangName))
    end)
end)

-- ─── Event: Ganga davet et ────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:invitePlayer', function(targetSrc)
    local source  = source
    local srcCid  = GetCitizenId(source)
    if not srcCid then return end

    if not HasGangPerm(srcCid, 'canInvite') then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    local targetCid = GetCitizenId(targetSrc)
    if not targetCid then
        TriggerClientEvent('QBCore:Notify', source, T('player_not_found'), 'error')
        return
    end

    if MemberCache[targetCid] then
        TriggerClientEvent('QBCore:Notify', source, T('already_in_gang'), 'error')
        return
    end

    local gangName = GangCache[MemberCache[srcCid].gangId].name
    local gangId   = MemberCache[srcCid].gangId

    -- Hedef oyuncuya davet bildirimi gönder
    TriggerClientEvent('cross-factions:client:gangInvite', targetSrc, gangId, gangName, source)
    TriggerClientEvent('QBCore:Notify', source, T('gang_invite_sent', GetPlayer(targetSrc) and (GetPlayer(targetSrc).PlayerData.charinfo.firstname) or '?'), 'success')
end)

-- ─── Event: Daveti kabul et ───────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:acceptInvite', function(gangId)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid then return end
    if MemberCache[cid] then
        TriggerClientEvent('QBCore:Notify', source, T('already_in_gang'), 'error')
        return
    end
    if not GangExists(gangId) then return end

    MySQL.insert('INSERT INTO cf_gang_members (gang_id, citizenid, rank_index, joined_at) VALUES (?, ?, 1, NOW())',
        { gangId, cid },
        function(id)
            if not id then
                TriggerClientEvent('QBCore:Notify', source, T('gang_join_fail'), 'error')
                return
            end
            MemberCache[cid] = { gangId = gangId, rankIndex = 1 }
            local gangName = GangCache[gangId].name
            TriggerClientEvent('QBCore:Notify', source, T('gang_joined', gangName), 'success')
            LogGang('Üye Katıldı', ('**%s** gangına **%s** katıldı.'):format(gangName, cid))
        end
    )
end)

-- ─── Event: Gangdan ayrıl ─────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:leaveGang', function()
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then
        TriggerClientEvent('QBCore:Notify', source, T('no_gang'), 'error')
        return
    end

    local gangId = MemberCache[cid].gangId
    -- Lider ayrılamaz (önce transfer etmeli)
    if GangCache[gangId] and GangCache[gangId].leader_cid == cid then
        TriggerClientEvent('QBCore:Notify', source, 'Lider olarak gangdan ayrılamazsınız. Önce liderliği devredin.', 'error')
        return
    end

    MySQL.update('DELETE FROM cf_gang_members WHERE citizenid = ? AND gang_id = ?', { cid, gangId }, function()
        MemberCache[cid] = nil
        TriggerClientEvent('QBCore:Notify', source, T('gang_left'), 'success')
    end)
end)

-- ─── Event: Üyeyi kickle ─────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:kickMember', function(targetCid)
    local source = source
    local srcCid = GetCitizenId(source)
    if not srcCid then return end

    if not HasGangPerm(srcCid, 'canKick') then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    local m = MemberCache[srcCid]
    local targetM = MemberCache[targetCid]
    if not targetM or targetM.gangId ~= m.gangId then
        TriggerClientEvent('QBCore:Notify', source, T('player_not_found'), 'error')
        return
    end

    -- Daha yüksek veya eşit rütbeye kick atamazsın
    if targetM.rankIndex >= m.rankIndex then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    -- Lider kicklenemez
    if GangCache[m.gangId] and GangCache[m.gangId].leader_cid == targetCid then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    MySQL.update('DELETE FROM cf_gang_members WHERE citizenid = ? AND gang_id = ?',
        { targetCid, m.gangId },
        function()
            MemberCache[targetCid] = nil
            -- Hedef oyuncu online ise bildir
            local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCid)
            if targetPlayer then
                TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, T('gang_kicked', GangCache[m.gangId].name), 'error')
            end
            TriggerClientEvent('QBCore:Notify', source, T('gang_kick_success', targetCid), 'success')
            LogGang('Üye Atıldı', ('**%s** gangından **%s** atıldı. (Yetkili: %s)'):format(GangCache[m.gangId].name, targetCid, srcCid))
        end
    )
end)

-- ─── Event: Terfi / Düşürme ───────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:setMemberRank', function(targetCid, newRankIndex)
    local source = source
    local srcCid = GetCitizenId(source)
    if not srcCid then return end

    -- Validasyon
    if not HasGangPerm(srcCid, 'canPromote') then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end
    if newRankIndex < 1 or newRankIndex > 5 then return end

    local m      = MemberCache[srcCid]
    local targetM = MemberCache[targetCid]
    if not targetM or targetM.gangId ~= m.gangId then
        TriggerClientEvent('QBCore:Notify', source, T('player_not_found'), 'error')
        return
    end

    -- Kendi rütbesinden yükseğine terfi ettiremezsin
    if newRankIndex >= m.rankIndex then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    MySQL.update('UPDATE cf_gang_members SET rank_index = ? WHERE citizenid = ? AND gang_id = ?',
        { newRankIndex, targetCid, m.gangId },
        function()
            MemberCache[targetCid].rankIndex = newRankIndex
            local rankLabel = Config.GangRanks[newRankIndex].label
            -- Hedef oyuncuya bildir
            local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCid)
            if targetPlayer then
                TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, T('gang_promoted', rankLabel), 'success')
            end
            TriggerClientEvent('QBCore:Notify', source, T('gang_promote_success', targetCid), 'success')
        end
    )
end)

-- ─── Event: Liderliği devret ──────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:transferLeadership', function(targetCid)
    local source = source
    local srcCid = GetCitizenId(source)
    if not srcCid then return end

    local m = MemberCache[srcCid]
    if not m then
        TriggerClientEvent('QBCore:Notify', source, T('no_gang'), 'error')
        return
    end

    -- Sadece lider devredebilir
    if GangCache[m.gangId].leader_cid ~= srcCid then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    local targetM = MemberCache[targetCid]
    if not targetM or targetM.gangId ~= m.gangId then
        TriggerClientEvent('QBCore:Notify', source, T('player_not_found'), 'error')
        return
    end

    MySQL.update('UPDATE cf_gangs SET leader_cid = ? WHERE id = ?', { targetCid, m.gangId }, function()
        MySQL.update('UPDATE cf_gang_members SET rank_index = 5 WHERE citizenid = ? AND gang_id = ?',
            { targetCid, m.gangId }, function()
                MySQL.update('UPDATE cf_gang_members SET rank_index = 4 WHERE citizenid = ? AND gang_id = ?',
                    { srcCid, m.gangId }, function()
                        GangCache[m.gangId].leader_cid = targetCid
                        MemberCache[targetCid].rankIndex = 5
                        MemberCache[srcCid].rankIndex    = 4
                        TriggerClientEvent('QBCore:Notify', source, T('gang_leader_transfer', targetCid), 'success')
                        LogGang('Liderlik Devredildi', ('**%s** gangında liderlik **%s** → **%s** olarak devredildi.'):format(GangCache[m.gangId].name, srcCid, targetCid))
                    end)
            end)
    end)
end)

-- ─── Event: Kasa para yatır ───────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:depositTreasury', function(amount)
    local source = source
    local cid    = GetCitizenId(source)
    amount = tonumber(amount)
    if not cid or not amount or amount <= 0 then return end

    if not HasGangPerm(cid, 'canAccessTreasury') then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    local player = GetPlayer(source)
    local cash   = player.Functions.GetMoney('cash')
    local bank   = player.Functions.GetMoney('bank')
    if (cash + bank) < amount then
        TriggerClientEvent('QBCore:Notify', source, T('not_enough_money', amount), 'error')
        return
    end

    local gangId = MemberCache[cid].gangId
    local fromBank = math.min(bank, amount)
    local fromCash = amount - fromBank
    player.Functions.RemoveMoney('bank', fromBank, 'gang-treasury-deposit')
    if fromCash > 0 then
        player.Functions.RemoveMoney('cash', fromCash, 'gang-treasury-deposit')
    end

    MySQL.update('UPDATE cf_gangs SET treasury = LEAST(treasury + ?, ?) WHERE id = ?',
        { amount, Config.Economy.MaxTreasury, gangId },
        function()
            if GangCache[gangId] then
                GangCache[gangId].treasury = math.min((GangCache[gangId].treasury or 0) + amount, Config.Economy.MaxTreasury)
            end
            TriggerClientEvent('QBCore:Notify', source, T('treasury_deposit', amount), 'success')
            MySQL.insert('INSERT INTO cf_finance_logs (gang_id, type, amount, description, created_at) VALUES (?, ?, ?, ?, NOW())',
                { gangId, 'deposit', amount, 'Kasa para yatırma: ' .. cid })
            LogFinance('Kasa Para Yatırma', ('**CID:** %s\n**Gang:** %s\n**Miktar:** $%d'):format(cid, GangCache[gangId].name, amount))
        end
    )
end)

-- ─── Event: Kasadan para çek ──────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:withdrawTreasury', function(amount)
    local source = source
    local cid    = GetCitizenId(source)
    amount = tonumber(amount)
    if not cid or not amount or amount <= 0 then return end

    if not HasGangPerm(cid, 'canAccessTreasury') then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    local gangId = MemberCache[cid].gangId
    local treasury = GangCache[gangId] and GangCache[gangId].treasury or 0
    if treasury < amount then
        TriggerClientEvent('QBCore:Notify', source, T('treasury_no_funds'), 'error')
        return
    end

    MySQL.update('UPDATE cf_gangs SET treasury = treasury - ? WHERE id = ? AND treasury >= ?',
        { amount, gangId, amount },
        function(rowsAffected)
            if rowsAffected == 0 then
                TriggerClientEvent('QBCore:Notify', source, T('treasury_no_funds'), 'error')
                return
            end
            if GangCache[gangId] then
                GangCache[gangId].treasury = GangCache[gangId].treasury - amount
            end
            local player = GetPlayer(source)
            player.Functions.AddMoney('bank', amount, 'gang-treasury-withdraw')
            TriggerClientEvent('QBCore:Notify', source, T('treasury_withdraw', amount), 'success')
            MySQL.insert('INSERT INTO cf_finance_logs (gang_id, type, amount, description, created_at) VALUES (?, ?, ?, ?, NOW())',
                { gangId, 'withdraw', amount, 'Kasa para çekme: ' .. cid })
            LogFinance('Kasa Para Çekme', ('**CID:** %s\n**Gang:** %s\n**Miktar:** $%d'):format(cid, GangCache[gangId].name, amount))
        end
    )
end)

-- ─── Event: Stash aç ─────────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:openStash', function(stashType)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then
        TriggerClientEvent('QBCore:Notify', source, T('no_gang'), 'error')
        return
    end

    local perm = stashType == 'armory' and 'canUseArmory' or 'canUseStash'
    if not HasGangPerm(cid, perm) then
        TriggerClientEvent('QBCore:Notify', source, stashType == 'armory' and T('armory_access_denied') or T('stash_access_denied'), 'error')
        return
    end

    local gangId   = MemberCache[cid].gangId
    local stashId  = 'cf_gang_' .. stashType .. '_' .. gangId
    local slots    = stashType == 'armory' and Config.Stash.ArmorySlots or Config.Stash.Slots
    local weight   = stashType == 'armory' and Config.Stash.ArmoryWeight or Config.Stash.Weight

    exports.ox_inventory:openInventory(source, { type = 'stash', id = stashId, slots = slots, maxWeight = weight })

    if stashType == 'armory' then
        LogGang('Armory Erişimi', ('**CID:** %s | **Gang:** #%d | **Stash:** %s'):format(cid, gangId, stashId))
    end
end)
