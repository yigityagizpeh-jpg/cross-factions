--[[
    client/spray.lua — Spray (Bölge İşaretleme) İstemci Sistemi
    Spray noktaları görselleştirme, progress bar, ox_target entegrasyonu.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Yerel Durum ──────────────────────────────────────────────────────────────
-- sprayId → { pointIndex, gangTag, gangColor, textHandle }
local SprayData    = {}
local SprayTexts   = {}   -- Dünyaya çizilen spray yazıları (3D text handle gibi)
local IsSpraying   = false

-- ─── Yardımcı: Renk string → RGBA (0-255) ────────────────────────────────────
local function HexToRGBA(hex)
    hex = hex:gsub('#', '')
    if #hex == 6 then
        return tonumber(hex:sub(1, 2), 16),
               tonumber(hex:sub(3, 4), 16),
               tonumber(hex:sub(5, 6), 16),
               255
    end
    return 255, 255, 255, 255
end

-- ─── Spray yazılarını çiz (her frame değil, sadece yakınken) ─────────────────
-- 3D Text UI gerçek bir GTA draw fonksiyonu ile yapılır
local function DrawSprayText(coords, text, color)
    local r, g, b, a = HexToRGBA(color or '#FFFFFF')
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(r, g, b, a)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    SetDrawOrigin(coords.x, coords.y, coords.z + 0.5, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- ─── Spray render loop ────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        local ped    = PlayerPedId()
        local myPos  = GetEntityCoords(ped)
        local hasNearby = false

        for _, spray in pairs(SprayData) do
            local spPoint = Config.Spray.Points[spray.point_index]
            if spPoint then
                local dist = #(myPos - spPoint.coords)
                if dist < 20.0 then
                    DrawSprayText(spPoint.coords, '[' .. (spray.gang_tag or '?') .. ']', spray.gang_color)
                    hasNearby = true
                end
            end
        end

        Wait(hasNearby and 0 or 1000)  -- Yakında spray varsa her frame, yoksa 1s
    end
end)

-- ─── ox_target: Spray noktalarını tanımla ────────────────────────────────────
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(3500)

    for i, point in ipairs(Config.Spray.Points) do
        exports.ox_target:addSphereZone({
            coords  = point.coords,
            radius  = Config.Spray.Range,
            debug   = Config.Debug,
            options = {
                {
                    label   = '🎨 Spray Yap',
                    icon    = 'fas fa-spray-can',
                    name    = 'spray_point_' .. i,
                    onSelect = function()
                        TriggerEvent('cross-factions:client:trySpray', i)
                    end,
                    canInteract = function()
                        return MyGangData ~= nil and MyPerms.canSpray == true
                    end,
                },
            },
        })
    end
end)

-- ─── Spray denemesi ───────────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:trySpray', function(pointIndex)
    if IsSpraying then return end
    if not MyGangData then
        Notify(T('no_gang'), 'error')
        return
    end
    if not MyPerms.canSpray then
        Notify(T('no_permission'), 'error')
        return
    end

    IsSpraying = true

    -- Progress bar
    local success = lib.progressBar({
        duration = Config.Spray.Duration * 1000,
        label    = T('spray_progress'),
        useWhileDead = false,
        canCancel    = true,
        disable = {
            move     = true,
            car      = true,
            combat   = true,
            sprint   = true,
        },
        anim = {
            dict   = 'amb@world_human_const_poop@base',
            clip   = 'base',
        },
    })

    IsSpraying = false

    if success then
        TriggerServerEvent('cross-factions:server:doSpray', pointIndex)
    end
end)

-- ─── Sunucudan: Spray güncelleme ─────────────────────────────────────────────
RegisterNetEvent('cross-factions:client:sprayUpdated', function(sprayId, pointIndex, gangId, gangTag, gangColor)
    -- Eski spray'i temizle (aynı noktadaki)
    for id, s in pairs(SprayData) do
        if s.point_index == pointIndex then
            SprayData[id] = nil
            break
        end
    end
    -- Yeni spray ekle
    SprayData[sprayId] = {
        id          = sprayId,
        point_index = pointIndex,
        gang_id     = gangId,
        gang_tag    = gangTag,
        gang_color  = gangColor,
    }
end)

-- ─── Sunucudan: Spray sil ─────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:client:removeSpray', function(sprayId)
    SprayData[sprayId] = nil
end)

-- ─── Sunucudan: Tüm spray'leri temizle ───────────────────────────────────────
RegisterNetEvent('cross-factions:client:clearAllSprays', function()
    SprayData = {}
end)

-- ─── Sunucudan: Mevcut spray'leri yükle (oyuncu bağlandığında) ────────────────
RegisterNetEvent('cross-factions:client:loadSprays', function(sprays)
    SprayData = {}
    if sprays then
        for _, spray in ipairs(sprays) do
            SprayData[spray.id] = spray
        end
    end
    -- DebugPrint, client/main.lua'dan gelir (aynı Lua ortamı, daha önce yüklenir)
    if DebugPrint then
        DebugPrint(('Spray yüklendi: %d adet'):format(#(sprays or {})))
    end
end)
