--[[
    server/turf.lua — Turf (Bölge) Yönetim Sistemi
    Ele geçirme mantığı, gelir dağıtımı, cooldown kontrolü
    ve turf ownership takibi bu dosyada işlenir.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── Aktif Capture Takibi ─────────────────────────────────────────────────────
-- turfId → { attackerGangId, progress, startTime, participants }
local ActiveCaptures = {}

-- ─── Yardımcı: Turf config'ini bul ───────────────────────────────────────────
local function GetTurfConfig(turfId)
    for _, t in ipairs(Config.Turfs) do
        if t.id == turfId then return t end
    end
    return nil
end

-- ─── Yardımcı: Turf'ün mevcut sahibini getir ─────────────────────────────────
local function GetTurfOwner(turfId)
    if TurfCache[turfId] then
        return TurfCache[turfId].owner
    end
    return nil
end

-- ─── Callback: Tüm turf durumlarını getir ────────────────────────────────────
QBCore.Functions.CreateCallback('cross-factions:cb:getTurfStates', function(source, cb)
    local states = {}
    for _, turf in ipairs(Config.Turfs) do
        local cache = TurfCache[turf.id] or {}
        states[turf.id] = {
            owner         = cache.owner,
            cooldownUntil = cache.cooldownUntil or 0,
            isCapturing   = ActiveCaptures[turf.id] ~= nil,
            capturingGang = ActiveCaptures[turf.id] and ActiveCaptures[turf.id].attackerGangId or nil,
        }
    end
    cb(states)
end)

-- ─── Event: Capture başlat ────────────────────────────────────────────────────
RegisterNetEvent('cross-factions:server:startCapture', function(turfId)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid or not MemberCache[cid] then
        TriggerClientEvent('QBCore:Notify', source, T('no_gang'), 'error')
        return
    end

    local gangId   = MemberCache[cid].gangId
    local turfCfg  = GetTurfConfig(turfId)
    if not turfCfg then return end

    -- Zaten capture aktif mi?
    if ActiveCaptures[turfId] then
        TriggerClientEvent('QBCore:Notify', source, 'Bu bölgede zaten bir ele geçirme süreci var.', 'error')
        return
    end

    -- Kendi turf'ü mü?
    local currentOwner = GetTurfOwner(turfId)
    if currentOwner == gangId then
        TriggerClientEvent('QBCore:Notify', source, T('turf_your_gang'), 'error')
        return
    end

    -- Cooldown kontrolü
    local cache = TurfCache[turfId]
    if cache and cache.cooldownUntil and cache.cooldownUntil > os.time() then
        local remaining = math.ceil((cache.cooldownUntil - os.time()) / 60)
        TriggerClientEvent('QBCore:Notify', source, T('turf_cooldown', remaining), 'error')
        return
    end

    -- Polis şartı
    if turfCfg.minPolice > 0 then
        local policeCount = GetActivePoliceCount()
        if policeCount < turfCfg.minPolice then
            TriggerClientEvent('QBCore:Notify', source, T('turf_police_required'), 'error')
            return
        end
    end

    -- Minimum saldırgan sayısı
    local attackerCount = CountOnlineGangMembers(gangId)
    if attackerCount < turfCfg.minAttackers then
        TriggerClientEvent('QBCore:Notify', source, T('turf_not_enough_members', turfCfg.minAttackers), 'error')
        return
    end

    -- Aynı anda aktif savaş sayısı limiti
    local activeCount = 0
    for _ in pairs(ActiveCaptures) do activeCount = activeCount + 1 end
    if activeCount >= Config.War.MaxActiveWars then
        TriggerClientEvent('QBCore:Notify', source, T('turf_max_wars'), 'error')
        return
    end

    -- Capture başlat
    ActiveCaptures[turfId] = {
        attackerGangId = gangId,
        defenderGangId = currentOwner,
        progress       = 0,
        startTime      = os.time(),
        participants   = { [cid] = true },
        cancelTimer    = nil,
    }

    -- Herkese bildirim: saldırgan gangın adı
    local attackGangName = GangCache[gangId] and GangCache[gangId].name or 'Bilinmiyor'
    local turfName       = turfCfg.name

    -- Savunanlara uyarı
    if currentOwner then
        local defGangName = GangCache[currentOwner] and GangCache[currentOwner].name or '?'
        local players = QBCore.Functions.GetQBPlayers()
        for _, player in pairs(players) do
            local pcid = player.PlayerData.citizenid
            if MemberCache[pcid] and MemberCache[pcid].gangId == currentOwner then
                TriggerClientEvent('QBCore:Notify', player.PlayerData.source, T('turf_under_attack', turfName), 'error')
            end
        end
        LogTurf('Turf Saldırısı Başladı',
            ('**Bölge:** %s\n**Saldıran:** %s\n**Savunan:** %s'):format(turfName, attackGangName, defGangName))
    end

    -- Tüm clientlara capture başladığını bildir
    TriggerClientEvent('cross-factions:client:captureStarted', -1, turfId, gangId)
    TriggerClientEvent('QBCore:Notify', source, T('turf_capture_started'), 'success')

    -- Capture ilerleme döngüsü
    CreateThread(function()
        local elapsed   = 0
        local interval  = 1000   -- Her 1 saniyede kontrol
        local totalTime = turfCfg.captureTime

        while ActiveCaptures[turfId] and ActiveCaptures[turfId].attackerGangId == gangId do
            Wait(interval)
            elapsed = elapsed + 1

            local capture = ActiveCaptures[turfId]
            if not capture then break end

            -- Bölgede yeterli saldırgan var mı? (anti-exploit: client zaten kontrol ediyor)
            -- Server sadece zaman sayar
            capture.progress = elapsed / totalTime

            -- Tüm clientlara ilerleme gönder
            TriggerClientEvent('cross-factions:client:captureProgress', -1, turfId, capture.progress)

            if elapsed >= totalTime then
                -- Capture tamamlandı
                TriggerEvent('cross-factions:internal:captureComplete', turfId, gangId, currentOwner)
                break
            end
        end
    end)
end)

-- ─── Event: Capture iptal et (client, oyuncu bölgeyi terketti) ───────────────
RegisterNetEvent('cross-factions:server:cancelCapture', function(turfId)
    local source = source
    local cid    = GetCitizenId(source)
    if not cid then return end

    local capture = ActiveCaptures[turfId]
    if not capture then return end

    -- Sadece saldıran gangın üyesi iptal edebilir (ya da otomatik)
    if MemberCache[cid] and MemberCache[cid].gangId ~= capture.attackerGangId then return end

    ActiveCaptures[turfId] = nil
    TriggerClientEvent('cross-factions:client:captureCancelled', -1, turfId)
    TriggerClientEvent('QBCore:Notify', source, T('turf_capture_cancelled'), 'error')
    DebugPrint(('Capture iptal edildi: Turf #%d'):format(turfId))
end)

-- ─── Internal: Capture tamamlandı ────────────────────────────────────────────
AddEventHandler('cross-factions:internal:captureComplete', function(turfId, newOwnerId, oldOwnerId)
    ActiveCaptures[turfId] = nil

    local turfCfg   = GetTurfConfig(turfId)
    local cooldownEnd = os.time() + (turfCfg and turfCfg.cooldown or 3600)

    -- DB güncelle
    MySQL.update(
        'INSERT INTO cf_turf_ownership (turf_id, owner_gang_id, cooldown_until, captured_at) VALUES (?, ?, FROM_UNIXTIME(?), NOW()) ON DUPLICATE KEY UPDATE owner_gang_id = ?, cooldown_until = FROM_UNIXTIME(?), captured_at = NOW()',
        { turfId, newOwnerId, cooldownEnd, newOwnerId, cooldownEnd },
        function()
            -- Cache güncelle
            if not TurfCache[turfId] then TurfCache[turfId] = {} end
            TurfCache[turfId].owner         = newOwnerId
            TurfCache[turfId].cooldownUntil = cooldownEnd

            -- Tüm clientlara yeni sahibi bildir
            TriggerClientEvent('cross-factions:client:turfOwnerChanged', -1, turfId, newOwnerId)
            TriggerClientEvent('cross-factions:client:captureSuccess', -1, turfId, newOwnerId)

            local newGangName = GangCache[newOwnerId] and GangCache[newOwnerId].name or 'Bilinmiyor'
            local turfName    = turfCfg and turfCfg.name or ('Turf #' .. turfId)

            -- Genel bildirim
            TriggerClientEvent('QBCore:Notify', -1, T('turf_capture_success', turfName), 'success')

            -- Eski sahibe bildirim
            if oldOwnerId and oldOwnerId ~= newOwnerId then
                local players = QBCore.Functions.GetQBPlayers()
                for _, player in pairs(players) do
                    local pcid = player.PlayerData.citizenid
                    if MemberCache[pcid] and MemberCache[pcid].gangId == oldOwnerId then
                        TriggerClientEvent('QBCore:Notify', player.PlayerData.source,
                            ('**%s** bölgenizi ele geçirdi!'):format(newGangName), 'error')
                    end
                end
            end

            LogTurf('Turf Ele Geçirildi',
                ('**Bölge:** %s\n**Yeni Sahip:** %s\n**Eski Sahip:** %s'):format(
                    turfName, newGangName,
                    oldOwnerId and GangCache[oldOwnerId] and GangCache[oldOwnerId].name or 'Sahipsiz'
                ))
        end
    )
end)

-- ─── Gelir Sistemi: Periyodik gang kasası geliri ──────────────────────────────
-- Her turf için incomeInterval dakikada bir gelir hesaplanır
CreateThread(function()
    Wait(30000) -- Başlangıçta 30 saniye bekle
    while true do
        local waitTime = 60 * 1000  -- Temel kontrol: her dakika
        Wait(waitTime)

        local now = os.time()
        for _, turf in ipairs(Config.Turfs) do
            local cache = TurfCache[turf.id]
            if cache and cache.owner then
                local gangId = cache.owner
                -- Son gelir zamanını kontrol et (DB yerine basit timer ile)
                if not cache.lastIncome or (now - cache.lastIncome) >= (turf.incomeInterval * 60) then
                    cache.lastIncome = now

                    local income = turf.income
                    MySQL.update(
                        'UPDATE cf_gangs SET treasury = LEAST(treasury + ?, ?) WHERE id = ?',
                        { income, Config.Economy.MaxTreasury, gangId },
                        function(rows)
                            if rows and rows > 0 then
                                if GangCache[gangId] then
                                    GangCache[gangId].treasury = math.min(
                                        (GangCache[gangId].treasury or 0) + income,
                                        Config.Economy.MaxTreasury
                                    )
                                end

                                -- Online üyelere bildir
                                local players = QBCore.Functions.GetQBPlayers()
                                for _, player in pairs(players) do
                                    local pcid = player.PlayerData.citizenid
                                    if MemberCache[pcid] and MemberCache[pcid].gangId == gangId then
                                        TriggerClientEvent('QBCore:Notify', player.PlayerData.source,
                                            T('income_received', turf.name, income), 'success')
                                    end
                                end

                                -- Finans logu
                                MySQL.insert(
                                    'INSERT INTO cf_finance_logs (gang_id, type, amount, description, created_at) VALUES (?, ?, ?, ?, NOW())',
                                    { gangId, 'turf_income', income, 'Turf geliri: ' .. turf.name }
                                )
                                LogFinance('Turf Geliri', ('**Gang:** %s\n**Bölge:** %s\n**Gelir:** $%d'):format(
                                    GangCache[gangId] and GangCache[gangId].name or gangId, turf.name, income
                                ))
                            end
                        end
                    )
                end
            end
        end
    end
end)
