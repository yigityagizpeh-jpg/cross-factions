-- =============================================================================
-- cross-factions — SQL Kurulum Dosyası
-- Tüm tablolar, indexler ve foreign key'ler burada tanımlanmıştır.
-- Çalıştırmadan önce charset'in utf8mb4 olduğundan emin olun.
-- =============================================================================

SET NAMES utf8mb4;
SET foreign_key_checks = 0;

-- ─── Gang Ana Tablosu ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cf_gangs` (
    `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `name`        VARCHAR(64)     NOT NULL,
    `tag`         VARCHAR(10)     NOT NULL,
    `color`       VARCHAR(10)     NOT NULL DEFAULT '#FF0000',
    `leader_cid`  VARCHAR(50)     NOT NULL,
    `treasury`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `level`       TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `reputation`  INT             NOT NULL DEFAULT 0,
    `settings`    JSON            NULL,
    `created_at`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_name`   (`name`),
    INDEX `idx_leader`     (`leader_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Gang Üyeleri ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cf_gang_members` (
    `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `gang_id`     INT UNSIGNED    NOT NULL,
    `citizenid`   VARCHAR(50)     NOT NULL,
    `rank_index`  TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Recruit 2=Member 3=Enforcer 4=CoLeader 5=Leader',
    `joined_at`   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_citizen`   (`citizenid`),
    INDEX `idx_gang`          (`gang_id`),
    CONSTRAINT `fk_members_gang` FOREIGN KEY (`gang_id`) REFERENCES `cf_gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Turf Sahipliği ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cf_turf_ownership` (
    `turf_id`       TINYINT UNSIGNED NOT NULL COMMENT 'Config.Turfs[i].id ile eşleşir',
    `owner_gang_id` INT UNSIGNED     NULL,
    `cooldown_until` TIMESTAMP       NULL,
    `captured_at`   TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`turf_id`),
    INDEX `idx_owner`   (`owner_gang_id`),
    CONSTRAINT `fk_turf_gang` FOREIGN KEY (`owner_gang_id`) REFERENCES `cf_gangs` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Gang Savaşları ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cf_gang_wars` (
    `id`            INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `gang1_id`      INT UNSIGNED    NOT NULL,
    `gang2_id`      INT UNSIGNED    NOT NULL,
    `gang1_kills`   INT UNSIGNED    NOT NULL DEFAULT 0,
    `gang2_kills`   INT UNSIGNED    NOT NULL DEFAULT 0,
    `status`        ENUM('active', 'ended') NOT NULL DEFAULT 'active',
    `starts_at`     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ends_at`       TIMESTAMP       NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_gang1`    (`gang1_id`),
    INDEX `idx_gang2`    (`gang2_id`),
    INDEX `idx_status`   (`status`),
    CONSTRAINT `fk_war_gang1` FOREIGN KEY (`gang1_id`) REFERENCES `cf_gangs` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_war_gang2` FOREIGN KEY (`gang2_id`) REFERENCES `cf_gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Gang İttifakları ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cf_gang_alliances` (
    `id`        INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `gang1_id`  INT UNSIGNED    NOT NULL,
    `gang2_id`  INT UNSIGNED    NOT NULL,
    `status`    ENUM('active', 'broken') NOT NULL DEFAULT 'active',
    `created_at` TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_alliance`    (`gang1_id`, `gang2_id`),
    INDEX `idx_g1`              (`gang1_id`),
    INDEX `idx_g2`              (`gang2_id`),
    CONSTRAINT `fk_ally_gang1` FOREIGN KEY (`gang1_id`) REFERENCES `cf_gangs` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_ally_gang2` FOREIGN KEY (`gang2_id`) REFERENCES `cf_gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Kill Logları ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cf_kill_logs` (
    `id`              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `killer_cid`      VARCHAR(50)     NOT NULL,
    `victim_cid`      VARCHAR(50)     NOT NULL,
    `killer_gang_id`  INT UNSIGNED    NOT NULL,
    `victim_gang_id`  INT UNSIGNED    NOT NULL,
    `killed_at`       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_killer_gang`   (`killer_gang_id`),
    INDEX `idx_victim_gang`   (`victim_gang_id`),
    INDEX `idx_killed_at`     (`killed_at`),
    INDEX `idx_killer_cid`    (`killer_cid`),
    INDEX `idx_victim_cid`    (`victim_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Spray Verileri ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cf_gang_sprays` (
    `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `gang_id`     INT UNSIGNED    NOT NULL,
    `point_index` TINYINT UNSIGNED NOT NULL COMMENT 'Config.Spray.Points[i] indeksi',
    `gang_tag`    VARCHAR(10)     NOT NULL,
    `gang_color`  VARCHAR(10)     NOT NULL DEFAULT '#FFFFFF',
    `created_by`  VARCHAR(50)     NOT NULL COMMENT 'CID',
    `created_at`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at`  TIMESTAMP       NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_point`    (`point_index`),
    INDEX `idx_gang`         (`gang_id`),
    INDEX `idx_expires`      (`expires_at`),
    CONSTRAINT `fk_spray_gang` FOREIGN KEY (`gang_id`) REFERENCES `cf_gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Finans Logları ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `cf_finance_logs` (
    `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `gang_id`     INT UNSIGNED    NOT NULL,
    `type`        VARCHAR(32)     NOT NULL COMMENT 'deposit, withdraw, turf_income, war_reward, ...',
    `amount`      BIGINT          NOT NULL,
    `description` VARCHAR(255)    NULL,
    `created_at`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_gang`         (`gang_id`),
    INDEX `idx_type`         (`type`),
    INDEX `idx_created_at`   (`created_at`),
    CONSTRAINT `fk_finance_gang` FOREIGN KEY (`gang_id`) REFERENCES `cf_gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET foreign_key_checks = 1;

-- =============================================================================
-- Örnek: 5 turf kaydını varsayılan (sahipsiz) olarak hazırla
-- =============================================================================
INSERT IGNORE INTO `cf_turf_ownership` (`turf_id`) VALUES (1), (2), (3), (4), (5);
