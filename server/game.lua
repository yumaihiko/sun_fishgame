-- 遊戲核心邏輯系統

-- 確保FishGame表存在
if not FishGame then
    FishGame = {}
    FishGame.Players = {}
    FishGame.Rooms = {}
    FishGame.Sessions = {}
end

-- 魚類生成（直接添加到房間）
function FishGame.SpawnFish(roomId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData then return end
    
    local currentTime = os.time()
    
    -- 控制生成頻率（每3秒最多生成一次）
    if currentTime - roomData.gameData.lastFishSpawn < 3 then
        return
    end
    
    local fishSpawned = 0
    local maxFishInRoom = 20  -- 降低房間最大魚數量，避免過多魚類
    local currentFishCount = 0
    
    -- 計算當前魚數量
    for _ in pairs(roomData.gameData.fish) do
        currentFishCount = currentFishCount + 1
    end
    
    -- 如果魚太多就不生成
    if currentFishCount >= maxFishInRoom then
        return
    end
    
    -- 初始化房間任務系統
    if not roomData.gameData.missionSystem then
        roomData.gameData.missionSystem = {
            totalKills = 0,
            playerKills = {},
            lastMissionTime = 0,
            activeMission = nil
        }
    end
    
    -- 檢查是否觸發任務
    FishGame.CheckMissionTrigger(roomId)
    
    -- 新的魚類生成邏輯 - 基於稀有度控制
    local fishToSpawn = {}
    local usedPositions = {}
    
    -- 獲取所有可用的魚類類型並按稀有度分類
    local commonFish = {}
    local rareFish = {}
    
    for fishType, fishData in pairs(Config.FishTypes) do
        if fishData.points >= 100 then
            -- 100分以上的魚為稀有魚
            table.insert(rareFish, {type = fishType, data = fishData})
        else
            -- 100分以下的魚為普通魚
            table.insert(commonFish, {type = fishType, data = fishData})
        end
    end
    
    -- 決定生成魚的數量（1-3條）
    local spawnCount = math.random(1, 3)
    
    for i = 1, spawnCount do
        if currentFishCount + fishSpawned >= maxFishInRoom then
            break
        end
        
        local selectedFish = nil
        
        -- 稀有魚生成機率控制
        local rareChance = math.random() * 100
        if #rareFish > 0 and rareChance <= 5 then -- 5%機率生成稀有魚
            selectedFish = rareFish[math.random(#rareFish)]
        else
            -- 生成普通魚
            if #commonFish > 0 then
                selectedFish = commonFish[math.random(#commonFish)]
            end
        end
        
        if selectedFish then
            -- 生成魚類位置，避免重複
            local position = FishGame.GenerateUniquePosition(usedPositions)
            if position then
                table.insert(usedPositions, position)
                
                -- 創建魚類
                roomData.gameData.fishIdCounter = roomData.gameData.fishIdCounter + 1
                local fishId = 'fish_' .. roomId .. '_' .. roomData.gameData.fishIdCounter
                
                -- 調整血量 - 高級魚血量更多
                local adjustedHealth = selectedFish.data.health
                if selectedFish.data.points >= 100 then
                    adjustedHealth = adjustedHealth * 3 -- 高級魚血量增加3倍
                elseif selectedFish.data.points >= 50 then
                    adjustedHealth = adjustedHealth * 2 -- 中級魚血量增加2倍
                end
                
                -- BOSS魚特殊處理
                if selectedFish.data.isBoss then
                    -- BOSS魚使用原始血量（已經設定為很高）
                    adjustedHealth = selectedFish.data.health
                    
                    -- 廣播BOSS出現通知
                    FishGame.BroadcastToRoom(roomId, 'fishgame:bossSpawned', {
                        bossName = selectedFish.data.name,
                        bossType = selectedFish.data.bossType,
                        bossHealth = adjustedHealth,
                        bossPoints = selectedFish.data.points,
                        message = '🐲 王級魚 ' .. selectedFish.data.name .. ' 出現了！準備迎戰！'
                    })
                    
                    -- 播放BOSS音樂
                    if selectedFish.data.bossMusic then
                        FishGame.BroadcastToRoom(roomId, 'fishgame:playBossMusic', {
                            musicFile = selectedFish.data.bossMusic
                        })
                    end
                end
                
                local fish = {
                    id = fishId,
                    type = selectedFish.type,
                    name = selectedFish.data.name,
                    points = selectedFish.data.points,
                    health = adjustedHealth,
                    maxHealth = adjustedHealth,
                    speed = selectedFish.data.speed,
                    size = selectedFish.data.size,
                    color = selectedFish.data.color,
                    rarity = selectedFish.data.rarity,
                    specialEffect = selectedFish.data.specialEffect,
                    image = selectedFish.data.image,
                    canLeaveScreen = selectedFish.data.canLeaveScreen,
                    showHealthBar = selectedFish.data.showHealthBar ~= false, -- BOSS魚默認顯示血量
                    isBoss = selectedFish.data.isBoss,
                    bossType = selectedFish.data.bossType,
                    position = position,
                    velocity = {
                        x = (math.random() - 0.5) * selectedFish.data.speed,
                        y = (math.random() - 0.5) * selectedFish.data.speed,
                        z = 0
                    },
                    rotation = math.random() * 360,
                    spawnTime = currentTime,
                    alive = true,
                    damageByPlayer = {},
                    schoolId = nil
                }
                
                -- 如果是大型魚，初始化倍數系統
                if selectedFish.data.multiplierSystem then
                    fish.multiplierData = {
                        currentMultiplier = selectedFish.data.multiplierSystem.baseMultiplier,
                        hitCount = 0,
                        lastHitTime = 0
                    }
                end
                
                roomData.gameData.fish[fishId] = fish
                fishSpawned = fishSpawned + 1
                roomData.stats.totalFishSpawned = roomData.stats.totalFishSpawned + 1
            end
        end
    end
    
    roomData.gameData.lastFishSpawn = currentTime
    
    -- 如果生成了新魚，通知房間內所有玩家
    if fishSpawned > 0 then
        FishGame.BroadcastToRoom(roomId, 'fishgame:fishSpawned', {
            newFishCount = fishSpawned,
            totalFishCount = currentFishCount + fishSpawned
        })
    end
end

-- 生成唯一位置，避免重複
function FishGame.GenerateUniquePosition(usedPositions)
    local maxAttempts = 20
    local minDistance = 150 -- 最小距離
    
    for attempt = 1, maxAttempts do
        local position = {
            x = math.random(-1800, 1800),
            y = math.random(-900, 900),
            z = 0
        }
        
        local isUnique = true
        for _, usedPos in ipairs(usedPositions) do
            local distance = math.sqrt(
                (position.x - usedPos.x)^2 + (position.y - usedPos.y)^2
            )
            if distance < minDistance then
                isUnique = false
                break
            end
        end
        
        if isUnique then
            return position
        end
    end
    
    -- 如果找不到唯一位置，返回隨機位置
    return {
        x = math.random(-1800, 1800),
        y = math.random(-900, 900),
        z = 0
    }
end

-- 檢查任務觸發
function FishGame.CheckMissionTrigger(roomId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData or not roomData.gameData.missionSystem then return end
    
    local missionSystem = roomData.gameData.missionSystem
    local currentTime = os.time()
    
    -- 檢查是否有活躍任務
    if missionSystem.activeMission then
        return
    end
    
    -- 檢查是否有玩家達到5次擊殺
    local readyPlayers = {}
    for sessionId, kills in pairs(missionSystem.playerKills) do
        if kills >= 5 then
            local session = FishGame.Sessions[sessionId]
            if session and session.status == 'active' then
                table.insert(readyPlayers, session)
            end
        end
    end
    
    -- 如果有玩家準備好，且距離上次任務超過30秒
    if #readyPlayers > 0 and (currentTime - missionSystem.lastMissionTime) > 30 then
        -- 20%機率觸發任務
        if math.random() * 100 <= 20 then
            FishGame.TriggerBigFishMission(roomId, readyPlayers)
        end
    end
end

-- 觸發大魚任務
function FishGame.TriggerBigFishMission(roomId, readyPlayers)
    local roomData = FishGame.Rooms[roomId]
    if not roomData then return end
    
    local missionSystem = roomData.gameData.missionSystem
    
    -- 創建任務
    missionSystem.activeMission = {
        type = 'big_fish_summon',
        startTime = os.time(),
        duration = 60, -- 60秒任務時間
        participants = {},
        bigFishSpawned = false
    }
    
    -- 添加參與者
    for _, session in ipairs(readyPlayers) do
        missionSystem.activeMission.participants[session.id] = {
            sessionId = session.id,
            playerName = session.playerName,
            contributed = false
        }
        -- 重置玩家擊殺數
        missionSystem.playerKills[session.id] = 0
    end
    
    -- 廣播任務開始
    FishGame.BroadcastToRoom(roomId, 'fishgame:missionStarted', {
        missionType = 'big_fish_summon',
        duration = 60,
        participants = missionSystem.activeMission.participants,
        description = '大魚召喚任務開始！所有參與者需要在60秒內合力召喚大魚！'
    })
    
    -- 10秒後生成大魚
    Citizen.SetTimeout(10000, function()
        if missionSystem.activeMission then
            FishGame.SpawnBigFish(roomId)
        end
    end)
    
    -- 60秒後結束任務
    Citizen.SetTimeout(60000, function()
        FishGame.EndMission(roomId)
    end)
    
    missionSystem.lastMissionTime = os.time()
end

-- 生成大魚
function FishGame.SpawnBigFish(roomId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData or not roomData.gameData.missionSystem.activeMission then return end
    
    -- 選擇一個高級魚類
    local bigFishTypes = {}
    for fishType, fishData in pairs(Config.FishTypes) do
        if fishData.points >= 500 then -- 500分以上的魚作為大魚
            table.insert(bigFishTypes, {type = fishType, data = fishData})
        end
    end
    
    if #bigFishTypes == 0 then return end
    
    local selectedBigFish = bigFishTypes[math.random(#bigFishTypes)]
    
    -- 生成大魚
    roomData.gameData.fishIdCounter = roomData.gameData.fishIdCounter + 1
    local fishId = 'big_fish_' .. roomId .. '_' .. roomData.gameData.fishIdCounter
    
    local fish = {
        id = fishId,
        type = selectedBigFish.type,
        name = selectedBigFish.data.name .. ' (任務大魚)',
        points = selectedBigFish.data.points * 2, -- 雙倍分數
        health = selectedBigFish.data.health * 5, -- 5倍血量
        maxHealth = selectedBigFish.data.health * 5,
        speed = selectedBigFish.data.speed * 0.5, -- 較慢速度
        size = selectedBigFish.data.size * 1.5, -- 較大尺寸
        color = selectedBigFish.data.color,
        rarity = 'mission',
        specialEffect = selectedBigFish.data.specialEffect,
        image = selectedBigFish.data.image,
        canLeaveScreen = false,
        showHealthBar = true, -- 任務大魚顯示血量
        isMissionFish = true,
        position = {
            x = 0, -- 螢幕中央
            y = 0,
            z = 0
        },
        velocity = {
            x = (math.random() - 0.5) * selectedBigFish.data.speed * 0.5,
            y = (math.random() - 0.5) * selectedBigFish.data.speed * 0.5,
            z = 0
        },
        rotation = math.random() * 360,
        spawnTime = os.time(),
        alive = true,
        damageByPlayer = {},
        schoolId = nil
    }
    
    -- 初始化倍數系統
    if selectedBigFish.data.multiplierSystem then
        fish.multiplierData = {
            currentMultiplier = selectedBigFish.data.multiplierSystem.baseMultiplier * 2,
            hitCount = 0,
            lastHitTime = 0
        }
    end
    
    roomData.gameData.fish[fishId] = fish
    roomData.gameData.missionSystem.activeMission.bigFishSpawned = true
    
    -- 廣播大魚出現
    FishGame.BroadcastToRoom(roomId, 'fishgame:bigFishSpawned', {
        fishId = fishId,
        fishName = fish.name,
        fishPoints = fish.points,
        message = '任務大魚出現了！快來攻擊獲得豐厚獎勵！'
    })
end

-- 結束任務
function FishGame.EndMission(roomId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData or not roomData.gameData.missionSystem.activeMission then return end
    
    local mission = roomData.gameData.missionSystem.activeMission
    
    -- 廣播任務結束
    FishGame.BroadcastToRoom(roomId, 'fishgame:missionEnded', {
        missionType = mission.type,
        success = mission.bigFishSpawned,
        message = mission.bigFishSpawned and '任務完成！' or '任務失敗！'
    })
    
    -- 清除任務
    roomData.gameData.missionSystem.activeMission = nil
end

-- 記錄玩家擊殺（在魚死亡時調用）
function FishGame.RecordPlayerKill(roomId, sessionId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData or not roomData.gameData.missionSystem then return end
    
    local missionSystem = roomData.gameData.missionSystem
    
    -- 記錄玩家擊殺
    if not missionSystem.playerKills[sessionId] then
        missionSystem.playerKills[sessionId] = 0
    end
    missionSystem.playerKills[sessionId] = missionSystem.playerKills[sessionId] + 1
    
    -- 增加總擊殺數
    missionSystem.totalKills = missionSystem.totalKills + 1
end

-- 更新魚類狀態（不更新位置，位置由客戶端控制）
function FishGame.UpdateFish(roomId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData then return end
    
    local currentTime = os.time()
    local fishToRemove = {}
    
    for fishId, fish in pairs(roomData.gameData.fish) do
        if fish.alive then
            -- 只清理過期魚類，不更新位置
            if currentTime - fish.spawnTime > 1800 then -- 30分鐘後消失
                table.insert(fishToRemove, fishId)
            end
        else
            -- 移除已死亡的魚
            table.insert(fishToRemove, fishId)
        end
    end
    
    -- 清理要移除的魚
    for _, fishId in ipairs(fishToRemove) do
        roomData.gameData.fish[fishId] = nil
    end
    
    -- 隨機生成新魚
    if math.random() < 0.1 then -- 10%機率生成新魚
        FishGame.SpawnFish(roomId)
    end
end

-- 處理射擊
RegisterServerEvent('fishgame:shoot')
AddEventHandler('fishgame:shoot', function(sessionId, weaponType, startPos, targetPos)
    local playerId = source
    local session = FishGame.Sessions[sessionId]
    
    if not session or session.playerId ~= playerId or session.status ~= 'active' then
        return
    end
    
    local roomData = FishGame.Rooms[session.roomId]
    if not roomData then return end
    
    local weapon = Config.Weapons[weaponType]
    if not weapon then return end
    
    -- 檢查玩家是否有足夠金錢發射
    if session.currentCoins < weapon.cost then
        TriggerClientEvent('fishgame:showNotification', playerId, '金幣不足', 'error')
        return
    end
    
    -- 扣除子彈成本
    session.currentCoins = session.currentCoins - weapon.cost
    session.bulletsFired = session.bulletsFired + 1
    
    -- 創建子彈（添加到房間數據）
    local bulletId = 'bullet_' .. sessionId .. '_' .. os.time() .. '_' .. math.random(1000, 9999)
    local bullet = {
        id = bulletId,
        weaponType = weaponType,
        playerId = playerId,
        sessionId = sessionId,
        playerName = session.playerName,
        damage = weapon.damage,
        speed = weapon.speed,
        size = weapon.size,
        color = weapon.color,
        position = {
            x = startPos.x,
            y = startPos.y,
            z = startPos.z
        },
        velocity = {
            x = (targetPos.x - startPos.x) / 100 * weapon.speed,
            y = (targetPos.y - startPos.y) / 100 * weapon.speed,
            z = 0
        },
        spawnTime = os.time(),
        active = true,
        range = weapon.range
    }
    
    roomData.gameData.bullets[bulletId] = bullet
    
    -- 計算玩家位置
    local playerPosition = FishGame.GetPlayerPositionInRoom(session.roomId)
    
    -- 廣播射擊事件給房間內所有玩家
    FishGame.BroadcastToRoom(session.roomId, 'fishgame:playerShoot', {
        sessionId = sessionId,
        playerName = session.playerName,
        playerPosition = playerPosition,
        bulletId = bulletId,
        bullet = bullet,
        weapon = weapon,
        startPos = startPos,
        targetPos = targetPos
    })
    
    -- 檢查即時碰撞（雷射武器等）
    if weapon.specialEffect == 'laser' then
        FishGame.CheckLaserHit(session.roomId, sessionId, bullet, startPos, targetPos)
    end
end)

-- 檢查雷射命中
function FishGame.CheckLaserHit(roomId, sessionId, bullet, startPos, targetPos)
    local roomData = FishGame.Rooms[roomId]
    if not roomData then return end
    
    local hitFish = {}
    
    for fishId, fish in pairs(roomData.gameData.fish) do
        if fish.alive then
            -- 計算點到線段的距離
            local distance = FishGame.PointToLineDistance(fish.position, startPos, targetPos)
            if distance <= (fish.size * 50) then -- 碰撞檢測
                table.insert(hitFish, {fishId = fishId, fish = fish})
            end
        end
    end
    
    -- 處理命中
    for _, hit in ipairs(hitFish) do
        FishGame.ProcessFishHit(roomId, sessionId, hit.fishId, hit.fish, bullet)
    end
end

-- 更新子彈位置
function FishGame.UpdateBullets(roomId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData then return end
    
    local currentTime = os.time()
    local bulletsToRemove = {}
    
    for bulletId, bullet in pairs(roomData.gameData.bullets) do
        if bullet.active then
            -- 更新位置
            bullet.position.x = bullet.position.x + bullet.velocity.x
            bullet.position.y = bullet.position.y + bullet.velocity.y
            
            local travelDistance = math.sqrt(
                (bullet.position.x - bullet.velocity.x) ^ 2 + 
                (bullet.position.y - bullet.velocity.y) ^ 2
            )
            
            -- 檢查範圍和邊界
            if travelDistance > bullet.range or 
               bullet.position.x > 1920 or bullet.position.x < -1920 or
               bullet.position.y > 1080 or bullet.position.y < -1080 or
               currentTime - bullet.spawnTime > 10 then
                bullet.active = false
                table.insert(bulletsToRemove, bulletId)
            else
                -- 碰撞檢測
                FishGame.CheckBulletCollision(roomId, bulletId, bullet)
            end
        else
            table.insert(bulletsToRemove, bulletId)
        end
    end
    
    -- 清理要移除的子彈
    for _, bulletId in ipairs(bulletsToRemove) do
        roomData.gameData.bullets[bulletId] = nil
    end
end

-- 碰撞檢測
function FishGame.CheckBulletCollision(roomId, bulletId, bullet)
    local roomData = FishGame.Rooms[roomId]
    if not roomData then return end
    
    for fishId, fish in pairs(roomData.gameData.fish) do
        if fish.alive then
            local distance = math.sqrt(
                (bullet.position.x - fish.position.x) ^ 2 + 
                (bullet.position.y - fish.position.y) ^ 2
            )
            
            local hitRadius = (fish.size * 30) + (bullet.size * 10)
            
            if distance <= hitRadius then
                -- 命中！
                FishGame.ProcessFishHit(roomId, bullet.sessionId, fishId, fish, bullet)
                bullet.active = false
                roomData.gameData.bullets[bulletId] = nil
                break
            end
        end
    end
end

-- 處理魚類被命中（支援多人攻擊同一條魚）
function FishGame.ProcessFishHit(roomId, sessionId, fishId, fish, bullet)
    local session = FishGame.Sessions[sessionId]
    local roomData = FishGame.Rooms[roomId]
    if not session or not roomData then return end
    
    local weapon = Config.Weapons[bullet.weaponType]
    if not weapon then return end
    
    local damage = bullet.damage
    
    -- 記錄玩家對此魚造成的傷害
    if not fish.damageByPlayer[sessionId] then
        fish.damageByPlayer[sessionId] = 0
    end
    fish.damageByPlayer[sessionId] = fish.damageByPlayer[sessionId] + damage
    
    -- 記錄玩家累計傷害（用於統計）
    if not session.damageDealt[fishId] then
        session.damageDealt[fishId] = 0
    end
    session.damageDealt[fishId] = session.damageDealt[fishId] + damage
    
    -- 如果是大型魚，更新倍數系統
    local fishConfig = Config.FishTypes[fish.type]
    if fishConfig.multiplierSystem and fish.multiplierData then
        local currentTime = os.time()
        fish.multiplierData.hitCount = fish.multiplierData.hitCount + 1
        fish.multiplierData.lastHitTime = currentTime
        
        -- 增加倍數
        local newMultiplier = fish.multiplierData.currentMultiplier + fishConfig.multiplierSystem.hitIncrement
        fish.multiplierData.currentMultiplier = math.min(newMultiplier, fishConfig.multiplierSystem.maxMultiplier)
        
        -- 檢查隨機死亡
        if math.random() < fishConfig.multiplierSystem.randomDeathChance then
            -- 隨機死亡！使用當前倍數
            fish.health = 0
            
            -- 廣播大型魚隨機死亡事件
            FishGame.BroadcastToRoom(roomId, 'fishgame:bossFishRandomDeath', {
                fishId = fishId,
                fishName = fish.name,
                currentMultiplier = fish.multiplierData.currentMultiplier,
                hitCount = fish.multiplierData.hitCount
            })
        else
            -- 廣播倍數更新
            FishGame.BroadcastToRoom(roomId, 'fishgame:bossFishMultiplierUpdate', {
                fishId = fishId,
                fishName = fish.name,
                currentMultiplier = fish.multiplierData.currentMultiplier,
                hitCount = fish.multiplierData.hitCount,
                maxMultiplier = fishConfig.multiplierSystem.maxMultiplier
            })
        end
    end
    
    -- 扣除魚的血量
    fish.health = fish.health - damage
    
    -- 廣播魚被攻擊事件
    FishGame.BroadcastToRoom(roomId, 'fishgame:fishDamaged', {
        fishId = fishId,
        attackerSessionId = sessionId,
        attackerName = session.playerName,
        damage = damage,
        remainingHealth = fish.health,
        maxHealth = fish.maxHealth,
        showHealthBar = fish.showHealthBar, -- 添加血量顯示控制
        weaponType = bullet.weaponType,
        weaponMultiplier = weapon.multiplier
    })
    
    if fish.health <= 0 then
        -- 魚死亡，記錄擊殺
        FishGame.RecordPlayerKill(roomId, sessionId)
        
        -- 魚死亡，計算獎勵分配
        fish.alive = false
        
        local basePoints = fishConfig.points
        local baseCoinReward = basePoints * 2 -- 1分 = 2金幣
        
        -- 應用武器倍數
        local weaponMultiplier = weapon.multiplier or 1
        baseCoinReward = baseCoinReward * weaponMultiplier
        basePoints = basePoints * weaponMultiplier
        
        -- 如果是賞金魚，應用賞金倍數
        if fishConfig.bonusMultiplier then
            baseCoinReward = baseCoinReward * fishConfig.bonusMultiplier
            basePoints = basePoints * fishConfig.bonusMultiplier
        end
        
        -- 如果是大型魚，應用累積倍數
        if fish.multiplierData then
            baseCoinReward = baseCoinReward * fish.multiplierData.currentMultiplier
            basePoints = basePoints * fish.multiplierData.currentMultiplier
        end
        
        -- 找出誰給了最後一擊（獲得基礎獎勵）
        local finalBlowSession = session
        local finalBlowPoints = basePoints
        local finalBlowCoins = baseCoinReward
        
        -- 特殊效果處理（最後一擊者獲得）
        if fishConfig.specialEffect then
            finalBlowCoins, finalBlowPoints = FishGame.ProcessSpecialEffect(roomId, sessionId, fishConfig.specialEffect, fish, finalBlowCoins, finalBlowPoints)
        end
        
        -- 計算總傷害
        local totalDamage = 0
        for _, playerDamage in pairs(fish.damageByPlayer) do
            totalDamage = totalDamage + playerDamage
        end
        
        -- 分配傷害貢獻獎勵（額外30%的獎勵按傷害比例分配）
        local bonusPool = math.floor(baseCoinReward * 0.3)
        local allRewards = {}
        
        for contributorSessionId, contributorDamage in pairs(fish.damageByPlayer) do
            local contributorSession = FishGame.Sessions[contributorSessionId]
            if contributorSession and contributorSession.status == 'active' then
                local damageRatio = contributorDamage / totalDamage
                local contributorBonus = math.floor(bonusPool * damageRatio)
                local contributorPoints = math.floor(basePoints * damageRatio * 0.3)
                
                -- 最後一擊者獲得主要獎勵
                if contributorSessionId == sessionId then
                    allRewards[contributorSessionId] = {
                        session = contributorSession,
                        points = finalBlowPoints + contributorPoints,
                        coins = finalBlowCoins + contributorBonus,
                        isFinalBlow = true,
                        damageRatio = damageRatio,
                        damage = contributorDamage,
                        weaponUsed = bullet.weaponType,
                        weaponMultiplier = weaponMultiplier
                    }
                else
                    -- 其他貢獻者獲得比例獎勵
                    allRewards[contributorSessionId] = {
                        session = contributorSession,
                        points = contributorPoints,
                        coins = contributorBonus,
                        isFinalBlow = false,
                        damageRatio = damageRatio,
                        damage = contributorDamage,
                        weaponUsed = 'assist',
                        weaponMultiplier = 1
                    }
                end
            end
        end
        
        -- 發放獎勵並保存記錄
        for rewardSessionId, rewardData in pairs(allRewards) do
            local rewardSession = rewardData.session
            
            -- 更新玩家數據
            rewardSession.score = rewardSession.score + rewardData.points
            rewardSession.currentCoins = rewardSession.currentCoins + rewardData.coins
            if rewardData.isFinalBlow then
                rewardSession.fishCaught = rewardSession.fishCaught + 1
            end
            
            -- 保存捕獲記錄
            MySQL.insert('INSERT INTO fishgame_catches (session_id, identifier, fish_type, fish_points, weapon_used, bullets_used, coins_earned, damage_dealt, damage_ratio, is_final_blow) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
                rewardSessionId,
                rewardSession.identifier,
                fish.type,
                rewardData.points,
                rewardData.weaponUsed,
                1,
                rewardData.coins,
                rewardData.damage,
                rewardData.damageRatio,
                rewardData.isFinalBlow and 1 or 0
            })
            
            -- 通知獲得獎勵者
            TriggerClientEvent('fishgame:fishReward', rewardSession.playerId, {
                fishName = fish.name,
                points = rewardData.points,
                coinReward = rewardData.coins,
                totalScore = rewardSession.score,
                totalCoins = rewardSession.currentCoins,
                isFinalBlow = rewardData.isFinalBlow,
                damageRatio = rewardData.damageRatio,
                contributors = #allRewards,
                weaponMultiplier = rewardData.weaponMultiplier,
                fishMultiplier = fish.multiplierData and fish.multiplierData.currentMultiplier or 1
            })
        end
        
        -- 廣播魚被捕獲事件
        FishGame.BroadcastToRoom(roomId, 'fishgame:fishCaught', {
            fishId = fishId,
            fishType = fish.type,
            fishName = fish.name,
            fishImage = fish.image,
            finalBlowSessionId = sessionId,
            finalBlowPlayerName = session.playerName,
            totalContributors = #allRewards,
            contributors = allRewards,
            specialEffect = fishConfig.specialEffect,
            totalDamage = totalDamage,
            fishMaxHealth = fish.maxHealth,
            weaponMultiplier = weaponMultiplier,
            fishMultiplier = fish.multiplierData and fish.multiplierData.currentMultiplier or 1,
            bonusMultiplier = fishConfig.bonusMultiplier
        })
        
        -- 移除魚類
        roomData.gameData.fish[fishId] = nil
        roomData.stats.totalFishCaught = roomData.stats.totalFishCaught + 1
        
        -- 清理玩家的傷害記錄
        for contributorSessionId, _ in pairs(fish.damageByPlayer) do
            local contributorSession = FishGame.Sessions[contributorSessionId]
            if contributorSession and contributorSession.damageDealt[fishId] then
                contributorSession.damageDealt[fishId] = nil
            end
        end

        -- 如果是BOSS魚死亡，特殊處理
        if fish.isBoss then
            -- 停止BOSS音樂
            FishGame.BroadcastToRoom(roomId, 'fishgame:stopBossMusic', {})
            
            -- 播放BOSS死亡音效
            FishGame.BroadcastToRoom(roomId, 'fishgame:playSound', {
                soundType = 'boss_death'
            })
            
            -- 廣播BOSS死亡通知
            FishGame.BroadcastToRoom(roomId, 'fishgame:bossDefeated', {
                bossName = fish.name,
                defeatedBy = session.playerName,
                totalDamage = totalDamage,
                finalMultiplier = fish.multiplierData and fish.multiplierData.currentMultiplier or 1,
                message = '🏆 王級魚 ' .. fish.name .. ' 被 ' .. session.playerName .. ' 擊敗了！'
            })
            
            -- BOSS魚額外獎勵
            for rewardSessionId, rewardData in pairs(allRewards) do
                local rewardSession = rewardData.session
                -- BOSS魚額外獎勵50%
                local bossBonus = math.floor(rewardData.coins * 0.5)
                rewardSession.currentCoins = rewardSession.currentCoins + bossBonus
                
                -- 通知BOSS獎勵
                TriggerClientEvent('fishgame:bossReward', rewardSession.playerId, {
                    bossName = fish.name,
                    bonusCoins = bossBonus,
                    message = '🏆 王級魚獎勵：+' .. bossBonus .. ' 金幣！'
                })
            end
        end
    end
end

-- 處理特殊效果
function FishGame.ProcessSpecialEffect(roomId, sessionId, effectType, fish, coinReward, points)
    local session = FishGame.Sessions[sessionId]
    local roomData = FishGame.Rooms[roomId]
    if not session or not roomData then return coinReward, points end
    
    if effectType == 'screen_bomb' then
        -- 全螢幕清除（不含大型魚）
        local bonusCoins = 0
        local bonusPoints = 0
        local clearedFish = {}
        
        for nearbyFishId, nearbyFish in pairs(roomData.gameData.fish) do
            if nearbyFish.alive and nearbyFishId ~= fish.id then
                local nearbyConfig = Config.FishTypes[nearbyFish.type]
                -- 只清除小型和中型魚
                if nearbyConfig.rarity ~= 'rare' and nearbyConfig.rarity ~= 'legendary' and nearbyConfig.rarity ~= 'mythic' then
                    nearbyFish.alive = false
                    bonusPoints = bonusPoints + nearbyConfig.points
                    bonusCoins = bonusCoins + (nearbyConfig.points * 2)
                    table.insert(clearedFish, {
                        id = nearbyFishId,
                        type = nearbyFish.type,
                        name = nearbyConfig.name,
                        points = nearbyConfig.points,
                        position = nearbyFish.position
                    })
                    session.fishCaught = session.fishCaught + 1
                end
            end
        end
        
        -- 移除被清除的魚
        for _, clearedFishData in ipairs(clearedFish) do
            roomData.gameData.fish[clearedFishData.id] = nil
        end
        
        coinReward = coinReward + bonusCoins
        points = points + bonusPoints
        
        -- 全螢幕清除特效
        roomData.gameData.effects['screen_clear_' .. os.time()] = {
            type = 'screen_clear',
            duration = 2000,
            spawnTime = os.time(),
            clearedFish = clearedFish,
            triggerPlayer = session.playerName
        }
        
        -- 廣播全螢幕清除事件
        FishGame.BroadcastToRoom(roomId, 'fishgame:screenClear', {
            clearedFish = clearedFish,
            triggerPlayer = session.playerName,
            bonusPoints = bonusPoints,
            bonusCoins = bonusCoins
        })
        
    elseif effectType == 'laser_cannon' then
        -- 變成雷射炮（持續效果）
        session.tempWeapon = {
            type = 'cannon_laser',
            duration = 10000, -- 10秒
            startTime = os.time()
        }
        
        -- 廣播雷射炮激活事件
        FishGame.BroadcastToRoom(roomId, 'fishgame:laserCannonActivated', {
            sessionId = sessionId,
            playerName = session.playerName,
            duration = 10000
        })
        
    elseif effectType == 'lucky_wheel' then
        -- 轉盤抽獎
        local prizes = {
            {name = '小獎勵', coinMultiplier = 2, chance = 40},
            {name = '中獎勵', coinMultiplier = 5, chance = 30},
            {name = '大獎勵', coinMultiplier = 10, chance = 20},
            {name = '超級獎勵', coinMultiplier = 20, chance = 8},
            {name = '頭獎', coinMultiplier = 50, chance = 2}
        }
        
        local roll = math.random() * 100
        local currentChance = 0
        local selectedPrize = prizes[1]
        
        for _, prize in ipairs(prizes) do
            currentChance = currentChance + prize.chance
            if roll <= currentChance then
                selectedPrize = prize
                break
            end
        end
        
        local bonusCoins = coinReward * (selectedPrize.coinMultiplier - 1)
        coinReward = coinReward * selectedPrize.coinMultiplier
        
        -- 廣播轉盤結果
        FishGame.BroadcastToRoom(roomId, 'fishgame:luckyWheelResult', {
            sessionId = sessionId,
            playerName = session.playerName,
            prize = selectedPrize,
            bonusCoins = bonusCoins
        })
    end
    
    return coinReward, points
end

-- 點到線段距離計算
function FishGame.PointToLineDistance(point, lineStart, lineEnd)
    local A = point.x - lineStart.x
    local B = point.y - lineStart.y
    local C = lineEnd.x - lineStart.x
    local D = lineEnd.y - lineStart.y
    
    local dot = A * C + B * D
    local lenSq = C * C + D * D
    
    if lenSq == 0 then
        return math.sqrt(A * A + B * B)
    end
    
    local param = dot / lenSq
    
    local xx, yy
    if param < 0 then
        xx, yy = lineStart.x, lineStart.y
    elseif param > 1 then
        xx, yy = lineEnd.x, lineEnd.y
    else
        xx = lineStart.x + param * C
        yy = lineStart.y + param * D
    end
    
    local dx = point.x - xx
    local dy = point.y - yy
    return math.sqrt(dx * dx + dy * dy)
end

-- 遊戲循環
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.UpdateInterval)
        
        for roomId, _ in pairs(Config.Rooms) do
            FishGame.UpdateFish(roomId)
            FishGame.UpdateBullets(roomId)
        end
    end
end)

-- 清理過期特效
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        local currentTime = os.time()
        for roomId, roomData in pairs(FishGame.Rooms) do
            if roomData and roomData.gameData then
                local effectsToRemove = {}
                for effectId, effect in pairs(roomData.gameData.effects) do
                    if currentTime - effect.spawnTime > (effect.duration / 1000) then
                        table.insert(effectsToRemove, effectId)
                    end
                end
                
                -- 清理過期特效
                for _, effectId in ipairs(effectsToRemove) do
                    roomData.gameData.effects[effectId] = nil
                end
            end
        end
    end
end)

print('^2[魚機遊戲] ^7遊戲核心邏輯載入完成') 