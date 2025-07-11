-- UI管理系統

local UIManager = {}
UIManager.isVisible = false
UIManager.currentScreen = nil

-- 屏幕狀態
local screens = {
    MAIN_MENU = 'main_menu',
    GAME_UI = 'game_ui',
    SETTINGS = 'settings',
    LEADERBOARD = 'leaderboard',
    STATISTICS = 'statistics'
}

-- 初始化UI管理器
function UIManager.Initialize()
    UIManager.isVisible = false
    UIManager.currentScreen = nil
end

-- 顯示主選單
function UIManager.ShowMainMenu(roomId, playerData)
    UIManager.currentScreen = screens.MAIN_MENU
    UIManager.isVisible = true
    
    SendNUIMessage({
        type = 'ui_show',
        screen = screens.MAIN_MENU,
        data = {
            roomId = roomId,
            playerData = playerData,
            rooms = nil -- 將通過別的事件獲取
        }
    })
end

-- 顯示遊戲UI
function UIManager.ShowGameUI(gameData)
    UIManager.currentScreen = screens.GAME_UI
    UIManager.isVisible = true
    
    SendNUIMessage({
        type = 'ui_show',
        screen = screens.GAME_UI,
        data = gameData
    })
end

-- 隱藏UI
function UIManager.Hide()
    UIManager.isVisible = false
    UIManager.currentScreen = nil
    
    SendNUIMessage({
        type = 'ui_hide'
    })
end

-- 更新遊戲數據
function UIManager.UpdateGameData(updateData)
    if UIManager.currentScreen == screens.GAME_UI then
        SendNUIMessage({
            type = 'ui_update',
            screen = screens.GAME_UI,
            data = updateData
        })
    end
end

-- 顯示設置界面
function UIManager.ShowSettings()
    UIManager.currentScreen = screens.SETTINGS
    
    SendNUIMessage({
        type = 'ui_show',
        screen = screens.SETTINGS,
        data = {
            settings = FishGameClient.PlayerData.settings or {}
        }
    })
end

-- 顯示排行榜
function UIManager.ShowLeaderboard()
    UIManager.currentScreen = screens.LEADERBOARD
    
    -- 請求排行榜數據
    TriggerServerEvent('fishgame:getLeaderboard')
    
    SendNUIMessage({
        type = 'ui_show',
        screen = screens.LEADERBOARD,
        data = {
            loading = true
        }
    })
end

-- 顯示統計數據
function UIManager.ShowStatistics()
    UIManager.currentScreen = screens.STATISTICS
    
    -- 請求統計數據
    TriggerServerEvent('fishgame:getStatistics')
    
    SendNUIMessage({
        type = 'ui_show',
        screen = screens.STATISTICS,
        data = {
            loading = true
        }
    })
end

-- 處理UI回調
function UIManager.HandleCallback(action, data)
    if action == 'close' then
        if UIManager.currentScreen == screens.MAIN_MENU then
            CloseMainMenu()
        elseif UIManager.currentScreen == screens.GAME_UI then
            LeaveGameRoom()
        else
            UIManager.Hide()
        end
        
    elseif action == 'navigate' then
        if data.screen == 'settings' then
            UIManager.ShowSettings()
        elseif data.screen == 'leaderboard' then
            UIManager.ShowLeaderboard()
        elseif data.screen == 'statistics' then
            UIManager.ShowStatistics()
        elseif data.screen == 'main_menu' then
            UIManager.ShowMainMenu(data.roomId, FishGameClient.PlayerData)
        end
        
    elseif action == 'join_room' then
        JoinGameRoom(data.roomId, data.betAmount)
        
    elseif action == 'save_settings' then
        -- 保存設置
        TriggerServerEvent('fishgame:saveSettings', data.settings)
        
    elseif action == 'switch_weapon' then
        -- 切換武器
        UIManager.SwitchWeapon(data.weaponType)
        
    elseif action == 'use_skill' then
        -- 使用技能
        UIManager.UseSkill(data.skillType)
        
    elseif action == 'shoot' then
        -- 射擊
        UIManager.HandleShoot(data)
    end
end

-- 切換武器
function UIManager.SwitchWeapon(weaponType)
    if not FishGameClient.CurrentSession then return end
    
    -- 檢查玩家是否解鎖此武器
    local playerData = FishGameClient.PlayerData
    local unlockedWeapons = json.decode(playerData.unlocked_weapons or '["cannon_1"]')
    
    local hasWeapon = false
    for _, weapon in ipairs(unlockedWeapons) do
        if weapon == weaponType then
            hasWeapon = true
            break
        end
    end
    
    if not hasWeapon then
        ShowNotification('您尚未解鎖此武器', 'error')
        return
    end
    
    -- 發送切換武器事件
    TriggerServerEvent('fishgame:switchWeapon', FishGameClient.CurrentSession, weaponType)
    
    SendNUIMessage({
        type = 'weapon_switched',
        weaponType = weaponType
    })
end

-- 使用技能
function UIManager.UseSkill(skillType)
    if not FishGameClient.CurrentSession then return end
    
    -- 檢查玩家是否解鎖此技能
    local playerData = FishGameClient.PlayerData
    local unlockedSkills = json.decode(playerData.unlocked_skills or '[]')
    
    local hasSkill = false
    for _, skill in ipairs(unlockedSkills) do
        if skill == skillType then
            hasSkill = true
            break
        end
    end
    
    if not hasSkill then
        ShowNotification('您尚未解鎖此技能', 'error')
        return
    end
    
    -- 發送使用技能事件
    TriggerServerEvent('fishgame:useSkill', FishGameClient.CurrentSession, skillType)
end

-- 處理射擊
function UIManager.HandleShoot(shootData)
    if not FishGameClient.CurrentSession then return end
    
    local startPos = shootData.startPos
    local targetPos = shootData.targetPos
    local weaponType = shootData.weaponType or 'cannon_1'
    
    -- 發送射擊事件到服務端
    TriggerServerEvent('fishgame:shoot', FishGameClient.CurrentSession, weaponType, startPos, targetPos)
end

-- 更新房間列表
function UIManager.UpdateRoomList(rooms)
    if UIManager.currentScreen == screens.MAIN_MENU then
        SendNUIMessage({
            type = 'room_list_updated',
            rooms = rooms
        })
    end
end

-- 更新排行榜數據
function UIManager.UpdateLeaderboard(leaderboardData)
    if UIManager.currentScreen == screens.LEADERBOARD then
        SendNUIMessage({
            type = 'leaderboard_updated',
            data = leaderboardData
        })
    end
end

-- 更新統計數據
function UIManager.UpdateStatistics(statisticsData)
    if UIManager.currentScreen == screens.STATISTICS then
        SendNUIMessage({
            type = 'statistics_updated',
            data = statisticsData
        })
    end
end

-- 顯示遊戲結果
function UIManager.ShowGameResult(sessionData)
    SendNUIMessage({
        type = 'show_game_result',
        data = sessionData
    })
end

-- 顯示等級提升動畫
function UIManager.ShowLevelUp(newLevel)
    SendNUIMessage({
        type = 'show_level_up',
        newLevel = newLevel
    })
end

-- 顯示捕魚特效
function UIManager.ShowFishCaught(fishData, isMyFish)
    SendNUIMessage({
        type = 'fish_caught_effect',
        fishData = fishData,
        isMyFish = isMyFish
    })
end

-- 顯示射擊特效
function UIManager.ShowShootEffect(shootData)
    SendNUIMessage({
        type = 'shoot_effect',
        shootData = shootData
    })
end

-- 更新玩家狀態
function UIManager.UpdatePlayerStatus(statusData)
    if UIManager.currentScreen == screens.GAME_UI then
        SendNUIMessage({
            type = 'player_status_update',
            data = statusData
        })
    end
end

-- NUI回調註冊
RegisterNUICallback('ui_action', function(data, cb)
    UIManager.HandleCallback(data.action, data.data)
    cb('ok')
end)

-- 網絡事件處理
RegisterNetEvent('fishgame:ui_updateRoomList')
AddEventHandler('fishgame:ui_updateRoomList', function(rooms)
    UIManager.UpdateRoomList(rooms)
end)

RegisterNetEvent('fishgame:ui_updateLeaderboard')
AddEventHandler('fishgame:ui_updateLeaderboard', function(leaderboardData)
    UIManager.UpdateLeaderboard(leaderboardData)
end)

RegisterNetEvent('fishgame:ui_updateStatistics')
AddEventHandler('fishgame:ui_updateStatistics', function(statisticsData)
    UIManager.UpdateStatistics(statisticsData)
end)

RegisterNetEvent('fishgame:ui_gameResult')
AddEventHandler('fishgame:ui_gameResult', function(sessionData)
    UIManager.ShowGameResult(sessionData)
end)

RegisterNetEvent('fishgame:ui_levelUp')
AddEventHandler('fishgame:ui_levelUp', function(newLevel)
    UIManager.ShowLevelUp(newLevel)
end)

RegisterNetEvent('fishgame:ui_fishCaught')
AddEventHandler('fishgame:ui_fishCaught', function(fishData, isMyFish)
    UIManager.ShowFishCaught(fishData, isMyFish or false)
end)

RegisterNetEvent('fishgame:ui_shootEffect')
AddEventHandler('fishgame:ui_shootEffect', function(shootData)
    UIManager.ShowShootEffect(shootData)
end)

RegisterNetEvent('fishgame:ui_playerStatusUpdate')
AddEventHandler('fishgame:ui_playerStatusUpdate', function(statusData)
    UIManager.UpdatePlayerStatus(statusData)
end)

print('^2[魚機遊戲] ^7UI管理系統載入完成') 