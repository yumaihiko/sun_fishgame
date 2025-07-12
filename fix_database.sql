-- 修復資料庫欄位長度問題
-- 請在您的 MySQL 資料庫中執行以下 SQL 語句

-- 使用您的資料庫名稱（請根據實際情況修改）
USE fishgame;

-- 修改 fishgame_players 表的欄位類型
ALTER TABLE `fishgame_players` 
MODIFY COLUMN `unlocked_weapons` LONGTEXT DEFAULT NULL,
MODIFY COLUMN `unlocked_skills` LONGTEXT DEFAULT NULL,
MODIFY COLUMN `settings` LONGTEXT DEFAULT NULL;

-- 修改其他表的相關欄位
ALTER TABLE `fishgame_rooms` 
MODIFY COLUMN `settings` LONGTEXT DEFAULT NULL;

ALTER TABLE `fishgame_sessions` 
MODIFY COLUMN `game_data` LONGTEXT DEFAULT NULL;

ALTER TABLE `fishgame_settings` 
MODIFY COLUMN `setting_value` LONGTEXT NOT NULL;

-- 檢查修改結果
DESCRIBE fishgame_players;

-- 顯示完成信息
SELECT 'Database fields updated successfully!' as Status; 