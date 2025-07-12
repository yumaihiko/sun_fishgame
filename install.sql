-- 魚機遊戲數據庫表結構
-- 請在你的MySQL數據庫中執行以下SQL語句

-- 玩家遊戲數據表
CREATE TABLE IF NOT EXISTS `fishgame_players` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(50) NOT NULL,
    `level` int(11) DEFAULT 1,
    `experience` int(11) DEFAULT 0,
    `total_coins_earned` bigint(20) DEFAULT 0,
    `total_games_played` int(11) DEFAULT 0,
    `total_fish_caught` int(11) DEFAULT 0,
    `best_score` int(11) DEFAULT 0,
    `unlocked_weapons` text DEFAULT NULL,
    `unlocked_skills` text DEFAULT NULL,
    `settings` text DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 遊戲房間表
CREATE TABLE IF NOT EXISTS `fishgame_rooms` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `room_id` varchar(50) NOT NULL,
    `name` varchar(100) NOT NULL,
    `max_players` int(11) DEFAULT 6,
    `current_players` int(11) DEFAULT 0,
    `min_bet` int(11) DEFAULT 100,
    `max_bet` int(11) DEFAULT 5000,
    `status` enum('active','inactive','maintenance') DEFAULT 'active',
    `settings` text DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `room_id` (`room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 遊戲會話表
CREATE TABLE IF NOT EXISTS `fishgame_sessions` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `session_id` varchar(100) NOT NULL,
    `room_id` varchar(50) NOT NULL,
    `identifier` varchar(50) NOT NULL,
    `player_name` varchar(100) DEFAULT NULL,
    `bet_amount` int(11) NOT NULL,
    `start_coins` int(11) NOT NULL,
    `current_coins` int(11) NOT NULL,
    `score` int(11) DEFAULT 0,
    `fish_caught` int(11) DEFAULT 0,
    `bullets_fired` int(11) DEFAULT 0,
    `status` enum('active','finished','disconnected') DEFAULT 'active',
    `start_time` timestamp DEFAULT CURRENT_TIMESTAMP,
    `end_time` timestamp NULL DEFAULT NULL,
    `game_data` text DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `session_id` (`session_id`),
    KEY `identifier` (`identifier`),
    KEY `room_id` (`room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 魚類捕獲記錄表
CREATE TABLE IF NOT EXISTS `fishgame_catches` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `session_id` varchar(100) NOT NULL,
    `identifier` varchar(50) NOT NULL,
    `fish_type` varchar(50) NOT NULL,
    `fish_points` int(11) NOT NULL,
    `weapon_used` varchar(50) NOT NULL,
    `bullets_used` int(11) NOT NULL,
    `coins_earned` int(11) NOT NULL,
    `damage_dealt` int(11) DEFAULT 0,
    `damage_ratio` decimal(5,4) DEFAULT 0.0000,
    `is_final_blow` tinyint(1) DEFAULT 0,
    `catch_time` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `session_id` (`session_id`),
    KEY `identifier` (`identifier`),
    KEY `is_final_blow` (`is_final_blow`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `fishgame_catches` 
ADD COLUMN IF NOT EXISTS `damage_dealt` int(11) DEFAULT 0,
ADD COLUMN IF NOT EXISTS `damage_ratio` decimal(5,4) DEFAULT 0.0000,
ADD COLUMN IF NOT EXISTS `is_final_blow` tinyint(1) DEFAULT 0,
ADD INDEX IF NOT EXISTS `idx_final_blow` (`is_final_blow`);

-- 每日統計表
CREATE TABLE IF NOT EXISTS `fishgame_daily_stats` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(50) NOT NULL,
    `date` date NOT NULL,
    `games_played` int(11) DEFAULT 0,
    `total_bet` bigint(20) DEFAULT 0,
    `total_won` bigint(20) DEFAULT 0,
    `fish_caught` int(11) DEFAULT 0,
    `best_score` int(11) DEFAULT 0,
    `play_time_minutes` int(11) DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `player_date` (`identifier`, `date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 排行榜表
CREATE TABLE IF NOT EXISTS `fishgame_leaderboard` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(50) NOT NULL,
    `player_name` varchar(100) DEFAULT NULL,
    `category` enum('daily_score','weekly_score','monthly_score','total_earnings','fish_caught') NOT NULL,
    `score` bigint(20) NOT NULL,
    `period` varchar(20) NOT NULL, -- YYYY-MM-DD or YYYY-WW or YYYY-MM
    `rank` int(11) DEFAULT NULL,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `player_category_period` (`identifier`, `category`, `period`),
    KEY `category_period_score` (`category`, `period`, `score` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 系統設定表
CREATE TABLE IF NOT EXISTS `fishgame_settings` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `setting_key` varchar(100) NOT NULL,
    `setting_value` text NOT NULL,
    `description` varchar(255) DEFAULT NULL,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `setting_key` (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 插入預設房間數據
INSERT INTO `fishgame_rooms` (`room_id`, `name`, `max_players`, `min_bet`, `max_bet`, `status`) VALUES
('room_1', '初級海域', 6, 100, 5000, 'active'),
('room_2', '中級海域', 8, 1000, 20000, 'active'),
('room_3', '高級海域', 10, 5000, 50000, 'active');

-- 插入預設系統設定
INSERT INTO `fishgame_settings` (`setting_key`, `setting_value`, `description`) VALUES
('max_concurrent_players', '100', '最大同時在線玩家數'),
('maintenance_mode', 'false', '維護模式開關'),
('daily_bonus_enabled', 'true', '每日獎勵是否啟用'),
('experience_multiplier', '1.0', '經驗值倍數'),
('coin_multiplier', '1.0', '金幣倍數'),
('special_event_active', 'false', '特殊活動是否啟用'); 