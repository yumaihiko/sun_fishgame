-- 房間管理系統

-- 確保FishGame表存在
if not FishGame then
    FishGame = {}
    FishGame.Players = {}
    FishGame.Rooms = {}
    FishGame.Sessions = {}
end

-- 初始化房間遊戲數據
function FishGame.InitializeRoomGameData(roomId)
    if not FishGame.Rooms[roomId] then
        FishGame.Rooms[roomId] = {
            id = roomId,
            activePlayers = {},
            gameData = {
                fish = {},          -- 房間共享的魚類
                bullets = {},       -- 房間共享的子彈
                effects = {},       -- 房間共享的特效
                lastFishSpawn = 0,  -- 上次生成魚的時間
                fishIdCounter = 0   -- 魚類ID計數器
            },
            stats = {
                totalFishSpawned = 0,
                totalFishCaught = 0,
                lastActivity = os.time()
            }
        }
        print('^2[魚機遊戲] ^7房間 ' .. roomId .. ' 遊戲數據初始化完成')
    end
    return FishGame.Rooms[roomId]
end

-- 添加玩家到房間
function FishGame.AddPlayerToRoom(roomId, sessionId, session)
    local roomData = FishGame.InitializeRoomGameData(roomId)
    roomData.activePlayers[sessionId] = {
        sessionId = sessionId,
        playerId = session.playerId,
        playerName = session.playerName,
        joinTime = os.time(),
        lastActivity = os.time()
    }
    roomData.stats.lastActivity = os.time()
    
    -- 通知房間內其他玩家
    FishGame.BroadcastToRoom(roomId, 'fishgame:playerJoinedRoom', {
        sessionId = sessionId,
        playerName = session.playerName,
        totalPlayers = FishGame.GetRoomPlayerCount(roomId)
    }, session.playerId)
    
    print('^2[魚機遊戲] ^7玩家 ' .. session.playerName .. ' 加入房間 ' .. roomId)
end

-- 從房間移除玩家
function FishGame.RemovePlayerFromRoom(roomId, sessionId)
    local roomData = FishGame.Rooms[roomId]
    if roomData and roomData.activePlayers[sessionId] then
        local playerInfo = roomData.activePlayers[sessionId]
        roomData.activePlayers[sessionId] = nil
        
        -- 通知房間內其他玩家
        FishGame.BroadcastToRoom(roomId, 'fishgame:playerLeftRoom', {
            sessionId = sessionId,
            playerName = playerInfo.playerName,
            totalPlayers = FishGame.GetRoomPlayerCount(roomId)
        })
        
        print('^2[魚機遊戲] ^7玩家 ' .. playerInfo.playerName .. ' 離開房間 ' .. roomId)
        
        -- 如果房間沒有玩家了，清理房間數據
        if FishGame.GetRoomPlayerCount(roomId) == 0 then
            FishGame.CleanupRoomData(roomId)
        end
    end
end

-- 獲取房間玩家數量
function FishGame.GetRoomPlayerCount(roomId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData then return 0 end
    
    local count = 0
    for _ in pairs(roomData.activePlayers) do
        count = count + 1
    end
    return count
end

-- 清理房間數據
function FishGame.CleanupRoomData(roomId)
    if FishGame.Rooms[roomId] then
        print('^2[魚機遊戲] ^7清理空房間數據：' .. roomId)
        FishGame.Rooms[roomId] = nil
    end
end

-- 創建遊戲會話
function FishGame.CreateSession(playerId, roomId, betAmount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return nil end
    
    local sessionId = 'session_' .. playerId .. '_' .. os.time() .. '_' .. math.random(1000, 9999)
    local identifier = xPlayer.identifier
    local playerName = xPlayer.getName()
    
    -- 保存到數據庫
    MySQL.insert('INSERT INTO fishgame_sessions (session_id, room_id, identifier, player_name, bet_amount, start_coins, current_coins, status, start_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
        sessionId,
        roomId,
        identifier,
        playerName,
        betAmount,
        betAmount,
        betAmount,
        'active'
    }, function(insertId)
        if insertId then
            print('^2[魚機遊戲] ^7會話創建成功：' .. sessionId)
        end
    end)
    
    -- 保存到內存
    local session = {
        id = sessionId,
        playerId = playerId,
        identifier = identifier,
        playerName = playerName,
        roomId = roomId,
        betAmount = betAmount,
        currentCoins = betAmount,
        score = 0,
        fishCaught = 0,
        bulletsFired = 0,
        status = 'active',
        startTime = os.time(),
        lastUpdate = os.time(),
        weapons = {current = 'cannon_1'},
        skills = {active = {}},
        damageDealt = {}  -- 追蹤對每條魚造成的傷害
    }
    
    FishGame.Sessions[sessionId] = session
    
    -- 將玩家添加到房間
    FishGame.AddPlayerToRoom(roomId, sessionId, session)
    
    return sessionId
end

-- 結束遊戲會話
function FishGame.EndSession(sessionId, reason)
    local session = FishGame.Sessions[sessionId]
    if not session then return false end
    
    local playerId = session.playerId
    local endTime = os.time()
    local playTime = endTime - session.startTime
    local winAmount = math.max(0, session.currentCoins - session.betAmount)
    
    -- 更新數據庫
    MySQL.update('UPDATE fishgame_sessions SET current_coins = ?, score = ?, fish_caught = ?, bullets_fired = ?, status = ?, end_time = NOW() WHERE session_id = ?', {
        session.currentCoins,
        session.score,
        session.fishCaught,
        session.bulletsFired,
        reason,
        sessionId
    })
    
    -- 如果有獲利，給予獎勵
    if winAmount > 0 then
        FishGame.AddPlayerMoney(playerId, winAmount, '魚機遊戲獎勵')
    end
    
    -- 更新玩家統計
    if FishGame.Players[playerId] then
        local playerData = FishGame.Players[playerId].data
        playerData.total_games_played = (playerData.total_games_played or 0) + 1
        playerData.total_fish_caught = (playerData.total_fish_caught or 0) + session.fishCaught
        playerData.total_coins_earned = (playerData.total_coins_earned or 0) + winAmount
        
        if session.score > (playerData.best_score or 0) then
            playerData.best_score = session.score
        end
        
        -- 經驗值計算
        local expGained = math.floor(session.score / 10) + session.fishCaught
        playerData.experience = (playerData.experience or 0) + expGained
        
        -- 等級計算
        local oldLevel = playerData.level or 1
        local newLevel = math.floor(playerData.experience / 1000) + 1
        if newLevel > oldLevel then
            playerData.level = newLevel
            
            -- 檢查並解鎖新武器
            local unlockedWeapons = json.decode(playerData.unlocked_weapons or '["cannon_1"]')
            local newWeaponsUnlocked = false
            
            for weaponId, weaponData in pairs(Config.Weapons) do
                if weaponData.unlockLevel and weaponData.unlockLevel <= newLevel then
                    -- 檢查是否已經解鎖
                    local alreadyUnlocked = false
                    for _, unlockedWeapon in ipairs(unlockedWeapons) do
                        if unlockedWeapon == weaponId then
                            alreadyUnlocked = true
                            break
                        end
                    end
                    
                    if not alreadyUnlocked then
                        table.insert(unlockedWeapons, weaponId)
                        newWeaponsUnlocked = true
                        print('^2[魚機遊戲] ^7玩家 ' .. session.playerName .. ' 解鎖新武器: ' .. weaponData.name)
                    end
                end
            end
            
            -- 檢查並解鎖新技能
            local unlockedSkills = json.decode(playerData.unlocked_skills or '[]')
            local newSkillsUnlocked = false
            
            for skillId, skillData in pairs(Config.SpecialSkills) do
                if skillData.unlockLevel and skillData.unlockLevel <= newLevel then
                    -- 檢查是否已經解鎖
                    local alreadyUnlocked = false
                    for _, unlockedSkill in ipairs(unlockedSkills) do
                        if unlockedSkill == skillId then
                            alreadyUnlocked = true
                            break
                        end
                    end
                    
                    if not alreadyUnlocked then
                        table.insert(unlockedSkills, skillId)
                        newSkillsUnlocked = true
                        print('^2[魚機遊戲] ^7玩家 ' .. session.playerName .. ' 解鎖新技能: ' .. skillData.name)
                    end
                end
            end
            
            -- 更新解鎖的武器和技能
            playerData.unlocked_weapons = json.encode(unlockedWeapons)
            playerData.unlocked_skills = json.encode(unlockedSkills)
            
            TriggerClientEvent('fishgame:levelUp', playerId, newLevel)
            
            -- 如果有新武器或技能解鎖，發送通知
            if newWeaponsUnlocked or newSkillsUnlocked then
                TriggerClientEvent('fishgame:showNotification', playerId, '恭喜！等級提升至 ' .. newLevel .. ' 級，解鎖了新內容！', 'success')
            end
        end
        
        FishGame.UpdatePlayerData(session.identifier, playerData)
        TriggerClientEvent('fishgame:setPlayerData', playerId, playerData)
    end
    
    -- 更新每日統計
    FishGame.UpdateDailyStats(session.identifier, session.score, session.betAmount, winAmount, session.fishCaught, playTime)
    
    -- 通知客戶端
    TriggerClientEvent('fishgame:sessionEnded', playerId, {
        sessionId = sessionId,
        reason = reason,
        finalScore = session.score,
        fishCaught = session.fishCaught,
        bulletsFired = session.bulletsFired,
        betAmount = session.betAmount,
        winAmount = winAmount,
        playTime = playTime
    })
    
    -- 從房間移除玩家
    FishGame.RemovePlayerFromRoom(session.roomId, sessionId)
    
    -- 清理內存
    session.status = reason
    
    return true
end

-- 更新每日統計
function FishGame.UpdateDailyStats(identifier, score, betAmount, winAmount, fishCaught, playTimeMinutes)
    local today = os.date('%Y-%m-%d')
    
    MySQL.query('SELECT * FROM fishgame_daily_stats WHERE identifier = ? AND date = ?', {identifier, today}, function(result)
        if result and result[1] then
            -- 更新現有記錄
            local stats = result[1]
            MySQL.update('UPDATE fishgame_daily_stats SET games_played = ?, total_bet = ?, total_won = ?, fish_caught = ?, best_score = ?, play_time_minutes = ? WHERE id = ?', {
                stats.games_played + 1,
                stats.total_bet + betAmount,
                stats.total_won + winAmount,
                stats.fish_caught + fishCaught,
                math.max(stats.best_score, score),
                stats.play_time_minutes + math.floor(playTimeMinutes / 60),
                stats.id
            })
        else
            -- 創建新記錄
            MySQL.insert('INSERT INTO fishgame_daily_stats (identifier, date, games_played, total_bet, total_won, fish_caught, best_score, play_time_minutes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
                identifier,
                today,
                1,
                betAmount,
                winAmount,
                fishCaught,
                score,
                math.floor(playTimeMinutes / 60)
            })
        end
    end)
end

-- 獲取房間內玩家列表
function FishGame.GetRoomPlayers(roomId)
    local players = {}
    for sessionId, session in pairs(FishGame.Sessions) do
        if session.roomId == roomId and session.status == 'active' then
            players[sessionId] = {
                sessionId = sessionId,
                playerId = session.playerId,
                playerName = session.playerName,
                score = session.score,
                fishCaught = session.fishCaught,
                currentWeapon = session.weapons.current
            }
        end
    end
    return players
end

-- 廣播房間消息
function FishGame.BroadcastToRoom(roomId, eventName, data, excludePlayerId)
    for sessionId, session in pairs(FishGame.Sessions) do
        if session.roomId == roomId and session.status == 'active' and session.playerId ~= excludePlayerId then
            TriggerClientEvent(eventName, session.playerId, data)
        end
    end
end

-- 同步房間狀態（僅同步非位置數據）
function FishGame.SyncRoomState(roomId)
    local players = FishGame.GetRoomPlayers(roomId)
    local roomData = FishGame.Rooms[roomId]
    
    if not roomData then return end
    
    -- 只同步玩家列表和房間統計，不同步魚類位置
    for sessionId, session in pairs(FishGame.Sessions) do
        if session.roomId == roomId and session.status == 'active' then
            TriggerClientEvent('fishgame:roomStateUpdate', session.playerId, {
                players = players,
                roomStats = roomData.stats
                -- 移除 fish, bullets, effects 的同步，讓客戶端自行管理
            })
        end
    end
end

-- 服務端事件處理
RegisterServerEvent('fishgame:updateSession')
AddEventHandler('fishgame:updateSession', function(sessionId, updateData)
    local playerId = source
    local session = FishGame.Sessions[sessionId]
    
    if not session or session.playerId ~= playerId or session.status ~= 'active' then
        return
    end
    
    -- 更新會話數據
    if updateData.score then
        session.score = updateData.score
    end
    
    if updateData.currentCoins then
        session.currentCoins = updateData.currentCoins
    end
    
    if updateData.fishCaught then
        session.fishCaught = updateData.fishCaught
    end
    
    if updateData.bulletsFired then
        session.bulletsFired = updateData.bulletsFired
    end
    
    if updateData.gameData then
        for key, value in pairs(updateData.gameData) do
            session.gameData[key] = value
        end
    end
    
    session.lastUpdate = os.time()
    
    -- 同步給房間內其他玩家
    if updateData.sync then
        FishGame.BroadcastToRoom(session.roomId, 'fishgame:playerUpdate', {
            sessionId = sessionId,
            playerName = session.playerName,
            score = session.score,
            fishCaught = session.fishCaught,
            updateData = updateData.sync
        }, playerId)
    end
end)

RegisterServerEvent('fishgame:getRoomPlayers')
AddEventHandler('fishgame:getRoomPlayers', function(roomId)
    local playerId = source
    local players = FishGame.GetRoomPlayers(roomId)
    TriggerClientEvent('fishgame:receiveRoomPlayers', playerId, players)
end)

RegisterServerEvent('fishgame:syncRoomState')
AddEventHandler('fishgame:syncRoomState', function(roomId)
    FishGame.SyncRoomState(roomId)
end)

-- 定時保存會話數據
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) -- 每30秒保存一次
        
        for sessionId, session in pairs(FishGame.Sessions) do
            if session.status == 'active' then
                MySQL.update('UPDATE fishgame_sessions SET current_coins = ?, score = ?, fish_caught = ?, bullets_fired = ? WHERE session_id = ?', {
                    session.currentCoins,
                    session.score,
                    session.fishCaught,
                    session.bulletsFired,
                    sessionId
                })
            end
        end
    end
end)

print('^2[魚機遊戲] ^7房間管理系統載入完成') 