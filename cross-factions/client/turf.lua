--[[
    client/turf.lua — Turf Bölge Sistemi
    Bölge zone'ları, girdi/çıktı algılama, capture progress bar,
    blip yönetimi ve turf durumu güncelleme işlemleri.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Yerel Durum ──────────────────────────────────────────────────────────────
local TurfStates     = {}   -- turfId → { owner, cooldownUntil, isCapturing }
local TurfZones      = {}   -- turfId → ox_lib zone
local TurfBlips      = {}   -- turfId → blip handle
local CurrentTurf    = nil  -- Oyuncunun içinde olduğu turf (nil = dışarıda)
local IsCapturing    = false
local CaptureProgress = 0.0

-- ─── Renk: Gang sahibine göre blip rengi ─────────────────────────────────────
local function GetBlipColor(turfId)
    local state = TurfStates[turfId]
    if not state or not state.owner then return 4 end  -- Gri: sahipsiz
    if MyGangData and state.owner == MyGangData.id then return 2 end  -- Yeşil: benim
    return 1  -- Kırmızı: düşman
end

-- ─── Blip güncelle ───────────────────────────────────────────────────────────
local function UpdateTurfBlip(turfCfg)
    local turfId = turfCfg.id
    if TurfBlips[turfId] and DoesBlipExist(TurfBlips[turfId]) then
        RemoveBlip(TurfBlips[turfId])
    end

    local blip = AddBlipForRadius(turfCfg.coords.x, turfCfg.coords.y, turfCfg.coords.z, turfCfg.radius)
    SetBlipColour(blip, GetBlipColor(turfId))
    SetBlipAlpha(blip, 128)
    TurfBlips[turfId] = blip

    -- Text blip
    local txtBlip = AddBlipForCoord(turfCfg.coords.x, turfCfg.coords.y, turfCfg.coords.z)
    local state   = TurfStates[turfId]
    local ownerName = state and state.owner and
        (GangCache and GangCache[state.owner] and GangCache[state.owner].name or '?') or T('turf_no_owner')
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(turfCfg.name .. ' [' .. ownerName .. ']')
    EndTextCommandSetBlipName(txtBlip)
    SetBlipColour(txtBlip, GetBlipColor(turfId))
    SetBlipSprite(txtBlip, 84)
    SetBlipScale(txtBlip, 0.8)
    SetBlipAsShortRange(txtBlip, true)
end

-- ─── Tüm blipleri yenile ─────────────────────────────────────────────────────
local function RefreshAllBlips()
    for _, turf in ipairs(Config.Turfs) do
        UpdateTurfBlip(turf)
    end
end

-- ─── Zone oluştur ─────────────────────────────────────────────────────────────
local function CreateTurfZone(turfCfg)
    local zone = lib.zones.sphere({
        coords  = turfCfg.coords,
        radius  = turfCfg.radius,
        debug   = Config.Debug,
        onEnter = function()
            CurrentTurf = turfCfg.id
            local state = TurfStates[turfCfg.id]
            local ownerName = state and state.owner and
                (GangCache and GangCache[state.owner] and GangCache[state.owner].name or '?') or T('turf_no_owner')
            Notify(T('turf_entered', turfCfg.name, ownerName), 'inform')
            TriggerEvent('cross-factions:client:turfEntered', turfCfg.id)
        end,
        onExit = function()
            if CurrentTurf == turfCfg.id then
                -- Eğer capture başlatılmışsa iptal et
                if IsCapturing then
                    TriggerServerEvent('cross-factions:server:cancelCapture', turfCfg.id)
                    IsCapturing    = false
                    CaptureProgress = 0.0
                end
                CurrentTurf = nil
            end
        end,
    })
    TurfZones[turfCfg.id] = zone
end

-- ─── Başlangıç: Turf zone ve blip'leri kur ───────────────────────────────────
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(3000)  -- Diğer scriptlerin ve sunucunun hazır olmasını bekle

    -- Turf durumlarını al
    QBCore.Functions.TriggerCallback('cross-factions:cb:getTurfStates', function(states)
        TurfStates = states or {}

        -- Her turf için zone ve blip oluştur
        for _, turf in ipairs(Config.Turfs) do
            CreateTurfZone(turf)
            UpdateTurfBlip(turf)
        end

        -- ox_target: capture ve stash noktaları
        for _, turf in ipairs(Config.Turfs) do
            exports.ox_target:addSphereZone({
                coords  = turf.coords,
                radius  = 3.0,
                debug   = Config.Debug,
                options = {
                    {
                        label   = '🏴 Bölgeyi Ele Geçir',
                        icon    = 'fas fa-flag',
                        name    = 'capture_turf_' .. turf.id,
                        onSelect = function()
                            TriggerEvent('cross-factions:client:tryCapture', turf.id)
                        end,
                        canInteract = function()
                            local state = TurfStates[turf.id]
                            -- Kendi bölgesi değilse ve cooldown aktif değilse
                            if not MyGangData then return false end
                            if state and state.owner == MyGangData.id then return false end
                            if state and state.cooldownUntil and state.cooldownUntil > os.time() then return false end
                            if state and state.isCapturing then return false end
                            return true
                        end,
                    },
                },
            })
        end
    end)
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    -- Zone'ları temizle
    for _, zone in pairs(TurfZones) do
        zone:remove()
    end
    TurfZones = {}

    -- Blipleri temizle
    for _, blip in pairs(TurfBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    TurfBlips  = {}
    TurfStates = {}
    CurrentTurf = nil
end)

-- ─── Capture denemesi ─────────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:tryCapture', function(turfId)
    if not MyGangData then
        Notify(T('no_gang'), 'error')
        return
    end

    if IsCapturing then
        Notify('Zaten bir ele geçirme işlemi devam ediyor.', 'error')
        return
    end

    -- ox_lib progress bar ile onay
    lib.alertDialog({
        header  = '🏴 Bölge Ele Geçir',
        content = 'Bu bölgeyi ele geçirmek istediğinize emin misiniz?',
        centered = true,
        cancel  = true,
    }, function(confirm)
        if confirm ~= 'confirm' then return end

        IsCapturing = true
        TriggerServerEvent('cross-factions:server:startCapture', turfId)
    end)
end)

-- ─── Capture başladı (sunucudan) ─────────────────────────────────────────────
RegisterNetEvent('cross-factions:client:captureStarted', function(turfId, attackerGangId)
    TurfStates[turfId] = TurfStates[turfId] or {}
    TurfStates[turfId].isCapturing   = true
    TurfStates[turfId].capturingGang = attackerGangId
    UpdateTurfBlip(GetTurfConfig(turfId))
end)

-- ─── Capture ilerleme güncellemesi ───────────────────────────────────────────
RegisterNetEvent('cross-factions:client:captureProgress', function(turfId, progress)
    CaptureProgress = progress
    -- Sadece bölgede olan oyuncular için progress bar göster
    if CurrentTurf ~= turfId then return end

    -- Text UI ile göster (ox_lib)
    lib.showTextUI(('🏴 Ele Geçiriliyor: **%d%%**'):format(math.floor(progress * 100)), {
        position = 'right-center',
    })

    if progress >= 1.0 then
        lib.hideTextUI()
    end
end)

-- ─── Capture iptal (sunucudan) ────────────────────────────────────────────────
RegisterNetEvent('cross-factions:client:captureCancelled', function(turfId)
    IsCapturing    = false
    CaptureProgress = 0.0
    lib.hideTextUI()

    if TurfStates[turfId] then
        TurfStates[turfId].isCapturing   = false
        TurfStates[turfId].capturingGang = nil
    end
    UpdateTurfBlip(GetTurfConfig(turfId))
end)

-- ─── Capture başarılı (sunucudan) ────────────────────────────────────────────
RegisterNetEvent('cross-factions:client:captureSuccess', function(turfId, newOwnerId)
    IsCapturing    = false
    CaptureProgress = 0.0
    lib.hideTextUI()

    if TurfStates[turfId] then
        TurfStates[turfId].owner         = newOwnerId
        TurfStates[turfId].isCapturing   = false
        TurfStates[turfId].capturingGang = nil
    end
    UpdateTurfBlip(GetTurfConfig(turfId))

    -- Bildirim ekranı
    Notify(T('turf_capture_success', GetTurfName(turfId)), 'success', 8000)
end)

-- ─── Turf sahibi değişti ──────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:client:turfOwnerChanged', function(turfId, newOwnerId)
    if TurfStates[turfId] then
        TurfStates[turfId].owner = newOwnerId
    else
        TurfStates[turfId] = { owner = newOwnerId }
    end
    local cfg = GetTurfConfig(turfId)
    if cfg then UpdateTurfBlip(cfg) end
end)

-- ─── Gang verisi yenilenince blipleri güncelle ────────────────────────────────
AddEventHandler('cross-factions:client:gangDataRefreshed', function()
    RefreshAllBlips()
end)

-- ─── Yardımcı: Turf config getir ─────────────────────────────────────────────
function GetTurfConfig(turfId)
    for _, t in ipairs(Config.Turfs) do
        if t.id == turfId then return t end
    end
    return nil
end

function GetTurfName(turfId)
    local cfg = GetTurfConfig(turfId)
    return cfg and cfg.name or ('Turf #' .. turfId)
end

-- ─── Sahiplik durumunu getir ──────────────────────────────────────────────────
function GetTurfOwnerName(turfId)
    local state = TurfStates[turfId]
    if not state or not state.owner then return T('turf_no_owner') end
    -- GangCache client tarafında yok; callback ile alınabilir veya event ile gönderilir
    return '?'
end
