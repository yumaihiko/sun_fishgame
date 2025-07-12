local ESX = exports["es_extended"]:getSharedObject()

-- 全局變數
FishGame = {}
FishGame.Players = {}
FishGame.Rooms = {}
FishGame.Sessions = {}

-- 初始化資料庫
MySQL.ready(function()
    print('^2[魚機遊戲] ^7數據庫連接成功')
    
    -- 檢查必要的表是否存在
    MySQL.query('SELECT 1 FROM fishgame_players LIMIT 1', {}, function(result)
        if result then
            print('^2[魚機遊戲] ^7數據庫表驗證成功')
        else
            print('^1[魚機遊戲] ^7錯誤：請確保已執行install.sql文件')
        end
    end)
end)

-- 獲取玩家數據
function FishGame.GetPlayerData(identifier)
    local promise = promise.new()
    
    MySQL.query('SELECT * FROM fishgame_players WHERE identifier = ?', {identifier}, function(result)
        if result and result[1] then
            promise:resolve(result[1])
        else
            -- 創建新玩家數據
            MySQL.insert('INSERT INTO fishgame_players (identifier, level, experience, unlocked_weapons, unlocked_skills) VALUES (?, ?, ?, ?, ?)', {
                identifier,
                1,
                0,
                json.encode({'cannon_1'}),
                json.encode({})
            }, function(insertId)
                if insertId then
                    MySQL.query('SELECT * FROM fishgame_players WHERE id = ?', {insertId}, function(newResult)
                        promise:resolve(newResult[1])
                    end)
                else
                    promise:resolve(nil)
                end
            end)
        end
    end)
    
    return Citizen.Await(promise)
end

-- 更新玩家數據
function FishGame.UpdatePlayerData(identifier, data)
    MySQL.update('UPDATE fishgame_players SET level = ?, experience = ?, total_coins_earned = ?, total_games_played = ?, total_fish_caught = ?, best_score = ?, unlocked_weapons = ?, unlocked_skills = ?, updated_at = NOW() WHERE identifier = ?', {
        data.level or 1,
        data.experience or 0,
        data.total_coins_earned or 0,
        data.total_games_played or 0,
        data.total_fish_caught or 0,
        data.best_score or 0,
        json.encode(data.unlocked_weapons or {'cannon_1'}),
        json.encode(data.unlocked_skills or {}),
        identifier
    })
end

-- 檢查玩家金錢
function FishGame.CheckPlayerMoney(playerId, amount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    return xPlayer.getMoney() >= amount
end

-- 扣除玩家金錢
function FishGame.RemovePlayerMoney(playerId, amount, reason)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    if xPlayer.getMoney() >= amount then
        xPlayer.removeMoney(amount, reason or '魚機遊戲')
        return true
    end
    return false
end

-- 增加玩家金錢
function FishGame.AddPlayerMoney(playerId, amount, reason)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    xPlayer.addMoney(amount, reason or '魚機遊戲獎勵')
    return true
end

-- 獲取房間列表
function FishGame.GetRoomList()
    local rooms = {}
    for roomId, roomData in pairs(Config.Rooms) do
        local currentPlayers = 0
        for _, session in pairs(FishGame.Sessions) do
            if session.roomId == roomId and session.status == 'active' then
                currentPlayers = currentPlayers + 1
            end
        end
        
        rooms[roomId] = {
            id = roomId,
            name = roomData.name,
            maxPlayers = roomData.maxPlayers,
            currentPlayers = currentPlayers,
            minBet = roomData.minBet,
            maxBet = roomData.maxBet,
            access = roomData.access
        }
    end
    return rooms
end

-- 獲取玩家在房間中的位置
function FishGame.GetPlayerPositionInRoom(roomId)
    local playerCount = 0
    for _, session in pairs(FishGame.Sessions) do
        if session.roomId == roomId and session.status == 'active' then
            playerCount = playerCount + 1
        end
    end
    
    -- 返回玩家位置索引 (0-5)
    return math.min(playerCount - 1, 5)
end

-- 檢查房間是否可加入
function FishGame.CanJoinRoom(playerId, roomId, betAmount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false, '玩家不存在' end
    
    local room = Config.Rooms[roomId]
    if not room then return false, '房間不存在' end
    
    -- 檢查金錢
    if not FishGame.CheckPlayerMoney(playerId, betAmount) then
        return false, '金錢不足'
    end
    
    -- 檢查下注範圍
    if betAmount < room.minBet or betAmount > room.maxBet then
        return false, '下注金額超出範圍'
    end
    
    -- 檢查房間人數
    local currentPlayers = 0
    for _, session in pairs(FishGame.Sessions) do
        if session.roomId == roomId and session.status == 'active' then
            currentPlayers = currentPlayers + 1
        end
    end
    
    if currentPlayers >= room.maxPlayers then
        return false, '房間已滿'
    end
    
    -- 檢查是否已在遊戲中
    local playerIdentifier = xPlayer.identifier
    for _, session in pairs(FishGame.Sessions) do
        if session.identifier == playerIdentifier and session.status == 'active' then
            return false, '您已在其他房間遊戲中'
        end
    end
    
    return true, 'OK'
end

-- ESX事件
RegisterServerEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local identifier = xPlayer.identifier
    local playerData = FishGame.GetPlayerData(identifier)
    
    if playerData then
        FishGame.Players[playerId] = {
            identifier = identifier,
            name = xPlayer.getName(),
            data = playerData
        }
        
        TriggerClientEvent('fishgame:setPlayerData', playerId, playerData)
    end
end)

RegisterServerEvent('esx:playerDropped')
AddEventHandler('esx:playerDropped', function(playerId, reason)
    -- 清理玩家數據
    if FishGame.Players[playerId] then
        local playerData = FishGame.Players[playerId]
        
        -- 如果玩家在遊戲中，結束會話
        for sessionId, session in pairs(FishGame.Sessions) do
            if session.playerId == playerId then
                FishGame.EndSession(sessionId, 'disconnected')
                break
            end
        end
        
        FishGame.Players[playerId] = nil
    end
end)

-- 客戶端事件處理
RegisterServerEvent('fishgame:getRoomList')
AddEventHandler('fishgame:getRoomList', function()
    local playerId = source
    local rooms = FishGame.GetRoomList()
    TriggerClientEvent('fishgame:receiveRoomList', playerId, rooms)
end)

RegisterServerEvent('fishgame:getPlayerData')
AddEventHandler('fishgame:getPlayerData', function()
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    local playerData = FishGame.GetPlayerData(identifier)
    
    if playerData then
        FishGame.Players[playerId] = {
            identifier = identifier,
            name = xPlayer.getName(),
            data = playerData
        }
        
        TriggerClientEvent('fishgame:setPlayerData', playerId, playerData)
    end
end)

RegisterServerEvent('fishgame:joinRoom')
AddEventHandler('fishgame:joinRoom', function(roomId, betAmount)
    local playerId = source
    
    print('^2[魚機遊戲] ^7收到加入房間請求 - 玩家ID:', playerId, '房間ID:', roomId, '下注金額:', betAmount)
    
    local canJoin, message = FishGame.CanJoinRoom(playerId, roomId, betAmount)
    
    if not canJoin then
        print('^1[魚機遊戲] ^7加入房間失敗:', message)
        TriggerClientEvent('fishgame:showNotification', playerId, message, 'error')
        return
    end
    
    print('^2[魚機遊戲] ^7房間檢查通過，開始扣除金錢')
    
    -- 扣除金錢
    if not FishGame.RemovePlayerMoney(playerId, betAmount, '魚機遊戲下注') then
        print('^1[魚機遊戲] ^7扣款失敗')
        TriggerClientEvent('fishgame:showNotification', playerId, '扣款失敗', 'error')
        return
    end
    
    print('^2[魚機遊戲] ^7金錢扣除成功，開始創建遊戲會話')
    
    -- 創建遊戲會話
    local sessionId = FishGame.CreateSession(playerId, roomId, betAmount)
    
    print('^2[魚機遊戲] ^7會話創建結果 - sessionId:', sessionId)
    
    if sessionId then
        -- 計算玩家位置
        local playerPosition = FishGame.GetPlayerPositionInRoom(roomId)
        print('^2[魚機遊戲] ^7玩家位置分配:', playerPosition)
        
        print('^2[魚機遊戲] ^7發送joinedRoom事件給客戶端')
        TriggerClientEvent('fishgame:joinedRoom', playerId, roomId, sessionId, betAmount, playerPosition, {
            fishTypes = Config.FishTypes,
            weapons = Config.Weapons,
            specialSkills = Config.SpecialSkills
        })
        TriggerClientEvent('fishgame:showNotification', playerId, '成功加入 ' .. Config.Rooms[roomId].name, 'success')
        
        -- 獲取房間內玩家列表
        local players = FishGame.GetRoomPlayers(roomId)
        TriggerClientEvent('fishgame:receiveRoomPlayers', playerId, players)
        
        -- 同步房間狀態
        FishGame.SyncRoomState(roomId)
    else
        print('^1[魚機遊戲] ^7會話創建失敗，退還金錢')
        -- 退還金錢
        FishGame.AddPlayerMoney(playerId, betAmount, '魚機遊戲退款')
        TriggerClientEvent('fishgame:showNotification', playerId, '加入房間失敗', 'error')
    end
end)

RegisterServerEvent('fishgame:leaveRoom')
AddEventHandler('fishgame:leaveRoom', function()
    local playerId = source
    
    -- 找到玩家的會話
    for sessionId, session in pairs(FishGame.Sessions) do
        if session.playerId == playerId and session.status == 'active' then
            FishGame.EndSession(sessionId, 'finished')
            TriggerClientEvent('fishgame:leftRoom', playerId)
            break
        end
    end
end)

RegisterServerEvent('fishgame:useSkill')
AddEventHandler('fishgame:useSkill', function(sessionId, skillType)
    local playerId = source
    local session = FishGame.Sessions[sessionId]
    
    print('^2[魚機遊戲] ^7收到技能使用請求 - 玩家:', playerId, '技能:', skillType)
    
    if not session or session.playerId ~= playerId or session.status ~= 'active' then
        print('^1[魚機遊戲] ^7技能使用失敗：無效會話')
        TriggerClientEvent('fishgame:showNotification', playerId, '無效會話', 'error')
        return
    end
    
    local skill = Config.SpecialSkills[skillType]
    if not skill then
        print('^1[魚機遊戲] ^7技能使用失敗：未知技能')
        TriggerClientEvent('fishgame:showNotification', playerId, '未知技能', 'error')
        return
    end
    
    -- 檢查金幣是否足夠
    if session.currentCoins < skill.cost then
        print('^1[魚機遊戲] ^7技能使用失敗：金幣不足')
        TriggerClientEvent('fishgame:showNotification', playerId, '金幣不足', 'error')
        return
    end
    
    -- 扣除技能成本
    session.currentCoins = session.currentCoins - skill.cost
    
    print('^2[魚機遊戲] ^7技能使用成功 - 剩餘金幣:', session.currentCoins)
    
    -- 廣播技能效果到房間內所有玩家
    FishGame.BroadcastToRoom(session.roomId, 'fishgame:skillActivated', {
        playerId = playerId,
        playerName = session.playerName,
        skillType = skillType,
        skillName = skill.name,
        duration = skill.duration
    })
    
    -- 通知使用者技能成功激活
    TriggerClientEvent('fishgame:showNotification', playerId, '技能激活：' .. skill.name, 'success')
    
    -- 更新會話狀態
    if not session.skills.active then
        session.skills.active = {}
    end
    
    session.skills.active[skillType] = {
        startTime = os.time(),
        duration = skill.duration / 1000, -- 轉換為秒
        endTime = os.time() + (skill.duration / 1000)
    }
    
    -- 根據技能類型執行特定效果
    if skillType == 'freeze_all' then
        -- 冰凍所有魚類
        for fishId, fish in pairs(session.gameData.fish) do
            fish.frozen = true
        end
        
    elseif skillType == 'double_points' then
        -- 雙倍積分效果
        session.doublePoints = true
        
    elseif skillType == 'auto_aim' then
        -- 自動瞄準效果
        session.autoAim = true
        
    elseif skillType == 'lightning_strike' then
        -- 閃電打擊：立即對所有魚造成傷害
        for fishId, fish in pairs(session.gameData.fish) do
            if fish.alive then
                fish.health = math.max(0, fish.health - 2)
                if fish.health <= 0 then
                    fish.alive = false
                    -- 給予積分獎勵
                    local points = fish.points
                    if session.doublePoints then
                        points = points * 2
                    end
                    session.score = session.score + points
                    session.fishCaught = session.fishCaught + 1
                end
            end
        end
    end
end)

-- 獲取排行榜數據
RegisterServerEvent('fishgame:getLeaderboard')
AddEventHandler('fishgame:getLeaderboard', function(period)
    local playerId = source
    local period = period or 'daily'
    
    print('^2[魚機遊戲] ^7收到排行榜請求 - 玩家:', playerId, '期間:', period)
    
    local query = ''
    local params = {}
    
    if period == 'daily' then
        query = [[
            SELECT 
                p.identifier,
                p.nickname,
                p.level,
                SUM(s.score) as total_score,
                SUM(s.coins_earned) as total_coins,
                SUM(s.fish_caught) as total_fish,
                MAX(s.score) as best_score
            FROM fishgame_sessions s
            JOIN fishgame_players p ON s.identifier = p.identifier
            WHERE DATE(s.start_time) = CURDATE()
            GROUP BY p.identifier, p.nickname, p.level
            ORDER BY total_score DESC
            LIMIT 50
        ]]
    elseif period == 'weekly' then
        query = [[
            SELECT 
                p.identifier,
                p.nickname,
                p.level,
                SUM(s.score) as total_score,
                SUM(s.coins_earned) as total_coins,
                SUM(s.fish_caught) as total_fish,
                MAX(s.score) as best_score
            FROM fishgame_sessions s
            JOIN fishgame_players p ON s.identifier = p.identifier
            WHERE YEARWEEK(s.start_time, 1) = YEARWEEK(CURDATE(), 1)
            GROUP BY p.identifier, p.nickname, p.level
            ORDER BY total_score DESC
            LIMIT 50
        ]]
    elseif period == 'monthly' then
        query = [[
            SELECT 
                p.identifier,
                p.nickname,
                p.level,
                SUM(s.score) as total_score,
                SUM(s.coins_earned) as total_coins,
                SUM(s.fish_caught) as total_fish,
                MAX(s.score) as best_score
            FROM fishgame_sessions s
            JOIN fishgame_players p ON s.identifier = p.identifier
            WHERE YEAR(s.start_time) = YEAR(CURDATE()) 
            AND MONTH(s.start_time) = MONTH(CURDATE())
            GROUP BY p.identifier, p.nickname, p.level
            ORDER BY total_score DESC
            LIMIT 50
        ]]
    else -- total
        query = [[
            SELECT 
                p.identifier,
                p.nickname,
                p.level,
                p.total_coins_earned as total_coins,
                p.total_fish_caught as total_fish,
                p.best_score,
                p.experience as total_score
            FROM fishgame_players p
            ORDER BY p.experience DESC
            LIMIT 50
        ]]
    end
    
    MySQL.query(query, params, function(result)
        if result then
            local leaderboard = {}
            for i, player in ipairs(result) do
                table.insert(leaderboard, {
                    rank = i,
                    identifier = player.identifier,
                    name = player.nickname or 'Unknown',
                    level = player.level,
                    score = player.total_score or 0,
                    coins = player.total_coins or 0,
                    fishCaught = player.total_fish or 0,
                    bestScore = player.best_score or 0
                })
            end
            
            TriggerClientEvent('fishgame:ui_updateLeaderboard', playerId, {
                period = period,
                data = leaderboard,
                timestamp = os.time()
            })
        else
            TriggerClientEvent('fishgame:ui_updateLeaderboard', playerId, {
                period = period,
                data = {},
                error = '無法獲取排行榜數據'
            })
        end
    end)
end)

-- 獲取統計數據
RegisterServerEvent('fishgame:getStatistics')
AddEventHandler('fishgame:getStatistics', function()
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    print('^2[魚機遊戲] ^7收到統計數據請求 - 玩家:', playerId)
    
    -- 獲取玩家統計數據
    MySQL.query('SELECT * FROM fishgame_players WHERE identifier = ?', {identifier}, function(playerResult)
        if playerResult and playerResult[1] then
            local playerData = playerResult[1]
            
            -- 獲取遊戲會話統計
            MySQL.query([[
                SELECT 
                    COUNT(*) as total_sessions,
                    SUM(score) as lifetime_score,
                    AVG(score) as avg_score,
                    SUM(fish_caught) as lifetime_fish,
                    AVG(fish_caught) as avg_fish,
                    SUM(bullets_fired) as lifetime_bullets,
                    AVG(bullets_fired) as avg_bullets,
                    SUM(coins_earned) as lifetime_earned,
                    AVG(coins_earned) as avg_earned,
                    SUM(coins_spent) as lifetime_spent,
                    AVG(coins_spent) as avg_spent,
                    MAX(score) as best_session_score,
                    MAX(fish_caught) as best_session_fish,
                    MAX(coins_earned) as best_session_coins
                FROM fishgame_sessions 
                WHERE identifier = ?
            ]], {identifier}, function(sessionResult)
                local sessionStats = sessionResult and sessionResult[1] or {}
                
                -- 獲取魚類捕獲統計
                MySQL.query([[
                    SELECT 
                        fish_type,
                        COUNT(*) as catch_count,
                        SUM(fish_points) as total_points,
                        SUM(coins_earned) as total_coins
                    FROM fishgame_catches 
                    WHERE identifier = ?
                    GROUP BY fish_type
                    ORDER BY catch_count DESC
                    LIMIT 20
                ]], {identifier}, function(catchResult)
                    local fishStats = {}
                    if catchResult then
                        for _, fish in ipairs(catchResult) do
                            local fishConfig = Config.FishTypes[fish.fish_type]
                            table.insert(fishStats, {
                                type = fish.fish_type,
                                name = fishConfig and fishConfig.name or 'Unknown',
                                count = fish.catch_count,
                                points = fish.total_points,
                                coins = fish.total_coins
                            })
                        end
                    end
                    
                    -- 組合所有統計數據
                    local statistics = {
                        player = {
                            level = playerData.level,
                            experience = playerData.experience,
                            totalCoinsEarned = playerData.total_coins_earned,
                            totalGamesPlayed = playerData.total_games_played,
                            totalFishCaught = playerData.total_fish_caught,
                            bestScore = playerData.best_score,
                            unlockedWeapons = json.decode(playerData.unlocked_weapons or '[]'),
                            unlockedSkills = json.decode(playerData.unlocked_skills or '[]'),
                            createdAt = playerData.created_at
                        },
                        sessions = {
                            totalSessions = tonumber(sessionStats.total_sessions) or 0,
                            lifetimeScore = tonumber(sessionStats.lifetime_score) or 0,
                            avgScore = tonumber(sessionStats.avg_score) or 0,
                            lifetimeFish = tonumber(sessionStats.lifetime_fish) or 0,
                            avgFish = tonumber(sessionStats.avg_fish) or 0,
                            lifetimeBullets = tonumber(sessionStats.lifetime_bullets) or 0,
                            avgBullets = tonumber(sessionStats.avg_bullets) or 0,
                            lifetimeEarned = tonumber(sessionStats.lifetime_earned) or 0,
                            avgEarned = tonumber(sessionStats.avg_earned) or 0,
                            lifetimeSpent = tonumber(sessionStats.lifetime_spent) or 0,
                            avgSpent = tonumber(sessionStats.avg_spent) or 0,
                            bestSessionScore = tonumber(sessionStats.best_session_score) or 0,
                            bestSessionFish = tonumber(sessionStats.best_session_fish) or 0,
                            bestSessionCoins = tonumber(sessionStats.best_session_coins) or 0
                        },
                        fishStats = fishStats
                    }
                    
                    TriggerClientEvent('fishgame:ui_updateStatistics', playerId, statistics)
                end)
            end)
        else
            TriggerClientEvent('fishgame:ui_updateStatistics', playerId, {
                error = '無法獲取統計數據'
            })
        end
    end)
end)

-- 保存設定
RegisterServerEvent('fishgame:saveSettings')
AddEventHandler('fishgame:saveSettings', function(settings)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    -- 更新玩家設定（可以保存到數據庫或暫存）
    if FishGame.Players[playerId] then
        FishGame.Players[playerId].settings = settings
    end
    
    TriggerClientEvent('fishgame:showNotification', playerId, '設定已保存', 'success')
end)

-- 定時清理過期會話
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- 每分鐘檢查一次
        
        local currentTime = os.time()
        for sessionId, session in pairs(FishGame.Sessions) do
            -- 清理超過1小時的非活躍會話
            if currentTime - session.startTime > 3600 and session.status ~= 'active' then
                FishGame.Sessions[sessionId] = nil
            end
        end
    end
end)

print('^2[魚機遊戲] ^7服務端主腳本載入完成') 