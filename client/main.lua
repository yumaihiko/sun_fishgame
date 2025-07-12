local ESX = exports["es_extended"]:getSharedObject()

-- 全局變數
local FishGameClient = {}
FishGameClient.PlayerData = nil
FishGameClient.CurrentRoom = nil
FishGameClient.CurrentSession = nil
FishGameClient.InGame = false
FishGameClient.UIOpen = false

-- UI狀態
local showingMainMenu = false
local showingGameUI = false

-- 獲取玩家數據
Citizen.CreateThread(function()
    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(100)
    end
    
    TriggerServerEvent('fishgame:getPlayerData')
end)

-- 創建遊戲機互動點
Citizen.CreateThread(function()
    for roomId, roomData in pairs(Config.Rooms) do
        local coords = roomData.position
        
        -- 創建標記
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 266) -- 魚的圖標
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("魚機遊戲 - " .. roomData.name)
        EndTextCommandSetBlipName(blip)
    end
end)

-- 主要互動循環
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        if not FishGameClient.InGame then
            for roomId, roomData in pairs(Config.Rooms) do
                local distance = #(playerCoords - roomData.position)
                
                if distance < 5.0 then
                    sleep = 0
                    
                    -- 繪製3D文字
                    DrawText3D(roomData.position.x, roomData.position.y, roomData.position.z + 1.0, 
                        "~g~[E]~w~ 進入魚機遊戲\n~y~" .. roomData.name .. "~w~\n最低下注: ~g~$" .. roomData.minBet .. "~w~ | 最高下注: ~g~$" .. roomData.maxBet)
                    
                    if distance < 2.0 and IsControlJustPressed(0, 38) then -- E鍵
                        OpenMainMenu(roomId)
                    end
                end
            end
        end
        
        Citizen.Wait(sleep)
    end
end)

-- 打開主選單
function OpenMainMenu(roomId)
    if FishGameClient.UIOpen then return end
    
    print('^2[魚機遊戲] ^7打開主選單，房間ID:', roomId)
    
    FishGameClient.UIOpen = true
    showingMainMenu = true
    
    -- 獲取房間列表
    TriggerServerEvent('fishgame:getRoomList')
    
    -- 打開NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showMainMenu',
        roomId = roomId,
        playerData = FishGameClient.PlayerData or {},
        rooms = {} -- 臨時空房間列表，真實數據將通過getRoomList獲取
    })
    
    print('^2[魚機遊戲] ^7NUI消息已發送')
end

-- 關閉主選單
function CloseMainMenu()
    FishGameClient.UIOpen = false
    showingMainMenu = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideMainMenu'
    })
end

-- 加入遊戲房間
function JoinGameRoom(roomId, betAmount)
    TriggerServerEvent('fishgame:joinRoom', roomId, betAmount)
end

-- 離開遊戲房間
function LeaveGameRoom()
    if FishGameClient.CurrentSession then
        TriggerServerEvent('fishgame:leaveRoom')
    end
end

-- 開始遊戲
function StartGame(roomId, sessionId, betAmount, playerPosition)
    print('^2[魚機遊戲] ^7開始遊戲函數被調用')
    
    FishGameClient.CurrentRoom = roomId
    FishGameClient.CurrentSession = sessionId
    FishGameClient.InGame = true
    showingGameUI = true
    
    print('^2[魚機遊戲] ^7設置遊戲狀態完成，關閉主選單')
    
    CloseMainMenu()
    
    print('^2[魚機遊戲] ^7設置遊戲攝像頭')
    -- 設置遊戲攝像頭
    SetGameCameraMode()
    
    print('^2[魚機遊戲] ^7打開遊戲UI')
    -- 打開遊戲UI
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showGameUI',
        roomId = roomId,
        sessionId = sessionId,
        betAmount = betAmount,
        playerData = FishGameClient.PlayerData,
        playerPosition = playerPosition
    })
    
    print('^2[魚機遊戲] ^7開始遊戲循環')
    -- 開始遊戲循環
    StartGameLoop()
    
    print('^2[魚機遊戲] ^7遊戲初始化完成')
end

-- 結束遊戲
function EndGame()
    FishGameClient.InGame = false
    showingGameUI = false
    
    -- 恢復正常攝像頭
    RestoreGameCamera()
    
    -- 關閉遊戲UI
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideGameUI'
    })
    
    FishGameClient.CurrentRoom = nil
    FishGameClient.CurrentSession = nil
end

-- 設置遊戲攝像頭
function SetGameCameraMode()
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, 0)
    
    -- 創建遊戲攝像頭
    if not DoesCamExist(gameCam) then
        gameCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 
            0.0, 0.0, 50.0, -- 位置
            -90.0, 0.0, 0.0, -- 旋轉
            60.0, -- FOV
            true, 2)
        SetCamActive(gameCam, true)
        RenderScriptCams(true, true, 500, 1, 0)
    end
end

-- 恢復遊戲攝像頭
function RestoreGameCamera()
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, 0)
    
    if DoesCamExist(gameCam) then
        RenderScriptCams(false, true, 500, 1, 0)
        DestroyCam(gameCam, false)
        gameCam = nil
    end
end

-- 遊戲循環
function StartGameLoop()
    Citizen.CreateThread(function()
        while FishGameClient.InGame do
            Citizen.Wait(0)
            
            -- 禁用某些控制
            DisableControlAction(0, 1, true)  -- 滑鼠左右
            DisableControlAction(0, 2, true)  -- 滑鼠上下
            DisableControlAction(0, 24, true) -- 攻擊
            DisableControlAction(0, 25, true) -- 瞄準
            DisableControlAction(0, 142, true) -- 近戰攻擊
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
            
            -- ESC退出遊戲
            if IsControlJustPressed(0, 322) then -- ESC
                LeaveGameRoom()
            end
        end
    end)
end

-- 繪製3D文字
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end

-- 顯示通知
function ShowNotification(message, type)
    local color = '~w~'
    if type == 'success' then
        color = '~g~'
    elseif type == 'error' then
        color = '~r~'
    elseif type == 'warning' then
        color = '~y~'
    end
    
    ESX.ShowNotification(color .. message)
end

-- NUI回調
RegisterNUICallback('closeMainMenu', function(data, cb)
    CloseMainMenu()
    cb('ok')
end)

RegisterNUICallback('joinRoom', function(data, cb)
    JoinGameRoom(data.roomId, data.betAmount)
    cb('ok')
end)

RegisterNUICallback('nuiReady', function(data, cb)
    print('^2[魚機遊戲] ^7NUI已準備就緒')
    cb('ok')
end)

RegisterNUICallback('leaveGame', function(data, cb)
    LeaveGameRoom()
    cb('ok')
end)

RegisterNUICallback('shoot', function(data, cb)
    print('^2[魚機遊戲] ^7收到射擊請求:', data.weaponType)
    
    if FishGameClient.CurrentSession then
        TriggerServerEvent('fishgame:shoot', FishGameClient.CurrentSession, data.weaponType, data.startPos, data.targetPos)
        cb('ok')
    else
        print('^1[魚機遊戲] ^7射擊失敗：無活動會話')
        cb('error')
    end
end)

RegisterNUICallback('switchWeapon', function(data, cb)
    print('^2[魚機遊戲] ^7收到切換武器請求:', data.weaponType)
    
    if FishGameClient.CurrentSession then
        -- 這裡可以添加武器切換的服務端邏輯
        cb('ok')
    else
        cb('error')
    end
end)

RegisterNUICallback('useSkill', function(data, cb)
    print('^2[魚機遊戲] ^7收到使用技能請求:', data.skillType)
    
    if FishGameClient.CurrentSession then
        TriggerServerEvent('fishgame:useSkill', FishGameClient.CurrentSession, data.skillType)
        cb('ok')
    else
        print('^1[魚機遊戲] ^7使用技能失敗：無活動會話')
        cb('error')
    end
end)

RegisterNUICallback('ui_action', function(data, cb)
    print('^2[魚機遊戲] ^7收到UI動作:', data.action)
    
    if data.action == 'shoot' then
        if FishGameClient.CurrentSession then
            TriggerServerEvent('fishgame:shoot', FishGameClient.CurrentSession, data.data.weaponType, data.data.startPos, data.data.targetPos)
            cb('ok')
        else
            print('^1[魚機遊戲] ^7射擊失敗：無活動會話')
            cb('error')
        end
    elseif data.action == 'switch_weapon' then
        print('^2[魚機遊戲] ^7切換武器:', data.data.weaponType)
        cb('ok')
    elseif data.action == 'use_skill' then
        if FishGameClient.CurrentSession then
            TriggerServerEvent('fishgame:useSkill', FishGameClient.CurrentSession, data.data.skillType)
            cb('ok')
        else
            print('^1[魚機遊戲] ^7使用技能失敗：無活動會話')
            cb('error')
        end
    elseif data.action == 'close' then
        LeaveGameRoom()
        cb('ok')
    else
        cb('ok')
    end
end)

-- 服務端事件處理
RegisterNetEvent('fishgame:setPlayerData')
AddEventHandler('fishgame:setPlayerData', function(playerData)
    FishGameClient.PlayerData = playerData
end)

RegisterNetEvent('fishgame:receiveRoomList')
AddEventHandler('fishgame:receiveRoomList', function(rooms)
    print('^2[魚機遊戲] ^7收到房間列表:', json.encode(rooms))
    
    SendNUIMessage({
        type = 'updateRoomList',
        rooms = rooms
    })
    
    print('^2[魚機遊戲] ^7房間列表已發送到NUI')
end)

RegisterNetEvent('fishgame:joinedRoom')
AddEventHandler('fishgame:joinedRoom', function(roomId, sessionId, betAmount, playerPosition, gameConfig)
    print('^2[魚機遊戲] ^7收到joinedRoom事件 - 房間:', roomId, '會話:', sessionId, '下注:', betAmount, '位置:', playerPosition)
    
    -- 如果有遊戲配置，更新到NUI
    if gameConfig then
        SendNUIMessage({
            type = 'updateGameConfig',
            config = gameConfig
        })
    end
    
    StartGame(roomId, sessionId, betAmount, playerPosition)
end)

RegisterNetEvent('fishgame:leftRoom')
AddEventHandler('fishgame:leftRoom', function()
    EndGame()
end)

RegisterNetEvent('fishgame:showNotification')
AddEventHandler('fishgame:showNotification', function(message, type)
    ShowNotification(message, type)
end)

RegisterNetEvent('fishgame:sessionEnded')
AddEventHandler('fishgame:sessionEnded', function(sessionData)
    -- 顯示遊戲結果
    SendNUIMessage({
        type = 'showGameResult',
        sessionData = sessionData
    })
    
    Citizen.Wait(5000) -- 顯示5秒結果
    EndGame()
end)

RegisterNetEvent('fishgame:levelUp')
AddEventHandler('fishgame:levelUp', function(newLevel)
    ShowNotification('恭喜！等級提升至 ' .. newLevel, 'success')
    
    SendNUIMessage({
        type = 'levelUp',
        newLevel = newLevel
    })
end)

RegisterNetEvent('fishgame:fishCaught')
AddEventHandler('fishgame:fishCaught', function(fishData)
    -- 廣播其他玩家捕魚
    SendNUIMessage({
        type = 'otherPlayerCaughtFish',
        fishData = fishData
    })
end)

RegisterNetEvent('fishgame:fishCaughtByMe')
AddEventHandler('fishgame:fishCaughtByMe', function(fishData)
    -- 自己捕到魚
    SendNUIMessage({
        type = 'fishCaughtByMe',
        fishData = fishData
    })
end)

RegisterNetEvent('fishgame:playerShoot')
AddEventHandler('fishgame:playerShoot', function(shootData)
    -- 其他玩家射擊
    SendNUIMessage({
        type = 'otherPlayerShoot',
        shootData = shootData
    })
end)

RegisterNetEvent('fishgame:playerUpdate')
AddEventHandler('fishgame:playerUpdate', function(updateData)
    -- 其他玩家狀態更新
    SendNUIMessage({
        type = 'playerUpdate',
        updateData = updateData
    })
end)

RegisterNetEvent('fishgame:roomStateUpdate')
AddEventHandler('fishgame:roomStateUpdate', function(roomState)
    -- 房間狀態同步
    SendNUIMessage({
        type = 'roomStateUpdate',
        roomState = roomState
    })
end)

RegisterNetEvent('fishgame:skillActivated')
AddEventHandler('fishgame:skillActivated', function(skillData)
    print('^2[魚機遊戲] ^7技能激活:', skillData.skillName, '持續時間:', skillData.duration)
    
    -- 發送技能激活效果到NUI
    SendNUIMessage({
        type = 'skillActivated',
        skillData = skillData
    })
    
    -- 顯示技能激活通知
    if skillData.playerId == GetPlayerServerId(PlayerId()) then
        ShowNotification('技能激活：' .. skillData.skillName, 'success')
    else
        ShowNotification(skillData.playerName .. ' 使用了 ' .. skillData.skillName, 'info')
    end
end)

-- 多人遊戲相關事件
RegisterNetEvent('fishgame:playerJoinedRoom')
AddEventHandler('fishgame:playerJoinedRoom', function(data)
    print('^2[魚機遊戲] ^7玩家加入房間:', data.playerName, '總玩家數:', data.totalPlayers)
    
    SendNUIMessage({
        type = 'playerJoinedRoom',
        data = data
    })
    
    ShowNotification(data.playerName .. ' 加入了房間', 'info')
end)

RegisterNetEvent('fishgame:playerLeftRoom')
AddEventHandler('fishgame:playerLeftRoom', function(data)
    print('^2[魚機遊戲] ^7玩家離開房間:', data.playerName, '總玩家數:', data.totalPlayers)
    
    SendNUIMessage({
        type = 'playerLeftRoom',
        data = data
    })
    
    ShowNotification(data.playerName .. ' 離開了房間', 'info')
end)

RegisterNetEvent('fishgame:fishSpawned')
AddEventHandler('fishgame:fishSpawned', function(data)
    print('^2[魚機遊戲] ^7新魚生成:', data.newFishCount, '總魚數:', data.totalFishCount)
    
    SendNUIMessage({
        type = 'fishSpawned',
        data = data
    })
end)

RegisterNetEvent('fishgame:fishDamaged')
AddEventHandler('fishgame:fishDamaged', function(data)
    print('^2[魚機遊戲] ^7魚被攻擊:', data.fishId, '攻擊者:', data.attackerName, '傷害:', data.damage)
    
    SendNUIMessage({
        type = 'fishDamaged',
        data = data
    })
end)

RegisterNetEvent('fishgame:fishReward')
AddEventHandler('fishgame:fishReward', function(data)
    print('^2[魚機遊戲] ^7獲得魚獎勵:', data.fishName, '分數:', data.points, '金幣:', data.coinReward)
    
    SendNUIMessage({
        type = 'fishReward',
        data = data
    })
    
    -- 顯示獎勵通知
    local rewardText = '捕獲 ' .. data.fishName .. '！'
    if data.isFinalBlow then
        rewardText = rewardText .. ' (最後一擊)'
    end
    rewardText = rewardText .. '\n+' .. data.points .. ' 分 +' .. data.coinReward .. ' 金幣'
    
    if data.contributors > 1 then
        rewardText = rewardText .. '\n協作獎勵！(' .. data.contributors .. ' 人參與)'
    end
    
    ShowNotification(rewardText, 'success')
end)

RegisterNetEvent('fishgame:bombExplosion')
AddEventHandler('fishgame:bombExplosion', function(data)
    print('^2[魚機遊戲] ^7炸彈爆炸:', data.triggerPlayer, '影響魚數:', #data.explodedFish)
    
    SendNUIMessage({
        type = 'bombExplosion',
        data = data
    })
    
    ShowNotification(data.triggerPlayer .. ' 的炸彈魚爆炸了！', 'warning')
end)

RegisterNetEvent('fishgame:lightningStrike')
AddEventHandler('fishgame:lightningStrike', function(data)
    print('^2[魚機遊戲] ^7閃電打擊:', data.triggerPlayer, '影響魚數:', #data.struckFish)
    
    SendNUIMessage({
        type = 'lightningStrike',
        data = data
    })
    
    ShowNotification(data.triggerPlayer .. ' 的閃電魚發動了！', 'warning')
end)

-- 定期同步房間狀態
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- 每5秒同步一次
        
        if FishGameClient.InGame and FishGameClient.CurrentRoom then
            TriggerServerEvent('fishgame:syncRoomState', FishGameClient.CurrentRoom)
        end
    end
end)

-- 清理資源
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if FishGameClient.InGame then
            EndGame()
        end
        
        if FishGameClient.UIOpen then
            CloseMainMenu()
        end
    end
end)

print('^2[魚機遊戲] ^7客戶端主腳本載入完成') 