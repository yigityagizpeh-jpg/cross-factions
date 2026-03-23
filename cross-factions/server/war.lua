--[[
    server/war.lua — Alliance ve War (Savaş) Sistemi
    Gang arası ittifak, savaş ilanı, skor takibi,
    savaş sonlandırma ve itibar/ödül işlemleri.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Bekleyen davetler ────────────────────────────────────────────────────────
-- "type:fromGangId:toGangId" → { timer, expiresAt }
local PendingInvites = {}

-- ─── Yardımcı: İki gang arasındaki war'ı bul ─────────────────────────────────
local function FindActiveWar(gangA, gangB)
    for warId, war in pairs(WarCache) do
        if war.status == 'active' then
            if (war.gang1_id == gangA and war.gang2_id == gangB) or
               (war.gang1_id == gangB and war.gang2_id == gangA) then
                return warId, war
            end
        end
    end
    return nil, nil
end

-- ─── Yardımcı: İki gang arasında ittifak var mı? ─────────────────────────────
local function AreAllied(gangA, gangB)
    local key = math.min(gangA, gangB) .. ':' .. math.max(gangA, gangB)
    return AllyCache[key] == true
end

-- ─── Callback: Gang ilişkilerini getir ───────────────────────────────────────
QBCore.Functions.CreateCallback('cross-factions:cb:getRelations', function(source, cb)
    local cid = GetCitizenId(source)
    if not cid or not MemberCache[cid] then cb({}) return end
    local gangId = MemberCache[cid].gangId

    local relations = { allies = {}, enemies = {}, activeWar = nil }

    -- Alliance
    for key, _ in pairs(AllyCache) do
        local parts = {}
        for part in key:gmatch('([^:]+)') do parts[#parts + 1] = tonumber(part) end
        if parts[1] == gangId or parts[2] == gangId then
            local allyId = parts[1] == gangId and parts[2] or parts[1]
            relations.allies[#relations.allies + 1] = {
                gangId = allyId,
                name   = GangCache[allyId] and GangCache[allyId].name or '?',
            }
        end
    end

    -- Active wars
    for warId, war in pairs(WarCache) do
        if war.status == 'active' and (war.gang1_id == gangId or war.gang2_id == gangId) then
            local enemyId = war.gang1_id == gangId and war.gang2_id or war.gang1_id
            relations.enemies[#relations.enemies + 1] = {
                warId    = warId,
                gangId   = enemyId,
                name     = GangCache[enemyId] and GangCache[enemyId].name or '?',
                myKills  = war.gang1_id == gangId and war.gang1_kills or war.gang2_kills,
                theirKills = war.gang1_id == gangId and war.gang2_kills or war.gang1_kills,
                startsAt = war.starts_at,
                endsAt   = war.ends_at,
            }
        end
    end

    cb(relations)
end)

-- ─── Event: Alliance teklif gönder ───────────────────────────────────────────
RegisterNetEvent('cross-factions:server:sendAllianceRequest', function(targetGangId)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then
        TriggerClientEvent('QBCore:Notify', source, T('no_gang'), 'error')
        return
    end

    if not QBCore.Functions.GetPlayer(source) then return end
    if not MemberCache[cid] then return end

    local m = MemberCache[cid]
    if not (Config.GangRanks[m.rankIndex] and Config.GangRanks[m.rankIndex].perms.canManageWar) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    local myGangId = m.gangId
    if myGangId == targetGangId then return end
    if not GangCache[targetGangId] then return end

    -- Zaten ittifak var mı?
    if AreAllied(myGangId, targetGangId) then
        TriggerClientEvent('QBCore:Notify', source, T('already_allied'), 'error')
        return
    end

    local inviteKey = 'alliance:' .. myGangId .. ':' .. targetGangId
    if PendingInvites[inviteKey] then return end  -- zaten bekliyor

    PendingInvites[inviteKey] = { expiresAt = os.time() + Config.War.AllianceAcceptTimeout }

    -- Hedef gangin online üyelerine (özellikle lidere) bildir
    local players = QBCore.Functions.GetQBPlayers()
    local myGangName = GangCache[myGangId].name
    for _, player in pairs(players) do
        local pcid = player.PlayerData.citizenid
        if MemberCache[pcid] and MemberCache[pcid].gangId == targetGangId then
            local ri = MemberCache[pcid].rankIndex
            if Config.GangRanks[ri] and Config.GangRanks[ri].perms.canManageWar then
                TriggerClientEvent('cross-factions:client:allianceRequest', player.PlayerData.source, myGangId, myGangName)
                TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('alliance_received', myGangName), 'info')
            end
        end
    end

    TriggerClientEvent('QBCore:Notify', source, T('alliance_sent', GangCache[targetGangId].name), 'success')

    -- Timeout: invite iptal et
    SetTimeout(Config.War.AllianceAcceptTimeout * 1000, function()
        PendingInvites[inviteKey] = nil
    end)
end)

-- ─── Event: Alliance kabul/ret ────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:respondAlliance', function(fromGangId, accept)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then return end

    local myGangId = MemberCache[cid].gangId
    local inviteKey = 'alliance:' .. fromGangId .. ':' .. myGangId
    if not PendingInvites[inviteKey] then return end
    PendingInvites[inviteKey] = nil

    local fromGangName = GangCache[fromGangId] and GangCache[fromGangId].name or '?'
    local myGangName   = GangCache[myGangId]   and GangCache[myGangId].name   or '?'

    if not accept then
        -- Ret
        local players = QBCore.Functions.GetQBPlayers()
        for _, player in pairs(players) do
            local pcid = player.PlayerData.citizenid
            if MemberCache[pcid] and MemberCache[pcid].gangId == fromGangId then
                TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('alliance_rejected', myGangName), 'error')
            end
        end
        return
    end

    -- Kabul
    local allyKey = math.min(fromGangId, myGangId) .. ':' .. math.max(fromGangId, myGangId)
    AllyCache[allyKey] = true

    MySQL.insert(
        'INSERT INTO cf_gang_alliances (gang1_id, gang2_id, status, created_at) VALUES (?, ?, ?, NOW()) ON DUPLICATE KEY UPDATE status = ?',
        { math.min(fromGangId, myGangId), math.max(fromGangId, myGangId), 'active', 'active' },
        function()
            -- Her iki gangin üyelerine bildir
            local players = QBCore.Functions.GetQBPlayers()
            for _, player in pairs(players) do
                local pcid = player.PlayerData.citizenid
                if MemberCache[pcid] then
                    local gId = MemberCache[pcid].gangId
                    if gId == fromGangId then
                        TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('alliance_accepted', myGangName), 'success')
                    elseif gId == myGangId then
                        TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('alliance_accepted', fromGangName), 'success')
                    end
                end
            end
            LogGang('İttifak Kuruldu', ('**%s** ↔ **%s** ittifak kurdu.'):format(fromGangName, myGangName))
        end
    )
end)

-- ─── Event: Alliance boz ─────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:breakAlliance', function(targetGangId)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then return end

    local m = MemberCache[cid]
    if not (Config.GangRanks[m.rankIndex] and Config.GangRanks[m.rankIndex].perms.canManageWar) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    local myGangId = m.gangId
    local allyKey  = math.min(myGangId, targetGangId) .. ':' .. math.max(myGangId, targetGangId)
    if not AllyCache[allyKey] then return end

    AllyCache[allyKey] = nil
    MySQL.update("UPDATE cf_gang_alliances SET status = 'broken' WHERE (gang1_id = ? AND gang2_id = ?) OR (gang1_id = ? AND gang2_id = ?)",
        { myGangId, targetGangId, targetGangId, myGangId },
        function()
            TriggerClientEvent('QBCore:Notify', source, T('alliance_broken', GangCache[targetGangId] and GangCache[targetGangId].name or '?'), 'success')
        end
    )
end)

-- ─── Event: War ilan et ───────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:declareWar', function(targetGangId)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then
        TriggerClientEvent('QBCore:Notify', source, T('no_gang'), 'error')
        return
    end

    local m = MemberCache[cid]
    if not (Config.GangRanks[m.rankIndex] and Config.GangRanks[m.rankIndex].perms.canManageWar) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    local myGangId = m.gangId
    if myGangId == targetGangId then return end
    if not GangCache[targetGangId] then return end

    -- İttifak varsa war ilanı yapılamaz
    if AreAllied(myGangId, targetGangId) then
        TriggerClientEvent('QBCore:Notify', source, T('no_war_with_ally'), 'error')
        return
    end

    -- Zaten aktif savaş var mı?
    local existingWarId, _ = FindActiveWar(myGangId, targetGangId)
    if existingWarId then
        TriggerClientEvent('QBCore:Notify', source, T('war_already_active'), 'error')
        return
    end

    -- Maksimum aktif savaş sayısı kontrolü
    local activeWarCount = 0
    for _, war in pairs(WarCache) do
        if war.status == 'active' then activeWarCount = activeWarCount + 1 end
    end
    if activeWarCount >= Config.War.MaxActiveWars then
        TriggerClientEvent('QBCore:Notify', source, 'Maksimum aktif savaş sayısına ulaşıldı.', 'error')
        return
    end

    local inviteKey = 'war:' .. myGangId .. ':' .. targetGangId
    if PendingInvites[inviteKey] then return end
    PendingInvites[inviteKey] = { expiresAt = os.time() + Config.War.AcceptTimeout }

    -- Hedef gangın liderine/co-liderine bildir
    local players    = QBCore.Functions.GetQBPlayers()
    local myGangName = GangCache[myGangId].name
    for _, player in pairs(players) do
        local pcid = player.PlayerData.citizenid
        if MemberCache[pcid] and MemberCache[pcid].gangId == targetGangId then
            local ri = MemberCache[pcid].rankIndex
            if Config.GangRanks[ri] and Config.GangRanks[ri].perms.canManageWar then
                TriggerClientEvent('cross-factions:client:warRequest', player.PlayerData.source, myGangId, myGangName)
                TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('war_received', myGangName), 'error')
            end
        end
    end

    TriggerClientEvent('QBCore:Notify', source, T('war_declared', GangCache[targetGangId].name), 'success')

    SetTimeout(Config.War.AcceptTimeout * 1000, function()
        PendingInvites[inviteKey] = nil
    end)
end)

-- ─── Event: War kabul/ret ─────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:respondWar', function(fromGangId, accept)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then return end

    local myGangId  = MemberCache[cid].gangId
    local inviteKey = 'war:' .. fromGangId .. ':' .. myGangId
    if not PendingInvites[inviteKey] then return end
    PendingInvites[inviteKey] = nil

    local fromGangName = GangCache[fromGangId] and GangCache[fromGangId].name or '?'
    local myGangName   = GangCache[myGangId]   and GangCache[myGangId].name   or '?'

    if not accept then
        local players = QBCore.Functions.GetQBPlayers()
        for _, player in pairs(players) do
            local pcid = player.PlayerData.citizenid
            if MemberCache[pcid] and MemberCache[pcid].gangId == fromGangId then
                TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('war_rejected', myGangName), 'error')
            end
        end
        return
    end

    -- Savaşı DB'ye kaydet
    local endsAt = os.time() + Config.War.DefaultWarDuration
    MySQL.insert(
        'INSERT INTO cf_gang_wars (gang1_id, gang2_id, gang1_kills, gang2_kills, status, starts_at, ends_at) VALUES (?, ?, 0, 0, ?, NOW(), FROM_UNIXTIME(?))',
        { fromGangId, myGangId, 'active', endsAt },
        function(warId)
            if not warId then return end

            WarCache[warId] = {
                id          = warId,
                gang1_id    = fromGangId,
                gang2_id    = myGangId,
                gang1_kills = 0,
                gang2_kills = 0,
                status      = 'active',
                ends_at     = endsAt,
            }

            -- Her iki gangin üyelerine bildir
            local players = QBCore.Functions.GetQBPlayers()
            for _, player in pairs(players) do
                local pcid = player.PlayerData.citizenid
                if MemberCache[pcid] then
                    local gId = MemberCache[pcid].gangId
                    if gId == fromGangId then
                        TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('war_accepted', myGangName), 'error')
                        TriggerClientEvent('cross-factions:client:warStarted', player.PlayerData.source, warId, myGangId)
                    elseif gId == myGangId then
                        TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('war_accepted', fromGangName), 'error')
                        TriggerClientEvent('cross-factions:client:warStarted', player.PlayerData.source, warId, fromGangId)
                    end
                end
            end

            LogWar('Savaş Başladı', ('**%s** ⚔️ **%s**\nBitiş: %s'):format(fromGangName, myGangName, os.date('%d/%m/%Y %H:%M', endsAt)))

            -- Savaş süresi dolunca otomatik sonlandır
            SetTimeout(Config.War.DefaultWarDuration * 1000, function()
                if WarCache[warId] and WarCache[warId].status == 'active' then
                    TriggerEvent('cross-factions:internal:resolveWar', warId, nil)
                end
            end)
        end
    )
end)

-- ─── Internal: War kill eventi ────────────────────────────────────────────────
AddEventHandler('cross-factions:internal:warKill', function(killerGangId, victimGangId, killerCid, victimCid)
    -- Bu iki gang arasında aktif savaş var mı?
    local warId, war = FindActiveWar(killerGangId, victimGangId)
    if not warId then return end

    -- Kill sayacını güncelle
    if war.gang1_id == killerGangId then
        war.gang1_kills = (war.gang1_kills or 0) + 1
        MySQL.update('UPDATE cf_gang_wars SET gang1_kills = gang1_kills + 1 WHERE id = ?', { warId })
    else
        war.gang2_kills = (war.gang2_kills or 0) + 1
        MySQL.update('UPDATE cf_gang_wars SET gang2_kills = gang2_kills + 1 WHERE id = ?', { warId })
    end

    -- Tüm savaştaki ganglere skor güncellemesi gönder
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        local pcid = player.PlayerData.citizenid
        if MemberCache[pcid] then
            local gId = MemberCache[pcid].gangId
            if gId == killerGangId or gId == victimGangId then
                TriggerClientEvent('cross-factions:client:warScoreUpdate', player.PlayerData.source, warId, war.gang1_kills, war.gang2_kills)
            end
        end
    end
end)

-- ─── Internal: War çözümle (bitir) ───────────────────────────────────────────
AddEventHandler('cross-factions:internal:resolveWar', function(warId, forceWinnerId)
    local war = WarCache[warId]
    if not war or war.status ~= 'active' then return end

    war.status = 'ended'
    MySQL.update("UPDATE cf_gang_wars SET status = 'ended', ends_at = NOW() WHERE id = ?", { warId })

    local g1 = war.gang1_id
    local g2 = war.gang2_id
    local k1 = war.gang1_kills or 0
    local k2 = war.gang2_kills or 0

    local winnerId, loserId
    if forceWinnerId then
        winnerId = forceWinnerId
        loserId  = winnerId == g1 and g2 or g1
    elseif k1 > k2 then
        winnerId = g1
        loserId  = g2
    elseif k2 > k1 then
        winnerId = g2
        loserId  = g1
    else
        -- Beraberlik: kimseye itibar değişimi yok
        winnerId = nil
        loserId  = nil
    end

    local winnerName = winnerId and GangCache[winnerId] and GangCache[winnerId].name or nil
    local loserName  = loserId  and GangCache[loserId]  and GangCache[loserId].name  or nil

    -- İtibar güncelle
    if winnerId then
        MySQL.update('UPDATE cf_gangs SET reputation = reputation + ? WHERE id = ?',
            { Config.War.WarEndReputationWin, winnerId }, function()
                if GangCache[winnerId] then
                    GangCache[winnerId].reputation = (GangCache[winnerId].reputation or 0) + Config.War.WarEndReputationWin
                end
            end)
        MySQL.update('UPDATE cf_gangs SET reputation = reputation + ? WHERE id = ?',
            { Config.War.WarEndReputationLose, loserId }, function()
                if GangCache[loserId] then
                    GangCache[loserId].reputation = (GangCache[loserId].reputation or 0) + Config.War.WarEndReputationLose
                end
            end)
    end

    -- Oyunculara bildir
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        local pcid = player.PlayerData.citizenid
        if MemberCache[pcid] then
            local gId = MemberCache[pcid].gangId
            if gId == g1 or gId == g2 then
                if not winnerId then
                    local enemyName = gId == g1 and (loserName or GangCache[g2] and GangCache[g2].name or '?') or (winnerName or GangCache[g1] and GangCache[g1].name or '?')
                    TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('war_ended_draw', enemyName), 'primary')
                elseif gId == winnerId then
                    TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('war_ended_win', loserName or '?', Config.War.WarEndReputationWin), 'success')
                else
                    TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('war_ended_lose', winnerName or '?', Config.War.WarEndReputationLose), 'error')
                end
                TriggerClientEvent('cross-factions:client:warEnded', player.PlayerData.source, warId)
            end
        end
    end

    LogWar('Savaş Bitti',
        ('**%s** ⚔️ **%s**\n**Skor:** %d - %d\n**Kazanan:** %s'):format(
            GangCache[g1] and GangCache[g1].name or g1,
            GangCache[g2] and GangCache[g2].name or g2,
            k1, k2,
            winnerName or 'Beraberlik'
        ))
end)

-- ─── Callback: Leaderboard verisi ────────────────────────────────────────────
QBCore.Functions.CreateCallback('cross-factions:cb:getLeaderboard', function(source, cb)
    -- Haftalık kill sayısına göre sıralama
    MySQL.query([[
        SELECT kl.killer_gang_id, cf.name, COUNT(*) as kills
        FROM cf_kill_logs kl
        JOIN cf_gangs cf ON cf.id = kl.killer_gang_id
        WHERE kl.killed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY kl.killer_gang_id
        ORDER BY kills DESC
        LIMIT ?
    ]], { Config.Leaderboard.TopGangsShown }, function(rows)
        local board = {}
        if rows then
            for i, row in ipairs(rows) do
                board[i] = {
                    rank      = i,
                    gangId    = row.killer_gang_id,
                    gangName  = row.name,
                    kills     = row.kills,
                    reputation = GangCache[row.killer_gang_id] and GangCache[row.killer_gang_id].reputation or 0,
                }
            end
        end
        cb(board)
    end)
end)
