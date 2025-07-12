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
    
    -- 控制生成頻率（每2秒最多生成一次）
    if currentTime - roomData.gameData.lastFishSpawn < 2 then
        return
    end
    
    local fishSpawned = 0
    local maxFishInRoom = 30  -- 房間最大魚數量（增加以容納群體魚）
    local currentFishCount = 0
    
    -- 計算當前魚數量
    for _ in pairs(roomData.gameData.fish) do
        currentFishCount = currentFishCount + 1
    end
    
    -- 如果魚太多就不生成
    if currentFishCount >= maxFishInRoom then
        return
    end
    
    -- 根據機率生成不同魚類
    for fishType, fishData in pairs(Config.FishTypes) do
        local spawnRoll = math.random() * 100
        if spawnRoll <= fishData.spawnChance and fishSpawned < 5 then -- 每次最多生成5條魚
            
            -- 如果是群體魚，生成多條
            local spawnCount = 1
            if fishData.schoolSize then
                spawnCount = math.random(fishData.schoolSize.min, fishData.schoolSize.max)
            end
            
            -- 群體魚的中心位置
            local schoolCenterX = math.random(-1920, 1920)
            local schoolCenterY = math.random(-1080, 1080)
            local schoolVelocityX = (math.random() - 0.5) * fishData.speed
            local schoolVelocityY = (math.random() - 0.5) * fishData.speed
            
            for i = 1, spawnCount do
                if currentFishCount + fishSpawned >= maxFishInRoom then
                    break
                end
                
                roomData.gameData.fishIdCounter = roomData.gameData.fishIdCounter + 1
                local fishId = 'fish_' .. roomId .. '_' .. roomData.gameData.fishIdCounter
                
                -- 群體魚的位置偏移
                local offsetX = 0
                local offsetY = 0
                if fishData.schoolSize and i > 1 then
                    offsetX = math.random(-50, 50)
                    offsetY = math.random(-50, 50)
                end
                
                -- 決定起始位置（如果可以離開螢幕，則可能從螢幕外開始）
                local startX = schoolCenterX + offsetX
                local startY = schoolCenterY + offsetY
                if fishData.canLeaveScreen and math.random() < 0.3 then
                    -- 30%機率從螢幕外開始
                    if math.random() < 0.5 then
                        startX = math.random() < 0.5 and -2200 or 2200
                        startY = math.random(-1080, 1080)
                    else
                        startX = math.random(-1920, 1920)
                        startY = math.random() < 0.5 and -1300 or 1300
                    end
                end
                
                local fish = {
                    id = fishId,
                    type = fishType,
                    name = fishData.name,
                    points = fishData.points,
                    health = fishData.health,
                    maxHealth = fishData.health,
                    speed = fishData.speed,
                    size = fishData.size,
                    color = fishData.color,
                    rarity = fishData.rarity,
                    specialEffect = fishData.specialEffect,
                    image = fishData.image,
                    canLeaveScreen = fishData.canLeaveScreen,
                    position = {
                        x = startX,
                        y = startY,
                        z = 0
                    },
                    velocity = {
                        x = schoolVelocityX + (math.random() - 0.5) * 0.5, -- 小幅隨機偏移
                        y = schoolVelocityY + (math.random() - 0.5) * 0.5,
                        z = 0
                    },
                    rotation = math.random() * 360,
                    spawnTime = currentTime,
                    alive = true,
                    damageByPlayer = {},  -- 追蹤每個玩家對此魚造成的傷害
                    schoolId = fishData.schoolSize and ('school_' .. roomId .. '_' .. currentTime .. '_' .. fishType) or nil
                }
                
                -- 如果是大型魚，初始化倍數系統
                if fishData.multiplierSystem then
                    fish.multiplierData = {
                        currentMultiplier = fishData.multiplierSystem.baseMultiplier,
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

-- 更新魚類位置
function FishGame.UpdateFish(roomId)
    local roomData = FishGame.Rooms[roomId]
    if not roomData then return end
    
    local currentTime = os.time()
    local fishToRemove = {}
    
    for fishId, fish in pairs(roomData.gameData.fish) do
        if fish.alive then
            -- 更新位置
            fish.position.x = fish.position.x + fish.velocity.x
            fish.position.y = fish.position.y + fish.velocity.y
            
            -- 更新旋轉角度（面向移動方向）
            if fish.velocity.x ~= 0 or fish.velocity.y ~= 0 then
                fish.rotation = math.atan2(fish.velocity.y, fish.velocity.x) * 180 / math.pi
            end
            
            -- 邊界檢查
            if fish.canLeaveScreen then
                -- 可以游出螢幕的魚
                if fish.position.x > 2500 or fish.position.x < -2500 or
                   fish.position.y > 1500 or fish.position.y < -1500 then
                    -- 從另一邊返回
                    if math.random() < 0.5 then
                        if fish.position.x > 2500 then
                            fish.position.x = -2500
                        elseif fish.position.x < -2500 then
                            fish.position.x = 2500
                        end
                        if fish.position.y > 1500 then
                            fish.position.y = -1500
                        elseif fish.position.y < -1500 then
                            fish.position.y = 1500
                        end
                    else
                        -- 改變方向游回來
                        if fish.position.x > 2500 or fish.position.x < -2500 then
                            fish.velocity.x = -fish.velocity.x
                        end
                        if fish.position.y > 1500 or fish.position.y < -1500 then
                            fish.velocity.y = -fish.velocity.y
                        end
                    end
                end
            else
                -- 不能游出螢幕的魚，在邊界反彈
                if fish.position.x > 1920 or fish.position.x < -1920 then
                    fish.velocity.x = -fish.velocity.x
                    fish.position.x = math.max(-1920, math.min(1920, fish.position.x))
                end
                
                if fish.position.y > 1080 or fish.position.y < -1080 then
                    fish.velocity.y = -fish.velocity.y
                    fish.position.y = math.max(-1080, math.min(1080, fish.position.y))
                end
            end
            
            -- 隨機改變方向
            if math.random() < 0.02 then -- 2%機率改變方向
                local fishConfig = Config.FishTypes[fish.type]
                if fishConfig then
                    fish.velocity.x = (math.random() - 0.5) * fishConfig.speed
                    fish.velocity.y = (math.random() - 0.5) * fishConfig.speed
                end
            end
            
            -- 群體魚行為（跟隨附近的同類）
            if fish.schoolId then
                local nearbyFish = 0
                local avgVelX = 0
                local avgVelY = 0
                for otherId, otherFish in pairs(roomData.gameData.fish) do
                    if otherFish.schoolId == fish.schoolId and otherId ~= fishId then
                        local distance = math.sqrt(
                            (fish.position.x - otherFish.position.x) ^ 2 +
                            (fish.position.y - otherFish.position.y) ^ 2
                        )
                        if distance < 200 then
                            nearbyFish = nearbyFish + 1
                            avgVelX = avgVelX + otherFish.velocity.x
                            avgVelY = avgVelY + otherFish.velocity.y
                        end
                    end
                end
                if nearbyFish > 0 then
                    avgVelX = avgVelX / nearbyFish
                    avgVelY = avgVelY / nearbyFish
                    fish.velocity.x = fish.velocity.x * 0.8 + avgVelX * 0.2
                    fish.velocity.y = fish.velocity.y * 0.8 + avgVelY * 0.2
                end
            end
            
            -- 清理過期魚類
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
        weaponType = bullet.weaponType,
        weaponMultiplier = weapon.multiplier
    })
    
    if fish.health <= 0 then
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