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
    -- 小魚 (1-10分)
    ['small_fish_1'] = {
        name = '丑魚',
        points = 2,
        health = 1,
        speed = 3.0,
        size = 0.8,
        model = 'small_fish_1',
        rarity = 'common',
        spawnChance = 25.0,
        color = {r = 255, g = 255, b = 0}
    },
    ['small_fish_2'] = {
        name = '熱帶魚',
        points = 3,
        health = 1,
        speed = 3.5,
        size = 0.9,
        model = 'small_fish_2',
        rarity = 'common',
        spawnChance = 20.0,
        color = {r = 0, g = 255, b = 255}
    },
    ['small_fish_3'] = {
        name = '小丑魚',
        points = 4,
        health = 1,
        speed = 4.0,
        size = 1.0,
        model = 'small_fish_3',
        rarity = 'common',
        spawnChance = 15.0,
        color = {r = 255, g = 165, b = 0}
    },
    
    -- 中魚 (10-50分)
    ['medium_fish_1'] = {
        name = '燈籠魚',
        points = 12,
        health = 2,
        speed = 2.5,
        size = 1.3,
        model = 'medium_fish_1',
        rarity = 'uncommon',
        spawnChance = 8.0,
        color = {r = 255, g = 0, b = 255}
    },
    ['medium_fish_2'] = {
        name = '比目魚',
        points = 18,
        health = 3,
        speed = 2.0,
        size = 1.5,
        model = 'medium_fish_2',
        rarity = 'uncommon',
        spawnChance = 6.0,
        color = {r = 139, g = 69, b = 19}
    },
    ['medium_fish_3'] = {
        name = '蝴蝶魚',
        points = 25,
        health = 3,
        speed = 2.8,
        size = 1.4,
        model = 'medium_fish_3',
        rarity = 'uncommon',
        spawnChance = 5.0,
        color = {r = 255, g = 20, b = 147}
    },
    
    -- 大魚 (50-200分)
    ['large_fish_1'] = {
        name = '石斑魚',
        points = 80,
        health = 5,
        speed = 1.8,
        size = 2.0,
        model = 'large_fish_1',
        rarity = 'rare',
        spawnChance = 3.0,
        color = {r = 128, g = 128, b = 128}
    },
    ['large_fish_2'] = {
        name = '金槍魚',
        points = 120,
        health = 6,
        speed = 2.2,
        size = 2.2,
        model = 'large_fish_2',
        rarity = 'rare',
        spawnChance = 2.0,
        color = {r = 192, g = 192, b = 192}
    },
    ['large_fish_3'] = {
        name = '劍魚',
        points = 150,
        health = 7,
        speed = 2.5,
        size = 2.5,
        model = 'large_fish_3',
        rarity = 'rare',
        spawnChance = 1.5,
        color = {r = 0, g = 0, b = 139}
    },
    
    -- BOSS魚 (200-1000分)
    ['boss_fish_1'] = {
        name = '金龍魚',
        points = 300,
        health = 10,
        speed = 1.5,
        size = 3.0,
        model = 'boss_fish_1',
        rarity = 'legendary',
        spawnChance = 0.8,
        color = {r = 255, g = 215, b = 0}
    },
    ['boss_fish_2'] = {
        name = '鯊魚',
        points = 500,
        health = 15,
        speed = 1.8,
        size = 3.5,
        model = 'boss_fish_2',
        rarity = 'legendary',
        spawnChance = 0.3,
        color = {r = 105, g = 105, b = 105}
    },
    ['boss_fish_3'] = {
        name = '龍王',
        points = 800,
        health = 20,
        speed = 1.2,
        size = 4.0,
        model = 'boss_fish_3',
        rarity = 'legendary',
        spawnChance = 0.1,
        color = {r = 138, g = 43, b = 226}
    },
    
    -- 特殊魚 (特殊效果)
    ['special_bomb_fish'] = {
        name = '炸彈魚',
        points = 50,
        health = 3,
        speed = 2.0,
        size = 1.8,
        model = 'special_bomb_fish',
        rarity = 'special',
        spawnChance = 1.0,
        specialEffect = 'bomb',
        color = {r = 255, g = 0, b = 0}
    },
    ['special_lightning_fish'] = {
        name = '閃電魚',
        points = 30,
        health = 2,
        speed = 4.0,
        size = 1.5,
        model = 'special_lightning_fish',
        rarity = 'special',
        spawnChance = 1.2,
        specialEffect = 'lightning',
        color = {r = 255, g = 255, b = 0}
    }
}

-- 武器設定
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
        unlockLevel = 1
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
        unlockLevel = 5
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
        unlockLevel = 10
    },
    ['cannon_laser'] = {
        name = '雷射砲',
        damage = 5,
        cost = 100,
        fireRate = 200,
        range = 800,
        speed = 20.0,
        size = 0.3,
        color = {r = 255, g = 0, b = 255},
        unlockLevel = 20,
        specialEffect = 'laser'
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
    }
}

-- 音效設定
Config.Sounds = {
    background = 'ocean_ambient.ogg',
    shoot = 'cannon_fire.ogg',
    hit = 'fish_hit.ogg',
    catch = 'fish_catch.ogg',
    special = 'special_effect.ogg',
    win = 'win_sound.ogg',
    lose = 'lose_sound.ogg'
} 