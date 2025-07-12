-- 清理玩家資料腳本
-- 修復可能過長的 unlocked_weapons 和 unlocked_skills 資料

-- 使用您的資料庫名稱
USE s16_fish;

-- 檢查有問題的資料
SELECT 
    identifier,
    level,
    CHAR_LENGTH(unlocked_weapons) as weapons_length,
    CHAR_LENGTH(unlocked_skills) as skills_length,
    unlocked_weapons,
    unlocked_skills
FROM fishgame_players 
WHERE CHAR_LENGTH(unlocked_weapons) > 1000 OR CHAR_LENGTH(unlocked_skills) > 1000;

-- 重置異常的武器資料（保留基本武器）
UPDATE fishgame_players 
SET unlocked_weapons = '["cannon_1"]'
WHERE CHAR_LENGTH(unlocked_weapons) > 1000;

-- 重置異常的技能資料
UPDATE fishgame_players 
SET unlocked_skills = '[]'
WHERE CHAR_LENGTH(unlocked_skills) > 1000;

-- 檢查修復後的資料
SELECT 
    identifier,
    level,
    CHAR_LENGTH(unlocked_weapons) as weapons_length,
    CHAR_LENGTH(unlocked_skills) as skills_length,
    unlocked_weapons,
    unlocked_skills
FROM fishgame_players 
ORDER BY level DESC
LIMIT 10;

-- 顯示完成信息
SELECT 'Player data cleanup completed!' as Status; 