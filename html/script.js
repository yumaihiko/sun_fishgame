// 魚機遊戲 JavaScript

// 輔助函數：獲取資源名稱
function getResourceName() {
    if (typeof GetParentResourceName === 'function') {
        return GetParentResourceName();
    }
    // 備用資源名稱
    return 'sun_fishgame';
}

// 輔助函數：發送NUI消息
function sendNUIMessage(endpoint, data = {}) {
    const resourceName = getResourceName();
    
    return fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(response => {
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
    }).catch(error => {
        console.error(`NUI Error [${endpoint}]:`, error);
        throw error;
    });
}

// 全局變數
let gameState = {
    currentScreen: null,
    inGame: false,
    selectedRoom: null,
    currentSession: null,
    playerData: null,
    autoAimActive: false,
    freezeActive: false,
    doublePointsActive: false,
    playerPosition: 0, // 玩家在6個位置中的索引 (0-5)
    gameData: {
        score: 0,
        coins: 0,
        fishCaught: 0,
        startTime: null,
        fish: {},
        bullets: {},
        effects: {}
    },
    settings: {
        masterVolume: 50,
        sfxVolume: 70,
        musicVolume: 30,
        autoAim: false,
        showFPS: false,
        particleQuality: 'medium'
    }
};

// 遊戲配置（從Lua配置同步）
let gameConfig = {
    fishTypes: {},
    weapons: {},
    specialSkills: {},
    rooms: {}
};

// Canvas和渲染相關
let canvas = null;
let ctx = null;
let animationFrame = null;
let lastFrameTime = 0;
let fps = 0;

// 音效系統
let audioContext = null;
let sounds = {};

// 輸入處理
let mousePos = { x: 0, y: 0 };
let currentWeapon = 'cannon_1';
let isMouseDown = false;

// 初始化
document.addEventListener('DOMContentLoaded', function() {
    initializeGame();
    setupEventListeners();
    loadGameSettings();
    setupMultiplayerEvents();
});

// 初始化遊戲
function initializeGame() {
    canvas = document.getElementById('gameCanvas');
    if (canvas) {
        ctx = canvas.getContext('2d');
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);
    }
    
    // 初始化音效
    initializeAudio();
    
    // 隱藏所有界面
    hideAllScreens();
    
    console.log('魚機遊戲初始化完成');
}

// 調整畫布大小
function resizeCanvas() {
    if (canvas) {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }
}

// 初始化音效系統
function initializeAudio() {
    try {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
        console.log('音效系統初始化成功');
    } catch (e) {
        console.warn('音效系統初始化失敗:', e);
    }
}

// 播放音效
function playSound(soundName, volume = 1.0) {
    if (!audioContext || !sounds[soundName]) return;
    
    try {
        const source = audioContext.createBufferSource();
        const gainNode = audioContext.createGain();
        
        source.buffer = sounds[soundName];
        gainNode.gain.value = volume * (gameState.settings.sfxVolume / 100);
        
        source.connect(gainNode);
        gainNode.connect(audioContext.destination);
        source.start();
    } catch (e) {
        console.warn('播放音效失敗:', e);
    }
}

// 設置事件監聽器
function setupEventListeners() {
    // 滑鼠事件
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mousedown', handleMouseDown);
    document.addEventListener('mouseup', handleMouseUp);
    document.addEventListener('contextmenu', e => e.preventDefault());
    
    // 鍵盤事件
    document.addEventListener('keydown', handleKeyDown);
    document.addEventListener('keyup', handleKeyUp);
    
    // 下注滑桿事件
    const betSlider = document.getElementById('betSlider');
    const betAmount = document.getElementById('betAmount');
    
    if (betSlider && betAmount) {
        betSlider.addEventListener('input', function() {
            betAmount.value = this.value;
        });
        
        betAmount.addEventListener('input', function() {
            betSlider.value = this.value;
        });
    }
    
    // 設定滑桿事件
    setupSettingsEventListeners();
}

// 設置設定選項事件監聽器
function setupSettingsEventListeners() {
    const volumeSliders = ['masterVolume', 'sfxVolume', 'musicVolume'];
    
    volumeSliders.forEach(sliderId => {
        const slider = document.getElementById(sliderId);
        const valueSpan = document.getElementById(sliderId + 'Value');
        
        if (slider && valueSpan) {
            slider.addEventListener('input', function() {
                valueSpan.textContent = this.value + '%';
                gameState.settings[sliderId] = parseInt(this.value);
            });
        }
    });
}

// 滑鼠移動處理
function handleMouseMove(e) {
    if (!gameState.autoAimActive) {
        mousePos.x = e.clientX;
        mousePos.y = e.clientY;
    } else {
        // 自動瞄準最近的魚
        const nearestFish = findNearestFish();
        if (nearestFish) {
            mousePos.x = nearestFish.position.x;
            mousePos.y = nearestFish.position.y;
        } else {
            mousePos.x = e.clientX;
            mousePos.y = e.clientY;
        }
    }
    
    if (gameState.inGame) {
        updateCrosshair(mousePos.x, mousePos.y);
    }
}

// 尋找最近的魚
function findNearestFish() {
    if (!canvas) return null;
    
    let nearestFish = null;
    let minDistance = Infinity;
    const centerX = canvas.width / 2;
    const centerY = canvas.height - 100;
    
    for (const fishId in gameState.gameData.fish) {
        const fish = gameState.gameData.fish[fishId];
        if (!fish.alive) continue;
        
        const distance = Math.sqrt(
            Math.pow(fish.position.x - centerX, 2) + 
            Math.pow(fish.position.y - centerY, 2)
        );
        
        if (distance < minDistance) {
            minDistance = distance;
            nearestFish = fish;
        }
    }
    
    return nearestFish;
}

// 滑鼠按下處理
function handleMouseDown(e) {
    if (e.button === 0 && gameState.inGame) { // 左鍵
        isMouseDown = true;
        handleShoot();
    }
}

// 滑鼠釋放處理
function handleMouseUp(e) {
    if (e.button === 0) {
        isMouseDown = false;
    }
}

// 鍵盤按下處理
function handleKeyDown(e) {
    switch(e.code) {
        case 'Escape':
            if (gameState.inGame) {
                leaveGame();
            } else if (gameState.currentScreen === 'mainMenu') {
                closeMainMenu();
            }
            break;
        case 'Space':
            if (gameState.inGame) {
                e.preventDefault();
                handleShoot();
            }
            break;
        case 'Digit1':
        case 'Digit2':
        case 'Digit3':
        case 'Digit4':
            if (gameState.inGame) {
                const weaponIndex = parseInt(e.code.slice(-1)) - 1;
                const weaponKeys = Object.keys(gameConfig.weapons);
                if (weaponKeys[weaponIndex]) {
                    switchWeapon(weaponKeys[weaponIndex]);
                }
            }
            break;
    }
}

// 鍵盤釋放處理
function handleKeyUp(e) {
    // 處理按鍵釋放事件
}

// 更新準心位置
function updateCrosshair(x, y) {
    const crosshair = document.getElementById('crosshair');
    if (crosshair) {
        crosshair.style.left = (x - 20) + 'px';
        crosshair.style.top = (y - 20) + 'px';
        crosshair.style.display = 'block';
    }
}

// 處理射擊
// 獲取玩家射擊位置
function getPlayerShootPosition() {
    const positions = [
        { x: canvas.width * 0.15, y: canvas.height - 80 }, // 位置1: 左側
        { x: canvas.width * 0.30, y: canvas.height - 80 }, // 位置2: 左中
        { x: canvas.width * 0.45, y: canvas.height - 80 }, // 位置3: 中左
        { x: canvas.width * 0.55, y: canvas.height - 80 }, // 位置4: 中右
        { x: canvas.width * 0.70, y: canvas.height - 80 }, // 位置5: 右中
        { x: canvas.width * 0.85, y: canvas.height - 80 }  // 位置6: 右側
    ];
    
    return positions[gameState.playerPosition] || positions[0];
}

function handleShoot() {
    if (!gameState.inGame || !gameState.currentSession) {
        console.log('Cannot shoot: not in game or no session');
        return;
    }
    
    if (!canvas) {
        console.error('Cannot shoot: canvas not found');
        return;
    }
    
    // 檢查金幣是否足夠
    const weaponCost = getWeaponCost(currentWeapon);
    if (gameState.gameData.coins < weaponCost) {
        showNotification('金幣不足', 'error');
        return;
    }
    
    const startPos = getPlayerShootPosition();
    const targetPos = { x: mousePos.x, y: mousePos.y, z: 0 };
    
    console.log('Shooting with weapon:', currentWeapon, 'from:', startPos, 'to:', targetPos, 'player position:', gameState.playerPosition);
    
    // 播放射擊音效
    playSound('shoot');
    
    // 發送射擊事件到客戶端
    fetch(`https://${GetParentResourceName()}/ui_action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: 'shoot',
            data: {
                weaponType: currentWeapon,
                startPos: startPos,
                targetPos: targetPos,
                playerPosition: gameState.playerPosition
            }
        })
    }).then(() => {
        console.log('Shoot request sent successfully');
        
        // 扣除武器成本
        gameState.gameData.coins -= weaponCost;
        updateGameHUD();
        
        // 添加本地射擊特效
        addShootEffect(startPos, targetPos);
        
        // 檢查魚類碰撞
        checkFishCollision(startPos, targetPos);
        
    }).catch(error => {
        console.error('Shoot request error:', error);
    });
}

// 添加射擊特效
function addShootEffect(startPos, targetPos) {
    const effectId = 'effect_' + Date.now() + '_' + Math.random();
    
    // 根據武器設置不同的特效屬性
    const weaponEffects = {
        'cannon_1': { color: 'rgba(255, 255, 255, 0.8)', width: 3, duration: 800 },
        'cannon_2': { color: 'rgba(0, 255, 0, 0.9)', width: 5, duration: 600 },
        'cannon_3': { color: 'rgba(255, 0, 0, 1.0)', width: 7, duration: 400 },
        'cannon_laser': { color: 'rgba(255, 0, 255, 1.0)', width: 10, duration: 200 }
    };
    
    const effect = weaponEffects[currentWeapon] || weaponEffects['cannon_1'];
    
    gameState.gameData.effects[effectId] = {
        type: 'bullet',
        startPos: startPos,
        currentPos: { ...startPos },
        targetPos: targetPos,
        startTime: Date.now(),
        duration: effect.duration,
        weapon: currentWeapon,
        color: effect.color,
        width: effect.width,
        playerPosition: gameState.playerPosition
    };
}

// 切換武器
function switchWeapon(weaponType) {
    console.log('Switching weapon to:', weaponType);
    
    if (!gameState.inGame) {
        console.log('Cannot switch weapon: not in game');
        return;
    }
    
    currentWeapon = weaponType;
    
    // 更新UI
    document.querySelectorAll('.weapon-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    const weaponBtn = document.querySelector(`[data-weapon="${weaponType}"]`);
    if (weaponBtn) {
        weaponBtn.classList.add('active');
        console.log('Weapon button activated:', weaponType);
    }
    
    // 發送到客戶端
    fetch(`https://${GetParentResourceName()}/ui_action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: 'switch_weapon',
            data: { weaponType: weaponType }
        })
    }).then(() => {
        console.log('Weapon switch request sent successfully');
        showNotification(`切換武器: ${getWeaponName(weaponType)}`, 'success');
    }).catch(error => {
        console.error('Weapon switch error:', error);
    });
}

// 獲取武器名稱
function getWeaponName(weaponType) {
    const weaponNames = {
        'cannon_1': '小型砲',
        'cannon_2': '中型砲',
        'cannon_3': '大型砲',
        'cannon_laser': '雷射砲'
    };
    return weaponNames[weaponType] || '未知武器';
}

// 獲取武器成本
function getWeaponCost(weaponType) {
    const weaponCosts = {
        'cannon_1': 10,
        'cannon_2': 20,
        'cannon_3': 40,
        'cannon_laser': 100
    };
    return weaponCosts[weaponType] || 10;
}

// 使用技能
function useSkill(skillType) {
    console.log('useSkill called with:', skillType);
    
    if (!gameState.inGame || !gameState.currentSession) {
        console.error('Cannot use skill: not in game or no session');
        showNotification('請先進入遊戲', 'warning');
        return;
    }
    
    // 檢查金幣是否足夠
    const skillCost = getSkillCost(skillType);
    if (gameState.gameData.coins < skillCost) {
        showNotification('金幣不足', 'error');
        return;
    }
    
    console.log('Using skill:', skillType);
    
    // 發送技能使用請求
    fetch(`https://${GetParentResourceName()}/ui_action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: 'use_skill',
            data: { skillType: skillType }
        })
    }).then(response => response.json())
    .then(data => {
        console.log('Skill use response:', data);
        showNotification(`使用技能: ${getSkillName(skillType)}`, 'success');
        
        // 扣除技能費用
        gameState.gameData.coins -= skillCost;
        updateGameHUD();
    })
    .catch(error => {
        console.error('Skill use error:', error);
        showNotification('技能使用失敗', 'error');
    });
}

// 獲取技能成本
function getSkillCost(skillType) {
    const skillCosts = {
        'freeze_all': 500,
        'double_points': 300,
        'auto_aim': 200,
        'lightning_strike': 400
    };
    return skillCosts[skillType] || 100;
}

// 獲取技能名稱
function getSkillName(skillType) {
    const skillNames = {
        'freeze_all': '冰凍全場',
        'double_points': '雙倍積分',
        'auto_aim': '自動瞄準',
        'lightning_strike': '閃電打擊'
    };
    return skillNames[skillType] || '未知技能';
}

// 顯示主選單
function showMainMenu(data) {
    console.log('Showing main menu with data:', data);
    
    gameState.currentScreen = 'mainMenu';
    gameState.playerData = data.playerData;
    
    updatePlayerInfo();
    updateRoomList(data.rooms);
    
    document.getElementById('mainMenu').style.display = 'flex';
    
    // 確保事件綁定（延遲執行確保DOM完全更新）
    setTimeout(() => {
        setupButtonEvents();
        testButtonEvents(); // 調試用
    }, 100);
}

// 隱藏主選單
function hideMainMenu() {
    document.getElementById('mainMenu').style.display = 'none';
    gameState.currentScreen = null;
}

// 關閉主選單
function closeMainMenu() {
    sendNUIMessage('closeMainMenu')
        .then(data => {
            console.log('Close menu response:', data);
            hideMainMenu();
        })
        .catch(error => {
            console.error('Close menu error:', error);
            // 即使失敗也嘗試隱藏UI
            hideMainMenu();
        });
}

// 更新玩家信息
function updatePlayerInfo() {
    if (!gameState.playerData) return;
    
    const playerLevel = document.getElementById('playerLevel');
    const playerMoney = document.getElementById('playerMoney');
    const playerExp = document.getElementById('playerExp');
    const playerExpMax = document.getElementById('playerExpMax');
    
    if (playerLevel) playerLevel.textContent = gameState.playerData.level || 1;
    if (playerMoney) playerMoney.textContent = formatNumber(gameState.playerData.money || 0);
    if (playerExp) playerExp.textContent = gameState.playerData.experience || 0;
    if (playerExpMax) playerExpMax.textContent = (gameState.playerData.level || 1) * 1000;
}

// 更新房間列表
function updateRoomList(rooms) {
    const roomsGrid = document.getElementById('roomsGrid');
    if (!roomsGrid || !rooms) return;
    
    roomsGrid.innerHTML = '';
    
    Object.values(rooms).forEach(room => {
        const roomCard = createRoomCard(room);
        roomsGrid.appendChild(roomCard);
    });
}

// 創建房間卡片
function createRoomCard(room) {
    const card = document.createElement('div');
    card.className = 'room-card';
    card.dataset.roomId = room.id;
    
    const isFull = room.currentPlayers >= room.maxPlayers;
    
    card.innerHTML = `
        <div class="room-name">${room.name}</div>
        <div class="room-info">最低下注: $${formatNumber(room.minBet)}</div>
        <div class="room-info">最高下注: $${formatNumber(room.maxBet)}</div>
        <div class="room-info">權限: ${getRoomAccessText(room.access)}</div>
        <div class="room-players ${isFull ? 'full' : ''}">
            <span>玩家: ${room.currentPlayers}/${room.maxPlayers}</span>
            <span>${isFull ? '房間已滿' : '可加入'}</span>
        </div>
    `;
    
    if (!isFull) {
        card.addEventListener('click', () => selectRoom(room.id));
    } else {
        card.style.opacity = '0.5';
        card.style.cursor = 'not-allowed';
    }
    
    return card;
}

// 獲取房間權限文字
function getRoomAccessText(access) {
    switch(access) {
        case 'public': return '公開';
        case 'vip': return 'VIP';
        case 'private': return '私人';
        default: return '未知';
    }
}

// 選擇房間
function selectRoom(roomId) {
    // 移除之前的選擇
    document.querySelectorAll('.room-card').forEach(card => {
        card.classList.remove('selected');
    });
    
    // 選擇新房間
    const selectedCard = document.querySelector(`[data-room-id="${roomId}"]`);
    if (selectedCard) {
        selectedCard.classList.add('selected');
        gameState.selectedRoom = roomId;
    }
}

// 設定下注金額
function setBetAmount(amount) {
    const betSlider = document.getElementById('betSlider');
    const betAmount = document.getElementById('betAmount');
    
    if (betSlider) betSlider.value = amount;
    if (betAmount) betAmount.value = amount;
}

// 加入選定的房間
function joinSelectedRoom() {
    if (!gameState.selectedRoom) {
        showNotification('請先選擇一個房間', 'warning');
        return;
    }
    
    const betAmount = parseInt(document.getElementById('betAmount').value);
    
    if (!betAmount || betAmount < 100) {
        showNotification('請輸入有效的下注金額', 'warning');
        return;
    }
    
    // 發送加入房間請求
    sendNUIMessage('joinRoom', {
        roomId: gameState.selectedRoom,
        betAmount: betAmount
    }).then(data => {
        console.log('Join room response:', data);
        showNotification('正在加入房間...', 'info');
    })
    .catch(error => {
        console.error('Join room error:', error);
        showNotification('加入房間時發生錯誤', 'error');
    });
}

// 顯示遊戲界面
function showGameUI(data) {
    console.log('showGameUI called with data:', data);
    
    gameState.currentScreen = 'gameUI';
    gameState.inGame = true;
    gameState.currentSession = data.sessionId;
    gameState.playerPosition = data.playerPosition || 0;
    gameState.gameData.startTime = Date.now();
    
    console.log('玩家位置設置為:', gameState.playerPosition);
    
    console.log('Game state updated, hiding main menu...');
    hideMainMenu();
    
    const gameUI = document.getElementById('gameUI');
    if (gameUI) {
        gameUI.style.display = 'block';
        console.log('Game UI set to display: block');
    } else {
        console.error('Game UI element not found!');
        return;
    }
    
    console.log('Initializing game UI...');
    // 初始化遊戲UI
    initializeGameUI(data);
    
    console.log('Starting game loop...');
    // 開始遊戲循環
    startGameLoop();
    
    console.log('showGameUI completed successfully');
}

// 初始化遊戲UI
function initializeGameUI(data) {
    console.log('initializeGameUI called');
    
    // 預加載魚類圖片
    preloadFishImages();
    
    // 預加載玩家圖片
    preloadPlayerImages();
    
    // 更新房間信息
    const roomName = document.getElementById('roomName');
    if (roomName) {
        roomName.textContent = data.roomName || '未知房間';
        console.log('Room name updated:', data.roomName || '未知房間');
    } else {
        console.error('Room name element not found');
    }
    
    console.log('Initializing weapons...');
    // 初始化武器選擇
    initializeWeapons();
    
    console.log('Initializing skills...');
    // 初始化技能
    initializeSkills();
    
    console.log('Resetting game data...');
    // 重置遊戲數據
    gameState.gameData.score = 0;
    gameState.gameData.coins = data.betAmount || 0;
    gameState.gameData.fishCaught = 0;
    gameState.gameData.fish = {};
    
    console.log('Starting fish generation...');
    // 開始生成魚類
    startFishGeneration();
    
    console.log('Updating game HUD...');
    updateGameHUD();
    
    console.log('initializeGameUI completed');
}

// 初始化武器選擇
function initializeWeapons() {
    const weaponsGrid = document.getElementById('weaponsGrid');
    if (!weaponsGrid) return;
    
    weaponsGrid.innerHTML = '';
    
    // 假設玩家解鎖的武器
    const unlockedWeapons = ['cannon_1', 'cannon_2', 'cannon_3', 'cannon_laser'];
    
    unlockedWeapons.forEach(weaponType => {
        const weaponBtn = createWeaponButton(weaponType);
        weaponsGrid.appendChild(weaponBtn);
    });
    
    // 默認選擇第一個武器
    if (unlockedWeapons.length > 0) {
        switchWeapon(unlockedWeapons[0]);
    }
}

// 創建武器按鈕
function createWeaponButton(weaponType) {
    console.log('Creating weapon button for:', weaponType);
    
    const btn = document.createElement('div');
    btn.className = 'weapon-btn';
    btn.dataset.weapon = weaponType;
    
    // 武器圖標 (使用emoji或字符代替)
    const weaponIcons = {
        'cannon_1': '🔫',
        'cannon_2': '💥',
        'cannon_3': '🚀',
        'cannon_laser': '⚡'
    };
    
    const weaponCost = getWeaponCost(weaponType);
    
    btn.innerHTML = `
        ${weaponIcons[weaponType] || '🔫'}
        <div class="weapon-cost">$${weaponCost}</div>
    `;
    
    btn.addEventListener('click', function(e) {
        e.preventDefault();
        console.log('Weapon button clicked:', weaponType);
        switchWeapon(weaponType);
    });
    
    console.log('Weapon button created for:', weaponType, 'with cost:', weaponCost);
    
    return btn;
}

// 初始化技能
function initializeSkills() {
    console.log('Initializing skills...');
    
    const skillsGrid = document.getElementById('skillsGrid');
    if (!skillsGrid) {
        console.error('Skills grid not found');
        return;
    }
    
    skillsGrid.innerHTML = '';
    
    // 基礎技能，所有玩家都可使用
    const unlockedSkills = ['freeze_all', 'double_points', 'auto_aim', 'lightning_strike'];
    
    console.log('Creating skill buttons for:', unlockedSkills);
    
    unlockedSkills.forEach(skillType => {
        const skillBtn = createSkillButton(skillType);
        skillsGrid.appendChild(skillBtn);
    });
    
    console.log('Skills initialization completed');
}

// 創建技能按鈕
function createSkillButton(skillType) {
    console.log('Creating skill button for:', skillType);
    
    const btn = document.createElement('div');
    btn.className = 'skill-btn';
    btn.dataset.skill = skillType;
    
    const skillIcons = {
        'freeze_all': '❄️',
        'double_points': '✨',
        'auto_aim': '🎯',
        'lightning_strike': '⚡'
    };
    
    const skillCost = getSkillCost(skillType);
    
    btn.innerHTML = `
        ${skillIcons[skillType] || '⭐'}
        <div class="skill-cost">$${skillCost}</div>
    `;
    
    btn.addEventListener('click', function(e) {
        e.preventDefault();
        console.log('Skill button clicked:', skillType);
        useSkill(skillType);
    });
    
    console.log('Skill button created for:', skillType, 'with cost:', skillCost);
    
    return btn;
}

// 開始遊戲循環
function startGameLoop() {
    console.log('startGameLoop called');
    
    if (animationFrame) {
        console.log('Cancelling previous animation frame');
        cancelAnimationFrame(animationFrame);
    }
    
    console.log('Canvas element:', canvas);
    console.log('Canvas context:', ctx);
    
    if (!canvas) {
        console.error('Canvas not found, cannot start game loop');
        return;
    }
    
    if (!ctx) {
        console.error('Canvas context not found, cannot start game loop');
        return;
    }
    
    console.log('Starting game loop...');
    gameLoop();
}

// 遊戲循環
function gameLoop() {
    const currentTime = performance.now();
    const deltaTime = currentTime - lastFrameTime;
    lastFrameTime = currentTime;
    
    // 計算FPS
    fps = Math.round(1000 / deltaTime);
    
    // 更新遊戲狀態
    updateGame(deltaTime);
    
    // 渲染遊戲
    renderGame();
    
    // 更新HUD
    updateGameHUD();
    
    if (gameState.inGame) {
        animationFrame = requestAnimationFrame(gameLoop);
    }
}

// 更新遊戲狀態
function updateGame(deltaTime) {
    // 更新魚類
    updateFish(deltaTime);
    
    // 更新子彈
    updateBullets(deltaTime);
    
    // 更新特效
    updateEffects(deltaTime);
    
    // 更新遊戲時間
    updateGameTime();
}

// 更新魚類
function updateFish(deltaTime) {
    const currentTime = Date.now();
    
    Object.keys(gameState.gameData.fish).forEach(fishId => {
        const fish = gameState.gameData.fish[fishId];
        if (!fish) return;
        
        // 清理死魚（移除超時檢查，只清理死魚）
        if (!fish.alive) {
            delete gameState.gameData.fish[fishId];
            return;
        }
        
        // 檢查是否被冰凍
        if (gameState.freezeActive) {
            return; // 冰凍狀態下不更新位置
        }
        
        // 更新位置
        fish.position.x += fish.velocity.x * deltaTime / 16;
        fish.position.y += fish.velocity.y * deltaTime / 16;
        
        // 根據魚的設定處理邊界
        if (fish.canLeaveScreen) {
            // 可以游出螢幕的魚
            const maxDistance = 500; // 螢幕外最大距離
            
            if (fish.position.x > canvas.width + maxDistance || fish.position.x < -maxDistance ||
                fish.position.y > canvas.height + maxDistance || fish.position.y < -maxDistance) {
                // 從另一邊返回
                if (fish.position.x > canvas.width + maxDistance) {
                    fish.position.x = -maxDistance;
                } else if (fish.position.x < -maxDistance) {
                    fish.position.x = canvas.width + maxDistance;
                }
                
                if (fish.position.y > canvas.height + maxDistance) {
                    fish.position.y = -maxDistance;
                } else if (fish.position.y < -maxDistance) {
                    fish.position.y = canvas.height + maxDistance;
                }
            }
        } else {
            // 不能游出螢幕的魚，在邊界附近轉向
            const margin = 50;
            if (fish.position.x < margin && fish.velocity.x < 0) {
                fish.velocity.x = Math.abs(fish.velocity.x);
            }
            if (fish.position.x > canvas.width - margin && fish.velocity.x > 0) {
                fish.velocity.x = -Math.abs(fish.velocity.x);
            }
            if (fish.position.y < margin && fish.velocity.y < 0) {
                fish.velocity.y = Math.abs(fish.velocity.y);
            }
            if (fish.position.y > canvas.height - margin && fish.velocity.y > 0) {
                fish.velocity.y = -Math.abs(fish.velocity.y);
            }
        }
        
        // 隨機改變方向
        if (Math.random() < 0.002) {
            fish.velocity.x = (Math.random() - 0.5) * fish.speed * 2;
            fish.velocity.y = (Math.random() - 0.5) * fish.speed * 2;
        }
    });
}

// 更新子彈
function updateBullets(deltaTime) {
    Object.keys(gameState.gameData.bullets).forEach(bulletId => {
        const bullet = gameState.gameData.bullets[bulletId];
        if (!bullet || !bullet.active) return;
        
        // 更新位置
        bullet.position.x += bullet.velocity.x * deltaTime / 16;
        bullet.position.y += bullet.velocity.y * deltaTime / 16;
        
        // 檢查邊界
        if (bullet.position.x < 0 || bullet.position.x > canvas.width ||
            bullet.position.y < 0 || bullet.position.y > canvas.height) {
            delete gameState.gameData.bullets[bulletId];
        }
        
        // 檢查存在時間
        if (Date.now() - bullet.startTime > 5000) {
            delete gameState.gameData.bullets[bulletId];
        }
    });
}

// 更新特效
function updateEffects(deltaTime) {
    const currentTime = Date.now();
    
    Object.keys(gameState.gameData.effects).forEach(effectId => {
        const effect = gameState.gameData.effects[effectId];
        if (!effect) return;
        
        if (effect.type === 'bullet') {
            // 更新子彈特效位置
            const progress = (currentTime - effect.startTime) / effect.duration;
            if (progress >= 1) {
                delete gameState.gameData.effects[effectId];
                return;
            }
            
            effect.currentPos.x = effect.startPos.x + (effect.targetPos.x - effect.startPos.x) * progress;
            effect.currentPos.y = effect.startPos.y + (effect.targetPos.y - effect.startPos.y) * progress;
        }
        
        // 清理過期特效
        if (currentTime - effect.startTime > effect.duration) {
            delete gameState.gameData.effects[effectId];
        }
    });
}

// 更新遊戲時間
function updateGameTime() {
    if (!gameState.gameData.startTime) return;
    
    const elapsed = Date.now() - gameState.gameData.startTime;
    const minutes = Math.floor(elapsed / 60000);
    const seconds = Math.floor((elapsed % 60000) / 1000);
    
    const timeDisplay = document.getElementById('gameTime');
    if (timeDisplay) {
        timeDisplay.textContent = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
}

// 渲染遊戲
function renderGame() {
    if (!ctx) return;
    
    // 清空畫布
    ctx.fillStyle = 'rgba(0, 20, 40, 0.3)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // 繪製背景效果
    drawBackground();
    
    // 繪製魚類
    drawFish();
    
    // 繪製子彈
    drawBullets();
    
    // 繪製特效
    drawEffects();
    
    // 繪製玩家位置
    drawPlayerPositions();
    
    // 繪製FPS (如果啟用)
    if (gameState.settings.showFPS) {
        drawFPS();
    }
}

// 繪製背景
function drawBackground() {
    // 繪製海洋背景效果
    const gradient = ctx.createRadialGradient(
        canvas.width / 2, canvas.height / 2, 0,
        canvas.width / 2, canvas.height / 2, Math.max(canvas.width, canvas.height)
    );
    gradient.addColorStop(0, 'rgba(0, 100, 150, 0.1)');
    gradient.addColorStop(1, 'rgba(0, 50, 100, 0.3)');
    
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // 繪製氣泡效果
    drawBubbles();
}

// 繪製氣泡
function drawBubbles() {
    const time = Date.now() * 0.001;
    ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
    
    for (let i = 0; i < 20; i++) {
        const x = (Math.sin(time + i) * 100) + (canvas.width / 20) * i;
        const y = (Math.cos(time * 0.5 + i) * 50) + (canvas.height / 10) * (i % 10);
        const radius = 3 + Math.sin(time + i) * 2;
        
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);
        ctx.fill();
    }
}

// 繪製魚類
function drawFish() {
    Object.values(gameState.gameData.fish).forEach(fish => {
        if (!fish || !fish.alive) return;
        
        ctx.save();
        ctx.translate(fish.position.x, fish.position.y);
        
        // 根據魚的移動方向決定是否需要水平翻轉
        const isMovingLeft = fish.velocity && fish.velocity.x < 0;
        if (isMovingLeft) {
            // 水平翻轉
            ctx.scale(-fish.size, fish.size);
        } else {
            ctx.scale(fish.size, fish.size);
        }
        
        // 設置陰影效果
        ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
        ctx.shadowBlur = 5;
        ctx.shadowOffsetX = 2;
        ctx.shadowOffsetY = 2;
        
        // 根據稀有度添加光環效果
        if (fish.rarity === 'rare') {
            ctx.shadowColor = 'rgba(255, 215, 0, 0.6)';
            ctx.shadowBlur = 15;
        } else if (fish.rarity === 'legendary') {
            ctx.shadowColor = 'rgba(128, 0, 128, 0.8)';
            ctx.shadowBlur = 20;
        } else if (fish.rarity === 'mythic') {
            ctx.shadowColor = 'rgba(255, 0, 255, 0.9)';
            ctx.shadowBlur = 25;
        }
        
        // 如果魚有圖片，使用圖片；否則使用emoji或形狀
        if (fish.image) {
            // 確保圖片已加載
            if (!fishImages[fish.image]) {
                fishImages[fish.image] = new Image();
                fishImages[fish.image].src = `images/${fish.image}`; // 修正路徑
                fishImages[fish.image].onload = function() {
                    // 圖片加載完成後會在下一幀繪製
                };
            }
            
            const img = fishImages[fish.image];
            if (img.complete && img.naturalHeight !== 0) {
                // 繪製魚的圖片
                const width = 50; // 基礎寬度
                const height = 50; // 基礎高度
                ctx.drawImage(img, -width/2, -height/2, width, height);
            } else {
                // 圖片還未加載，顯示占位符
                ctx.fillStyle = fish.color ? `rgb(${fish.color.r}, ${fish.color.g}, ${fish.color.b})` : 'blue';
                ctx.beginPath();
                ctx.ellipse(0, 0, 25, 15, 0, 0, Math.PI * 2);
                ctx.fill();
                
                // 魚尾
                ctx.beginPath();
                ctx.moveTo(20, 0);
                ctx.lineTo(35, -10);
                ctx.lineTo(35, 10);
                ctx.closePath();
                ctx.fill();
            }
        } else if (fish.emoji) {
            // 使用emoji
            ctx.font = '30px Arial';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(fish.emoji, 0, 0);
        } else {
            // 使用默認形狀
            ctx.fillStyle = fish.color ? `rgb(${fish.color.r}, ${fish.color.g}, ${fish.color.b})` : 'blue';
            ctx.beginPath();
            ctx.ellipse(0, 0, 25, 15, 0, 0, Math.PI * 2);
            ctx.fill();
            
            // 魚尾
            ctx.beginPath();
            ctx.moveTo(20, 0);
            ctx.lineTo(35, -10);
            ctx.lineTo(35, 10);
            ctx.closePath();
            ctx.fill();
        }
        
        ctx.restore();
        
        // 繪製血條（如果受傷）
        if (fish.health < fish.maxHealth) {
            drawHealthBar(fish);
        }
        
        // 顯示大型魚的倍數
        if (fish.multiplierData) {
            ctx.save();
            ctx.font = 'bold 16px Arial';
            ctx.fillStyle = 'yellow';
            ctx.strokeStyle = 'black';
            ctx.lineWidth = 3;
            ctx.textAlign = 'center';
            
            const multiplierText = `x${fish.multiplierData.currentMultiplier}`;
            const textY = fish.position.y - fish.size * 50;
            
            // 描邊文字
            ctx.strokeText(multiplierText, fish.position.x, textY);
            ctx.fillText(multiplierText, fish.position.x, textY);
            
            // 顯示擊中次數
            ctx.font = '12px Arial';
            ctx.fillStyle = 'white';
            const hitText = `擊中: ${fish.multiplierData.hitCount}`;
            ctx.strokeText(hitText, fish.position.x, textY + 20);
            ctx.fillText(hitText, fish.position.x, textY + 20);
            
            ctx.restore();
        }
        
        // 繪製魚類名稱和分數（調試用）
        if (gameState.settings.showFPS) {
            ctx.save();
            ctx.font = '12px Arial';
            ctx.fillStyle = 'white';
            ctx.textAlign = 'center';
            ctx.fillText(`${fish.name} (${fish.points}分)`, fish.position.x, fish.position.y + fish.size * 40);
            ctx.restore();
        }
    });
}

// 魚類圖片緩存
const fishImages = {};

// 玩家圖片緩存
const playerImages = {};

// 預加載玩家圖片
function preloadPlayerImages() {
    console.log('Preloading player images...');
    
    for (let i = 1; i <= 6; i++) {
        const playerImageName = `player${i.toString().padStart(3, '0')}.png`;
        if (!playerImages[playerImageName]) {
            const img = new Image();
            img.src = `images/${playerImageName}`;
            img.onload = function() {
                console.log('Loaded player image:', playerImageName);
            };
            img.onerror = function() {
                console.error('Failed to load player image:', playerImageName);
            };
            playerImages[playerImageName] = img;
        }
    }
}

// 預加載魚類圖片
function preloadFishImages() {
    console.log('Preloading fish images...');
    
    if (!gameConfig.fishTypes) {
        console.log('No fish types to preload');
        return;
    }
    
    Object.values(gameConfig.fishTypes).forEach(fishData => {
        if (fishData.image && !fishImages[fishData.image]) {
            const img = new Image();
            img.src = `images/${fishData.image}`; // 修正路徑，移除 html/ 前綴
            img.onload = function() {
                console.log('Loaded fish image:', fishData.image);
            };
            img.onerror = function() {
                console.error('Failed to load fish image:', fishData.image);
            };
            fishImages[fishData.image] = img;
        }
    });
}

// 繪製血條
function drawHealthBar(fish) {
    const barWidth = 60;
    const barHeight = 8;
    const x = fish.position.x - barWidth / 2;
    const y = fish.position.y - 40;
    
    // 背景
    ctx.fillStyle = 'rgba(255, 0, 0, 0.3)';
    ctx.fillRect(x, y, barWidth, barHeight);
    
    // 血量
    const healthPercent = fish.health / fish.maxHealth;
    ctx.fillStyle = healthPercent > 0.5 ? 'green' : healthPercent > 0.25 ? 'yellow' : 'red';
    ctx.fillRect(x, y, barWidth * healthPercent, barHeight);
    
    // 邊框
    ctx.strokeStyle = 'white';
    ctx.lineWidth = 1;
    ctx.strokeRect(x, y, barWidth, barHeight);
}

// 繪製子彈
function drawBullets() {
    Object.values(gameState.gameData.bullets).forEach(bullet => {
        if (!bullet || !bullet.active) return;
        
        ctx.save();
        ctx.translate(bullet.position.x, bullet.position.y);
        
        // 繪製子彈
        ctx.fillStyle = `rgb(${bullet.color.r}, ${bullet.color.g}, ${bullet.color.b})`;
        ctx.beginPath();
        ctx.arc(0, 0, bullet.size * 5, 0, Math.PI * 2);
        ctx.fill();
        
        // 繪製發光效果
        const gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, bullet.size * 10);
        gradient.addColorStop(0, `rgba(${bullet.color.r}, ${bullet.color.g}, ${bullet.color.b}, 0.8)`);
        gradient.addColorStop(1, `rgba(${bullet.color.r}, ${bullet.color.g}, ${bullet.color.b}, 0)`);
        
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.arc(0, 0, bullet.size * 10, 0, Math.PI * 2);
        ctx.fill();
        
        ctx.restore();
    });
}

// 繪製特效
function drawEffects() {
    Object.values(gameState.gameData.effects).forEach(effect => {
        if (!effect) return;
        
        switch(effect.type) {
            case 'bullet':
                drawBulletTrail(effect);
                break;
            case 'explosion':
                drawExplosion(effect);
                break;
            case 'lightning':
                drawLightning(effect);
                break;
            case 'lightning_strike':
                drawLightningStrike(effect);
                break;
            case 'electric':
                drawElectricEffect(effect);
                break;
            case 'damage':
                drawDamageEffect(effect);
                break;
            case 'damageNumber':
                drawDamageNumber(effect);
                break;
            case 'reward':
                drawRewardEffect(effect);
                break;
        }
    });
}

// 繪製子彈軌跡
function drawBulletTrail(effect) {
    const progress = (Date.now() - effect.startTime) / effect.duration;
    const alpha = Math.max(0, 1 - progress);
    
    // 計算子彈當前位置（從起點到終點的動畫）
    const currentX = effect.startPos.x + (effect.targetPos.x - effect.startPos.x) * progress;
    const currentY = effect.startPos.y + (effect.targetPos.y - effect.startPos.y) * progress;
    
    // 使用武器特定的顏色和粗度
    ctx.strokeStyle = effect.color ? effect.color.replace(/[\d\.]+\)$/g, `${alpha})`) : `rgba(255, 255, 100, ${alpha})`;
    ctx.lineWidth = effect.width || 3;
    
    // 雷射武器添加發光效果
    if (effect.weapon === 'cannon_laser') {
        ctx.shadowColor = 'rgba(255, 0, 255, 0.8)';
        ctx.shadowBlur = 15;
    } else {
        ctx.shadowBlur = 0;
    }
    
    // 繪製子彈軌跡
    ctx.beginPath();
    ctx.moveTo(effect.startPos.x, effect.startPos.y);
    ctx.lineTo(currentX, currentY);
    ctx.stroke();
    
    // 如果是其他玩家的射擊，添加玩家名稱標記
    if (effect.playerPosition === -1 && effect.playerName) {
        ctx.save();
        ctx.fillStyle = `rgba(255, 255, 255, ${alpha * 0.8})`;
        ctx.font = '12px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(effect.playerName, effect.startPos.x, effect.startPos.y - 20);
        ctx.restore();
    }
    
    // 重置陰影
    ctx.shadowBlur = 0;
    
    // 更新子彈當前位置
    effect.currentPos.x = currentX;
    effect.currentPos.y = currentY;
}

// 繪製爆炸特效
function drawExplosion(effect) {
    const progress = (Date.now() - effect.startTime) / effect.duration;
    const radius = effect.radius * progress;
    const alpha = Math.max(0, 1 - progress);
    
    // 爆炸圓圈
    const gradient = ctx.createRadialGradient(
        effect.position.x, effect.position.y, 0,
        effect.position.x, effect.position.y, radius
    );
    gradient.addColorStop(0, `rgba(255, 100, 0, ${alpha})`);
    gradient.addColorStop(0.5, `rgba(255, 200, 0, ${alpha * 0.5})`);
    gradient.addColorStop(1, `rgba(255, 255, 0, 0)`);
    
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(effect.position.x, effect.position.y, radius, 0, Math.PI * 2);
    ctx.fill();
}

// 繪製閃電特效
function drawLightning(effect) {
    const progress = (Date.now() - effect.startTime) / effect.duration;
    const alpha = Math.max(0, 1 - progress);
    
    ctx.strokeStyle = `rgba(255, 255, 0, ${alpha})`;
    ctx.lineWidth = 5;
    ctx.shadowColor = 'yellow';
    ctx.shadowBlur = 10;
    
    // 繪製閃電線條
    ctx.beginPath();
    ctx.moveTo(effect.position.x - 200, effect.position.y);
    ctx.lineTo(effect.position.x + 200, effect.position.y);
    ctx.moveTo(effect.position.x, effect.position.y - 200);
    ctx.lineTo(effect.position.x, effect.position.y + 200);
    ctx.stroke();
    
    ctx.shadowBlur = 0;
}

// 繪製雷電打擊範圍特效
function drawLightningStrike(effect) {
    const progress = (Date.now() - effect.startTime) / effect.duration;
    const alpha = Math.max(0, 1 - progress);
    
    // 繪製範圍圓圈
    ctx.save();
    ctx.strokeStyle = `rgba(255, 255, 0, ${alpha * 0.8})`;
    ctx.lineWidth = 4;
    ctx.shadowColor = 'yellow';
    ctx.shadowBlur = 20;
    
    ctx.beginPath();
    ctx.arc(effect.position.x, effect.position.y, effect.radius, 0, Math.PI * 2);
    ctx.stroke();
    
    // 繪製內部閃電效果
    ctx.fillStyle = `rgba(255, 255, 0, ${alpha * 0.1})`;
    ctx.fill();
    
    // 繪製雷電紋路
    for (let i = 0; i < 8; i++) {
        const angle = (i / 8) * Math.PI * 2;
        const startX = effect.position.x + Math.cos(angle) * 20;
        const startY = effect.position.y + Math.sin(angle) * 20;
        const endX = effect.position.x + Math.cos(angle) * effect.radius;
        const endY = effect.position.y + Math.sin(angle) * effect.radius;
        
        ctx.strokeStyle = `rgba(255, 255, 255, ${alpha * 0.6})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(startX, startY);
        ctx.lineTo(endX, endY);
        ctx.stroke();
    }
    
    ctx.restore();
}

// 繪製電擊特效
function drawElectricEffect(effect) {
    const progress = (Date.now() - effect.startTime) / effect.duration;
    const alpha = Math.max(0, 1 - progress);
    
    ctx.save();
    ctx.strokeStyle = `rgba(255, 255, 0, ${alpha})`;
    ctx.lineWidth = 3;
    ctx.shadowColor = 'yellow';
    ctx.shadowBlur = 10;
    
    // 繪製電火花
    for (let i = 0; i < 5; i++) {
        const angle = Math.random() * Math.PI * 2;
        const length = 20 + Math.random() * 20;
        const startX = effect.position.x;
        const startY = effect.position.y;
        const endX = startX + Math.cos(angle) * length;
        const endY = startY + Math.sin(angle) * length;
        
        ctx.beginPath();
        ctx.moveTo(startX, startY);
        ctx.lineTo(endX, endY);
        ctx.stroke();
    }
    
    ctx.restore();
}

// 繪製傷害特效
function drawDamageEffect(effect) {
    const progress = (Date.now() - effect.startTime) / effect.duration;
    const alpha = Math.max(0, 1 - progress);
    
    ctx.save();
    ctx.fillStyle = `rgba(255, 0, 0, ${alpha})`;
    ctx.font = 'bold 20px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    
    // 向上浮動的傷害數字
    const offsetY = progress * 30;
    ctx.fillText('傷害!', effect.position.x, effect.position.y - offsetY);
    
    ctx.restore();
}

// 繪製傷害數字特效
function drawDamageNumber(effect) {
    const progress = (Date.now() - effect.startTime) / effect.duration;
    const alpha = Math.max(0, 1 - progress);
    
    ctx.save();
    ctx.fillStyle = `rgba(255, 255, 0, ${alpha})`;
    ctx.font = 'bold 24px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.shadowColor = 'rgba(255, 0, 0, 0.8)';
    ctx.shadowBlur = 5;
    
    // 向上浮動的傷害數字
    const offsetY = progress * 50;
    const offsetX = (Math.random() - 0.5) * 20;
    ctx.fillText(`-${effect.damage}`, effect.position.x + offsetX, effect.position.y - offsetY);
    
    // 顯示攻擊者名稱
    if (effect.attacker) {
        ctx.font = '14px Arial';
        ctx.fillStyle = `rgba(255, 255, 255, ${alpha * 0.8})`;
        ctx.fillText(effect.attacker, effect.position.x + offsetX, effect.position.y - offsetY + 25);
    }
    
    ctx.restore();
}

// 繪製獎勵特效
function drawRewardEffect(effect) {
    const progress = (Date.now() - effect.startTime) / effect.duration;
    const alpha = Math.max(0, 1 - progress);
    
    ctx.save();
    
    // 背景光暈
    const gradient = ctx.createRadialGradient(
        effect.position.x, effect.position.y, 0,
        effect.position.x, effect.position.y, 200
    );
    gradient.addColorStop(0, `rgba(255, 215, 0, ${alpha * 0.3})`);
    gradient.addColorStop(1, `rgba(255, 215, 0, 0)`);
    
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // 主要獎勵文字
    ctx.fillStyle = `rgba(255, 215, 0, ${alpha})`;
    ctx.font = 'bold 32px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.shadowColor = 'rgba(0, 0, 0, 0.8)';
    ctx.shadowBlur = 10;
    
    const centerY = effect.position.y - 50;
    ctx.fillText(`🎣 捕獲 ${effect.fishName}！`, effect.position.x, centerY);
    
    // 分數和金幣
    ctx.font = 'bold 24px Arial';
    ctx.fillStyle = `rgba(0, 255, 0, ${alpha})`;
    ctx.fillText(`+${effect.points} 分`, effect.position.x, centerY + 40);
    
    ctx.fillStyle = `rgba(255, 215, 0, ${alpha})`;
    ctx.fillText(`+${effect.coins} 金幣`, effect.position.x, centerY + 70);
    
    // 最後一擊標記
    if (effect.isFinalBlow) {
        ctx.fillStyle = `rgba(255, 0, 0, ${alpha})`;
        ctx.font = 'bold 20px Arial';
        ctx.fillText('🏆 最後一擊！', effect.position.x, centerY + 100);
    }
    
    // 協作獎勵標記
    if (effect.contributors > 1) {
        ctx.fillStyle = `rgba(0, 255, 255, ${alpha})`;
        ctx.font = 'bold 18px Arial';
        ctx.fillText(`👥 協作獎勵 (${effect.contributors} 人參與)`, effect.position.x, centerY + 130);
    }
    
    ctx.restore();
}

// 繪製玩家位置
function drawPlayerPositions() {
    const positions = [
        { x: canvas.width * 0.15, y: canvas.height - 80 }, // 位置1: 左側
        { x: canvas.width * 0.30, y: canvas.height - 80 }, // 位置2: 左中
        { x: canvas.width * 0.45, y: canvas.height - 80 }, // 位置3: 中左
        { x: canvas.width * 0.55, y: canvas.height - 80 }, // 位置4: 中右
        { x: canvas.width * 0.70, y: canvas.height - 80 }, // 位置5: 右中
        { x: canvas.width * 0.85, y: canvas.height - 80 }  // 位置6: 右側
    ];
    
    positions.forEach((pos, index) => {
        ctx.save();
        
        // 繪製玩家位置標記
        const isCurrentPlayer = index === gameState.playerPosition;
        const isOccupied = index < 3; // 假設前3個位置被佔用（可以從房間狀態獲取）
        // TODO: 從房間狀態獲取實際的玩家位置信息
        
        // 獲取玩家圖片
        const playerImageName = `player${(index + 1).toString().padStart(3, '0')}.png`;
        const playerImg = playerImages[playerImageName];
        
        if (playerImg && playerImg.complete && playerImg.naturalHeight !== 0) {
            // 使用玩家圖片
            const imgSize = isCurrentPlayer ? 60 : 50; // 當前玩家圖片稍大
            
            // 設置圖片透明度和效果
            if (isCurrentPlayer) {
                ctx.globalAlpha = 1.0;
                // 當前玩家添加發光效果
                ctx.shadowColor = 'rgba(0, 255, 0, 0.8)';
                ctx.shadowBlur = 20;
            } else if (isOccupied) {
                ctx.globalAlpha = 0.8;
                ctx.shadowColor = 'rgba(255, 255, 255, 0.5)';
                ctx.shadowBlur = 10;
            } else {
                ctx.globalAlpha = 0.4;
                ctx.shadowColor = 'rgba(100, 100, 100, 0.3)';
                ctx.shadowBlur = 5;
            }
            
            // 繪製玩家圖片
            ctx.drawImage(playerImg, pos.x - imgSize/2, pos.y - imgSize/2, imgSize, imgSize);
            
            // 如果是當前玩家，添加額外的邊框效果
            if (isCurrentPlayer) {
                ctx.globalAlpha = 1.0;
                ctx.strokeStyle = 'rgba(0, 255, 0, 1.0)';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(pos.x, pos.y, imgSize/2 + 5, 0, Math.PI * 2);
                ctx.stroke();
                
                // 添加"你"的標記
                ctx.fillStyle = 'rgba(0, 255, 0, 1.0)';
                ctx.font = 'bold 14px Arial';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.shadowColor = 'rgba(0, 0, 0, 0.8)';
                ctx.shadowBlur = 3;
                ctx.fillText('你', pos.x, pos.y + imgSize/2 + 20);
            }
        } else {
            // 圖片未加載完成，使用原來的圓形標記作為備用
            if (isCurrentPlayer) {
                ctx.fillStyle = 'rgba(0, 255, 0, 0.8)';
                ctx.strokeStyle = 'rgba(0, 255, 0, 1.0)';
                ctx.lineWidth = 3;
            } else if (isOccupied) {
                ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
                ctx.lineWidth = 2;
            } else {
                ctx.fillStyle = 'rgba(100, 100, 100, 0.3)';
                ctx.strokeStyle = 'rgba(100, 100, 100, 0.5)';
                ctx.lineWidth = 1;
            }
            
            // 繪製圓形標記
            ctx.beginPath();
            ctx.arc(pos.x, pos.y, 15, 0, Math.PI * 2);
            ctx.fill();
            ctx.stroke();
            
            // 繪製玩家編號
            ctx.fillStyle = isCurrentPlayer ? 'rgba(0, 0, 0, 0.8)' : 'rgba(255, 255, 255, 0.8)';
            ctx.font = 'bold 14px Arial';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText((index + 1).toString(), pos.x, pos.y);
            
            // 如果是當前玩家，添加額外標記
            if (isCurrentPlayer) {
                ctx.strokeStyle = 'rgba(0, 255, 0, 1.0)';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(pos.x, pos.y, 25, 0, Math.PI * 2);
                ctx.stroke();
                
                // 添加"你"的標記
                ctx.fillStyle = 'rgba(0, 255, 0, 1.0)';
                ctx.font = 'bold 12px Arial';
                ctx.fillText('你', pos.x, pos.y + 35);
            }
        }
        
        // 重置陰影和透明度
        ctx.shadowColor = 'transparent';
        ctx.shadowBlur = 0;
        ctx.globalAlpha = 1.0;
        
        ctx.restore();
    });
}

// 繪製FPS
function drawFPS() {
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    ctx.fillRect(10, 10, 80, 30);
    
    ctx.fillStyle = 'white';
    ctx.font = '16px Arial';
    ctx.fillText(`FPS: ${fps}`, 15, 30);
}

// 更新遊戲HUD
function updateGameHUD() {
    // 更新分數
    const scoreElement = document.getElementById('gameScore');
    if (scoreElement) scoreElement.textContent = formatNumber(gameState.gameData.score);
    
    // 更新金幣
    const coinsElement = document.getElementById('gameCoins');
    if (coinsElement) coinsElement.textContent = formatNumber(gameState.gameData.coins);
    
    // 更新捕魚數
    const fishCaughtElement = document.getElementById('fishCaught');
    if (fishCaughtElement) fishCaughtElement.textContent = gameState.gameData.fishCaught;
}

// 離開遊戲
function leaveGame() {
    fetch(`https://${GetParentResourceName()}/ui_action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: 'close',
            data: {}
        })
    });
}

// 隱藏遊戲界面
function hideGameUI() {
    gameState.inGame = false;
    gameState.currentScreen = null;
    
    if (animationFrame) {
        cancelAnimationFrame(animationFrame);
        animationFrame = null;
    }
    
    document.getElementById('gameUI').style.display = 'none';
    document.getElementById('crosshair').style.display = 'none';
}

// 隱藏所有界面
function hideAllScreens() {
    document.querySelectorAll('.screen').forEach(screen => {
        screen.style.display = 'none';
    });
    
    document.querySelectorAll('.modal').forEach(modal => {
        modal.style.display = 'none';
    });
}

// 顯示通知
function showNotification(message, type = 'info', duration = 3000) {
    const container = document.getElementById('notificationContainer');
    if (!container) return;
    
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    container.appendChild(notification);
    
    setTimeout(() => {
        notification.style.opacity = '0';
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, duration);
}

// 顯示設定界面
function showSettings() {
    document.getElementById('settingsModal').style.display = 'flex';
    loadSettingsToUI();
}

// 關閉設定界面
function closeSettings() {
    document.getElementById('settingsModal').style.display = 'none';
}

// 載入設定到UI
function loadSettingsToUI() {
    Object.keys(gameState.settings).forEach(key => {
        const element = document.getElementById(key);
        if (element) {
            if (element.type === 'checkbox') {
                element.checked = gameState.settings[key];
            } else if (element.type === 'range' || element.type === 'number') {
                element.value = gameState.settings[key];
                
                // 更新顯示值
                const valueSpan = document.getElementById(key + 'Value');
                if (valueSpan) {
                    valueSpan.textContent = element.value + (element.type === 'range' ? '%' : '');
                }
            } else if (element.tagName === 'SELECT') {
                element.value = gameState.settings[key];
            }
        }
    });
}

// 保存設定
function saveSettings() {
    // 從UI讀取設定值
    Object.keys(gameState.settings).forEach(key => {
        const element = document.getElementById(key);
        if (element) {
            if (element.type === 'checkbox') {
                gameState.settings[key] = element.checked;
            } else if (element.type === 'range' || element.type === 'number') {
                gameState.settings[key] = parseInt(element.value);
            } else if (element.tagName === 'SELECT') {
                gameState.settings[key] = element.value;
            }
        }
    });
    
    // 保存到本地存儲
    localStorage.setItem('fishgame_settings', JSON.stringify(gameState.settings));
    
    // 發送到服務器
    fetch(`https://${GetParentResourceName()}/ui_action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: 'save_settings',
            data: { settings: gameState.settings }
        })
    });
    
    closeSettings();
    showNotification('設定已保存', 'success');
}

// 重置設定
function resetSettings() {
    gameState.settings = {
        masterVolume: 50,
        sfxVolume: 70,
        musicVolume: 30,
        autoAim: false,
        showFPS: false,
        particleQuality: 'medium'
    };
    
    loadSettingsToUI();
    showNotification('設定已重置', 'info');
}

// 載入遊戲設定
function loadGameSettings() {
    const saved = localStorage.getItem('fishgame_settings');
    if (saved) {
        try {
            gameState.settings = { ...gameState.settings, ...JSON.parse(saved) };
        } catch (e) {
            console.warn('載入設定失敗:', e);
        }
    }
}

// 顯示排行榜
function showLeaderboard() {
    document.getElementById('leaderboardModal').style.display = 'flex';
    
    // 顯示載入動畫
    const leaderboardContent = document.getElementById('leaderboardContent');
    if (leaderboardContent) {
        leaderboardContent.innerHTML = `
            <div class="leaderboard-loading">
                <div class="spinner"></div>
                <div>載入排行榜中...</div>
            </div>
        `;
    }
    
    // 預設顯示今日排行榜
    showLeaderboardTab('daily');
}

// 顯示特定期間的排行榜
function showLeaderboardTab(period) {
    // 更新標籤按鈕狀態
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    const activeTab = document.querySelector(`.tab-btn[onclick*="${period}"]`);
    if (activeTab) {
        activeTab.classList.add('active');
    }
    
    // 發送請求獲取排行榜數據
    fetch(`https://${GetParentResourceName()}/ui_action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: 'navigate',
            data: { 
                screen: 'leaderboard',
                period: period
            }
        })
    }).then(() => {
        console.log('Leaderboard request sent for period:', period);
    }).catch(error => {
        console.error('Failed to request leaderboard:', error);
        showLeaderboardError();
    });
}

// 更新排行榜內容
function updateLeaderboardContent(data) {
    const leaderboardContent = document.getElementById('leaderboardContent');
    if (!leaderboardContent) return;
    
    if (data.error) {
        showLeaderboardError(data.error);
        return;
    }
    
    if (!data.data || data.data.length === 0) {
        leaderboardContent.innerHTML = `
            <div style="text-align: center; padding: 50px; opacity: 0.7;">
                <p>暫無排行榜數據</p>
            </div>
        `;
        return;
    }
    
    let html = '';
    data.data.forEach((player, index) => {
        const rankClass = index === 0 ? 'first' : index === 1 ? 'second' : index === 2 ? 'third' : '';
        const rankIcon = index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : '';
        
        html += `
            <div class="leaderboard-item">
                <div class="rank ${rankClass}">${rankIcon || player.rank}</div>
                <div class="player-info-leaderboard">
                    <div>
                        <div class="player-name-leaderboard">${player.name}</div>
                        <div style="font-size: 12px; opacity: 0.7;">等級 ${player.level}</div>
                    </div>
                    <div class="player-stats">
                        <div class="stat-item">
                            <div class="stat-label">積分</div>
                            <div class="stat-value">${formatNumber(player.score)}</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-label">金幣</div>
                            <div class="stat-value">${formatNumber(player.coins)}</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-label">捕魚</div>
                            <div class="stat-value">${formatNumber(player.fishCaught)}</div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    });
    
    leaderboardContent.innerHTML = html;
}

// 顯示排行榜錯誤
function showLeaderboardError(message = '無法載入排行榜') {
    const leaderboardContent = document.getElementById('leaderboardContent');
    if (leaderboardContent) {
        leaderboardContent.innerHTML = `
            <div style="text-align: center; padding: 50px; opacity: 0.7;">
                <p style="color: #ff6b6b;">${message}</p>
            </div>
        `;
    }
}

// 關閉排行榜
function closeLeaderboard() {
    document.getElementById('leaderboardModal').style.display = 'none';
}

// 顯示統計資料
function showStatistics() {
    document.getElementById('statisticsModal').style.display = 'flex';
    
    // 顯示載入動畫
    const statsGrid = document.getElementById('statsGrid');
    if (statsGrid) {
        statsGrid.innerHTML = `
            <div class="leaderboard-loading" style="grid-column: 1 / -1;">
                <div class="spinner"></div>
                <div>載入統計資料中...</div>
            </div>
        `;
    }
    
    // 發送請求獲取統計資料
    fetch(`https://${GetParentResourceName()}/ui_action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: 'navigate',
            data: { 
                screen: 'statistics'
            }
        })
    }).then(() => {
        console.log('Statistics request sent');
    }).catch(error => {
        console.error('Failed to request statistics:', error);
        updateStatisticsContent({ error: '無法載入統計資料' });
    });
}

// 關閉統計資料
function closeStatistics() {
    document.getElementById('statisticsModal').style.display = 'none';
}

// 格式化數字
function formatNumber(num) {
    if (num >= 1000000) {
        return (num / 1000000).toFixed(1) + 'M';
    } else if (num >= 1000) {
        return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
}

// 處理來自客戶端的消息
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.type) {
        case 'showMainMenu':
            showMainMenu(data);
            break;
            
        case 'hideMainMenu':
            hideMainMenu();
            break;
            
        case 'showGameUI':
            showGameUI(data);
            break;
            
        case 'hideGameUI':
            hideGameUI();
            break;
            
        case 'updateGameConfig':
            console.log('Received game config:', data.config);
            if (data.config) {
                gameConfig = data.config;
                // 收到配置後預加載圖片
                preloadFishImages();
                preloadPlayerImages();
            }
            break;
            
        case 'updateRoomList':
            console.log('Received room list update:', data.rooms);
            updateRoomList(data.rooms);
            // 重新設置按鈕事件以防DOM改變
            setTimeout(() => {
                setupButtonEvents();
            }, 50);
            break;
            
        case 'fishCaughtByMe':
            handleFishCaught(data.fishData, true);
            break;
            
        case 'otherPlayerCaughtFish':
            handleFishCaught(data.fishData, false);
            break;
            
        case 'show_level_up':
            showLevelUpEffect(data.newLevel);
            break;
            
        case 'roomStateUpdate':
            updateRoomState(data.roomState);
            break;
            
        case 'skillActivated':
            handleSkillActivated(data.skillData);
            break;
            
        case 'leaderboard_updated':
            updateLeaderboardContent(data);
            break;
            
        case 'statistics_updated':
            updateStatisticsContent(data.data);
            break;
    }
});

// 確保NUI準備就緒
document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM Content Loaded - Initializing Fish Game UI');
    
    // 發送NUI準備就緒信號
    sendNUIMessage('nuiReady')
        .then(data => {
            console.log('NUI ready signal sent successfully');
        })
        .catch(error => {
            // 如果在瀏覽器中測試，忽略錯誤
            console.log('NUI ready signal failed (might be running in browser):', error);
        });
    
    // 確保按鈕事件綁定
    setupButtonEvents();
});

// 設置按鈕事件
function setupButtonEvents() {
    console.log('Setting up button events');
    
    // 設置關閉按鈕事件
    const closeBtn = document.getElementById('closeBtn');
    if (closeBtn) {
        // 移除可能已存在的事件監聽器
        closeBtn.replaceWith(closeBtn.cloneNode(true));
        const newCloseBtn = document.getElementById('closeBtn');
        newCloseBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Close button clicked');
            closeMainMenu();
        });
    } else {
        console.error('Close button not found');
    }
    
    // 設置加入遊戲按鈕事件
    const joinBtn = document.getElementById('joinGameBtn');
    if (joinBtn) {
        // 移除可能已存在的事件監聽器
        joinBtn.replaceWith(joinBtn.cloneNode(true));
        const newJoinBtn = document.getElementById('joinGameBtn');
        newJoinBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Join game button clicked');
            joinSelectedRoom();
        });
    } else {
        console.error('Join game button not found');
    }
    
    // 設置其他按鈕事件
    setupMenuButtons();
}

// 設置選單按鈕事件
function setupMenuButtons() {
    console.log('Setting up menu buttons');
    
    // 設置排行榜按鈕
    const leaderboardBtn = document.getElementById('leaderboardBtn');
    if (leaderboardBtn) {
        leaderboardBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Leaderboard button clicked');
            showLeaderboard();
        });
    } else {
        console.error('Leaderboard button not found');
    }
    
    // 設置統計資料按鈕
    const statsBtn = document.getElementById('statisticsBtn');
    if (statsBtn) {
        statsBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Statistics button clicked');
            showStatistics();
        });
    } else {
        console.error('Statistics button not found');
    }
    
    // 設置設定按鈕
    const settingsBtn = document.getElementById('settingsBtn');
    if (settingsBtn) {
        settingsBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Settings button clicked');
            showSettings();
        });
    } else {
        console.error('Settings button not found');
    }
    
    // 設置下注金額按鈕
    const betButtons = document.querySelectorAll('.bet-buttons button[data-bet-amount]');
    console.log('Found bet buttons:', betButtons.length);
    betButtons.forEach(btn => {
        const amount = btn.getAttribute('data-bet-amount');
        if (amount) {
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                console.log('Bet amount button clicked:', amount);
                setBetAmount(parseInt(amount));
            });
        }
    });
}

// 處理捕魚事件
function handleFishCaught(fishData, isMyFish) {
    if (isMyFish) {
        gameState.gameData.score += fishData.points;
        gameState.gameData.coins += fishData.coinReward;
        gameState.gameData.fishCaught++;
        
        playSound('catch');
        showFishCaughtEffect(fishData);
    } else {
        // 其他玩家捕魚的視覺效果
        playSound('hit');
    }
    
    updateGameHUD();
}

// 顯示捕魚特效
function showFishCaughtEffect(fishData) {
    const effect = document.getElementById('fishCaughtEffect');
    if (!effect) return;
    
    document.getElementById('caughtFishName').textContent = fishData.fishName;
    document.getElementById('caughtFishPoints').textContent = `+${fishData.points} 分`;
    document.getElementById('caughtFishCoins').textContent = `+$${fishData.coinReward}`;
    
    effect.style.display = 'flex';
    
    setTimeout(() => {
        effect.style.display = 'none';
    }, 2000);
}

// 顯示等級提升特效
function showLevelUpEffect(newLevel) {
    const effect = document.getElementById('levelUpEffect');
    if (!effect) return;
    
    document.getElementById('newLevelNumber').textContent = newLevel;
    
    effect.style.display = 'flex';
    
    setTimeout(() => {
        effect.style.display = 'none';
    }, 3000);
}

// 更新房間狀態
function updateRoomState(roomState) {
    if (roomState.fish) {
        gameState.gameData.fish = roomState.fish;
    }
    
    if (roomState.bullets) {
        gameState.gameData.bullets = roomState.bullets;
    }
    
    if (roomState.effects) {
        gameState.gameData.effects = roomState.effects;
    }
    
    // 更新玩家列表
    if (roomState.players) {
        updatePlayersList(roomState.players);
    }
}

// 更新玩家列表
function updatePlayersList(players) {
    const playersList = document.getElementById('playersList');
    if (!playersList) return;
    
    playersList.innerHTML = '';
    
    Object.values(players).forEach(player => {
        const playerItem = document.createElement('div');
        playerItem.className = 'player-item';
        playerItem.innerHTML = `
            <div class="player-name">${player.playerName}</div>
            <div class="player-score">${formatNumber(player.score)}</div>
        `;
        playersList.appendChild(playerItem);
    });
}

// 處理技能激活
function handleSkillActivated(skillData) {
    console.log('Skill activated:', skillData);
    
    // 播放技能音效
    playSound('special');
    
    // 顯示技能激活特效
    showSkillActivationEffect(skillData);
    
    // 根據技能類型應用視覺效果
    switch(skillData.skillType) {
        case 'freeze_all':
            applyFreezeEffect(skillData.duration);
            break;
        case 'double_points':
            applyDoublePointsEffect(skillData.duration);
            break;
        case 'auto_aim':
            applyAutoAimEffect(skillData.duration);
            break;
        case 'lightning_strike':
            applyLightningStrikeEffect();
            break;
    }
}

// 顯示技能激活特效
function showSkillActivationEffect(skillData) {
    const effectContainer = document.getElementById('gameUI');
    if (!effectContainer) return;
    
    const effect = document.createElement('div');
    effect.className = 'skill-activation-effect';
    effect.innerHTML = `
        <div class="skill-name">${skillData.skillName}</div>
        <div class="skill-duration">持續 ${Math.round(skillData.duration / 1000)}秒</div>
    `;
    
    effect.style.cssText = `
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: linear-gradient(45deg, #ff6b6b, #feca57);
        color: white;
        padding: 20px 30px;
        border-radius: 15px;
        font-size: 24px;
        font-weight: bold;
        text-align: center;
        box-shadow: 0 0 30px rgba(255, 107, 107, 0.5);
        animation: skillActivation 2s ease-out forwards;
        z-index: 1000;
    `;
    
    effectContainer.appendChild(effect);
    
    // 2秒後移除特效
    setTimeout(() => {
        if (effect.parentNode) {
            effect.parentNode.removeChild(effect);
        }
    }, 2000);
}

// 應用冰凍效果
function applyFreezeEffect(duration) {
    console.log('Applying freeze effect for', duration, 'ms');
    
    // 激活冰凍效果
    gameState.freezeActive = true;
    
    // 添加冰凍視覺效果
    const gameUI = document.getElementById('gameUI');
    if (gameUI) {
        gameUI.classList.add('frozen-effect');
    }
    
    // 顯示冰凍通知
    showNotification('所有魚類已被冰凍！', 'success');
    
    setTimeout(() => {
        gameState.freezeActive = false;
        if (gameUI) {
            gameUI.classList.remove('frozen-effect');
        }
        showNotification('冰凍效果已結束', 'info');
    }, duration);
}

// 應用雙倍積分效果
function applyDoublePointsEffect(duration) {
    console.log('Applying double points effect for', duration, 'ms');
    
    // 激活雙倍積分
    gameState.doublePointsActive = true;
    
    // 添加雙倍積分視覺提示
    const scoreElement = document.getElementById('gameScore');
    if (scoreElement) {
        scoreElement.classList.add('double-points-effect');
    }
    
    // 顯示雙倍積分通知
    showNotification('雙倍積分已激活！', 'success');
    
    setTimeout(() => {
        gameState.doublePointsActive = false;
        if (scoreElement) {
            scoreElement.classList.remove('double-points-effect');
        }
        showNotification('雙倍積分已結束', 'info');
    }, duration);
}

// 應用自動瞄準效果
function applyAutoAimEffect(duration) {
    console.log('Applying auto aim effect for', duration, 'ms');
    
    // 激活自動瞄準
    gameState.autoAimActive = true;
    
    // 添加自動瞄準視覺提示
    const crosshair = document.getElementById('crosshair');
    if (crosshair) {
        crosshair.classList.add('auto-aim-effect');
    }
    
    // 顯示自動瞄準通知
    showNotification('自動瞄準已激活', 'success');
    
    setTimeout(() => {
        gameState.autoAimActive = false;
        if (crosshair) {
            crosshair.classList.remove('auto-aim-effect');
        }
        showNotification('自動瞄準已停用', 'info');
    }, duration);
}

// 應用閃電打擊效果
function applyLightningStrikeEffect() {
    console.log('Applying lightning strike effect');
    
    // 創建全屏閃電效果
    const lightningEffect = document.createElement('div');
    lightningEffect.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: radial-gradient(circle, rgba(255,255,0,0.3) 0%, transparent 70%);
        pointer-events: none;
        z-index: 999;
        animation: lightningFlash 0.5s ease-out;
    `;
    
    document.body.appendChild(lightningEffect);
    
    setTimeout(() => {
        if (lightningEffect.parentNode) {
            lightningEffect.parentNode.removeChild(lightningEffect);
        }
    }, 500);
}

// 魚類生成系統
function startFishGeneration() {
    console.log('Starting fish generation system');
    
    // 立即生成一些魚
    generateInitialFish();
    
    // 定期生成新魚
    setInterval(() => {
        if (gameState.inGame && Object.keys(gameState.gameData.fish).length < 15) {
            generateRandomFish();
        }
    }, 3000); // 每3秒生成一條魚
}

// 生成初始魚群
function generateInitialFish() {
    console.log('Generating initial fish');
    
    const fishCount = 8; // 初始生成8條魚
    for (let i = 0; i < fishCount; i++) {
        generateRandomFish();
    }
}

// 生成隨機魚類
function generateRandomFish() {
    if (!canvas || !gameConfig.fishTypes) return;
    
    // 從配置中獲取所有魚類類型
    const fishTypeKeys = Object.keys(gameConfig.fishTypes);
    if (fishTypeKeys.length === 0) {
        console.log('No fish types available in config');
        return;
    }
    
    // 根據稀有度權重選擇魚類
    const rarityWeights = {
        common: 60,
        uncommon: 25,
        special: 10,
        rare: 4,
        legendary: 0.8,
        mythic: 0.2
    };
    
    // 計算總權重
    let totalWeight = 0;
    const weightedFishTypes = [];
    
    fishTypeKeys.forEach(fishTypeKey => {
        const fishData = gameConfig.fishTypes[fishTypeKey];
        const weight = rarityWeights[fishData.rarity] || 1;
        totalWeight += weight;
        weightedFishTypes.push({
            key: fishTypeKey,
            weight: totalWeight,
            data: fishData
        });
    });
    
    // 根據權重隨機選擇
    const random = Math.random() * totalWeight;
    let selectedFishType = null;
    
    for (const weightedFish of weightedFishTypes) {
        if (random <= weightedFish.weight) {
            selectedFishType = weightedFish;
            break;
        }
    }
    
    if (!selectedFishType) {
        console.log('Failed to select fish type');
        return;
    }
    
    const fishData = selectedFishType.data;
    const fishId = 'fish_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    
    // 隨機生成位置（從屏幕邊緣進入）
    const side = Math.floor(Math.random() * 4); // 0:上, 1:右, 2:下, 3:左
    let x, y, vx, vy;
    
    const spawnDistance = 100; // 在螢幕外生成的距離
    
    switch (side) {
        case 0: // 從上方進入
            x = Math.random() * canvas.width;
            y = -spawnDistance;
            vx = (Math.random() - 0.5) * fishData.speed;
            vy = Math.random() * fishData.speed + 0.5;
            break;
        case 1: // 從右側進入
            x = canvas.width + spawnDistance;
            y = Math.random() * canvas.height;
            vx = -Math.random() * fishData.speed - 0.5;
            vy = (Math.random() - 0.5) * fishData.speed;
            break;
        case 2: // 從下方進入
            x = Math.random() * canvas.width;
            y = canvas.height + spawnDistance;
            vx = (Math.random() - 0.5) * fishData.speed;
            vy = -Math.random() * fishData.speed - 0.5;
            break;
        case 3: // 從左側進入
            x = -spawnDistance;
            y = Math.random() * canvas.height;
            vx = Math.random() * fishData.speed + 0.5;
            vy = (Math.random() - 0.5) * fishData.speed;
            break;
    }
    
    // 如果是群體魚，生成多條
    const schoolSize = fishData.schoolSize ? 
        Math.floor(Math.random() * (fishData.schoolSize.max - fishData.schoolSize.min + 1)) + fishData.schoolSize.min : 1;
    
    const schoolId = fishData.schoolSize ? 
        'school_' + Date.now() + '_' + selectedFishType.key : null;
    
    // 生成主魚
    gameState.gameData.fish[fishId] = {
        id: fishId,
        type: selectedFishType.key,
        name: fishData.name,
        points: fishData.points,
        health: fishData.health,
        maxHealth: fishData.health,
        speed: fishData.speed,
        size: fishData.size,
        rarity: fishData.rarity,
        image: fishData.image,
        color: fishData.color,
        canLeaveScreen: fishData.canLeaveScreen || false,
        position: { x: x, y: y },
        velocity: { x: vx, y: vy },
        alive: true,
        spawnTime: Date.now(),
        schoolId: schoolId,
        specialEffect: fishData.specialEffect,
        bonusMultiplier: fishData.bonusMultiplier,
        multiplierSystem: fishData.multiplierSystem
    };
    
    // 如果是大型魚，初始化倍數系統
    if (fishData.multiplierSystem) {
        gameState.gameData.fish[fishId].multiplierData = {
            currentMultiplier: fishData.multiplierSystem.baseMultiplier,
            hitCount: 0,
            lastHitTime: 0
        };
    }
    
    // 如果是群體魚，生成額外的同伴
    if (schoolId && schoolSize > 1) {
        for (let i = 1; i < schoolSize && i < 5; i++) { // 最多生成5條同伴
            const companionId = fishId + '_companion_' + i;
            const offsetX = (Math.random() - 0.5) * 100;
            const offsetY = (Math.random() - 0.5) * 100;
            
            gameState.gameData.fish[companionId] = {
                ...gameState.gameData.fish[fishId],
                id: companionId,
                position: { 
                    x: x + offsetX, 
                    y: y + offsetY 
                },
                velocity: {
                    x: vx + (Math.random() - 0.5) * 0.5,
                    y: vy + (Math.random() - 0.5) * 0.5
                }
            };
        }
    }
    
    console.log('Generated fish:', fishData.name, 'at position:', x, y);
}

// 根據稀有度選擇魚類
function selectFishByRarity(fishTypes, rarityWeights) {
    const totalWeight = Object.values(rarityWeights).reduce((a, b) => a + b, 0);
    const random = Math.random() * totalWeight;
    
    let currentWeight = 0;
    let selectedRarity = 'common';
    
    for (const [rarity, weight] of Object.entries(rarityWeights)) {
        currentWeight += weight;
        if (random <= currentWeight) {
            selectedRarity = rarity;
            break;
        }
    }
    
    const fishOfRarity = fishTypes.filter(fish => fish.rarity === selectedRarity);
    return fishOfRarity[Math.floor(Math.random() * fishOfRarity.length)];
}

// 檢查魚類碰撞
function checkFishCollision(startPos, targetPos) {
    if (!gameState.inGame) return;
    
    const weaponDamage = getWeaponDamage(currentWeapon);
    
    // 雷電打擊使用範圍傷害
    if (currentWeapon === 'cannon_laser') {
        checkLightningStrikeCollision(targetPos, weaponDamage);
        return;
    }
    
    // 其他武器使用射線檢測
    for (const fishId in gameState.gameData.fish) {
        const fish = gameState.gameData.fish[fishId];
        if (!fish.alive) continue;
        
        // 檢查射線是否與魚類碰撞
        if (isLineIntersectingCircle(startPos, targetPos, fish.position, fish.size * 30)) {
            console.log('Fish hit:', fish.name);
            
            // 造成傷害
            fish.health -= weaponDamage;
            
            if (fish.health <= 0) {
                // 魚類死亡
                catchFish(fishId, fish);
            } else {
                // 顯示受傷特效
                showFishDamageEffect(fish);
            }
            
            // 只能擊中一條魚（除了雷射）
            break;
        }
    }
}

// 雷電打擊範圍傷害檢測
function checkLightningStrikeCollision(targetPos, weaponDamage) {
    const strikeRadius = 150; // 雷電打擊範圍半徑
    let hitCount = 0;
    
    console.log('Lightning strike at position:', targetPos, 'with radius:', strikeRadius);
    
    // 添加雷電範圍特效
    addLightningStrikeEffect(targetPos, strikeRadius);
    
    for (const fishId in gameState.gameData.fish) {
        const fish = gameState.gameData.fish[fishId];
        if (!fish.alive) continue;
        
        // 計算魚類與雷電中心的距離
        const distance = Math.sqrt(
            Math.pow(fish.position.x - targetPos.x, 2) + 
            Math.pow(fish.position.y - targetPos.y, 2)
        );
        
        // 檢查是否在雷電範圍內
        if (distance <= strikeRadius) {
            console.log('Lightning hit fish:', fish.name, 'distance:', distance);
            hitCount++;
            
            // 範圍內的魚受到傷害
            fish.health -= weaponDamage;
            
            if (fish.health <= 0) {
                // 魚類死亡
                catchFish(fishId, fish);
            } else {
                // 顯示受傷特效
                showFishDamageEffect(fish);
            }
            
            // 添加電擊特效
            addElectricEffect(fish.position);
        }
    }
    
    // 顯示雷電打擊結果
    if (hitCount > 0) {
        showNotification(`雷電打擊命中 ${hitCount} 條魚！`, 'success');
    } else {
        showNotification('雷電打擊未命中任何魚', 'warning');
    }
}

// 添加雷電打擊範圍特效
function addLightningStrikeEffect(position, radius) {
    const effectId = 'lightning_' + Date.now();
    gameState.gameData.effects[effectId] = {
        type: 'lightning_strike',
        position: position,
        radius: radius,
        startTime: Date.now(),
        duration: 800
    };
}

// 添加電擊特效
function addElectricEffect(position) {
    const effectId = 'electric_' + Date.now() + '_' + Math.random();
    gameState.gameData.effects[effectId] = {
        type: 'electric',
        position: { ...position },
        startTime: Date.now(),
        duration: 500
    };
}

// 獲取武器傷害
function getWeaponDamage(weaponType) {
    const weaponDamages = {
        'cannon_1': 1,
        'cannon_2': 2,
        'cannon_3': 3,
        'cannon_laser': 5
    };
    return weaponDamages[weaponType] || 1;
}

// 檢查線段與圓形碰撞
function isLineIntersectingCircle(lineStart, lineEnd, circleCenter, radius) {
    const dx = lineEnd.x - lineStart.x;
    const dy = lineEnd.y - lineStart.y;
    const fx = lineStart.x - circleCenter.x;
    const fy = lineStart.y - circleCenter.y;
    
    const a = dx * dx + dy * dy;
    const b = 2 * (fx * dx + fy * dy);
    const c = (fx * fx + fy * fy) - radius * radius;
    
    const discriminant = b * b - 4 * a * c;
    
    if (discriminant >= 0) {
        const t1 = (-b - Math.sqrt(discriminant)) / (2 * a);
        const t2 = (-b + Math.sqrt(discriminant)) / (2 * a);
        
        return (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1);
    }
    
    return false;
}

// 捕獲魚類
function catchFish(fishId, fish) {
    console.log('Caught fish:', fish.name, 'Points:', fish.points);
    
    fish.alive = false;
    
    // 增加分數和捕魚數
    let points = fish.points;
    
    // 雙倍積分技能效果
    if (gameState.doublePointsActive) {
        points *= 2;
    }
    
    gameState.gameData.score += points;
    gameState.gameData.fishCaught += 1;
    
    // 顯示捕魚特效
    showFishCaughtEffect({
        fishName: fish.name,
        points: points,
        coinReward: Math.floor(points * 0.5),
        position: fish.position
    });
    
    // 播放捕魚音效
    playSound('catch');
    
    // 更新HUD
    updateGameHUD();
    
    // 從遊戲中移除魚類
    setTimeout(() => {
        delete gameState.gameData.fish[fishId];
    }, 500);
    
    // 顯示通知
    showNotification(`捕獲 ${fish.name} +${points}分!`, 'success');
}

// 顯示魚類受傷特效
function showFishDamageEffect(fish) {
    // 創建受傷特效
    const effectId = 'damage_' + Date.now();
    gameState.gameData.effects[effectId] = {
        type: 'damage',
        position: { ...fish.position },
        startTime: Date.now(),
        duration: 300
    };
}

// 調試函數：測試按鈕事件
function testButtonEvents() {
    console.log('Testing button events...');
    
    const closeBtn = document.getElementById('closeBtn');
    const joinBtn = document.getElementById('joinGameBtn');
    
    console.log('Close button found:', !!closeBtn);
    console.log('Join button found:', !!joinBtn);
    
    if (closeBtn) {
        console.log('Close button onclick:', closeBtn.onclick);
        console.log('Close button style:', closeBtn.style.display);
    }
    
    if (joinBtn) {
        console.log('Join button onclick:', joinBtn.onclick);
        console.log('Join button style:', joinBtn.style.display);
    }
}

// 添加全局點擊事件監聽器來調試
document.addEventListener('click', function(event) {
    console.log('Global click detected on:', event.target.tagName, event.target.className, event.target.id);
});

console.log('魚機遊戲 JavaScript 載入完成');

// 設置多人遊戲事件處理器
function setupMultiplayerEvents() {
    // 監聽來自客戶端的多人遊戲事件
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        switch (data.type) {
            case 'playerJoinedRoom':
                handlePlayerJoinedRoom(data.data);
                break;
            case 'playerLeftRoom':
                handlePlayerLeftRoom(data.data);
                break;
            case 'fishSpawned':
                handleFishSpawned(data.data);
                break;
            case 'fishDamaged':
                handleFishDamaged(data.data);
                break;
            case 'fishReward':
                handleFishReward(data.data);
                break;
            case 'bombExplosion':
                handleBombExplosion(data.data);
                break;
            case 'lightningStrike':
                handleLightningStrike(data.data);
                break;
            case 'roomStateUpdate':
                handleRoomStateUpdate(data.roomState);
                break;
            case 'otherPlayerShoot':
                handleOtherPlayerShoot(data.shootData);
                break;
        }
    });
}

// 處理玩家加入房間
function handlePlayerJoinedRoom(data) {
    console.log('玩家加入房間:', data.playerName, '總玩家數:', data.totalPlayers);
    
    // 更新玩家列表
    updatePlayersList(data);
    
    // 顯示通知
    showNotification(data.playerName + ' 加入了房間', 'info');
    
    // 更新房間狀態
    if (gameState.inGame) {
        updateRoomState({
            players: data.totalPlayers,
            roomStats: { totalPlayers: data.totalPlayers }
        });
    }
}

// 處理玩家離開房間
function handlePlayerLeftRoom(data) {
    console.log('玩家離開房間:', data.playerName, '總玩家數:', data.totalPlayers);
    
    // 更新玩家列表
    updatePlayersList(data);
    
    // 顯示通知
    showNotification(data.playerName + ' 離開了房間', 'info');
    
    // 更新房間狀態
    if (gameState.inGame) {
        updateRoomState({
            players: data.totalPlayers,
            roomStats: { totalPlayers: data.totalPlayers }
        });
    }
}

// 處理新魚生成
function handleFishSpawned(data) {
    console.log('新魚生成:', data.newFishCount, '總魚數:', data.totalFishCount);
    
    // 更新魚類數據
    if (data.fish) {
        Object.assign(gameState.gameData.fish, data.fish);
    }
    
    // 顯示通知
    showNotification('新魚群出現了！', 'info');
}

// 處理魚被攻擊
function handleFishDamaged(data) {
    console.log('魚被攻擊:', data.fishId, '攻擊者:', data.attackerName, '傷害:', data.damage);
    
    // 更新魚的血量
    const fish = gameState.gameData.fish[data.fishId];
    if (fish) {
        fish.health = data.remainingHealth;
        fish.maxHealth = data.maxHealth;
        
        // 添加傷害效果
        addDamageEffect(fish, data.damage, data.attackerName);
    }
    
    // 顯示傷害數字
    showDamageNumber(data.damage, data.attackerName);
}

// 處理魚獎勵
function handleFishReward(data) {
    console.log('獲得魚獎勵:', data.fishName, '分數:', data.points, '金幣:', data.coinReward);
    
    // 更新遊戲數據
    gameState.gameData.score += data.points;
    gameState.gameData.coins += data.coinReward;
    
    // 更新HUD
    updateGameHUD();
    
    // 顯示獎勵效果
    showRewardEffect(data);
}

// 處理炸彈爆炸
function handleBombExplosion(data) {
    console.log('炸彈爆炸:', data.triggerPlayer, '影響魚數:', data.explodedFish.length);
    
    // 添加爆炸效果
    addExplosionEffect(data.position, data.radius);
    
    // 移除被爆炸影響的魚
    data.explodedFish.forEach(fishData => {
        delete gameState.gameData.fish[fishData.id];
    });
    
    // 顯示通知
    showNotification(data.triggerPlayer + ' 的炸彈魚爆炸了！', 'warning');
}

// 處理閃電打擊
function handleLightningStrike(data) {
    console.log('閃電打擊:', data.triggerPlayer, '影響魚數:', data.struckFish.length);
    
    // 添加閃電效果
    data.struckFish.forEach(fishData => {
        addLightningStrikeEffect(fishData.position, 100);
    });
    
    // 移除被電擊的魚
    data.struckFish.forEach(fishData => {
        delete gameState.gameData.fish[fishData.id];
    });
    
    // 顯示通知
    showNotification(data.triggerPlayer + ' 的閃電魚發動了！', 'warning');
}

// 處理房間狀態更新
function handleRoomStateUpdate(roomState) {
    console.log('房間狀態更新:', roomState);
    
    // 更新魚類數據
    if (roomState.fish) {
        gameState.gameData.fish = roomState.fish;
    }
    
    // 更新子彈數據
    if (roomState.bullets) {
        gameState.gameData.bullets = roomState.bullets;
    }
    
    // 更新特效數據
    if (roomState.effects) {
        gameState.gameData.effects = roomState.effects;
    }
    
    // 更新玩家列表
    if (roomState.players) {
        updatePlayersList(roomState.players);
    }
    
    // 更新房間統計
    if (roomState.roomStats) {
        updateRoomStats(roomState.roomStats);
    }
}

// 添加傷害效果
function addDamageEffect(fish, damage, attackerName) {
    const effectId = 'damage_' + Date.now() + '_' + Math.random();
    gameState.gameData.effects[effectId] = {
        type: 'damage',
        position: { x: fish.position.x, y: fish.position.y },
        damage: damage,
        attacker: attackerName,
        startTime: Date.now(),
        duration: 2000
    };
}

// 顯示傷害數字
function showDamageNumber(damage, attackerName) {
    const damageId = 'damageNumber_' + Date.now() + '_' + Math.random();
    gameState.gameData.effects[damageId] = {
        type: 'damageNumber',
        position: { x: mousePos.x, y: mousePos.y },
        damage: damage,
        attacker: attackerName,
        startTime: Date.now(),
        duration: 1500
    };
}

// 顯示獎勵效果
function showRewardEffect(data) {
    const rewardId = 'reward_' + Date.now() + '_' + Math.random();
    gameState.gameData.effects[rewardId] = {
        type: 'reward',
        position: { x: window.innerWidth / 2, y: window.innerHeight / 2 },
        points: data.points,
        coins: data.coinReward,
        fishName: data.fishName,
        isFinalBlow: data.isFinalBlow,
        contributors: data.contributors,
        startTime: Date.now(),
        duration: 3000
    };
}

// 處理其他玩家射擊
function handleOtherPlayerShoot(shootData) {
    console.log('其他玩家射擊:', shootData);
    
    // 獲取其他玩家的射擊位置（與 drawPlayerPositions 使用相同的位置）
    const otherPlayerPosition = shootData.playerPosition || 0;
    const positions = [
        { x: canvas.width * 0.15, y: canvas.height - 80 }, // 位置1: 左側
        { x: canvas.width * 0.30, y: canvas.height - 80 }, // 位置2: 左中
        { x: canvas.width * 0.45, y: canvas.height - 80 }, // 位置3: 中左
        { x: canvas.width * 0.55, y: canvas.height - 80 }, // 位置4: 中右
        { x: canvas.width * 0.70, y: canvas.height - 80 }, // 位置5: 右中
        { x: canvas.width * 0.85, y: canvas.height - 80 }  // 位置6: 右側
    ];
    
    const startPos = positions[otherPlayerPosition] || positions[0];
    const targetPos = shootData.targetPos || { x: mousePos.x, y: mousePos.y };
    
    // 添加其他玩家的射擊特效
    addOtherPlayerShootEffect(startPos, targetPos, shootData.bullet.weaponType, shootData.playerName);
}

// 添加其他玩家射擊特效
function addOtherPlayerShootEffect(startPos, targetPos, weaponType, playerName) {
    const effectId = 'other_effect_' + Date.now() + '_' + Math.random();
    
    // 根據武器設置不同的特效屬性
    const weaponEffects = {
        'cannon_1': { color: 'rgba(255, 255, 255, 0.6)', width: 3, duration: 800 },
        'cannon_2': { color: 'rgba(0, 255, 0, 0.7)', width: 5, duration: 600 },
        'cannon_3': { color: 'rgba(255, 0, 0, 0.8)', width: 7, duration: 400 },
        'cannon_laser': { color: 'rgba(255, 0, 255, 0.8)', width: 10, duration: 200 }
    };
    
    const effect = weaponEffects[weaponType] || weaponEffects['cannon_1'];
    
    gameState.gameData.effects[effectId] = {
        type: 'bullet',
        startPos: startPos,
        currentPos: { ...startPos },
        targetPos: targetPos,
        startTime: Date.now(),
        duration: effect.duration,
        weapon: weaponType,
        color: effect.color,
        width: effect.width,
        playerPosition: -1, // 標記為其他玩家
        playerName: playerName
    };
}

// 更新房間統計
function updateRoomStats(stats) {
    // 更新房間統計顯示
    const statsElement = document.getElementById('roomStats');
    if (statsElement) {
        statsElement.innerHTML = `
            <div class="stat-item">
                <span class="stat-label">總魚數:</span>
                <span class="stat-value">${stats.totalFishSpawned || 0}</span>
            </div>
            <div class="stat-item">
                <span class="stat-label">已捕獲:</span>
                <span class="stat-value">${stats.totalFishCaught || 0}</span>
            </div>
        `;
    }
}

// 切換設定界面（遊戲中使用）
function toggleSettings() {
    const settingsModal = document.getElementById('settingsModal');
    if (settingsModal) {
        if (settingsModal.style.display === 'flex') {
            closeSettings();
        } else {
            showSettings();
        }
    }
}

// 更新統計資料內容
function updateStatisticsContent(statistics) {
    const statsGrid = document.getElementById('statsGrid');
    if (!statsGrid) return;
    
    if (!statistics || statistics.error) {
        statsGrid.innerHTML = `
            <div style="text-align: center; padding: 50px; opacity: 0.7;">
                <p style="color: #ff6b6b;">${statistics?.error || '無法載入統計資料'}</p>
            </div>
        `;
        return;
    }
    
    const stats = [
        { icon: '🏆', title: '等級', value: statistics.player.level },
        { icon: '⭐', title: '經驗值', value: formatNumber(statistics.player.experience) },
        { icon: '💰', title: '總賺取金幣', value: formatNumber(statistics.player.totalCoinsEarned) },
        { icon: '🎮', title: '遊戲場次', value: formatNumber(statistics.player.totalGamesPlayed) },
        { icon: '🐟', title: '總捕魚數', value: formatNumber(statistics.player.totalFishCaught) },
        { icon: '📈', title: '最高分數', value: formatNumber(statistics.player.bestScore) },
        { icon: '🎯', title: '平均得分', value: formatNumber(Math.floor(statistics.sessions.avgScore)) },
        { icon: '💵', title: '平均收益', value: formatNumber(Math.floor(statistics.sessions.avgEarned)) },
        { icon: '🎲', title: '勝率', value: Math.floor((statistics.sessions.lifetimeEarned / statistics.sessions.lifetimeSpent) * 100) + '%' }
    ];
    
    let html = '';
    stats.forEach(stat => {
        html += `
            <div class="stat-card">
                <div class="stat-icon">${stat.icon}</div>
                <div class="stat-title">${stat.title}</div>
                <div class="stat-number">${stat.value}</div>
            </div>
        `;
    });
    
    // 添加捕魚統計
    if (statistics.fishStats && statistics.fishStats.length > 0) {
        html += `
            <div style="grid-column: 1 / -1; margin-top: 20px;">
                <h3 style="text-align: center; margin-bottom: 15px; color: #feca57;">🐟 捕魚統計</h3>
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px;">
        `;
        
        statistics.fishStats.slice(0, 6).forEach(fish => {
            html += `
                <div style="background: rgba(255,255,255,0.05); padding: 10px; border-radius: 8px;">
                    <div style="font-weight: bold;">${fish.name}</div>
                    <div style="font-size: 12px; opacity: 0.7;">捕獲 ${fish.count} 次</div>
                    <div style="font-size: 12px; color: #feca57;">獲得 ${formatNumber(fish.coins)} 金幣</div>
                </div>
            `;
        });
        
        html += '</div></div>';
    }
    
    statsGrid.innerHTML = html;
}