-- 客戶端遊戲邏輯

local GameEngine = {}
GameEngine.isActive = false
GameEngine.gameData = {
    fish = {},
    bullets = {},
    effects = {},
    players = {}
}

-- 初始化遊戲引擎
function GameEngine.Initialize()
    GameEngine.isActive = false
    GameEngine.gameData = {
        fish = {},
        bullets = {},
        effects = {},
        players = {}
    }
end

-- 啟動遊戲引擎
function GameEngine.Start()
    GameEngine.isActive = true
    print('^2[魚機遊戲] ^7遊戲引擎已啟動')
end

-- 停止遊戲引擎
function GameEngine.Stop()
    GameEngine.isActive = false
    GameEngine.gameData = {
        fish = {},
        bullets = {},
        effects = {},
        players = {}
    }
    print('^2[魚機遊戲] ^7遊戲引擎已停止')
end

-- 更新魚類數據
function GameEngine.UpdateFish(fishData)
    if not GameEngine.isActive then return end
    
    for fishId, fish in pairs(fishData) do
        GameEngine.gameData.fish[fishId] = fish
    end
end

-- 更新子彈數據
function GameEngine.UpdateBullets(bulletData)
    if not GameEngine.isActive then return end
    
    for bulletId, bullet in pairs(bulletData) do
        GameEngine.gameData.bullets[bulletId] = bullet
    end
end

-- 更新特效數據
function GameEngine.UpdateEffects(effectData)
    if not GameEngine.isActive then return end
    
    for effectId, effect in pairs(effectData) do
        GameEngine.gameData.effects[effectId] = effect
    end
end

-- 更新玩家數據
function GameEngine.UpdatePlayers(playersData)
    if not GameEngine.isActive then return end
    
    GameEngine.gameData.players = playersData
end

-- 添加魚類
function GameEngine.AddFish(fishId, fishData)
    if not GameEngine.isActive then return end
    
    GameEngine.gameData.fish[fishId] = fishData
    
    -- 發送到UI
    SendNUIMessage({
        type = 'fish_spawned',
        fishId = fishId,
        fishData = fishData
    })
end

-- 移除魚類
function GameEngine.RemoveFish(fishId)
    if not GameEngine.isActive then return end
    
    GameEngine.gameData.fish[fishId] = nil
    
    -- 發送到UI
    SendNUIMessage({
        type = 'fish_removed',
        fishId = fishId
    })
end

-- 添加子彈
function GameEngine.AddBullet(bulletId, bulletData)
    if not GameEngine.isActive then return end
    
    GameEngine.gameData.bullets[bulletId] = bulletData
    
    -- 發送到UI
    SendNUIMessage({
        type = 'bullet_fired',
        bulletId = bulletId,
        bulletData = bulletData
    })
end

-- 移除子彈
function GameEngine.RemoveBullet(bulletId)
    if not GameEngine.isActive then return end
    
    GameEngine.gameData.bullets[bulletId] = nil
    
    -- 發送到UI
    SendNUIMessage({
        type = 'bullet_removed',
        bulletId = bulletId
    })
end

-- 添加特效
function GameEngine.AddEffect(effectId, effectData)
    if not GameEngine.isActive then return end
    
    GameEngine.gameData.effects[effectId] = effectData
    
    -- 發送到UI
    SendNUIMessage({
        type = 'effect_started',
        effectId = effectId,
        effectData = effectData
    })
end

-- 移除特效
function GameEngine.RemoveEffect(effectId)
    if not GameEngine.isActive then return end
    
    GameEngine.gameData.effects[effectId] = nil
    
    -- 發送到UI
    SendNUIMessage({
        type = 'effect_ended',
        effectId = effectId
    })
end

-- 處理魚類被擊中
function GameEngine.HandleFishHit(fishId, damage, shooterId)
    if not GameEngine.isActive then return end
    
    local fish = GameEngine.gameData.fish[fishId]
    if not fish then return end
    
    -- 更新魚類血量
    fish.health = math.max(0, fish.health - damage)
    
    -- 發送受傷特效
    SendNUIMessage({
        type = 'fish_hit',
        fishId = fishId,
        damage = damage,
        shooterId = shooterId,
        remainingHealth = fish.health
    })
    
    -- 如果魚類死亡
    if fish.health <= 0 then
        GameEngine.HandleFishDeath(fishId, shooterId)
    end
end

-- 處理魚類死亡
function GameEngine.HandleFishDeath(fishId, shooterId)
    if not GameEngine.isActive then return end
    
    local fish = GameEngine.gameData.fish[fishId]
    if not fish then return end
    
    -- 播放死亡特效
    SendNUIMessage({
        type = 'fish_death',
        fishId = fishId,
        shooterId = shooterId,
        fishData = fish
    })
    
    -- 移除魚類
    GameEngine.RemoveFish(fishId)
end

-- 處理特殊效果
function GameEngine.HandleSpecialEffect(effectType, position, data)
    if not GameEngine.isActive then return end
    
    local effectId = 'special_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    
    local effectData = {
        type = effectType,
        position = position,
        startTime = GetGameTimer(),
        data = data
    }
    
    -- 根據效果類型設置持續時間
    if effectType == 'explosion' then
        effectData.duration = 2000
        effectData.radius = data.radius or 200
    elseif effectType == 'lightning' then
        effectData.duration = 1500
    elseif effectType == 'freeze' then
        effectData.duration = data.duration or 10000
    end
    
    GameEngine.AddEffect(effectId, effectData)
    
    -- 自動移除特效
    Citizen.SetTimeout(effectData.duration, function()
        GameEngine.RemoveEffect(effectId)
    end)
end

-- 獲取遊戲狀態
function GameEngine.GetGameState()
    return {
        isActive = GameEngine.isActive,
        fishCount = GetTableLength(GameEngine.gameData.fish),
        bulletCount = GetTableLength(GameEngine.gameData.bullets),
        effectCount = GetTableLength(GameEngine.gameData.effects),
        playerCount = GetTableLength(GameEngine.gameData.players)
    }
end

-- 清理遊戲數據
function GameEngine.CleanupGameData()
    local currentTime = GetGameTimer()
    
    -- 清理過期子彈
    for bulletId, bullet in pairs(GameEngine.gameData.bullets) do
        if currentTime - bullet.startTime > 10000 then -- 10秒後清理
            GameEngine.RemoveBullet(bulletId)
        end
    end
    
    -- 清理過期特效
    for effectId, effect in pairs(GameEngine.gameData.effects) do
        if effect.duration and currentTime - effect.startTime > effect.duration then
            GameEngine.RemoveEffect(effectId)
        end
    end
end

-- 定期清理數據
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- 每5秒清理一次
        
        if GameEngine.isActive then
            GameEngine.CleanupGameData()
        end
    end
end)

-- 輔助函數：計算表長度
function GetTableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- 網絡事件處理
RegisterNetEvent('fishgame:game_fishSpawned')
AddEventHandler('fishgame:game_fishSpawned', function(fishId, fishData)
    GameEngine.AddFish(fishId, fishData)
end)

RegisterNetEvent('fishgame:game_fishRemoved')
AddEventHandler('fishgame:game_fishRemoved', function(fishId)
    GameEngine.RemoveFish(fishId)
end)

RegisterNetEvent('fishgame:game_bulletFired')
AddEventHandler('fishgame:game_bulletFired', function(bulletId, bulletData)
    GameEngine.AddBullet(bulletId, bulletData)
end)

RegisterNetEvent('fishgame:game_bulletRemoved')
AddEventHandler('fishgame:game_bulletRemoved', function(bulletId)
    GameEngine.RemoveBullet(bulletId)
end)

RegisterNetEvent('fishgame:game_effectStarted')
AddEventHandler('fishgame:game_effectStarted', function(effectId, effectData)
    GameEngine.AddEffect(effectId, effectData)
end)

RegisterNetEvent('fishgame:game_effectEnded')
AddEventHandler('fishgame:game_effectEnded', function(effectId)
    GameEngine.RemoveEffect(effectId)
end)

RegisterNetEvent('fishgame:game_fishHit')
AddEventHandler('fishgame:game_fishHit', function(fishId, damage, shooterId)
    GameEngine.HandleFishHit(fishId, damage, shooterId)
end)

RegisterNetEvent('fishgame:game_specialEffect')
AddEventHandler('fishgame:game_specialEffect', function(effectType, position, data)
    GameEngine.HandleSpecialEffect(effectType, position, data)
end)

RegisterNetEvent('fishgame:game_stateUpdate')
AddEventHandler('fishgame:game_stateUpdate', function(gameData)
    if gameData.fish then
        GameEngine.UpdateFish(gameData.fish)
    end
    
    if gameData.bullets then
        GameEngine.UpdateBullets(gameData.bullets)
    end
    
    if gameData.effects then
        GameEngine.UpdateEffects(gameData.effects)
    end
    
    if gameData.players then
        GameEngine.UpdatePlayers(gameData.players)
    end
end)

RegisterNetEvent('fishgame:game_start')
AddEventHandler('fishgame:game_start', function()
    GameEngine.Start()
end)

RegisterNetEvent('fishgame:game_stop')
AddEventHandler('fishgame:game_stop', function()
    GameEngine.Stop()
end)

-- 導出給其他腳本使用
_G.GameEngine = GameEngine

print('^2[魚機遊戲] ^7客戶端遊戲邏輯載入完成') 