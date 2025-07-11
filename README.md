# 🐟 FIVEM ESX 魚機遊戲插件

一個完整復刻現實魚機遊戲功能的FIVEM ESX 1.12插件，提供多人在線魚機遊戲體驗。

## ✨ 功能特色

### 🎮 核心遊戲功能
- **多人房間系統** - 支援3個不同等級的房間，最多10人同時遊玩
- **真實魚機體驗** - 完整復刻現實魚機的遊戲機制和規則
- **豐富魚類系統** - 16種不同魚類，包含普通魚、稀有魚、BOSS魚和特殊魚
- **多樣武器系統** - 4種不同威力的砲台，包含雷射砲等特殊武器
- **技能系統** - 冰凍全場、雙倍積分、自動瞄準等特殊技能
- **特效系統** - 爆炸魚、閃電魚等特殊效果

### 💰 經濟系統
- **ESX整合** - 完全整合ESX經濟系統
- **下注機制** - 靈活的下注金額設定（$100-$50,000）
- **獎勵系統** - 基於分數的金幣獎勵機制
- **風險控制** - 防止外掛和作弊的服務端驗證

### 👤 玩家系統
- **等級系統** - 基於經驗值的等級提升
- **解鎖系統** - 隨等級解鎖新武器和技能
- **統計追蹤** - 詳細的遊戲統計和成就系統
- **排行榜** - 日、週、月和總計排行榜

### 🎨 界面設計
- **現代UI** - 美觀的漸變色彩和毛玻璃效果
- **響應式設計** - 支援各種螢幕尺寸
- **流暢動畫** - 豐富的CSS動畫和特效
- **直觀操作** - 簡單易懂的操作界面

## 📋 系統需求

- **FIVEM** 服務器
- **ESX 1.12** 框架
- **oxmysql** 數據庫資源
- **MySQL** 數據庫

## 🚀 安裝指南

### 1. 下載和放置文件
```bash
# 將插件放置到resources資料夾
resources/
└── [esx]/
    └── sun_fishgame/
        ├── fxmanifest.lua
        ├── config.lua
        ├── install.sql
        ├── README.md
        ├── server/
        │   ├── main.lua
        │   ├── room.lua
        │   └── game.lua
        ├── client/
        │   ├── main.lua
        │   ├── ui.lua
        │   ├── game.lua
        │   └── effects.lua
        └── html/
            ├── index.html
            ├── style.css
            ├── script.js
            ├── sounds/
            │   └── placeholder.txt
            └── images/
                └── placeholder.txt
```

### 2. 數據庫設置
```sql
-- 在MySQL中執行install.sql文件
SOURCE path/to/sun_fishgame/install.sql;
```

### 3. 服務器配置
在`server.cfg`中添加：
```cfg
# 確保依賴項已啟動
ensure es_extended
ensure oxmysql

# 啟動魚機遊戲
ensure sun_fishgame
```

### 4. 依賴檢查
確保以下資源已正確安裝：
- ✅ es_extended
- ✅ oxmysql

## ⚙️ 配置說明

### 基本設置 (`config.lua`)
```lua
-- 貨幣設定
Config.Currency = 'money'        -- ESX貨幣類型
Config.MinBet = 100             -- 最小下注金額
Config.MaxBet = 50000           -- 最大下注金額

-- 更新間隔
Config.UpdateInterval = 100      -- 遊戲更新間隔(ms)
```

### 房間配置
```lua
Config.Rooms = {
    ['room_1'] = {
        name = '初級海域',
        maxPlayers = 6,
        minBet = 100,
        maxBet = 5000,
        position = vector3(1115.0, 220.0, -49.0),
        access = 'public'
    }
    -- 更多房間配置...
}
```

### 魚類配置
```lua
Config.FishTypes = {
    ['small_fish_1'] = {
        name = '丑魚',
        points = 2,
        health = 1,
        spawnChance = 25.0,
        -- 更多屬性...
    }
    -- 更多魚類配置...
}
```

## 🎯 遊戲規則

### 基本玩法
1. **進入房間** - 選擇合適的房間並設定下注金額
2. **選擇武器** - 根據目標魚類選擇合適的武器
3. **瞄準射擊** - 使用滑鼠瞄準並射擊魚類
4. **累積分數** - 成功捕獲魚類獲得分數和金幣
5. **使用技能** - 在關鍵時刻使用特殊技能

### 分數系統
- **小魚** (1-10分) - 容易捕獲，分數較低
- **中魚** (10-50分) - 中等難度，適中分數
- **大魚** (50-200分) - 較難捕獲，高分數
- **BOSS魚** (200-1000分) - 極難捕獲，超高分數
- **特殊魚** - 具有特殊效果的魚類

### 武器系統
- **小型砲** - 低成本，適合小魚
- **中型砲** - 中等成本，適合中魚
- **大型砲** - 高成本，適合大魚
- **雷射砲** - 特殊武器，貫穿效果

### 技能系統
- **冰凍全場** - 暫停所有魚類移動
- **雙倍積分** - 短時間內獲得雙倍分數
- **自動瞄準** - 自動鎖定最佳目標

## 🎮 操作指南

### 鍵盤控制
- **滑鼠移動** - 瞄準
- **滑鼠左鍵/空白鍵** - 射擊
- **1-4數字鍵** - 切換武器
- **ESC鍵** - 退出遊戲/關閉選單

### 界面操作
- **E鍵** - 在遊戲機附近互動進入遊戲
- **滑鼠點擊** - 所有UI互動
- **滾輪** - 調整下注金額

## 📊 數據庫結構

### 主要數據表
- `fishgame_players` - 玩家數據
- `fishgame_sessions` - 遊戲會話
- `fishgame_catches` - 捕魚記錄
- `fishgame_daily_stats` - 每日統計
- `fishgame_leaderboard` - 排行榜
- `fishgame_rooms` - 房間數據
- `fishgame_settings` - 系統設置

### 性能優化
- 定期清理過期數據
- 索引優化查詢性能
- 分批處理大量數據

## 🔧 自定義開發

### 添加新魚類
```lua
-- 在config.lua中添加
Config.FishTypes['new_fish'] = {
    name = '新魚類',
    points = 50,
    health = 3,
    speed = 2.0,
    size = 1.2,
    spawnChance = 5.0,
    color = {r = 255, g = 0, b = 0}
}
```

### 添加新武器
```lua
-- 在config.lua中添加
Config.Weapons['new_cannon'] = {
    name = '新砲台',
    damage = 4,
    cost = 60,
    fireRate = 300,
    range = 800,
    unlockLevel = 15
}
```

### 修改遊戲位置
```lua
-- 修改房間位置
Config.Rooms['room_1'].position = vector3(x, y, z)
```

## 🐛 故障排除

### 常見問題

**問題：遊戲無法啟動**
```bash
# 檢查依賴項
ensure es_extended
ensure oxmysql

# 檢查數據庫連接
# 確保MySQL服務正常運行

# 檢查資源啟動順序
ensure es_extended
ensure oxmysql
ensure sun_fishgame
```

**問題：FishGame nil value 錯誤**
```lua
-- 已修復：確保所有服務端腳本都能訪問FishGame變數
-- 解決方案已包含在代碼中
```

**問題：數據庫錯誤**
```sql
-- 檢查表是否存在
SHOW TABLES LIKE 'fishgame_%';

-- 重新導入數據庫
SOURCE install.sql;
```

**問題：UI不顯示**
```lua
-- 檢查NUI資源是否正確載入
-- 確保html文件路徑正確
```

### 日誌檢查
```bash
# 查看服務器日誌
tail -f server.log | grep fishgame

# 查看客戶端錯誤
F8 控制台
```

## 📝 更新日誌

### v1.0.0 (2024-01-01)
- ✅ 初始版本發布
- ✅ 完整魚機遊戲功能
- ✅ ESX 1.12 整合
- ✅ 多人房間系統
- ✅ 排行榜和統計系統

## 🤝 技術支持

### 聯繫方式
- **Discord** - [加入我們的Discord服務器](discord_link)
- **GitHub** - [提交Issue](github_link)
- **論壇** - [官方論壇](forum_link)

### 反饋和建議
歡迎提供以下反饋：
- 🐛 Bug報告
- 💡 功能建議
- 🎨 UI/UX改進
- ⚡ 性能優化建議

## 📄 授權條款

本插件遵循 MIT 授權條款。詳細內容請參閱 LICENSE 文件。

### 使用限制
- ✅ 可自由使用和修改
- ✅ 可用於商業用途
- ✅ 可重新分發
- ❌ 不得移除版權聲明

## 🙏 致謝

感謝以下項目和開發者：
- **ESX Framework** - 提供優秀的框架基礎
- **FIVEM Community** - 活躍的開發者社群
- **Beta測試玩家** - 提供寶貴的測試反饋

---

**享受遊戲！🎣**

> 如果這個插件對您有幫助，請考慮給我們一個⭐Star！ 