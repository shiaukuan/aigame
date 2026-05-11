# 技術架構文件

## 架構總覽

```
res://
├── desktop.tscn / desktop.gd        # 主桌面場景（所有關卡共用）
├── scenes/
│   ├── main_menu.tscn               # 主選單
│   ├── level_intro.tscn             # 關卡提示面板
│   ├── level_result.tscn            # 過關結果面板
│   └── apps/                        # 桌面應用程式場景
│       ├── email_app.tscn           # 郵件 App
│       ├── file_manager.tscn        # 檔案總管
│       ├── settings_app.tscn        # 設定
│       ├── browser_app.tscn         # 瀏覽器
│       ├── chat_app.tscn            # 通訊軟體
│       ├── ai_assistant.tscn        # AI 助手
│       ├── code_editor.tscn         # 程式碼編輯器
│       └── wifi_panel.tscn          # WiFi 面板
├── scripts/
│   ├── level_manager.gd             # 關卡管理器（單例）
│   ├── score_manager.gd             # 計分系統（單例）
│   └── game_state.gd               # 遊戲狀態（單例）
├── data/
│   └── levels/                      # 關卡資料（Resource）
│       ├── level_01_phishing.tres
│       ├── level_02_password.tres
│       └── ...
└── docs/                            # 設計文件（本目錄）
```

## 核心系統

### 1. LevelManager（關卡管理器）

**職責**：載入/切換關卡、管理關卡狀態

```gdscript
# scripts/level_manager.gd
extends Node  # 設為 Autoload 單例

var current_level: int = 0
var levels: Array[LevelData] = []

func load_level(level_id: int) -> void
func complete_level(score: int) -> void
func next_level() -> void
func get_level_data() -> LevelData
```

### 2. LevelData（關卡資料）

**職責**：定義每關的設定，用 Godot Resource 實現

```gdscript
# scripts/level_data.gd
class_name LevelData
extends Resource

@export var level_id: int
@export var title: String                    # 關卡名稱
@export var category: String                 # "security" 或 "ai"
@export var difficulty: int                  # 1-3
@export var intro_text: String               # 情境提示文字
@export var objective: String                # 任務目標
@export var hint: String                     # 提示
@export var pass_conditions: Dictionary      # 過關條件
@export var teaching_text: String            # 教學解說
@export var desktop_config: Dictionary       # 桌面設定（哪些App要顯示、桌面檔案等）
@export var completion_type: String          # "answer" 或 "workflow"
```

### 3. ScoreManager（計分系統）

**職責**：記錄分數和考核結果

```gdscript
# scripts/score_manager.gd
extends Node  # 設為 Autoload 單例

var scores: Dictionary = {}     # {level_id: score}
var attempts: Dictionary = {}   # {level_id: attempt_count}

func record_score(level_id: int, score: int) -> void
func get_total_score() -> int
func get_max_score() -> int
func is_passing() -> bool       # 總分 >= 70%
func get_results() -> Dictionary
```

### 4. GameState（遊戲狀態）

**職責**：追蹤當前關卡中的玩家行為

```gdscript
# scripts/game_state.gd
extends Node  # 設為 Autoload 單例

var actions_taken: Array = []           # 玩家做了什麼操作
var items_selected: Array = []          # 玩家選了什麼
var wrong_actions: Array = []           # 錯誤操作記錄

func record_action(action: String) -> void
func check_conditions(conditions: Dictionary) -> bool
func reset() -> void
```

## 桌面系統設計

### 動態桌面

桌面場景（`desktop.tscn`）是所有關卡共用的，每關透過 `LevelData.desktop_config` 動態設定：

```gdscript
# desktop_config 範例
{
    "desktop_icons": ["email", "file_manager", "settings"],
    "taskbar_apps": ["email", "browser", "chat"],
    "extra_files": [
        {"name": "薪資表.xlsx.exe", "type": "suspicious"},
        {"name": "會議記錄.docx", "type": "normal"}
    ],
    "notifications": [
        {"text": "密碼即將過期", "type": "warning"}
    ],
    "background": "office"  # 或 "cafe" 等情境
}
```

### App 視窗系統

每個 App 是一個獨立場景，以假視窗的方式在桌面上開啟：

```
FakeWindow（Panel）
├── TitleBar — 可拖曳、有最小化/最大化/關閉
├── Content — 每個 App 的實際內容
│   └── [各 App 的獨立場景實例]
└── 視窗陰影效果
```

### App 場景列表

| App | 場景 | 使用關卡 |
|-----|------|----------|
| 郵件 | email_app.tscn | 1, 7 |
| 設定 | settings_app.tscn | 2 |
| 通訊軟體 | chat_app.tscn | 3, 4, 6 |
| 檔案總管 | file_manager.tscn | 4, 8, 11 |
| WiFi面板 | wifi_panel.tscn | 5 |
| AI 助手 | ai_assistant.tscn | 8, 11 |
| AI客服後台 | ai_admin.tscn | 10 |
| 程式碼編輯器 | code_editor.tscn | 12 |
| 瀏覽器 | browser_app.tscn | 7, 9 |
| 文件檢視器 | doc_viewer.tscn | 9, 11 |

## 關卡流程時序

```
LevelManager.load_level(id)
  → GameState.reset()
  → 載入 LevelData
  → 顯示 LevelIntro（情境提示面板）
  → 玩家按「開始」
  → Desktop 依 desktop_config 重新配置
  → 玩家自由互動
    → GameState.record_action() 記錄每個操作
  → 觸發過關檢查
    → GameState.check_conditions(pass_conditions)
  → 顯示 LevelResult（結果 + 教學解說）
  → ScoreManager.record_score()
  → LevelManager.next_level() 或回主選單
```

## Autoload 設定

在 `project.godot` 中設為全域單例：

```ini
[autoload]
LevelManager="*res://scripts/level_manager.gd"
ScoreManager="*res://scripts/score_manager.gd"
GameState="*res://scripts/game_state.gd"
```

## 開發順序建議

### Phase 1：基礎框架
1. 重構 desktop.gd，支援動態配置
2. 建立 FakeWindow 通用元件
3. 實作 LevelManager + LevelData
4. 實作關卡提示面板和結果面板
5. 實作主選單

### Phase 2：App 開發
6. 郵件 App（第1關需要）
7. 設定 App（第2關需要）
8. 通訊軟體 App（第3、4、6關需要）
9. 檔案總管 App（第4、8、11關需要）

### Phase 3：更多 App + 關卡
10. WiFi 面板（第5關）
11. AI 助手 App（第8、11關）
12. AI 客服後台 App（第10關）
13. 程式碼編輯器 App（第12關）
14. 瀏覽器/文件檢視器（第7、9關）

### Phase 4：完善
15. 計分系統 + 成績單
16. 音效與動畫
17. HTML5 匯出測試
18. 平衡性測試與調整
