-- ============================================================
--  cross-factions  |  Konfigürasyon Dosyası
-- ============================================================

Config = {}

-- ── Genel ──────────────────────────────────────────────────
Config.Debug = false                -- true ise sunucu konsoluna detaylı log basar

-- ── Faction ─────────────────────────────────────────────────
Config.MaxFactionUyeSayisi   = 20   -- Faction başına maksimum üye
Config.MinFactionUyeSayisi   = 1    -- Faction kurmak için gereken minimum (kurucu dahil)
Config.FactionIsimMinUzunluk = 3    -- Faction ismi minimum karakter
Config.FactionIsimMaxUzunluk = 24   -- Faction ismi maksimum karakter
Config.VarsayilanMaas         = 500  -- Yeni üyelere verilecek başlangıç maaşı ($)

-- Kullanılabilir faction renkleri (HEX) – iki faction aynı rengi alamaz
Config.FactionRenkleri = {
    '#e74c3c', '#e67e22', '#f1c40f', '#2ecc71',
    '#1abc9c', '#3498db', '#9b59b6', '#e91e63',
    '#00bcd4', '#8bc34a', '#ff5722', '#607d8b',
    '#795548', '#ff9800', '#cddc39', '#009688',
}

-- Faction yetki seviyeleri (1 = en düşük)
Config.YetkiSeviyeleri = {
    { seviye = 1, isim = 'Üye'     },
    { seviye = 2, isim = 'Askeri'  },
    { seviye = 3, isim = 'Subay'   },
    { seviye = 4, isim = 'Komutan' },
    { seviye = 5, isim = 'Lider'   },
}

-- ── Territory ───────────────────────────────────────────────
Config.TerritoryYakalamaMinoyuncu  = 2     -- Bir bölgeyi capture etmek için gereken min. oyuncu sayısı
Config.TerritoryYakalamaMaxSure    = 120   -- Tam capture için gereken süre (saniye)
Config.TerritoryYakalamaDuraksama  = 30    -- Rakip faction varken donma/yavaşlama süresi (saniye)
Config.TerritoryYavaşlamaÇarpan    = 0.3   -- Rakip faction varken ilerleme çarpanı (0-1)
Config.TerritoryCooldownSuresi     = 300   -- Capture sonrası cooldown (saniye)

-- Haritadaki tüm territory bölgeleri
Config.Territoriler = {
    {
        id       = 1,
        isim     = 'Vinewood Tepeleri',
        x        = 252.0,
        y        = 201.0,
        z        = 104.0,
        radius   = 80.0,
        level    = 1,
    },
    {
        id       = 2,
        isim     = 'Grove Sokağı',
        x        = 116.0,
        y        = -1944.0,
        z        = 20.0,
        radius   = 70.0,
        level    = 1,
    },
    {
        id       = 3,
        isim     = 'Bawsaq Binası',
        x        = -75.0,
        y        = -818.0,
        z        = 326.0,
        radius   = 60.0,
        level    = 2,
    },
    {
        id       = 4,
        isim     = 'Alamo Denizi',
        x        = 1135.0,
        y        = 2671.0,
        z        = 36.0,
        radius   = 90.0,
        level    = 1,
    },
    {
        id       = 5,
        isim     = 'Paleto Limanı',
        x        = -270.0,
        y        = 6205.0,
        z        = 7.0,
        radius   = 75.0,
        level    = 1,
    },
    {
        id       = 6,
        isim     = 'Sandy Shores',
        x        = 1848.0,
        y        = 3686.0,
        z        = 33.0,
        radius   = 80.0,
        level    = 2,
    },
    {
        id       = 7,
        isim     = 'Maze Bankası',
        x        = 231.0,
        y        = 214.0,
        z        = 107.0,
        radius   = 50.0,
        level    = 3,
    },
    {
        id       = 8,
        isim     = 'Davis Mahallesi',
        x        = 84.0,
        y        = -1948.0,
        z        = 20.0,
        radius   = 65.0,
        level    = 2,
    },
}

-- ── War ─────────────────────────────────────────────────────
Config.SavasIlanCooldown     = 3600  -- İki savaş ilan arasındaki bekleme (saniye)
Config.SavasMaksSure         = 1800  -- Savaş maksimum süresi (saniye); süre dolunca draw
Config.SavasMinKatilimci     = 2     -- Savaş başlamak için her taraftan min. oyuncu
Config.SavasKazanmaKill      = 20    -- Kill-count modunda kazanmak için gereken kill sayısı
Config.SavasAFKSure          = 60    -- Bu süre hareket yoksa AFK sayılır ve savaş dışı bırakılır (saniye)
Config.SavasAFKMesafe        = 3.0   -- AFK kontrolü için minimum hareket mesafesi (metre)

-- ── Sezon ───────────────────────────────────────────────────
Config.SezonSuresi           = 120   -- Sezon süresi GÜN olarak (örn. 120 = ~4 ay)
Config.SezonOdulPara         = 50000 -- Sezon birincisine verilecek para ödülü ($)
Config.SezonOdulItem         = 'gold_bar'  -- Sezon birincisine verilecek item (inventory item adı)
Config.SezonOdulItemMiktar   = 5           -- Item miktarı

-- ── Görev / Contract ────────────────────────────────────────
Config.GorevSuresi           = 3600  -- Görev süresi (saniye)
Config.GorevCooldown         = 7200  -- Görev alma cooldown'u (saniye)
Config.Gorevler = {
    {
        id      = 1,
        isim    = 'Nakit Taşıma',
        aciklama = 'Belirtilen konuma $50.000 nakit teslim edin.',
        odulPara = 10000,
        odulItem = nil,
        sure     = 3600,
    },
    {
        id      = 2,
        isim    = 'Bölge Koruma',
        aciklama = '30 dakika boyunca bir bölgeyi savunun.',
        odulPara = 8000,
        odulItem = nil,
        sure     = 1800,
    },
    {
        id      = 3,
        isim    = 'Hedef Etkisizleştirme',
        aciklama = 'Rakip faction liderini 3 kez etkisizleştirin.',
        odulPara = 15000,
        odulItem = 'weapon_pistol',
        sure     = 7200,
    },
}

-- ── Faction Yönetim Yeri ────────────────────────────────────
-- Oyuncular bu koordinatta Faction tabletini açabilir.
Config.YonetimYeri = {
    x      = 315.8,
    y      = -191.2,
    z      = 54.3,
    radius = 3.0,   -- Etkileşim yarıçapı (metre)
}

-- ── Blip renk kodları (GTA blip colour index) ────────────────
Config.BlipRenkleri = {
    ['#e74c3c'] = 1,  ['#e67e22'] = 17, ['#f1c40f'] = 5,
    ['#2ecc71'] = 2,  ['#1abc9c'] = 53, ['#3498db'] = 3,
    ['#9b59b6'] = 27, ['#e91e63'] = 6,  ['#00bcd4'] = 4,
    ['#8bc34a'] = 11, ['#ff5722'] = 76, ['#607d8b'] = 7,
    ['#795548'] = 43, ['#ff9800'] = 17, ['#cddc39'] = 43,
    ['#009688'] = 53,
}
