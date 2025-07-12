Config = {}

-- 基本設定
Config.Locale = 'zh-tw'
Config.EnableDebug = false
Config.UpdateInterval = 100 -- ms

-- 貨幣設定
Config.Currency = 'money' -- ESX貨幣類型：money, bank, black_money
Config.MinBet = 100 -- 最小下注金額
Config.MaxBet = 50000 -- 最大下注金額

-- 房間設定
Config.Rooms = {
    ['room_1'] = {
        name = '初級海域',
        maxPlayers = 6,
        minBet = 100,
        maxBet = 5000,
        position = vector3(1115.0, 220.0, -49.0), -- 賭場位置
        heading = 90.0,
        access = 'public' -- public, vip, private
    },
    ['room_2'] = {
        name = '中級海域',
        maxPlayers = 8,
        minBet = 1000,
        maxBet = 20000,
        position = vector3(1125.0, 220.0, -49.0),
        heading = 90.0,
        access = 'vip'
    },
    ['room_3'] = {
        name = '高級海域',
        maxPlayers = 10,
        minBet = 5000,
        maxBet = 50000,
        position = vector3(1135.0, 220.0, -49.0),
        heading = 90.0,
        access = 'private'
    }
}

-- 魚類設定
Config.FishTypes = {
    -- 小型魚 (1-10分) - 數量很多，可以一群群的游
    ['small_fish_1'] = {
        name = '小丑魚',
        points = 2,
        health = 1,
        speed = 3.0,
        size = 0.8,
        image = 'GGL_Fish_1.png',
        rarity = 'common',
        spawnChance = 25.0,
        color = {r = 255, g = 255, b = 0},
        schoolSize = {min = 3, max = 8}, -- 群體大小
        canLeaveScreen = true -- 可以游出螢幕
    },
    ['small_fish_2'] = {
        name = '熱帶魚',
        points = 3,
        health = 1,
        speed = 3.5,
        size = 0.9,
        image = 'GGL_Fish_2.png',
        rarity = 'common',
        spawnChance = 22.0,
        color = {r = 0, g = 255, b = 255},
        schoolSize = {min = 4, max = 10},
        canLeaveScreen = true
    },
    ['small_fish_3'] = {
        name = '金魚',
        points = 4,
        health = 1,
        speed = 4.0,
        size = 1.0,
        image = 'GGL_Fish_3.png',
        rarity = 'common',
        spawnChance = 20.0,
        color = {r = 255, g = 165, b = 0},
        schoolSize = {min = 2, max = 6},
        canLeaveScreen = true
    },
    ['small_fish_4'] = {
        name = '斑馬魚',
        points = 5,
        health = 1,
        speed = 4.5,
        size = 0.8,
        image = 'GGL_Fish_4.png',
        rarity = 'common',
        spawnChance = 18.0,
        schoolSize = {min = 5, max = 12},
        canLeaveScreen = true
    },
    ['small_fish_5'] = {
        name = '藍鰭魚',
        points = 6,
        health = 1,
        speed = 3.8,
        size = 0.9,
        image = 'GGL_Fish_5.png',
        rarity = 'common',
        spawnChance = 16.0,
        schoolSize = {min = 3, max = 7},
        canLeaveScreen = true
    },
    ['small_fish_6'] = {
        name = '銀魚',
        points = 7,
        health = 2,
        speed = 5.0,
        size = 0.7,
        image = 'GGL_Fish_6.png',
        rarity = 'common',
        spawnChance = 15.0,
        schoolSize = {min = 8, max = 15},
        canLeaveScreen = true
    },
    ['small_fish_7'] = {
        name = '珊瑚魚',
        points = 8,
        health = 2,
        speed = 3.2,
        size = 1.0,
        image = 'GGL_Fish_7.png',
        rarity = 'common',
        spawnChance = 14.0,
        canLeaveScreen = true
    },
    ['small_fish_8'] = {
        name = '孔雀魚',
        points = 9,
        health = 2,
        speed = 4.2,
        size = 0.8,
        image = 'GGL_Fish_8.png',
        rarity = 'common',
        spawnChance = 12.0,
        schoolSize = {min = 2, max = 5},
        canLeaveScreen = true
    },
    ['small_fish_9'] = {
        name = '鸚鵡魚',
        points = 10,
        health = 2,
        speed = 3.6,
        size = 1.1,
        image = 'GGL_Fish_9.png',
        rarity = 'common',
        spawnChance = 10.0,
        canLeaveScreen = true
    },
    ['small_fish_10'] = {
        name = '海馬',
        points = 12,
        health = 2,
        speed = 2.5,
        size = 0.9,
        image = 'GGL_Fish_10.png',
        rarity = 'common',
        spawnChance = 8.0,
        canLeaveScreen = true
    },
    
    -- 中型魚 - 道具魚 (特殊效果)
    ['special_laser_fish'] = {
        name = '雷射魚',
        points = 30,
        health = 3,
        speed = 2.5,
        size = 1.5,
        image = 'Fish_task_16.png',
        rarity = 'special',
        spawnChance = 2.0,
        specialEffect = 'laser_cannon', -- 變成雷射炮
        effectDuration = 10000, -- 10秒
        canLeaveScreen = true
    },
    ['special_bomb_fish'] = {
        name = '炸彈魚',
        points = 40,
        health = 4,
        speed = 2.0,
        size = 1.6,
        image = 'Fish_task_17.png',
        rarity = 'special',
        spawnChance = 1.5,
        specialEffect = 'screen_bomb', -- 全螢幕清除（不含大型魚）
        canLeaveScreen = true
    },
    ['special_wheel_fish'] = {
        name = '轉盤魚',
        points = 25,
        health = 3,
        speed = 3.0,
        size = 1.4,
        image = 'Fish_task_18.png',
        rarity = 'special',
        spawnChance = 2.5,
        specialEffect = 'lucky_wheel', -- 轉盤抽獎
        canLeaveScreen = true
    },
    
    -- 中型魚 - 賞金魚 (高分數)
    ['medium_fish_1'] = {
        name = '燈籠魚',
        points = 20,
        health = 3,
        speed = 2.5,
        size = 1.3,
        image = 'GGL_Fish_11.png',
        rarity = 'uncommon',
        spawnChance = 6.0,
        bonusMultiplier = 2, -- 賞金倍數
        canLeaveScreen = true
    },
    ['medium_fish_2'] = {
        name = '比目魚',
        points = 25,
        health = 3,
        speed = 2.0,
        size = 1.5,
        image = 'GGL_Fish_12.png',
        rarity = 'uncommon',
        spawnChance = 5.5,
        bonusMultiplier = 2,
        canLeaveScreen = true
    },
    ['medium_fish_3'] = {
        name = '蝴蝶魚',
        points = 30,
        health = 4,
        speed = 2.8,
        size = 1.4,
        image = 'GGL_Fish_13.png',
        rarity = 'uncommon',
        spawnChance = 5.0,
        bonusMultiplier = 2.5,
        canLeaveScreen = true
    },
    ['medium_fish_4'] = {
        name = '神仙魚',
        points = 35,
        health = 4,
        speed = 2.3,
        size = 1.6,
        image = 'GGL_Fish_14.png',
        rarity = 'uncommon',
        spawnChance = 4.5,
        bonusMultiplier = 2.5,
        canLeaveScreen = true
    },
    ['medium_fish_5'] = {
        name = '獅子魚',
        points = 40,
        health = 5,
        speed = 2.1,
        size = 1.7,
        image = 'GGL_Fish_15.png',
        rarity = 'uncommon',
        spawnChance = 4.0,
        bonusMultiplier = 3,
        canLeaveScreen = true
    },
    ['medium_fish_6'] = {
        name = '河豚',
        points = 45,
        health = 5,
        speed = 1.8,
        size = 1.8,
        image = 'GGL_Fish_16.png',
        rarity = 'uncommon',
        spawnChance = 3.5,
        bonusMultiplier = 3,
        canLeaveScreen = true
    },
    ['medium_fish_7'] = {
        name = '海龜',
        points = 50,
        health = 6,
        speed = 1.5,
        size = 2.0,
        image = 'GGL_Fish_17.png',
        rarity = 'uncommon',
        spawnChance = 3.0,
        bonusMultiplier = 3.5,
        canLeaveScreen = true
    },
    ['medium_fish_8'] = {
        name = '章魚',
        points = 55,
        health = 6,
        speed = 2.0,
        size = 1.9,
        image = 'GGL_Fish_18.png',
        rarity = 'uncommon',
        spawnChance = 2.8,
        bonusMultiplier = 3.5,
        canLeaveScreen = true
    },
    ['medium_fish_9'] = {
        name = '水母',
        points = 60,
        health = 4,
        speed = 1.2,
        size = 1.7,
        image = 'GGL_Fish_19.png',
        rarity = 'uncommon',
        spawnChance = 2.5,
        bonusMultiplier = 4,
        canLeaveScreen = true
    },
    ['medium_fish_10'] = {
        name = '海星',
        points = 65,
        health = 7,
        speed = 0.8,
        size = 1.6,
        image = 'GGL_Fish_20.png',
        rarity = 'uncommon',
        spawnChance = 2.2,
        bonusMultiplier = 4,
        canLeaveScreen = true
    },
    
    -- 大型魚 (倍數累積系統)
    ['large_fish_1'] = {
        name = '石斑魚',
        points = 100,
        health = 10,
        speed = 1.8,
        size = 2.5,
        image = 'GGL_Fish_21.png',
        rarity = 'rare',
        spawnChance = 2.0,
        multiplierSystem = {
            baseMultiplier = 1,
            hitIncrement = 0.5, -- 每次擊中增加0.5倍
            maxMultiplier = 10,
            randomDeathChance = 0.1 -- 10%機率隨機死亡
        },
        canLeaveScreen = true
    },
    ['large_fish_2'] = {
        name = '金槍魚',
        points = 150,
        health = 15,
        speed = 2.2,
        size = 2.8,
        image = 'GGL_Fish_22.png',
        rarity = 'rare',
        spawnChance = 1.8,
        multiplierSystem = {
            baseMultiplier = 1,
            hitIncrement = 0.8,
            maxMultiplier = 15,
            randomDeathChance = 0.08
        },
        canLeaveScreen = true
    },
    ['large_fish_3'] = {
        name = '劍魚',
        points = 200,
        health = 20,
        speed = 2.5,
        size = 3.0,
        image = 'GGL_Fish_23.png',
        rarity = 'rare',
        spawnChance = 1.5,
        multiplierSystem = {
            baseMultiplier = 1,
            hitIncrement = 1.0,
            maxMultiplier = 20,
            randomDeathChance = 0.06
        },
        canLeaveScreen = true
    },
    ['large_fish_4'] = {
        name = '鯊魚',
        points = 300,
        health = 25,
        speed = 2.0,
        size = 3.5,
        image = 'GGL_Fish_24.png',
        rarity = 'rare',
        spawnChance = 1.2,
        multiplierSystem = {
            baseMultiplier = 2,
            hitIncrement = 1.2,
            maxMultiplier = 25,
            randomDeathChance = 0.05
        },
        canLeaveScreen = true
    },
    ['large_fish_5'] = {
        name = '虎鯨',
        points = 400,
        health = 30,
        speed = 1.8,
        size = 4.0,
        image = 'GGL_Fish_25.png',
        rarity = 'legendary',
        spawnChance = 1.0,
        multiplierSystem = {
            baseMultiplier = 2,
            hitIncrement = 1.5,
            maxMultiplier = 30,
            randomDeathChance = 0.04
        },
        canLeaveScreen = true
    },
    ['large_fish_6'] = {
        name = '巨型章魚',
        points = 500,
        health = 3600, -- 6個玩家 * 10分鐘 * 10DPS = 3600血量
        speed = 1.0, -- 降低速度
        size = 8.0, -- 王級尺寸
        image = 'GGL_Fish_26.png',
        rarity = 'boss',
        spawnChance = 0.01, -- 極低生成機率
        isBoss = true,
        bossType = 'king',
        multiplierSystem = {
            baseMultiplier = 5,
            hitIncrement = 2.0,
            maxMultiplier = 100,
            randomDeathChance = 0.001 -- 極低隨機死亡機率
        },
        canLeaveScreen = false, -- 王級魚不能離開螢幕
        showHealthBar = true,
        bossMusic = 'boss_battle.ogg'
    },
    ['large_fish_7'] = {
        name = '海龍',
        points = 600,
        health = 4200, -- 7分鐘戰鬥時間
        speed = 0.8,
        size = 9.0,
        image = 'GGL_Fish_27.png',
        rarity = 'boss',
        spawnChance = 0.008,
        isBoss = true,
        bossType = 'king',
        multiplierSystem = {
            baseMultiplier = 8,
            hitIncrement = 3.0,
            maxMultiplier = 150,
            randomDeathChance = 0.0008
        },
        canLeaveScreen = false,
        showHealthBar = true,
        bossMusic = 'boss_battle.ogg'
    },
    ['large_fish_8'] = {
        name = '巨齒鯊',
        points = 800,
        health = 4800, -- 8分鐘戰鬥時間
        speed = 0.9,
        size = 10.0,
        image = 'GGL_Fish_28.png',
        rarity = 'boss',
        spawnChance = 0.006,
        isBoss = true,
        bossType = 'king',
        multiplierSystem = {
            baseMultiplier = 10,
            hitIncrement = 4.0,
            maxMultiplier = 200,
            randomDeathChance = 0.0006
        },
        canLeaveScreen = false,
        showHealthBar = true,
        bossMusic = 'boss_battle.ogg'
    },
    ['large_fish_9'] = {
        name = '深海巨獸',
        points = 1000,
        health = 60,
        speed = 1.2,
        size = 5.5,
        image = 'GGL_Fish_29.png',
        rarity = 'mythic',
        spawnChance = 0.2,
        multiplierSystem = {
            baseMultiplier = 5,
            hitIncrement = 4.0,
            maxMultiplier = 80,
            randomDeathChance = 0.015
        },
        canLeaveScreen = true
    },
    ['large_fish_10'] = {
        name = '黃金龍魚',
        points = 1500,
        health = 5400, -- 9分鐘戰鬥時間
        speed = 0.6,
        size = 12.0, -- 最大王級尺寸
        image = 'GGL_Fish_30.png',
        rarity = 'boss',
        spawnChance = 0.004,
        isBoss = true,
        bossType = 'king',
        multiplierSystem = {
            baseMultiplier = 15,
            hitIncrement = 5.0,
            maxMultiplier = 300,
            randomDeathChance = 0.0004
        },
        canLeaveScreen = false,
        showHealthBar = true,
        bossMusic = 'boss_battle.ogg'
    },
    ['large_fish_11'] = {
        name = '遠古海皇',
        points = 2000,
        health = 6000, -- 10分鐘戰鬥時間
        speed = 0.5,
        size = 15.0, -- 終極王級尺寸
        image = 'GGL_Fish_31.png',
        rarity = 'boss',
        spawnChance = 0.002,
        isBoss = true,
        bossType = 'emperor',
        multiplierSystem = {
            baseMultiplier = 20,
            hitIncrement = 8.0,
            maxMultiplier = 500,
            randomDeathChance = 0.0002
        },
        canLeaveScreen = false,
        showHealthBar = true,
        bossMusic = 'boss_battle.ogg'
    }
}

-- 武器設定（增加倍數）
Config.Weapons = {
    ['cannon_1'] = {
        name = '小型砲',
        damage = 1,
        cost = 10, -- 每發子彈成本
        fireRate = 800, -- ms
        range = 500,
        speed = 8.0,
        size = 0.5,
        color = {r = 255, g = 255, b = 255},
        unlockLevel = 1,
        multiplier = 1 -- 倍數
    },
    ['cannon_2'] = {
        name = '中型砲',
        damage = 2,
        cost = 20,
        fireRate = 600,
        range = 600,
        speed = 10.0,
        size = 0.7,
        color = {r = 0, g = 255, b = 0},
        unlockLevel = 5,
        multiplier = 2
    },
    ['cannon_3'] = {
        name = '大型砲',
        damage = 3,
        cost = 40,
        fireRate = 400,
        range = 700,
        speed = 12.0,
        size = 1.0,
        color = {r = 255, g = 0, b = 0},
        unlockLevel = 10,
        multiplier = 3
    },
    ['cannon_4'] = {
        name = '黃金砲',
        damage = 5,
        cost = 80,
        fireRate = 300,
        range = 800,
        speed = 15.0,
        size = 1.2,
        color = {r = 255, g = 215, b = 0},
        unlockLevel = 15,
        multiplier = 5
    },
    ['cannon_laser'] = {
        name = '雷射砲',
        damage = 10,
        cost = 200,
        fireRate = 200,
        range = 1000,
        speed = 20.0,
        size = 0.3,
        color = {r = 255, g = 0, b = 255},
        unlockLevel = 20,
        specialEffect = 'laser',
        multiplier = 10,
        penetrating = true -- 可以穿透多條魚
    }
}

-- 特殊技能
Config.SpecialSkills = {
    ['freeze_all'] = {
        name = '冰凍全場',
        cost = 500,
        duration = 10000, -- ms
        cooldown = 60000, -- ms
        unlockLevel = 15
    },
    ['double_points'] = {
        name = '雙倍積分',
        cost = 300,
        duration = 15000,
        cooldown = 45000,
        unlockLevel = 10
    },
    ['auto_aim'] = {
        name = '自動瞄準',
        cost = 200,
        duration = 20000,
        cooldown = 30000,
        unlockLevel = 8
    },
    ['lightning_strike'] = {
        name = '閃電打擊',
        cost = 1000,
        duration = 0, -- 立即效果
        cooldown = 90000,
        unlockLevel = 25
    }
}

-- 音效設定
Config.Sounds = {
    background = 'background_music.ogg', -- 背景音樂.ogg
    shoot = 'cannon_fire.ogg', -- 中型炮的聲音.ogg
    shoot_miss = 'shoot_miss.ogg', -- 射空的聲音.ogg
    hit = 'fish_hit.ogg', -- 射到魚的聲音.ogg
    catch = 'fish_catch.ogg', -- 殺了大魚的聲音.ogg
    laser = 'laser_cannon.ogg', -- 雷射炮的聲音.ogg
    double_points = 'double_points.ogg', -- 雙倍時間的聲音.ogg
    boss_battle = 'boss_battle.ogg', -- 王級魚戰鬥音樂
    boss_death = 'boss_death.ogg', -- 王級魚死亡音效
    special = 'special_effect.ogg',
    win = 'win_sound.ogg',
    lose = 'lose_sound.ogg'
} 