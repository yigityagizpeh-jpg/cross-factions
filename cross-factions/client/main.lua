--[[
    client/main.lua — İstemci Çekirdeği
    QBCore başlatma, kill tracking, temel event handler'lar,
    ox_target entegrasyonu ve ortak yardımcı fonksiyonlar.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Yerel Durum ──────────────────────────────────────────────────────────────
local MyGangData    = nil    -- Oyuncunun gang verisi (callback'ten gelir)
local MyRankIndex   = 0
local MyPerms       = {}
local ActiveWarData = nil    -- Aktif savaş varsa skor bilgisi

-- ─── Yardımcı: Gang verisini yenile ──────────────────────────────────────────
function RefreshMyGang(cb)
    QBCore.Functions.TriggerCallback('cross-factions:cb:getMyGang', function(data)
        if data then
            MyGangData  = data.gang
            MyRankIndex = data.myRank
            MyPerms     = data.perms
        else
            MyGangData  = nil
            MyRankIndex = 0
            MyPerms     = {}
        end
        if cb then cb(data) end
    end)
end

-- ─── Yardımcı: Debug çıktı ────────────────────────────────────────────────────
function DebugPrint(msg)
    if Config.Debug then
        print('[cross-factions CLIENT] ' .. tostring(msg))
    end
end

-- ─── Yardımcı: ox_lib notify ──────────────────────────────────────────────────
function Notify(msg, notifyType, duration)
    lib.notify({
        title       = 'Cross-Factions',
        description = msg,
        type        = notifyType or 'inform',
        duration    = duration or Config.NotifyDuration,
    })
end

-- ─── Yardımcı: Gang renk string'i ────────────────────────────────────────────
function GetGangColor()
    if MyGangData and MyGangData.color then
        return MyGangData.color
    end
    return '#FFFFFF'
end

-- ─── Yükleme: Gang verisini al ────────────────────────────────────────────────
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)  -- Sunucu tarafının hazır olması için bekle
    RefreshMyGang()
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    MyGangData  = nil
    MyRankIndex = 0
    MyPerms     = {}
end)

-- ─── Kill Tracking: Ölüm algılama ─────────────────────────────────────────────
-- Oyuncu öldüğünde kimin öldürdüğünü sunucuya bildir
-- ─── Kill Tracking: Öldürme algılama ─────────────────────────────────────────
-- Yakındaki oyuncuların ölümünü izleyerek kimi öldürdüğümüzü tespit eder.
-- Bu yaklaşım killer client tarafından tetiklenir; sunucunun source parametresi
-- killer'ın server ID'si olur — daha güvenli ve exploit'e karşı dayanıklı.
CreateThread(function()
    -- Kısa sürede aynı kurbanı tekrar saymamak için local tracker
    local recentKills = {}  -- victimServerId → timestamp

    while true do
        Wait(500)
        local myPed = PlayerPedId()

        if IsEntityDead(myPed) then
            Wait(3000)  -- Ölüyken kontrol etme
        else
            local now = GetGameTimer()
            for _, playerId in ipairs(GetActivePlayers()) do
                if playerId ~= PlayerId() then
                    local victimPed = GetPlayerPed(playerId)
                    if victimPed and victimPed ~= 0 and IsEntityDead(victimPed) then
                        -- Öldüren entity bu client'ın ped'i mi?
                        local killerEnt = GetPedSourceOfDeath(victimPed)
                        if killerEnt == myPed then
                            local victimServerId = GetPlayerServerId(playerId)
                            if victimServerId and victimServerId ~= 0 then
                                -- 10 saniye içinde aynı kurbanı tekrar sayma (client-side guard)
                                if not recentKills[victimServerId] or (now - recentKills[victimServerId]) > 10000 then
                                    recentKills[victimServerId] = now
                                    TriggerServerEvent('cross-factions:server:registerKill', victimServerId)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ─── ox_target: Stash / Armory Hedefleri ─────────────────────────────────────
-- Gerçek sunucuda hedef nesneleri koordinatlarla veya obje hash ile tanımlanır.
-- Bu örnek, gang stash ve armory erişimini basit obje etkileşimi ile gösterir.
-- Gerçek harita entegrasyonu için ox_target zone veya poly zone kullanılmalı.

-- Gang menüsünü açmak için komut
RegisterCommand('gangmenu', function()
    TriggerEvent('cross-factions:client:openBossMenu')
end, false)

-- Leaderboard komutu
RegisterCommand('gangleaderboard', function()
    TriggerEvent('cross-factions:client:openLeaderboard')
end, false)

-- Gang bilgisi komutu
RegisterCommand('ganginfo', function()
    TriggerEvent('cross-factions:client:openGangInfo')
end, false)

-- ─── Sunucudan gelen genel event'ler ──────────────────────────────────────────
RegisterNetEvent('cross-factions:client:gangInvite', function(gangId, gangName, senderSrc)
    -- ox_lib alert dialog ile davet
    lib.alertDialog({
        header  = '🏴 Gang Daveti',
        content = ('**%s** gangından davet aldınız!\nKatılmak ister misiniz?'):format(gangName),
        centered = true,
        cancel  = true,
    }, function(confirm)
        if confirm == 'confirm' then
            TriggerServerEvent('cross-factions:server:acceptInvite', gangId)
        end
    end)
end)

RegisterNetEvent('cross-factions:client:allianceRequest', function(fromGangId, fromGangName)
    lib.alertDialog({
        header  = '🤝 İttifak Teklifi',
        content = ('**%s** gangı size ittifak teklif ediyor!\nKabul etmek ister misiniz?'):format(fromGangName),
        centered = true,
        cancel  = true,
    }, function(confirm)
        TriggerServerEvent('cross-factions:server:respondAlliance', fromGangId, confirm == 'confirm')
    end)
end)

RegisterNetEvent('cross-factions:client:warRequest', function(fromGangId, fromGangName)
    lib.alertDialog({
        header  = '⚔️ Savaş İlanı',
        content = ('**%s** gangı size **SAVAŞ** ilan etti!\nKabul etmek ister misiniz?'):format(fromGangName),
        centered = true,
        cancel  = true,
    }, function(confirm)
        TriggerServerEvent('cross-factions:server:respondWar', fromGangId, confirm == 'confirm')
    end)
end)

RegisterNetEvent('cross-factions:client:warStarted', function(warId, enemyGangId)
    ActiveWarData = { warId = warId, enemyGangId = enemyGangId, myKills = 0, theirKills = 0 }
    Notify('⚔️ Savaş başladı!', 'error', 8000)
    -- HUD güncelle
    TriggerEvent('cross-factions:client:updateWarHUD')
end)

RegisterNetEvent('cross-factions:client:warScoreUpdate', function(warId, g1Kills, g2Kills)
    if ActiveWarData and ActiveWarData.warId == warId then
        -- Hangi gang 1 hangisi 2 olduğunu bilmemiz gerekiyor; bu bilgiyi cache'de tutabiliriz
        -- Basitlik adına sadece ham skorları gösterelim
        ActiveWarData.g1Kills = g1Kills
        ActiveWarData.g2Kills = g2Kills
        TriggerEvent('cross-factions:client:updateWarHUD')
    end
end)

RegisterNetEvent('cross-factions:client:warEnded', function(warId)
    if ActiveWarData and ActiveWarData.warId == warId then
        ActiveWarData = nil
        TriggerEvent('cross-factions:client:updateWarHUD')
    end
end)

-- ─── Gang refresh tetikleyici ─────────────────────────────────────────────────
RegisterNetEvent('cross-factions:client:refreshGangData', function()
    RefreshMyGang()
end)

-- ─── Exports (diğer clientların kullanımı için) ───────────────────────────────
exports('GetMyGangData', function()
    return MyGangData
end)

exports('GetMyRankIndex', function()
    return MyRankIndex
end)

exports('HasPerm', function(perm)
    return MyPerms[perm] == true
end)
