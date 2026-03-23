-- ============================================================
--  cross-factions  |  İstemci Tarafı (client/main.lua)
-- ============================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ── Yerel durum ──────────────────────────────────────────────
local TabletAcik        = false
local SyncVeri          = {}
local TerritoryBlipleri = {}   -- [tId] = blip handle
local OyuncuBlipleri    = {}
local CaptureBarlar     = {}   -- [tId] = { thread, aktif }
local AFKKontrol        = { son_pos = nil, son_zaman = 0, afk = false }
local BenimFactionId    = nil
local BenimCitizenId    = nil

-- ── Yardımcı ─────────────────────────────────────────────────
local function RenkHextenRGBA(hex)
    hex = hex:gsub('#', '')
    local r = tonumber(hex:sub(1,2), 16) or 255
    local g = tonumber(hex:sub(3,4), 16) or 255
    local b = tonumber(hex:sub(5,6), 16) or 255
    return r, g, b, 200
end

local function BlipRenkInd(renk)
    return Config.BlipRenkleri[renk] or 0
end

-- ── Blip yönetimi ────────────────────────────────────────────
local function TumBlipleriTemizle()
    for _, blip in pairs(TerritoryBlipleri) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    TerritoryBlipleri = {}
end

local function TerritoryBlipleriniGuncelle()
    TumBlipleriTemizle()
    for tId, t in pairs(SyncVeri.territoriler or {}) do
        local blip = AddBlipForCoord(t.x, t.y, t.z)
        SetBlipSprite(blip, 830)
        SetBlipScale(blip, 0.8)
        SetBlipDisplay(blip, 4)
        SetBlipAsShortRange(blip, true)

        if t.ownerFactionId and SyncVeri.factionlar and SyncVeri.factionlar[t.ownerFactionId] then
            local f = SyncVeri.factionlar[t.ownerFactionId]
            SetBlipColour(blip, BlipRenkInd(f.renk))
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(t.isim .. ' (' .. f.isim .. ')')
            EndTextCommandSetBlipName(blip)
        else
            SetBlipColour(blip, 4)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(t.isim .. ' (Sahipsiz)')
            EndTextCommandSetBlipName(blip)
        end

        TerritoryBlipleri[tId] = blip
    end
end

-- ── Sync alındı ──────────────────────────────────────────────
RegisterNetEvent('cross-factions:sync', function(veri)
    SyncVeri = veri
    TerritoryBlipleriniGuncelle()
    -- UI açıksa güncelle
    if TabletAcik then
        SendNUIMessage({ type = 'syncVeri', veri = veri })
    end
end)

-- ── Tablet verileri ──────────────────────────────────────────
RegisterNetEvent('cross-factions:tabletVeri', function(veri)
    SyncVeri = veri
    BenimFactionId = veri.benimFactionId
    BenimCitizenId = veri.benimCitizenId
    SendNUIMessage({ type = 'tabletVeri', veri = veri })
end)

-- ── Bildirim ─────────────────────────────────────────────────
RegisterNetEvent('cross-factions:bildirim', function(mesaj, tip)
    QBCore.Functions.Notify(mesaj, tip or 'primary', 5000)
end)

-- ── Davet ────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:davetAl', function(factionId, factionIsim, gonderen)
    QBCore.Functions.Notify('Davet: ' .. factionIsim .. ' factionına katılmak ister misin? [/davetKabul ' .. factionId .. ']', 'primary', 15000)
end)

-- ── Territory capture başladı ────────────────────────────────
RegisterNetEvent('cross-factions:captureBasladi', function(tId, factionId)
    local t = (SyncVeri.territoriler or {})[tId]
    if not t then return end
    local fIsim = (SyncVeri.factionlar and SyncVeri.factionlar[factionId] and SyncVeri.factionlar[factionId].isim) or '?'
    QBCore.Functions.Notify(t.isim .. ' capture başladı (' .. fIsim .. ')', 'primary', 4000)
end)

-- ── Territory alındı ─────────────────────────────────────────
RegisterNetEvent('cross-factions:territoryAlindi', function(tId, factionId)
    local t = (SyncVeri.territoriler or {})[tId]
    if not t then return end
    local fIsim = (SyncVeri.factionlar and SyncVeri.factionlar[factionId] and SyncVeri.factionlar[factionId].isim) or '?'
    QBCore.Functions.Notify(t.isim .. ' bölgesi ' .. fIsim .. ' tarafından ele geçirildi!', 'success', 6000)
    TerritoryBlipleriniGuncelle()
end)

-- ── Savaş bitti ──────────────────────────────────────────────
RegisterNetEvent('cross-factions:savasBitti', function(savasId, kazananId, sebep)
    local kazananIsim = 'Berabere'
    if kazananId and SyncVeri.factionlar and SyncVeri.factionlar[kazananId] then
        kazananIsim = SyncVeri.factionlar[kazananId].isim
    end
    QBCore.Functions.Notify('Savaş bitti! Kazanan: ' .. kazananIsim .. ' (' .. (sebep or '?') .. ')', 'success', 8000)
end)

-- ── Savaş güncelle ───────────────────────────────────────────
RegisterNetEvent('cross-factions:savasGuncelle', function(savasId, savasVeri)
    if SyncVeri.aktifSavaslar then
        SyncVeri.aktifSavaslar[savasId] = savasVeri
    end
    if TabletAcik then
        SendNUIMessage({ type = 'savasGuncelle', savasId = savasId, veri = savasVeri })
    end
end)

-- ── Capture bar HUD ──────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(0)
        local myCoords = GetEntityCoords(PlayerPedId())

        for tId, t in pairs(SyncVeri.territoriler or {}) do
            local dist = #(vector3(t.x, t.y, t.z) - myCoords)
            if dist <= t.radius + 5.0 then
                -- Yüzde göster
                local progress = t.captureProgress or 0
                local owner    = t.ownerFactionId
                local ownerIsim = 'Sahipsiz'
                local r, g, b = 255, 255, 255
                if owner and SyncVeri.factionlar and SyncVeri.factionlar[owner] then
                    ownerIsim = SyncVeri.factionlar[owner].isim
                    r, g, b   = RenkHextenRGBA(SyncVeri.factionlar[owner].renk)
                end

                -- Başlık
                local yazi = t.isim .. ' | ' .. ownerIsim .. ' | %' .. math.floor(progress)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.0, 0.45)
                SetTextColour(r, g, b, 255)
                SetTextOutline()
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(yazi)
                EndTextCommandDisplayText(0.5 - GetTextScaleWithCurrentFont(0.45, 4) * #yazi * 0.02, 0.94)

                -- İlerleme çubuğu
                local barW  = 0.2
                local barH  = 0.012
                local barX  = 0.5 - barW / 2
                local barY  = 0.96
                local fill  = (progress / 100) * barW

                DrawRect(barX + barW / 2, barY, barW + 0.002, barH + 0.003, 0, 0, 0, 180)
                DrawRect(barX + fill / 2, barY, fill, barH, r, g, b, 220)
            end
        end
    end
end)

-- ── AFK kontrol ──────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(5000)
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        if AFKKontrol.son_pos then
            local dist = #(coords - AFKKontrol.son_pos)
            if dist < Config.SavasAFKMesafe then
                if (GetGameTimer() / 1000 - AFKKontrol.son_zaman) >= Config.SavasAFKSure then
                    AFKKontrol.afk = true
                end
            else
                AFKKontrol.afk      = false
                AFKKontrol.son_zaman = GetGameTimer() / 1000
            end
        else
            AFKKontrol.son_zaman = GetGameTimer() / 1000
        end
        AFKKontrol.son_pos = coords

        -- AFK ise savaştan çıkar
        if AFKKontrol.afk then
            QBCore.Functions.Notify('AFK olduğunuz için savaştan sayılmıyorsunuz!', 'error', 5000)
        end
    end
end)

-- ── Komutlar ─────────────────────────────────────────────────

-- Tablet aç/kapat
RegisterCommand('tablet', function()
    if not TabletAcik then
        TabletAcik = true
        SetNuiFocus(true, true)
        SendNUIMessage({ type = 'tablet', durum = 'ac' })
        TriggerServerEvent('cross-factions:tabletAc')
    else
        TabletAcik = false
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'tablet', durum = 'kapat' })
    end
end, false)

RegisterKeyMapping('tablet', 'Faction Tableti Aç/Kapat', 'keyboard', 'F6')

-- Davet kabul et
RegisterCommand('davetKabul', function(source, args)
    local factionId = tonumber(args[1])
    if not factionId then
        QBCore.Functions.Notify('Kullanım: /davetKabul [faction_id]', 'error')
        return
    end
    TriggerServerEvent('cross-factions:davetKabul', factionId)
end, false)

-- ── NUI Callbacks ────────────────────────────────────────────

RegisterNUICallback('tabletKapat', function(_, cb)
    TabletAcik = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('factionOlustur', function(veri, cb)
    TriggerServerEvent('cross-factions:factionOlustur', veri)
    cb('ok')
end)

RegisterNUICallback('factionSil', function(_, cb)
    TriggerServerEvent('cross-factions:factionSil')
    cb('ok')
end)

RegisterNUICallback('factionAyril', function(_, cb)
    TriggerServerEvent('cross-factions:factionAyril')
    cb('ok')
end)

RegisterNUICallback('factionGuncelle', function(veri, cb)
    TriggerServerEvent('cross-factions:factionGuncelle', veri)
    cb('ok')
end)

RegisterNUICallback('uyeDavetEt', function(veri, cb)
    TriggerServerEvent('cross-factions:uyeDavetEt', veri.citizenId)
    cb('ok')
end)

RegisterNUICallback('uyeKov', function(veri, cb)
    TriggerServerEvent('cross-factions:uyeKov', veri.citizenId)
    cb('ok')
end)

RegisterNUICallback('yetkiAta', function(veri, cb)
    TriggerServerEvent('cross-factions:yetkiAta', veri.citizenId, veri.yetki)
    cb('ok')
end)

RegisterNUICallback('maasGuncelle', function(veri, cb)
    TriggerServerEvent('cross-factions:maasGuncelle', veri.citizenId, veri.maas)
    cb('ok')
end)

RegisterNUICallback('savasIlanEt', function(veri, cb)
    TriggerServerEvent('cross-factions:savasIlanEt', veri.hedefFactionId, veri.territoryId)
    cb('ok')
end)

RegisterNUICallback('captureBaslat', function(veri, cb)
    TriggerServerEvent('cross-factions:captureBaslat', veri.tId)
    cb('ok')
end)

RegisterNUICallback('captureDurdur', function(veri, cb)
    TriggerServerEvent('cross-factions:captureDurdur', veri.tId)
    cb('ok')
end)

RegisterNUICallback('gorevAl', function(veri, cb)
    TriggerServerEvent('cross-factions:gorevAl', veri.gorevId)
    cb('ok')
end)

RegisterNUICallback('gorevTamamla', function(veri, cb)
    TriggerServerEvent('cross-factions:gorevTamamla', veri.gorevId)
    cb('ok')
end)

RegisterNUICallback('syncIste', function(_, cb)
    TriggerServerEvent('cross-factions:syncIste')
    cb('ok')
end)

-- ── ESC tuşu tablet kapatsın ─────────────────────────────────
CreateThread(function()
    while true do
        Wait(0)
        if TabletAcik and IsControlJustReleased(0, 200) then -- ESC
            TabletAcik = false
            SetNuiFocus(false, false)
            SendNUIMessage({ type = 'tablet', durum = 'kapat' })
        end
    end
end)

-- ── Faction Yönetim Yeri – blip ──────────────────────────────
local function YonetimBlipOlustur()
    local blip = AddBlipForCoord(Config.YonetimYeri.x, Config.YonetimYeri.y, Config.YonetimYeri.z)
    SetBlipSprite(blip, 478)          -- tablet/management icon
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, 3)            -- mavi
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Faction Yönetim Merkezi')
    EndTextCommandSetBlipName(blip)
end

CreateThread(function()
    YonetimBlipOlustur()

    local merkezVec = vector3(Config.YonetimYeri.x, Config.YonetimYeri.y, Config.YonetimYeri.z)
    local r         = Config.YonetimYeri.radius

    while true do
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist   = #(coords - merkezVec)

        if dist <= r + 20.0 then
            -- Yön işareti
            DrawMarker(
                1,                                      -- silindir
                merkezVec.x, merkezVec.y, merkezVec.z - 0.95,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                r * 0.6, r * 0.6, 0.5,
                52, 152, 219, 80,                       -- mavi, yarı şeffaf
                false, true, 2, false, nil, nil, false
            )

            if dist <= r then
                -- Ekranda ipucu metni
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.0, 0.4)
                SetTextColour(52, 152, 219, 255)
                SetTextOutline()
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Faction Tabletini Aç')
                EndTextCommandDisplayText(0.5, 0.91)

                -- E tuşu (38) ile tablet aç
                if IsControlJustReleased(0, 38) then
                    if not TabletAcik then
                        TabletAcik = true
                        SetNuiFocus(true, true)
                        SendNUIMessage({ type = 'tablet', durum = 'ac' })
                        TriggerServerEvent('cross-factions:tabletAc')
                    end
                end
            end

            Wait(0)
        else
            Wait(1000)
        end
    end
end)
