--[[
    server/spray.lua — Spray (Bölge İşaretleme) Sistemi
    Spray noktaları, item kontrolü, cooldown ve veri yönetimi.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Spray Cooldown: citizenid → timestamp ────────────────────────────────────
local SprayCooldowns = {}

-- ─── Resource başlarken DB'deki spray'leri yükle ─────────────────────────────
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    MySQL.query('SELECT * FROM cf_gang_sprays WHERE expires_at > NOW()', {}, function(rows)
        if rows then
            for _, row in ipairs(rows) do
                SprayCache[row.id] = row
            end
        end
        DebugPrint(('Spray cache yüklendi: %d spray'):format(#(rows or {})))

        -- Tüm mevcut spray'leri clientlara gönder (resource restart durumu)
        -- Bu event resource start'tan sonra oyuncular bağlandığında PlayerLoaded ile de tetiklenir
    end)
end)

-- ─── Oyuncu yüklendiğinde mevcut spray'leri gönder ───────────────────────────
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    local activeSprays = {}
    for _, spray in pairs(SprayCache) do
        activeSprays[#activeSprays + 1] = spray
    end
    TriggerClientEvent('cross-factions:client:loadSprays', src, activeSprays)
end)

-- ─── Event: Spray yap ────────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:doSpray', function(pointIndex)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then
        TriggerClientEvent('QBCore:Notify', source, T('no_gang'), 'error')
        return
    end

    -- Rank kontrolü
    local m = MemberCache[cid]
    if not (Config.GangRanks[m.rankIndex] and Config.GangRanks[m.rankIndex].perms.canSpray) then
        TriggerClientEvent('QBCore:Notify', source, T('no_permission'), 'error')
        return
    end

    -- Spray noktası geçerli mi?
    local sprayPoint = Config.Spray.Points[pointIndex]
    if not sprayPoint then
        TriggerClientEvent('QBCore:Notify', source, T('spray_not_in_turf'), 'error')
        return
    end

    -- Cooldown kontrolü
    local now = os.time()
    if SprayCooldowns[cid] and (now - SprayCooldowns[cid]) < Config.Spray.Cooldown then
        TriggerClientEvent('QBCore:Notify', source, T('spray_cooldown'), 'error')
        return
    end

    -- Item kontrolü
    local hasItem = exports.ox_inventory:Search(source, 'count', Config.Spray.RequiredItem)
    if not hasItem or hasItem < 1 then
        TriggerClientEvent('QBCore:Notify', source, T('spray_no_item', Config.Spray.RequiredItem), 'error')
        return
    end

    -- Mesafe kontrolü (client'tan gelen index'e güvenme, server-side doğrula)
    local plyPed   = GetPlayerPed(source)
    local plyCoords = GetEntityCoords(plyPed)
    local spCoords = sprayPoint.coords
    local dist = #(vector3(plyCoords.x, plyCoords.y, plyCoords.z) - vector3(spCoords.x, spCoords.y, spCoords.z))
    if dist > Config.Spray.Range + 5.0 then  -- 5.0 tolerans
        TriggerClientEvent('QBCore:Notify', source, 'Spray noktasına yeterince yakın değilsiniz.', 'error')
        DebugPrint(('Spray mesafe ihlali: %s, dist=%.1f'):format(cid, dist))
        return
    end

    -- Item'ı düşür
    exports.ox_inventory:RemoveItem(source, Config.Spray.RequiredItem, 1)

    local gangId   = m.gangId
    local gangData = GangCache[gangId]
    local expiresAt = now + Config.Spray.SprayExpiry

    -- Aynı noktada önceki spray'i sil
    MySQL.update('DELETE FROM cf_gang_sprays WHERE point_index = ?', { pointIndex }, function()
        -- Yeni spray kaydet
        MySQL.insert(
            'INSERT INTO cf_gang_sprays (gang_id, point_index, gang_tag, gang_color, created_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?, NOW(), FROM_UNIXTIME(?))',
            { gangId, pointIndex, gangData and gangData.tag or '?', gangData and gangData.color or '#FFFFFF', cid, expiresAt },
            function(sprayId)
                if not sprayId then return end

                -- Cache güncelle
                for id, s in pairs(SprayCache) do
                    if s.point_index == pointIndex then
                        SprayCache[id] = nil
                        break
                    end
                end
                SprayCache[sprayId] = {
                    id          = sprayId,
                    gang_id     = gangId,
                    point_index = pointIndex,
                    gang_tag    = gangData and gangData.tag or '?',
                    gang_color  = gangData and gangData.color or '#FFFFFF',
                }

                SprayCooldowns[cid] = now

                -- Tüm clientlara spray güncellemesi gönder
                TriggerClientEvent('cross-factions:client:sprayUpdated', -1, sprayId, pointIndex, gangId,
                    gangData and gangData.tag or '?', gangData and gangData.color or '#FFFFFF')

                TriggerClientEvent('QBCore:Notify', source, T('spray_success'), 'success')
                LogGang('Spray Yapıldı', ('**Gang:** %s\n**Nokta:** #%d\n**CID:** %s'):format(
                    gangData and gangData.name or gangId, pointIndex, cid))
            end
        )
    end)
end)

-- ─── Periyodik: Süresi dolan spray'leri temizle ───────────────────────────────
CreateThread(function()
    while true do
        Wait(300000)  -- Her 5 dakikada bir kontrol
        MySQL.query('SELECT id FROM cf_gang_sprays WHERE expires_at <= NOW()', {}, function(expired)
            if not expired or #expired == 0 then return end
            local ids = {}
            for _, row in ipairs(expired) do
                ids[#ids + 1] = row.id
                SprayCache[row.id] = nil
                TriggerClientEvent('cross-factions:client:removeSpray', -1, row.id)
            end
            if #ids > 0 then
                MySQL.update('DELETE FROM cf_gang_sprays WHERE id IN (' .. table.concat(ids, ',') .. ')', {})
            end
        end)
    end
end)
