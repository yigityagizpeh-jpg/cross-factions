--[[
    cross-factions — Config
    Tüm sistem ayarları bu dosyadan yapılır.
    İstemci ve sunucu tarafı paylaşımlı olarak yüklenir.
--]]

Config = {}

-- ─── Genel ────────────────────────────────────────────────────────────────────
Config.Debug            = false          -- Debug modunda konsol çıktıları aktif
Config.Locale           = 'tr'           -- Varsayılan dil ('tr' veya 'en')
Config.NotifyDuration   = 5000           -- Bildirim süresi (ms)

-- ─── Gang Oluşturma Gereksinimleri ────────────────────────────────────────────
Config.GangCreation = {
    RequireAdmin  = false,               -- true → sadece admin oluşturabilir
    RequireMoney  = true,                -- Para şartı
    MoneyAmount   = 50000,               -- Gerekli para miktarı ($ cinsinden)
    RequireItem   = false,               -- Item şartı
    ItemName      = 'gang_license',      -- Gerekli item adı
    MaxNameLength = 32,                  -- Gang adı maksimum karakter
    MinNameLength = 3,                   -- Gang adı minimum karakter
    MaxTagLength  = 5,                   -- Gang tag maksimum karakter
    MaxGangs      = 20,                  -- Sunucuda maksimum gang sayısı
}

-- ─── Gang Rütbe Sistemi ───────────────────────────────────────────────────────
-- Her rütbenin yetki listesi; izinler boolean olarak tanımlanır
Config.GangRanks = {
    [1] = {
        name  = 'Recruit',
        label = 'Çaylak',
        perms = {
            canUseStash     = false,
            canUseArmory    = false,
            canUseGarage    = true,
            canSpray        = false,
            canInvite       = false,
            canKick         = false,
            canPromote      = false,
            canManageWar    = false,
            canAccessTreasury = false,
        },
    },
    [2] = {
        name  = 'Member',
        label = 'Üye',
        perms = {
            canUseStash     = true,
            canUseArmory    = false,
            canUseGarage    = true,
            canSpray        = true,
            canInvite       = false,
            canKick         = false,
            canPromote      = false,
            canManageWar    = false,
            canAccessTreasury = false,
        },
    },
    [3] = {
        name  = 'Enforcer',
        label = 'Uygulayıcı',
        perms = {
            canUseStash     = true,
            canUseArmory    = true,
            canUseGarage    = true,
            canSpray        = true,
            canInvite       = true,
            canKick         = false,
            canPromote      = false,
            canManageWar    = false,
            canAccessTreasury = false,
        },
    },
    [4] = {
        name  = 'CoLeader',
        label = 'Yardımcı Lider',
        perms = {
            canUseStash     = true,
            canUseArmory    = true,
            canUseGarage    = true,
            canSpray        = true,
            canInvite       = true,
            canKick         = true,
            canPromote      = true,
            canManageWar    = true,
            canAccessTreasury = true,
        },
    },
    [5] = {
        name  = 'Leader',
        label = 'Lider',
        perms = {
            canUseStash     = true,
            canUseArmory    = true,
            canUseGarage    = true,
            canSpray        = true,
            canInvite       = true,
            canKick         = true,
            canPromote      = true,
            canManageWar    = true,
            canAccessTreasury = true,
        },
    },
}

-- ─── Turf (Bölge) Listesi ─────────────────────────────────────────────────────
-- coords: bölgenin merkez koordinatları
-- radius: ele geçirme alanının yarıçapı
-- captureTime: ele geçirme süresi (saniye)
-- cooldown: aynı bölge tekrar saldırılamaz süresi (saniye)
-- minAttackers: saldırı için gereken minimum saldırgan sayısı
-- minDefenders: savunma için gereken minimum savunan sayısı
-- minPolice: bölge savaşı için asgari aktif polis sayısı (0 = polis şartı yok)
-- income: saatlik gang kasası geliri ($)
-- incomeInterval: gelir periyodu (dakika)
-- bonuses: bu bölgeye sahip olunca kazanılan bonuslar
Config.Turfs = {
    {
        id          = 1,
        name        = 'Forum Drive',
        coords      = vector3(-56.0, -1637.0, 29.0),
        radius      = 80.0,
        captureTime = 300,
        cooldown    = 3600,
        minAttackers = 2,
        minDefenders = 1,
        minPolice   = 0,
        income      = 5000,
        incomeInterval = 60,
        bonuses = {
            drugBonus    = 10,    -- % drug processing hız bonusu
            craftBonus   = 5,     -- % crafting hız bonusu
            saleBonus    = 5,     -- % satış bonusu
        },
    },
    {
        id          = 2,
        name        = 'Chamberlain Hills',
        coords      = vector3(119.0, -1717.0, 29.2),
        radius      = 90.0,
        captureTime = 360,
        cooldown    = 3600,
        minAttackers = 2,
        minDefenders = 1,
        minPolice   = 0,
        income      = 6000,
        incomeInterval = 60,
        bonuses = {
            drugBonus    = 15,
            craftBonus   = 0,
            saleBonus    = 10,
        },
    },
    {
        id          = 3,
        name        = 'Davis',
        coords      = vector3(105.0, -1935.0, 20.8),
        radius      = 100.0,
        captureTime = 420,
        cooldown    = 7200,
        minAttackers = 3,
        minDefenders = 2,
        minPolice   = 0,
        income      = 8000,
        incomeInterval = 60,
        bonuses = {
            drugBonus    = 20,
            craftBonus   = 10,
            saleBonus    = 15,
        },
    },
    {
        id          = 4,
        name        = 'Strawberry',
        coords      = vector3(-271.0, -1474.0, 31.2),
        radius      = 85.0,
        captureTime = 300,
        cooldown    = 3600,
        minAttackers = 2,
        minDefenders = 1,
        minPolice   = 0,
        income      = 5500,
        incomeInterval = 60,
        bonuses = {
            drugBonus    = 10,
            craftBonus   = 5,
            saleBonus    = 5,
        },
    },
    {
        id          = 5,
        name        = 'Vespucci Canals',
        coords      = vector3(-1157.0, -1516.0, 3.0),
        radius      = 95.0,
        captureTime = 360,
        cooldown    = 3600,
        minAttackers = 2,
        minDefenders = 1,
        minPolice   = 0,
        income      = 7000,
        incomeInterval = 60,
        bonuses = {
            drugBonus    = 5,
            craftBonus   = 20,
            saleBonus    = 10,
        },
    },
}

-- ─── Savaş Sistemi ────────────────────────────────────────────────────────────
Config.War = {
    MaxActiveWars     = 3,               -- Aynı anda maksimum aktif savaş sayısı
    DefaultWarDuration = 86400,          -- Savaş süresi (saniye, 24 saat)
    AcceptTimeout     = 300,             -- War daveti kabul etme süresi (saniye)
    AllianceAcceptTimeout = 300,         -- Alliance daveti kabul etme süresi
    FriendlyFire      = false,           -- Alliance gang'lere dost ateşi (varsayılan kapalı)
    WarEndReputationWin  = 500,          -- Savaş galibine itibar bonusu
    WarEndReputationLose = -100,         -- Savaş mağlubuna itibar maliyeti
    KillFarmCooldown  = 300,             -- Aynı oyuncudan kill sayılmama süresi (saniye)
    MaxKillsPerTarget = 3,               -- Bir savaşta aynı hedefe sayılabilecek maksimum öldürme
}

-- ─── Spray Sistemi ────────────────────────────────────────────────────────────
Config.Spray = {
    RequiredItem  = 'spray_can',         -- Spray yapmak için gerekli item
    Duration      = 5.0,                 -- Spray yapma progress bar süresi (saniye)
    SprayExpiry   = 604800,              -- Spray'in silinme süresi (saniye, 7 gün)
    Cooldown      = 600,                 -- Aynı oyuncu tekrar spray yapma cooldown (saniye)
    Range         = 3.0,                 -- Spray noktasına yaklaşma mesafesi
    -- Tanımlanmış spray noktaları (turf içinde duvarlar)
    Points = {
        { coords = vector3(-56.0, -1648.0, 29.0),  turfId = 1, heading = 0.0 },
        { coords = vector3(119.0, -1730.0, 29.2),  turfId = 2, heading = 90.0 },
        { coords = vector3(105.0, -1950.0, 20.8),  turfId = 3, heading = 180.0 },
        { coords = vector3(-271.0, -1488.0, 31.2), turfId = 4, heading = 270.0 },
        { coords = vector3(-1157.0, -1530.0, 3.0), turfId = 5, heading = 0.0 },
    },
}

-- ─── Stash / Depo Sistemi ─────────────────────────────────────────────────────
Config.Stash = {
    Slots   = 50,                        -- Gang stash slot sayısı
    Weight  = 100000,                    -- Gang stash maksimum ağırlık (gram)
    ArmorySlots  = 30,                   -- Silah stash slot sayısı
    ArmoryWeight = 50000,                -- Silah stash ağırlığı
}

-- ─── Garage Sistemi ───────────────────────────────────────────────────────────
Config.Garage = {
    SpawnCooldown = 300,                 -- Araç spawn cooldown (saniye)
    MaxVehicles   = 5,                   -- Gang başına maksimum araç
    -- Gang garaj noktaları gang oluşturulurken veya config'den tanımlanır
    -- Gerçek sunucuda harita noktalarına uygun koordinatlar girilmeli
    DefaultSpawnPoint = vector4(120.0, -1080.0, 29.2, 90.0),
}

-- ─── Ekonomi ve Gelir ─────────────────────────────────────────────────────────
Config.Economy = {
    MaxTreasury  = 10000000,             -- Gang kasası maksimum para
    IncomeShare  = false,                -- true → gelir online üyelere paylaştırılır
    IncomeSharePercent = 50,             -- Kasaya giden %, geri kalanı üyelere
}

-- ─── Log Sistemi (Discord Webhook) ───────────────────────────────────────────
Config.Logs = {
    Enabled       = true,
    WebhookURL    = 'DISCORD_WEBHOOK_URL_HERE',  -- Discord webhook URL'si
    BotName       = 'Cross-Factions Logs',
    BotAvatar     = '',                  -- Bot avatar URL (opsiyonel)
    Color = {
        Info      = 3447003,             -- Mavi
        Success   = 3066993,             -- Yeşil
        Warning   = 15844367,            -- Sarı
        Error     = 15158332,            -- Kırmızı
        Kill      = 10038562,            -- Koyu kırmızı
        Turf      = 1752220,             -- Turkuaz
        Finance   = 16776960,            -- Altın sarısı
    },
}

-- ─── Kill Tracking / Leaderboard ─────────────────────────────────────────────
Config.Leaderboard = {
    WeeklyReset     = true,              -- Haftalık leaderboard sıfırlama
    MonthlyReset    = false,             -- Aylık leaderboard sıfırlama
    TopGangsShown   = 10,                -- Leaderboard'da gösterilen gang sayısı
}

-- ─── Admin ───────────────────────────────────────────────────────────────────
Config.AdminGroups = { 'admin', 'superadmin', 'god' }
