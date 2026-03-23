-- ============================================================
--  cross-factions  |  Sunucu Tarafı (server/main.lua)
-- ============================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ── Bellekte tutulan durum ───────────────────────────────────
local Factionlar       = {}   -- [faction_id] = { ... }
local TerritoryDurum   = {}   -- [territory_id] = { captureProgress, owner, ... }
local AktifSavaslar    = {}   -- [savas_id] = { ... }
local AktifGorevler    = {}   -- [faction_id] = { ... }
local CaptureIslemleri = {}   -- [territory_id] = { faction_id, oyuncular, timer, ... }
local SonSavasIlan     = {}   -- [faction_id] = timestamp

-- ── Yardımcı fonksiyonlar ────────────────────────────────────
local function Log(mesaj)
    if Config.Debug then
        print('^3[cross-factions]^0 ' .. tostring(mesaj))
    end
end

local function FactionGetir(factionId)
    return Factionlar[factionId]
end

local function OyuncuFactioniBul(citizenId)
    for fid, f in pairs(Factionlar) do
        if f.uyeler then
            for _, uye in ipairs(f.uyeler) do
                if uye.citizen_id == citizenId then
                    return fid, f, uye
                end
            end
        end
    end
    return nil, nil, nil
end

local function HerkeseSyncGonder()
    local veri = {
        factionlar     = Factionlar,
        territoriler   = TerritoryDurum,
        aktifSavaslar  = AktifSavaslar,
    }
    TriggerClientEvent('cross-factions:sync', -1, veri)
end

local function KaynakIsimGetir(source)
    local oyuncu = QBCore.Functions.GetPlayer(source)
    if oyuncu then
        return oyuncu.PlayerData.charinfo.firstname .. ' ' .. oyuncu.PlayerData.charinfo.lastname
    end
    return 'Bilinmiyor'
end

local function CitizenIdGetir(source)
    local oyuncu = QBCore.Functions.GetPlayer(source)
    if oyuncu then return oyuncu.PlayerData.citizenid end
    return nil
end

-- ── Veritabanından yükleme ───────────────────────────────────
local function FactionlariYukle()
    local sonuc = MySQL.query.await('SELECT * FROM cf_factions')
    for _, f in ipairs(sonuc) do
        f.uyeler = {}
        local uyeler = MySQL.query.await('SELECT * FROM cf_faction_uyeler WHERE faction_id = ?', { f.id })
        for _, u in ipairs(uyeler) do
            table.insert(f.uyeler, u)
        end
        Factionlar[f.id] = f
    end
    Log('Factionlar yüklendi: ' .. #sonuc)
end

local function TeritorileriYukle()
    -- Önce config'dan oluştur/güncelle
    for _, t in ipairs(Config.Territoriler) do
        MySQL.query.await(
            'INSERT INTO cf_territoriler (id, isim, x, y, z, radius, level) VALUES (?,?,?,?,?,?,?) ' ..
            'ON DUPLICATE KEY UPDATE isim=VALUES(isim), x=VALUES(x), y=VALUES(y), z=VALUES(z), radius=VALUES(radius), level=VALUES(level)',
            { t.id, t.isim, t.x, t.y, t.z, t.radius, t.level }
        )
    end
    local sonuc = MySQL.query.await('SELECT * FROM cf_territoriler')
    for _, t in ipairs(sonuc) do
        TerritoryDurum[t.id] = {
            id              = t.id,
            isim            = t.isim,
            x               = t.x,
            y               = t.y,
            z               = t.z,
            radius          = t.radius,
            level           = t.level,
            ownerFactionId  = t.owner_faction_id,
            captureProgress = t.capture_progress or 0.0,
            sonCapture      = t.son_capture,
        }
    end
    Log('Territoriler yüklendi: ' .. #sonuc)
end

local function AktifSavaslarilYukle()
    local sonuc = MySQL.query.await("SELECT * FROM cf_savaslar WHERE durum='aktif'")
    for _, s in ipairs(sonuc) do
        AktifSavaslar[s.id] = {
            id           = s.id,
            saldiranId   = s.saldiran_id,
            savunucuId   = s.savunucu_id,
            territoryId  = s.territory_id,
            saldiranKill = s.saldiran_kill,
            savunucuKill = s.savunucu_kill,
            baslangic    = s.baslangic,
            sure         = Config.SavasMaksSure,
        }
    end
    Log('Aktif savaşlar yüklendi: ' .. #sonuc)
end

-- ── Başlatma ─────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(500)
    FactionlariYukle()
    TeritorileriYukle()
    AktifSavaslarilYukle()
    -- Aktif sezon yoksa oluştur
    local sezon = MySQL.query.await("SELECT id FROM cf_sezonlar WHERE aktif=1 LIMIT 1")
    if #sezon == 0 then
        MySQL.insert.await('INSERT INTO cf_sezonlar (aktif) VALUES (1)')
        Log('Yeni sezon başlatıldı.')
    end
    HerkeseSyncGonder()
    Log('Sistem başlatıldı.')
end)

-- ── ─────────────────────────────────────────────────────────
--   FACTION YÖNETİMİ
-- ── ─────────────────────────────────────────────────────────

-- Faction Oluştur
RegisterNetEvent('cross-factions:factionOlustur', function(veri)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local isim    = tostring(veri.isim or ''):sub(1, Config.FactionIsimMaxUzunluk)
    local renk    = tostring(veri.renk or '')
    local logoUrl = tostring(veri.logo_url or '')

    if #isim < Config.FactionIsimMinUzunluk then
        TriggerClientEvent('cross-factions:bildirim', source, 'Faction ismi en az ' .. Config.FactionIsimMinUzunluk .. ' karakter olmalı!', 'error')
        return
    end

    -- Zaten bir factionda mı?
    local fid, _, _ = OyuncuFactioniBul(citizenId)
    if fid then
        TriggerClientEvent('cross-factions:bildirim', source, 'Zaten bir faction üyesisin!', 'error')
        return
    end

    -- İsim çakışması
    for _, f in pairs(Factionlar) do
        if f.isim:lower() == isim:lower() then
            TriggerClientEvent('cross-factions:bildirim', source, 'Bu faction ismi zaten kullanılıyor!', 'error')
            return
        end
        -- Renk çakışması
        if f.renk == renk then
            TriggerClientEvent('cross-factions:bildirim', source, 'Bu renk başka bir faction tarafından kullanılıyor!', 'error')
            return
        end
    end

    -- Renk geçerli mi?
    local renkGecerli = false
    for _, r in ipairs(Config.FactionRenkleri) do
        if r == renk then renkGecerli = true break end
    end
    if not renkGecerli then
        TriggerClientEvent('cross-factions:bildirim', source, 'Geçersiz renk!', 'error')
        return
    end

    local oyuncuIsim = KaynakIsimGetir(source)
    local insertId = MySQL.insert.await(
        'INSERT INTO cf_factions (isim, renk, logo_url, lider_citizen) VALUES (?,?,?,?)',
        { isim, renk, logoUrl, citizenId }
    )
    if not insertId then
        TriggerClientEvent('cross-factions:bildirim', source, 'Faction oluşturulurken hata!', 'error')
        return
    end

    Factionlar[insertId] = {
        id            = insertId,
        isim          = isim,
        renk          = renk,
        logo_url      = logoUrl,
        lider_citizen = citizenId,
        para          = 0,
        wins          = 0,
        sezon_wins    = 0,
        uyeler        = {},
    }

    -- Lideri üye olarak ekle
    MySQL.insert.await(
        'INSERT INTO cf_faction_uyeler (faction_id, citizen_id, isim, yetki, maas) VALUES (?,?,?,?,?)',
        { insertId, citizenId, oyuncuIsim, 5, Config.VarsayilanMaas }
    )
    table.insert(Factionlar[insertId].uyeler, {
        faction_id = insertId,
        citizen_id = citizenId,
        isim       = oyuncuIsim,
        yetki      = 5,
        maas       = Config.VarsayilanMaas,
    })

    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', source, isim .. ' faction\'ı oluşturuldu!', 'success')
    Log('Faction oluşturuldu: ' .. isim .. ' (' .. citizenId .. ')')
end)

-- Faction Sil (sadece lider)
RegisterNetEvent('cross-factions:factionSil', function()
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid then
        TriggerClientEvent('cross-factions:bildirim', source, 'Bir faction\'a üye değilsin!', 'error')
        return
    end
    if uye.yetki < 5 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Sadece lider faction\'ı silebilir!', 'error')
        return
    end

    MySQL.query.await('DELETE FROM cf_factions WHERE id = ?', { fid })
    Factionlar[fid] = nil
    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', source, 'Faction silindi.', 'success')
end)

-- Üye Davet Et
RegisterNetEvent('cross-factions:uyeDavetEt', function(hedefCitizenId)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid or uye.yetki < 3 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Yetkin yetersiz!', 'error')
        return
    end

    if #f.uyeler >= Config.MaxFactionUyeSayisi then
        TriggerClientEvent('cross-factions:bildirim', source, 'Faction üye limiti doldu!', 'error')
        return
    end

    -- Hedef zaten factionda mı?
    local hfid = OyuncuFactioniBul(hedefCitizenId)
    if hfid then
        TriggerClientEvent('cross-factions:bildirim', source, 'Oyuncu zaten bir factionda!', 'error')
        return
    end

    -- Online oyuncu mu bul
    local hedefSource = nil
    local tumOyuncular = QBCore.Functions.GetQBPlayers()
    for _, p in pairs(tumOyuncular) do
        if p.PlayerData.citizenid == hedefCitizenId then
            hedefSource = p.PlayerData.source
            break
        end
    end

    if not hedefSource then
        TriggerClientEvent('cross-factions:bildirim', source, 'Oyuncu çevrimiçi değil!', 'error')
        return
    end

    -- Daveti gönder
    TriggerClientEvent('cross-factions:davetAl', hedefSource, fid, f.isim, citizenId)
    TriggerClientEvent('cross-factions:bildirim', source, 'Davet gönderildi.', 'success')
end)

-- Davet Kabul
RegisterNetEvent('cross-factions:davetKabul', function(factionId)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local f = Factionlar[factionId]
    if not f then return end

    if #f.uyeler >= Config.MaxFactionUyeSayisi then
        TriggerClientEvent('cross-factions:bildirim', source, 'Faction üye limiti doldu!', 'error')
        return
    end

    local mevcutFid = OyuncuFactioniBul(citizenId)
    if mevcutFid then
        TriggerClientEvent('cross-factions:bildirim', source, 'Zaten bir faction üyesisin!', 'error')
        return
    end

    local oyuncuIsim = KaynakIsimGetir(source)
    MySQL.insert.await(
        'INSERT INTO cf_faction_uyeler (faction_id, citizen_id, isim, yetki, maas) VALUES (?,?,?,?,?)',
        { factionId, citizenId, oyuncuIsim, 1, Config.VarsayilanMaas }
    )
    table.insert(f.uyeler, {
        faction_id = factionId,
        citizen_id = citizenId,
        isim       = oyuncuIsim,
        yetki      = 1,
        maas       = Config.VarsayilanMaas,
    })

    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', source, f.isim .. ' factionına katıldın!', 'success')
end)

-- Üye Kov
RegisterNetEvent('cross-factions:uyeKov', function(hedefCitizenId)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid or uye.yetki < 3 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Yetkin yetersiz!', 'error')
        return
    end

    -- Hedef bul
    local hedefIdx = nil
    local hedefUye = nil
    for i, u in ipairs(f.uyeler) do
        if u.citizen_id == hedefCitizenId then
            hedefIdx = i
            hedefUye = u
            break
        end
    end

    if not hedefUye then
        TriggerClientEvent('cross-factions:bildirim', source, 'Üye bulunamadı!', 'error')
        return
    end

    if hedefUye.yetki >= uye.yetki then
        TriggerClientEvent('cross-factions:bildirim', source, 'Daha yüksek veya eşit yetkideki birini kovamazsın!', 'error')
        return
    end

    MySQL.query.await('DELETE FROM cf_faction_uyeler WHERE faction_id=? AND citizen_id=?', { fid, hedefCitizenId })
    table.remove(f.uyeler, hedefIdx)

    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', source, hedefUye.isim .. ' faction\'dan kovuldu.', 'success')
end)

-- Factiondan Ayrıl
RegisterNetEvent('cross-factions:factionAyril', function()
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid then return end

    if uye.yetki == 5 and #f.uyeler > 1 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Ayrılmadan önce liderliği başka birine devredin!', 'error')
        return
    end

    MySQL.query.await('DELETE FROM cf_faction_uyeler WHERE faction_id=? AND citizen_id=?', { fid, citizenId })
    for i, u in ipairs(f.uyeler) do
        if u.citizen_id == citizenId then
            table.remove(f.uyeler, i)
            break
        end
    end

    if #f.uyeler == 0 then
        MySQL.query.await('DELETE FROM cf_factions WHERE id=?', { fid })
        Factionlar[fid] = nil
    end

    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', source, 'Faction\'dan ayrıldın.', 'success')
end)

-- Yetki Ata
RegisterNetEvent('cross-factions:yetkiAta', function(hedefCitizenId, yeniYetki)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    yeniYetki = tonumber(yeniYetki) or 1
    if yeniYetki < 1 or yeniYetki > 5 then return end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid or uye.yetki < 4 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Yetkin yetersiz!', 'error')
        return
    end

    for _, u in ipairs(f.uyeler) do
        if u.citizen_id == hedefCitizenId then
            if yeniYetki >= uye.yetki and uye.yetki < 5 then
                TriggerClientEvent('cross-factions:bildirim', source, 'Kendi yetkinizden yüksek yetki veremezsiniz!', 'error')
                return
            end
            u.yetki = yeniYetki
            MySQL.query.await('UPDATE cf_faction_uyeler SET yetki=? WHERE faction_id=? AND citizen_id=?',
                { yeniYetki, fid, hedefCitizenId })
            HerkeseSyncGonder()
            TriggerClientEvent('cross-factions:bildirim', source, u.isim .. ' yetkisi güncellendi.', 'success')
            return
        end
    end
    TriggerClientEvent('cross-factions:bildirim', source, 'Üye bulunamadı!', 'error')
end)

-- Maaş Güncelle
RegisterNetEvent('cross-factions:maasGuncelle', function(hedefCitizenId, yeniMaas)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    yeniMaas = tonumber(yeniMaas) or Config.VarsayilanMaas
    if yeniMaas < 0 then yeniMaas = 0 end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid or uye.yetki < 4 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Yetkin yetersiz!', 'error')
        return
    end

    for _, u in ipairs(f.uyeler) do
        if u.citizen_id == hedefCitizenId then
            u.maas = yeniMaas
            MySQL.query.await('UPDATE cf_faction_uyeler SET maas=? WHERE faction_id=? AND citizen_id=?',
                { yeniMaas, fid, hedefCitizenId })
            HerkeseSyncGonder()
            TriggerClientEvent('cross-factions:bildirim', source, u.isim .. ' maaşı $' .. yeniMaas .. ' olarak güncellendi.', 'success')
            return
        end
    end
    TriggerClientEvent('cross-factions:bildirim', source, 'Üye bulunamadı!', 'error')
end)

-- Faction Bilgisi Güncelle (logo, renk)
RegisterNetEvent('cross-factions:factionGuncelle', function(veri)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid or uye.yetki < 5 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Yetkin yetersiz!', 'error')
        return
    end

    local yeniRenk   = tostring(veri.renk or f.renk)
    local yeniLogo   = tostring(veri.logo_url or f.logo_url or '')

    -- Renk çakışma kontrolü
    if yeniRenk ~= f.renk then
        for oid, of in pairs(Factionlar) do
            if oid ~= fid and of.renk == yeniRenk then
                TriggerClientEvent('cross-factions:bildirim', source, 'Bu renk başka bir faction tarafından kullanılıyor!', 'error')
                return
            end
        end
        -- Renk geçerli mi?
        local renkGecerli = false
        for _, r in ipairs(Config.FactionRenkleri) do
            if r == yeniRenk then renkGecerli = true break end
        end
        if not renkGecerli then
            TriggerClientEvent('cross-factions:bildirim', source, 'Geçersiz renk!', 'error')
            return
        end
    end

    f.renk     = yeniRenk
    f.logo_url = yeniLogo
    MySQL.query.await('UPDATE cf_factions SET renk=?, logo_url=? WHERE id=?', { yeniRenk, yeniLogo, fid })
    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', source, 'Faction güncellendi.', 'success')
end)

-- ── ─────────────────────────────────────────────────────────
--   TERRITORY
-- ── ─────────────────────────────────────────────────────────

local function TerritoryGuncelle(tId)
    local t = TerritoryDurum[tId]
    if not t then return end
    MySQL.query.await(
        'UPDATE cf_territoriler SET owner_faction_id=?, capture_progress=?, son_capture=NOW() WHERE id=?',
        { t.ownerFactionId, t.captureProgress, tId }
    )
end

-- Capture döngüsü – her saniye çalışır
CreateThread(function()
    while true do
        Wait(1000)
        local senkronGerekli = false

        for tId, capture in pairs(CaptureIslemleri) do
            local t = TerritoryDurum[tId]
            if not t then
                CaptureIslemleri[tId] = nil
                goto devam
            end

            -- Cooldown kontrolü
            if t.sonCapture then
                local gecen = os.time() - (t.sonCapture or 0)
                if gecen < Config.TerritoryCooldownSuresi then
                    TriggerClientEvent('cross-factions:territoryDurum', -1, tId, 'cooldown', Config.TerritoryCooldownSuresi - gecen)
                    goto devam
                end
            end

            -- Online olan, bu bölgedeki faction oyuncularını say
            local fOyuncular    = 0
            local rakipOyuncular = 0

            local tumOyuncular = QBCore.Functions.GetQBPlayers()
            for _, p in pairs(tumOyuncular) do
                local pSource = p.PlayerData.source
                local pCoords = GetEntityCoords(GetPlayerPed(pSource))
                local dist    = #(vector3(t.x, t.y, t.z) - pCoords)

                if dist <= t.radius then
                    local pfid = OyuncuFactioniBul(p.PlayerData.citizenid)
                    if pfid == capture.factionId then
                        fOyuncular = fOyuncular + 1
                    elseif pfid then
                        rakipOyuncular = rakipOyuncular + 1
                    end
                end
            end

            if fOyuncular < Config.TerritoryYakalamaMinoyuncu then
                -- Yetersiz oyuncu → progress düşme
                if t.captureProgress > 0 then
                    t.captureProgress = math.max(0, t.captureProgress - 0.5)
                    senkronGerekli = true
                end
            else
                local artis = (100.0 / Config.TerritoryYakalamaMaxSure)
                if rakipOyuncular > 0 then
                    artis = artis * Config.TerritoryYavaşlamaÇarpan
                end
                t.captureProgress = math.min(100.0, t.captureProgress + artis)
                senkronGerekli = true

                if t.captureProgress >= 100.0 then
                    -- Capture tamamlandı
                    t.ownerFactionId  = capture.factionId
                    t.captureProgress = 100.0
                    t.sonCapture      = os.time()
                    TerritoryGuncelle(tId)
                    CaptureIslemleri[tId] = nil
                    TriggerClientEvent('cross-factions:territoryAlindi', -1, tId, capture.factionId)
                    Log('Territory ele geçirildi: ' .. tId .. ' → faction ' .. capture.factionId)
                end
            end

            ::devam::
        end

        if senkronGerekli then
            HerkeseSyncGonder()
        end
    end
end)

-- Capture başlat
RegisterNetEvent('cross-factions:captureBaslat', function(tId)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid then
        TriggerClientEvent('cross-factions:bildirim', source, 'Bir faction\'a üye değilsin!', 'error')
        return
    end

    local t = TerritoryDurum[tId]
    if not t then return end

    if t.ownerFactionId == fid then
        TriggerClientEvent('cross-factions:bildirim', source, 'Bu bölge zaten sizin!', 'error')
        return
    end

    -- Cooldown
    if t.sonCapture then
        local gecen = os.time() - t.sonCapture
        if gecen < Config.TerritoryCooldownSuresi then
            TriggerClientEvent('cross-factions:bildirim', source, 'Bu bölge cooldown\'da! (' .. (Config.TerritoryCooldownSuresi - gecen) .. 's)', 'error')
            return
        end
    end

    -- Aktif savaş var mı?
    local savasVar = false
    for _, s in pairs(AktifSavaslar) do
        if (s.saldiranId == fid or s.savunucuId == fid) and s.territoryId == tId then
            savasVar = true
            break
        end
    end
    if not savasVar then
        -- Savaş yokken capture yapılamaz; önce savaş ilan edilmesi gerekmektedir.
        TriggerClientEvent('cross-factions:bildirim', source, 'Bu bölgeyi ele geçirmek için önce savaş ilan etmeniz gerekiyor!', 'error')
        return
    end

    if CaptureIslemleri[tId] then
        TriggerClientEvent('cross-factions:bildirim', source, 'Bu bölge zaten capture ediliyor!', 'error')
        return
    end

    -- Sıfırla ve başlat
    t.captureProgress = 0.0
    CaptureIslemleri[tId] = { factionId = fid, baslangic = os.time() }
    TriggerClientEvent('cross-factions:captureBasladi', -1, tId, fid)
    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', source, t.isim .. ' capture başladı!', 'success')
end)

-- Capture durdur
RegisterNetEvent('cross-factions:captureDurdur', function(tId)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid = OyuncuFactioniBul(citizenId)
    if not fid then return end

    if CaptureIslemleri[tId] and CaptureIslemleri[tId].factionId == fid then
        CaptureIslemleri[tId] = nil
        TerritoryDurum[tId].captureProgress = 0.0
        HerkeseSyncGonder()
        TriggerClientEvent('cross-factions:bildirim', source, 'Capture durduruldu.', 'error')
    end
end)

-- ── ─────────────────────────────────────────────────────────
--   SAVAŞ SİSTEMİ
-- ── ─────────────────────────────────────────────────────────

local function SavasBit(savasId, kazananId, sebep)
    local s = AktifSavaslar[savasId]
    if not s then return end

    s.durum    = 'bitti'
    s.kaybeden = (kazananId == s.saldiranId) and s.savunucuId or s.saldiranId

    MySQL.query.await(
        'UPDATE cf_savaslar SET durum=?, kazanan_id=?, bitis=NOW() WHERE id=?',
        { 'bitti', kazananId, savasId }
    )

    -- Kazanan faction wins artır
    if kazananId and Factionlar[kazananId] then
        Factionlar[kazananId].wins      = (Factionlar[kazananId].wins or 0) + 1
        Factionlar[kazananId].sezon_wins = (Factionlar[kazananId].sezon_wins or 0) + 1
        MySQL.query.await('UPDATE cf_factions SET wins=wins+1, sezon_wins=sezon_wins+1 WHERE id=?', { kazananId })
    end

    TriggerClientEvent('cross-factions:savasBitti', -1, savasId, kazananId, sebep)
    AktifSavaslar[savasId] = nil
    HerkeseSyncGonder()
    Log('Savaş bitti: ' .. savasId .. ' → kazanan faction ' .. tostring(kazananId) .. ' (' .. sebep .. ')')
end

-- Savaş ilan et
RegisterNetEvent('cross-factions:savasIlanEt', function(hedefFactionId, territoryId)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    hedefFactionId = tonumber(hedefFactionId)
    territoryId    = tonumber(territoryId)

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid or uye.yetki < 4 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Yetkin yetersiz!', 'error')
        return
    end

    if fid == hedefFactionId then
        TriggerClientEvent('cross-factions:bildirim', source, 'Kendinize savaş ilan edemezsiniz!', 'error')
        return
    end

    if not Factionlar[hedefFactionId] then
        TriggerClientEvent('cross-factions:bildirim', source, 'Hedef faction bulunamadı!', 'error')
        return
    end

    -- Cooldown
    local simdi = os.time()
    if SonSavasIlan[fid] and (simdi - SonSavasIlan[fid]) < Config.SavasIlanCooldown then
        local kalan = Config.SavasIlanCooldown - (simdi - SonSavasIlan[fid])
        TriggerClientEvent('cross-factions:bildirim', source, 'Savaş ilan cooldown\'da! (' .. kalan .. 's)', 'error')
        return
    end

    -- Zaten aktif savaş var mı?
    for _, s in pairs(AktifSavaslar) do
        if (s.saldiranId == fid or s.savunucuId == fid) then
            TriggerClientEvent('cross-factions:bildirim', source, 'Zaten aktif bir savaşınız var!', 'error')
            return
        end
    end

    SonSavasIlan[fid] = simdi
    local insertId = MySQL.insert.await(
        'INSERT INTO cf_savaslar (saldiran_id, savunucu_id, territory_id, durum) VALUES (?,?,?,?)',
        { fid, hedefFactionId, territoryId, 'aktif' }
    )

    AktifSavaslar[insertId] = {
        id           = insertId,
        saldiranId   = fid,
        savunucuId   = hedefFactionId,
        territoryId  = territoryId,
        saldiranKill = 0,
        savunucuKill = 0,
        sure         = Config.SavasMaksSure,
        baslangic    = simdi,
    }

    -- Capture'a izin ver
    if territoryId and TerritoryDurum[territoryId] then
        TerritoryDurum[territoryId].captureProgress = 0.0
        CaptureIslemleri[territoryId] = { factionId = fid, baslangic = simdi }
    end

    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', -1,
        f.isim .. ' → ' .. Factionlar[hedefFactionId].isim .. ' savaşı başladı!', 'warning')
    Log('Savaş ilan: ' .. fid .. ' vs ' .. hedefFactionId)
end)

-- Kill bildirimi (ölüm scriptiyle entegre)
RegisterNetEvent('cross-factions:savasKillBildir', function(oldurenSource)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local oldurenCitizen = CitizenIdGetir(oldurenSource)
    if not oldurenCitizen then return end

    local fid1 = OyuncuFactioniBul(citizenId)
    local fid2 = OyuncuFactioniBul(oldurenCitizen)
    if not fid1 or not fid2 or fid1 == fid2 then return end

    for savasId, s in pairs(AktifSavaslar) do
        if (s.saldiranId == fid2 and s.savunucuId == fid1) then
            s.saldiranKill = s.saldiranKill + 1
            MySQL.query.await('UPDATE cf_savaslar SET saldiran_kill=? WHERE id=?', { s.saldiranKill, savasId })
            TriggerClientEvent('cross-factions:savasGuncelle', -1, savasId, s)
            if s.saldiranKill >= Config.SavasKazanmaKill then
                SavasBit(savasId, s.saldiranId, 'kill')
            end
            return
        elseif (s.savunucuId == fid2 and s.saldiranId == fid1) then
            s.savunucuKill = s.savunucuKill + 1
            MySQL.query.await('UPDATE cf_savaslar SET savunucu_kill=? WHERE id=?', { s.savunucuKill, savasId })
            TriggerClientEvent('cross-factions:savasGuncelle', -1, savasId, s)
            if s.savunucuKill >= Config.SavasKazanmaKill then
                SavasBit(savasId, s.savunucuId, 'kill')
            end
            return
        end
    end
end)

-- Savaş süresi takibi
CreateThread(function()
    while true do
        Wait(5000)
        local simdi = os.time()
        for savasId, s in pairs(AktifSavaslar) do
            if (simdi - s.baslangic) >= Config.SavasMaksSure then
                -- Berabere veya üstün olan kazanır
                local kazanan = nil
                if s.saldiranKill > s.savunucuKill then
                    kazanan = s.saldiranId
                elseif s.savunucuKill > s.saldiranKill then
                    kazanan = s.savunucuId
                end
                SavasBit(savasId, kazanan, 'sure')
            end
        end
    end
end)

-- ── ─────────────────────────────────────────────────────────
--   SEZON SİSTEMİ
-- ── ─────────────────────────────────────────────────────────

local function SezonBitir()
    -- Kazananı bul
    local enCokWin = 0
    local kazananId = nil
    for fid, f in pairs(Factionlar) do
        if (f.sezon_wins or 0) > enCokWin then
            enCokWin  = f.sezon_wins
            kazananId = fid
        end
    end

    -- DB güncelle
    MySQL.query.await("UPDATE cf_sezonlar SET aktif=0, kazanan_id=?, bitis=NOW() WHERE aktif=1", { kazananId })
    -- Yeni sezon başlat
    MySQL.insert.await('INSERT INTO cf_sezonlar (aktif) VALUES (1)')

    -- Ödül ver
    if kazananId and Factionlar[kazananId] then
        local f = Factionlar[kazananId]
        MySQL.query.await('UPDATE cf_factions SET para=para+? WHERE id=?', { Config.SezonOdulPara, kazananId })
        f.para = (f.para or 0) + Config.SezonOdulPara

        -- Online oyunculara item ver
        local tumOyuncular = QBCore.Functions.GetQBPlayers()
        for _, p in pairs(tumOyuncular) do
            local pfid = OyuncuFactioniBul(p.PlayerData.citizenid)
            if pfid == kazananId then
                p.Functions.AddItem(Config.SezonOdulItem, Config.SezonOdulItemMiktar)
                TriggerClientEvent('cross-factions:bildirim', p.PlayerData.source,
                    'Sezon ödülü aldınız: $' .. Config.SezonOdulPara .. ' + ' .. Config.SezonOdulItemMiktar .. 'x ' .. Config.SezonOdulItem, 'success')
            end
        end

        TriggerClientEvent('cross-factions:bildirim', -1, f.isim .. ' sezonu kazandı! Ödüller dağıtıldı.', 'success')
    end

    -- Sezon wins sıfırla
    MySQL.query.await('UPDATE cf_factions SET sezon_wins=0')
    for _, f in pairs(Factionlar) do
        f.sezon_wins = 0
    end

    HerkeseSyncGonder()
    Log('Sezon bitti. Kazanan: ' .. tostring(kazananId))
end

-- Sezon süresi günlük kontrol
CreateThread(function()
    while true do
        Wait(3600 * 1000) -- Her saat kontrol et
        local sezon = MySQL.query.await("SELECT id, baslangic FROM cf_sezonlar WHERE aktif=1 LIMIT 1")
        if #sezon > 0 then
            -- MySQL TIMESTAMPDIFF ile geçen süreyi saniye cinsinden alarak sezon süresini kontrol et
            -- Config.SezonSuresi gün → saniye
            local sezonSaniye = Config.SezonSuresi * 24 * 3600
            local kontrol = MySQL.query.await(
                "SELECT TIMESTAMPDIFF(SECOND, baslangic, NOW()) AS gecen FROM cf_sezonlar WHERE aktif=1 LIMIT 1"
            )
            if #kontrol > 0 and kontrol[1].gecen >= sezonSaniye then
                SezonBitir()
            end
        end
    end
end)

-- ── ─────────────────────────────────────────────────────────
--   GÖREV / CONTRACT SİSTEMİ
-- ── ─────────────────────────────────────────────────────────

RegisterNetEvent('cross-factions:gorevAl', function(gorevConfigId)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    gorevConfigId = tonumber(gorevConfigId)
    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid or uye.yetki < 3 then
        TriggerClientEvent('cross-factions:bildirim', source, 'Yetkin yetersiz!', 'error')
        return
    end

    -- Zaten aktif görev?
    if AktifGorevler[fid] then
        TriggerClientEvent('cross-factions:bildirim', source, 'Zaten aktif bir göreviniz var!', 'error')
        return
    end

    -- Görev var mı?
    local gorevCfg = nil
    for _, g in ipairs(Config.Gorevler) do
        if g.id == gorevConfigId then gorevCfg = g break end
    end
    if not gorevCfg then return end

    local insertId = MySQL.insert.await(
        'INSERT INTO cf_gorevler (faction_id, gorev_config_id, durum) VALUES (?,?,?)',
        { fid, gorevConfigId, 'aktif' }
    )

    AktifGorevler[fid] = {
        id          = insertId,
        factionId   = fid,
        configId    = gorevConfigId,
        isim        = gorevCfg.isim,
        aciklama    = gorevCfg.aciklama,
        odulPara    = gorevCfg.odulPara,
        odulItem    = gorevCfg.odulItem,
        baslangic   = os.time(),
        sure        = gorevCfg.sure,
    }

    TriggerClientEvent('cross-factions:bildirim', source, '"' .. gorevCfg.isim .. '" görevi başladı!', 'success')
    HerkeseSyncGonder()
end)

RegisterNetEvent('cross-factions:gorevTamamla', function(gorevId)
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid, f, uye = OyuncuFactioniBul(citizenId)
    if not fid then return end

    local gorev = AktifGorevler[fid]
    if not gorev or gorev.id ~= tonumber(gorevId) then
        TriggerClientEvent('cross-factions:bildirim', source, 'Aktif görev bulunamadı!', 'error')
        return
    end

    MySQL.query.await('UPDATE cf_gorevler SET durum=?, bitis=NOW() WHERE id=?', { 'tamamlandi', gorev.id })

    -- Ödül
    MySQL.query.await('UPDATE cf_factions SET para=para+? WHERE id=?', { gorev.odulPara, fid })
    f.para = (f.para or 0) + gorev.odulPara

    if gorev.odulItem then
        local oyuncu = QBCore.Functions.GetPlayer(source)
        if oyuncu then
            oyuncu.Functions.AddItem(gorev.odulItem, 1)
        end
    end

    AktifGorevler[fid] = nil
    HerkeseSyncGonder()
    TriggerClientEvent('cross-factions:bildirim', source, '"' .. gorev.isim .. '" görevi tamamlandı! Ödül: $' .. gorev.odulPara, 'success')
end)

-- Görev süresi kontrolü
CreateThread(function()
    while true do
        Wait(10000)
        local simdi = os.time()
        for fid, gorev in pairs(AktifGorevler) do
            if (simdi - gorev.baslangic) >= gorev.sure then
                MySQL.query.await('UPDATE cf_gorevler SET durum=?, bitis=NOW() WHERE id=?', { 'basarisiz', gorev.id })
                AktifGorevler[fid] = nil
                -- Online üyelere bildir
                local tumOyuncular = QBCore.Functions.GetQBPlayers()
                for _, p in pairs(tumOyuncular) do
                    local pfid = OyuncuFactioniBul(p.PlayerData.citizenid)
                    if pfid == fid then
                        TriggerClientEvent('cross-factions:bildirim', p.PlayerData.source,
                            '"' .. gorev.isim .. '" görevi başarısız! Süre doldu.', 'error')
                    end
                end
            end
        end
    end
end)

-- ── ─────────────────────────────────────────────────────────
--   TABLETİ AÇ / SYNC
-- ── ─────────────────────────────────────────────────────────

RegisterNetEvent('cross-factions:tabletAc', function()
    local source    = source
    local citizenId = CitizenIdGetir(source)
    if not citizenId then return end

    local fid, f = OyuncuFactioniBul(citizenId)
    local aktifGorev = fid and AktifGorevler[fid] or nil
    local aktifSavasListesi = {}
    for sid, s in pairs(AktifSavaslar) do
        aktifSavasListesi[#aktifSavasListesi + 1] = s
    end

    local sezonlar = MySQL.query.await('SELECT * FROM cf_sezonlar ORDER BY id DESC LIMIT 5')

    TriggerClientEvent('cross-factions:tabletVeri', source, {
        factionlar    = Factionlar,
        territoriler  = TerritoryDurum,
        savaslar      = aktifSavasListesi,
        benimFactionId = fid,
        aktifGorev    = aktifGorev,
        sezonlar      = sezonlar,
        gorevler      = Config.Gorevler,
    })
end)

-- İstemci sync talebi
RegisterNetEvent('cross-factions:syncIste', function()
    HerkeseSyncGonder()
end)

-- ── Maaş ödeme (örn. her saat) ────────────────────────────────
CreateThread(function()
    while true do
        Wait(3600 * 1000) -- Her saat
        local tumOyuncular = QBCore.Functions.GetQBPlayers()
        for _, p in pairs(tumOyuncular) do
            local fid, f, uye = OyuncuFactioniBul(p.PlayerData.citizenid)
            if fid and uye and uye.maas > 0 then
                p.Functions.AddMoney('cash', uye.maas, 'faction-maas')
                TriggerClientEvent('cross-factions:bildirim', p.PlayerData.source,
                    'Faction maaşı alındı: $' .. uye.maas, 'success')
            end
        end
    end
end)
