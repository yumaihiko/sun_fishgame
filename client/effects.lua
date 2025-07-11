-- 客戶端特效系統

local EffectsManager = {}
EffectsManager.activeEffects = {}
EffectsManager.particleDict = 'core'
EffectsManager.soundEnabled = true

-- 初始化特效管理器
function EffectsManager.Initialize()
    EffectsManager.activeEffects = {}
    EffectsManager.LoadParticleAssets()
    print('^2[魚機遊戲] ^7特效系統初始化完成')
end

-- 載入粒子特效資源
function EffectsManager.LoadParticleAssets()
    -- 請求載入粒子字典
    if not HasNamedPtfxAssetLoaded(EffectsManager.particleDict) then
        RequestNamedPtfxAsset(EffectsManager.particleDict)
        
        Citizen.CreateThread(function()
            while not HasNamedPtfxAssetLoaded(EffectsManager.particleDict) do
                Citizen.Wait(10)
            end
            print('^2[魚機遊戲] ^7粒子特效資源載入完成')
        end)
    end
end

-- 播放射擊特效
function EffectsManager.PlayShootEffect(startPos, targetPos, weaponType)
    local effectId = 'shoot_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    
    local effect = {
        id = effectId,
        type = 'shoot',
        startPos = startPos,
        targetPos = targetPos,
        weaponType = weaponType,
        startTime = GetGameTimer(),
        duration = 500
    }
    
    EffectsManager.activeEffects[effectId] = effect
    
    -- 創建子彈軌跡特效
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        
        while GetGameTimer() - startTime < effect.duration do
            local progress = (GetGameTimer() - startTime) / effect.duration
            local currentX = startPos.x + (targetPos.x - startPos.x) * progress
            local currentY = startPos.y + (targetPos.y - startPos.y) * progress
            local currentZ = startPos.z + (targetPos.z - startPos.z) * progress
            
            -- 繪制子彈軌跡粒子
            UseParticleFxAssetNextCall(EffectsManager.particleDict)
            StartParticleFxNonLoopedAtCoord('ent_dst_rocks', currentX, currentY, currentZ, 0.0, 0.0, 0.0, 0.3, false, false, false)
            
            Citizen.Wait(16) -- 60 FPS
        end
        
        EffectsManager.activeEffects[effectId] = nil
    end)
    
    -- 播放射擊音效
    EffectsManager.PlaySound('shoot', startPos)
    
    return effectId
end

-- 播放爆炸特效
function EffectsManager.PlayExplosionEffect(position, radius, intensity)
    local effectId = 'explosion_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    
    local effect = {
        id = effectId,
        type = 'explosion',
        position = position,
        radius = radius or 5.0,
        intensity = intensity or 1.0,
        startTime = GetGameTimer(),
        duration = 2000
    }
    
    EffectsManager.activeEffects[effectId] = effect
    
    -- 創建爆炸視覺特效
    UseParticleFxAssetNextCall(EffectsManager.particleDict)
    StartParticleFxNonLoopedAtCoord('exp_grd_grenade_smoke', position.x, position.y, position.z, 0.0, 0.0, 0.0, effect.radius, false, false, false)
    
    -- 創建火焰特效
    UseParticleFxAssetNextCall(EffectsManager.particleDict)
    StartParticleFxNonLoopedAtCoord('exp_grd_grenade', position.x, position.y, position.z, 0.0, 0.0, 0.0, effect.radius, false, false, false)
    
    -- 添加屏幕震動
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', effect.intensity)
    
    -- 播放爆炸音效
    EffectsManager.PlaySound('explosion', position)
    
    -- 自動清理
    Citizen.SetTimeout(effect.duration, function()
        EffectsManager.activeEffects[effectId] = nil
    end)
    
    return effectId
end

-- 播放閃電特效
function EffectsManager.PlayLightningEffect(position, direction)
    local effectId = 'lightning_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    
    local effect = {
        id = effectId,
        type = 'lightning',
        position = position,
        direction = direction or {x = 0, y = 0, z = 1},
        startTime = GetGameTimer(),
        duration = 1500
    }
    
    EffectsManager.activeEffects[effectId] = effect
    
    -- 創建閃電視覺特效
    Citizen.CreateThread(function()
        for i = 1, 5 do
            local offsetX = (math.random() - 0.5) * 2.0
            local offsetY = (math.random() - 0.5) * 2.0
            
            UseParticleFxAssetNextCall(EffectsManager.particleDict)
            StartParticleFxNonLoopedAtCoord('ent_dst_elec_fire', 
                position.x + offsetX, 
                position.y + offsetY, 
                position.z, 
                0.0, 0.0, 0.0, 1.0, false, false, false)
            
            Citizen.Wait(100)
        end
    end)
    
    -- 創建閃光效果
    SetFlash(0, 0, 200, 300, 100)
    
    -- 播放閃電音效
    EffectsManager.PlaySound('lightning', position)
    
    -- 自動清理
    Citizen.SetTimeout(effect.duration, function()
        EffectsManager.activeEffects[effectId] = nil
    end)
    
    return effectId
end

-- 播放冰凍特效
function EffectsManager.PlayFreezeEffect(position, radius)
    local effectId = 'freeze_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    
    local effect = {
        id = effectId,
        type = 'freeze',
        position = position,
        radius = radius or 10.0,
        startTime = GetGameTimer(),
        duration = 3000
    }
    
    EffectsManager.activeEffects[effectId] = effect
    
    -- 創建冰凍範圍視覺效果
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        
        while GetGameTimer() - startTime < effect.duration do
            -- 創建冰晶粒子
            for i = 1, 8 do
                local angle = (i / 8) * 2 * math.pi
                local x = position.x + math.cos(angle) * effect.radius
                local y = position.y + math.sin(angle) * effect.radius
                
                UseParticleFxAssetNextCall(EffectsManager.particleDict)
                StartParticleFxNonLoopedAtCoord('ent_dst_inflate_ball', x, y, position.z, 0.0, 0.0, 0.0, 0.5, false, false, false)
            end
            
            Citizen.Wait(500)
        end
        
        EffectsManager.activeEffects[effectId] = nil
    end)
    
    -- 播放冰凍音效
    EffectsManager.PlaySound('freeze', position)
    
    return effectId
end

-- 播放捕魚成功特效
function EffectsManager.PlayCatchEffect(position, fishType, points)
    local effectId = 'catch_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    
    local effect = {
        id = effectId,
        type = 'catch',
        position = position,
        fishType = fishType,
        points = points,
        startTime = GetGameTimer(),
        duration = 2000
    }
    
    EffectsManager.activeEffects[effectId] = effect
    
    -- 創建成功捕獲的視覺特效
    UseParticleFxAssetNextCall(EffectsManager.particleDict)
    StartParticleFxNonLoopedAtCoord('ent_dst_gen_gobstop', position.x, position.y, position.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
    
    -- 根據魚類稀有度播放不同特效
    if fishType == 'legendary' then
        -- 傳說魚類特效
        UseParticleFxAssetNextCall(EffectsManager.particleDict)
        StartParticleFxNonLoopedAtCoord('ent_dst_concrete', position.x, position.y, position.z + 2.0, 0.0, 0.0, 0.0, 2.0, false, false, false)
        
        -- 金色光芒
        SetFlash(255, 215, 0, 200, 500)
    elseif fishType == 'rare' then
        -- 稀有魚類特效
        UseParticleFxAssetNextCall(EffectsManager.particleDict)
        StartParticleFxNonLoopedAtCoord('ent_dst_rocks', position.x, position.y, position.z + 1.0, 0.0, 0.0, 0.0, 1.5, false, false, false)
        
        -- 紫色光芒
        SetFlash(138, 43, 226, 150, 300)
    end
    
    -- 播放捕獲音效
    EffectsManager.PlaySound('catch', position)
    
    -- 自動清理
    Citizen.SetTimeout(effect.duration, function()
        EffectsManager.activeEffects[effectId] = nil
    end)
    
    return effectId
end

-- 播放水波紋特效
function EffectsManager.PlayWaterRippleEffect(position, size)
    local effectId = 'ripple_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    
    local effect = {
        id = effectId,
        type = 'ripple',
        position = position,
        size = size or 1.0,
        startTime = GetGameTimer(),
        duration = 1000
    }
    
    EffectsManager.activeEffects[effectId] = effect
    
    -- 創建水波紋特效
    UseParticleFxAssetNextCall(EffectsManager.particleDict)
    StartParticleFxNonLoopedAtCoord('ent_dst_inflate_ball_clr', position.x, position.y, position.z, 0.0, 0.0, 0.0, effect.size, false, false, false)
    
    -- 自動清理
    Citizen.SetTimeout(effect.duration, function()
        EffectsManager.activeEffects[effectId] = nil
    end)
    
    return effectId
end

-- 播放等級提升特效
function EffectsManager.PlayLevelUpEffect(playerPed)
    local effectId = 'levelup_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    local playerPos = GetEntityCoords(playerPed)
    
    local effect = {
        id = effectId,
        type = 'levelup',
        position = playerPos,
        playerPed = playerPed,
        startTime = GetGameTimer(),
        duration = 3000
    }
    
    EffectsManager.activeEffects[effectId] = effect
    
    -- 創建等級提升光柱特效
    Citizen.CreateThread(function()
        for i = 1, 10 do
            local coords = GetEntityCoords(playerPed)
            
            UseParticleFxAssetNextCall(EffectsManager.particleDict)
            StartParticleFxNonLoopedAtCoord('ent_dst_gen_gobstop', coords.x, coords.y, coords.z + 2.0, 0.0, 0.0, 0.0, 2.0, false, false, false)
            
            Citizen.Wait(200)
        end
        
        EffectsManager.activeEffects[effectId] = nil
    end)
    
    -- 金色閃光
    SetFlash(255, 215, 0, 255, 1000)
    
    -- 播放等級提升音效
    EffectsManager.PlaySound('levelup', playerPos)
    
    return effectId
end

-- 播放音效
function EffectsManager.PlaySound(soundType, position, volume)
    if not EffectsManager.soundEnabled then return end
    
    volume = volume or 0.5
    
    -- 使用GTA內建音效系統
    local soundId = GetSoundId()
    
    if soundType == 'shoot' then
        PlaySoundFromCoord(soundId, 'CHECKPOINT_PERFECT', position.x, position.y, position.z, 'HUD_MINI_GAME_SOUNDSET', false, 0, false)
    elseif soundType == 'explosion' then
        PlaySoundFromCoord(soundId, 'EXPLOSION', position.x, position.y, position.z, 'GTAO_FM_EVENTS_SOUNDSET', false, 0, false)
    elseif soundType == 'lightning' then
        PlaySoundFromCoord(soundId, 'ELECTRICITY_SPARKS', position.x, position.y, position.z, 'SCRIPTED_SCANNER_REPORT_SOUNDSET', false, 0, false)
    elseif soundType == 'catch' then
        PlaySoundFromCoord(soundId, 'CHECKPOINT_PERFECT', position.x, position.y, position.z, 'HUD_MINI_GAME_SOUNDSET', false, 0, false)
    elseif soundType == 'freeze' then
        PlaySoundFromCoord(soundId, 'WATER_SLOW_FALL', position.x, position.y, position.z, 'FAMILY_1_BOAT', false, 0, false)
    elseif soundType == 'levelup' then
        PlaySoundFrontend(soundId, 'RANK_UP', 'HUD_AWARDS', true)
    end
    
    -- 釋放音效ID
    Citizen.SetTimeout(5000, function()
        ReleaseSoundId(soundId)
    end)
end

-- 設置音效開關
function EffectsManager.SetSoundEnabled(enabled)
    EffectsManager.soundEnabled = enabled
end

-- 清理所有特效
function EffectsManager.ClearAllEffects()
    EffectsManager.activeEffects = {}
    print('^2[魚機遊戲] ^7已清理所有特效')
end

-- 清理過期特效
function EffectsManager.CleanupExpiredEffects()
    local currentTime = GetGameTimer()
    
    for effectId, effect in pairs(EffectsManager.activeEffects) do
        if effect.duration and currentTime - effect.startTime > effect.duration then
            EffectsManager.activeEffects[effectId] = nil
        end
    end
end

-- 獲取活躍特效數量
function EffectsManager.GetActiveEffectCount()
    local count = 0
    for _ in pairs(EffectsManager.activeEffects) do
        count = count + 1
    end
    return count
end

-- 定期清理特效
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- 每5秒清理一次
        EffectsManager.CleanupExpiredEffects()
    end
end)

-- 網絡事件處理
RegisterNetEvent('fishgame:effects_shoot')
AddEventHandler('fishgame:effects_shoot', function(startPos, targetPos, weaponType)
    EffectsManager.PlayShootEffect(startPos, targetPos, weaponType)
end)

RegisterNetEvent('fishgame:effects_explosion')
AddEventHandler('fishgame:effects_explosion', function(position, radius, intensity)
    EffectsManager.PlayExplosionEffect(position, radius, intensity)
end)

RegisterNetEvent('fishgame:effects_lightning')
AddEventHandler('fishgame:effects_lightning', function(position, direction)
    EffectsManager.PlayLightningEffect(position, direction)
end)

RegisterNetEvent('fishgame:effects_freeze')
AddEventHandler('fishgame:effects_freeze', function(position, radius)
    EffectsManager.PlayFreezeEffect(position, radius)
end)

RegisterNetEvent('fishgame:effects_catch')
AddEventHandler('fishgame:effects_catch', function(position, fishType, points)
    EffectsManager.PlayCatchEffect(position, fishType, points)
end)

RegisterNetEvent('fishgame:effects_ripple')
AddEventHandler('fishgame:effects_ripple', function(position, size)
    EffectsManager.PlayWaterRippleEffect(position, size)
end)

RegisterNetEvent('fishgame:effects_levelup')
AddEventHandler('fishgame:effects_levelup', function()
    local playerPed = PlayerPedId()
    EffectsManager.PlayLevelUpEffect(playerPed)
end)

RegisterNetEvent('fishgame:effects_clear')
AddEventHandler('fishgame:effects_clear', function()
    EffectsManager.ClearAllEffects()
end)

RegisterNetEvent('fishgame:effects_setSoundEnabled')
AddEventHandler('fishgame:effects_setSoundEnabled', function(enabled)
    EffectsManager.SetSoundEnabled(enabled)
end)

-- 資源停止時清理
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        EffectsManager.ClearAllEffects()
    end
end)

-- 初始化特效管理器
Citizen.CreateThread(function()
    EffectsManager.Initialize()
end)

-- 導出給其他腳本使用
_G.EffectsManager = EffectsManager

print('^2[魚機遊戲] ^7客戶端特效系統載入完成') 