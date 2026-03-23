-- ============================================================
--  cross-factions  |  SQL Şeması
--  Bu dosyayı sunucunuzun veritabanına (örn. essentialmode veya
--  qbcore) aktarın. Tüm tablolar IF NOT EXISTS ile oluşturulur;
--  mevcut tablolar etkilenmez.
--
--  Örnek komut:
--    mysql -u root -p qbcore < sql/schema.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS `cf_factions` (
    `id`            INT          NOT NULL AUTO_INCREMENT,
    `isim`          VARCHAR(64)  NOT NULL UNIQUE,
    `renk`          VARCHAR(16)  NOT NULL,
    `logo_url`      TEXT         DEFAULT NULL,
    `lider_citizen` VARCHAR(50)  NOT NULL,
    `para`          INT          NOT NULL DEFAULT 0,
    `wins`          INT          NOT NULL DEFAULT 0,
    `sezon_wins`    INT          NOT NULL DEFAULT 0,
    `olusturma`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cf_faction_uyeler` (
    `id`            INT          NOT NULL AUTO_INCREMENT,
    `faction_id`    INT          NOT NULL,
    `citizen_id`    VARCHAR(50)  NOT NULL UNIQUE,
    `isim`          VARCHAR(100) NOT NULL,
    `yetki`         INT          NOT NULL DEFAULT 1,
    `maas`          INT          NOT NULL DEFAULT 500,
    `katilma`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`faction_id`) REFERENCES `cf_factions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cf_territoriler` (
    `id`               INT          NOT NULL AUTO_INCREMENT,
    `isim`             VARCHAR(100) NOT NULL,
    `x`                FLOAT        NOT NULL,
    `y`                FLOAT        NOT NULL,
    `z`                FLOAT        NOT NULL,
    `radius`           FLOAT        NOT NULL DEFAULT 80.0,
    `owner_faction_id` INT          DEFAULT NULL,
    `level`            INT          NOT NULL DEFAULT 1,
    `capture_progress` FLOAT        NOT NULL DEFAULT 0.0,
    `son_capture`      TIMESTAMP    DEFAULT NULL,
    `faction_ozel`     INT          DEFAULT NULL,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`owner_faction_id`) REFERENCES `cf_factions`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`faction_ozel`) REFERENCES `cf_factions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cf_savaslar` (
    `id`                INT          NOT NULL AUTO_INCREMENT,
    `saldiran_id`       INT          NOT NULL,
    `savunucu_id`       INT          NOT NULL,
    `territory_id`      INT          DEFAULT NULL,
    `durum`             ENUM('aktif','bitti','berabere') NOT NULL DEFAULT 'aktif',
    `kazanan_id`        INT          DEFAULT NULL,
    `saldiran_kill`     INT          NOT NULL DEFAULT 0,
    `savunucu_kill`     INT          NOT NULL DEFAULT 0,
    `baslangic`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `bitis`             TIMESTAMP    DEFAULT NULL,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`saldiran_id`) REFERENCES `cf_factions`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`savunucu_id`) REFERENCES `cf_factions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cf_sezonlar` (
    `id`            INT          NOT NULL AUTO_INCREMENT,
    `baslangic`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `bitis`         TIMESTAMP    DEFAULT NULL,
    `kazanan_id`    INT          DEFAULT NULL,
    `aktif`         TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`kazanan_id`) REFERENCES `cf_factions`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cf_gorevler` (
    `id`            INT          NOT NULL AUTO_INCREMENT,
    `faction_id`    INT          NOT NULL,
    `gorev_config_id` INT        NOT NULL,
    `durum`         ENUM('aktif','tamamlandi','basarisiz') NOT NULL DEFAULT 'aktif',
    `baslangic`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `bitis`         TIMESTAMP    DEFAULT NULL,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`faction_id`) REFERENCES `cf_factions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
