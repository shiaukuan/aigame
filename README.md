# CyberDesk — 資安與 AI 意識考核遊戲

一款以 Godot 4.6 開發的互動式企業資安培訓遊戲，模擬 Windows 11 桌面環境，透過 15 個關卡測驗員工的**資訊安全意識**與**生成式 AI 正確使用觀念**。

**線上試玩**: https://game.itsmygo.uk

## 目錄

- [遊戲概念](#遊戲概念)
- [技術規格](#技術規格)
- [專案結構](#專案結構)
- [程式架構](#程式架構)
  - [Autoload 單例系統](#autoload-單例系統)
  - [關卡處理器模式](#關卡處理器模式)
  - [Signal 驅動的關卡生命週期](#signal-驅動的關卡生命週期)
  - [Desktop 委派模式](#desktop-委派模式)
- [關卡一覽](#關卡一覽)
- [計分系統](#計分系統)
- [執行與開發](#執行與開發)
- [Web 部署架構](#web-部署架構)

---

## 遊戲概念

玩家在模擬的 Windows 11 桌面環境中，操作郵件、瀏覽器、檔案總管、設定等桌面應用程式來完成各關挑戰。每一關模擬一個真實的職場資安或 AI 使用情境，玩家必須做出正確判斷才能過關。

**目標對象**：一般企業員工（非技術背景）

**核心玩法**：

```
關卡開始 → 顯示謎題提示 → 玩家在桌面自由探索 → 完成任務 → 系統判定過關 → 教學解說 → 下一關
```

**兩種過關機制**：

| 類型 | 說明 | 範例 |
|------|------|------|
| 找到正確答案 | 從桌面環境中辨識線索並選擇 | 從多封郵件中找出釣魚信 |
| 完成操作流程 | 依序完成一系列正確操作步驟 | 發現可疑檔案 → 右鍵回報 → 通知 IT |

---

## 技術規格

| 項目 | 規格 |
|------|------|
| 遊戲引擎 | Godot 4.6.2 |
| 程式語言 | GDScript |
| 渲染器 | GL Compatibility |
| 設計解析度 | 1280×720（content_scale_size） |
| 視窗大小 | 2560×1440 |
| UI 語言 | 繁體中文 |
| 部署平台 | Web（Cloudflare Pages） |
| 場景數量 | 1（`desktop.tscn`，所有 UI 皆以 GDScript 動態建構） |

**字型支援**（支援 CJK + Emoji）：

```
NotoSansTC → SegoeUIEmoji → NotoEmoji → NotoSansSymbols2
```

---

## 專案結構

```
aigame/
├── desktop.tscn                # 唯一場景檔
├── desktop.gd                  # 主 UI 控制器（~2000 行）
├── project.godot               # Godot 專案設定（含 Autoload 定義）
├── deploy.sh                   # 自動化部署腳本
├── icon.svg                    # 遊戲圖示
│
├── scripts/
│   ├── game_state.gd           # 單例：每關玩家狀態
│   ├── score_manager.gd        # 單例：跨關卡計分
│   ├── level_manager.gd        # 單例：關卡生命週期管理
│   ├── level_data.gd           # 關卡資料 Resource 定義
│   ├── summary_screen.gd       # 最終成績總覽畫面
│   └── levels/                 # 15 個關卡處理器
│       ├── level_01_phishing.gd
│       ├── level_02_password.gd
│       ├── ...
│       └── level_15_data_leak.gd
│
├── fonts/                      # 多語系字型
│   ├── NotoSansTC-Regular.ttf
│   ├── SegoeUIEmoji.ttf
│   ├── NotoEmoji.ttf
│   └── NotoSansSymbols2-Regular.ttf
│
├── docs/                       # 設計文件
│   ├── game-design.md          # 遊戲概念與機制
│   ├── levels.md               # 15 關詳細規格
│   ├── puzzle-hints.md         # 各關謎語標題與提示
│   └── architecture.md         # 架構設計文件
│
├── build/web/                  # Web 輸出（已追蹤於 Git）
│   ├── index.html              # HTML 進入點
│   ├── index.js                # Godot JS Runtime
│   ├── index.wasm              # 編譯後遊戲（gzip 壓縮）
│   ├── index.pck               # 遊戲資料封包
│   ├── _worker.js              # Cloudflare Pages Function
│   └── _headers                # HTTP 標頭設定
│
└── .github/workflows/          # CI/CD 管線
    ├── claude.yml              # Claude Code GitHub 整合
    └── claude-code-review.yml  # 自動化 Code Review
```

---

## 程式架構

### 整體架構圖

```
┌─────────────────────────────────────────────────────────┐
│                     desktop.tscn                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │               desktop.gd (~2000 行)               │  │
│  │  主 UI 控制器：桌面佈局、視窗管理、應用程式、     │  │
│  │  關卡 UI 覆蓋層（intro/result/summary）            │  │
│  └──────────────────┬────────────────────────────────┘  │
│                     │ 委派（delegation）                 │
│  ┌──────────────────▼────────────────────────────────┐  │
│  │          LevelManager.current_handler             │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │     level_XX_name.gd (RefCounted)           │  │  │
│  │  │  - get_level_data()                         │  │  │
│  │  │  - setup_desktop()                          │  │  │
│  │  │  - build_app_content()                      │  │  │
│  │  │  - check_completion()                       │  │  │
│  │  │  - calculate_score()                        │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────────┐  │
│  │  GameState   │ │ ScoreManager │ │  LevelManager    │  │
│  │  每關狀態    │ │ 跨關計分     │ │  關卡生命週期    │  │
│  │  (Autoload)  │ │ (Autoload)   │ │  (Autoload)      │  │
│  └─────────────┘ └──────────────┘ └──────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Autoload 單例系統

專案使用三個 Autoload 單例（在 `project.godot` 中註冊），任何腳本皆可直接以全域名稱存取：

#### GameState（`scripts/game_state.gd`）

每關重置的玩家操作記錄。

```gdscript
var selected_emails: Array[int] = []       # 第 1 關專用
var actions_taken: Array[Dictionary] = []  # 正確/中性操作
var wrong_actions: Array[Dictionary] = []  # 錯誤操作

func record_action(action, detail)         # 記錄正確操作
func record_wrong_action(action, detail)   # 記錄錯誤操作
func reset()                               # 每關開始時自動呼叫
```

#### ScoreManager（`scripts/score_manager.gd`）

跨關卡持久化的計分系統。

```gdscript
var scores: Dictionary = {}    # {level_id: 分數}
var attempts: Dictionary = {}  # {level_id: 嘗試次數}

func record_score(level_id, score)
func increment_attempts(level_id)
func get_total_score() -> int        # 總分
func get_max_score() -> int          # 滿分（15 × 100 = 1500）
func is_passing() -> bool            # 是否及格（≥ 70%）
```

#### LevelManager（`scripts/level_manager.gd`）

關卡生命週期編排器，管理關卡載入、啟動、完成的全過程。

```gdscript
signal show_intro_requested(level_data)     # 顯示關卡介紹
signal level_started(level_id)              # 關卡正式開始
signal show_result_requested(level_id, score, passed)  # 顯示結果

var current_handler: RefCounted = null      # 當前關卡處理器實例
var level_active: bool = false              # 關卡是否進行中

func load_level(level_id)    # 載入關卡 → 重置狀態 → 發射 intro signal
func start_level()           # 啟動關卡 → 發射 level_started signal
func complete_level(score)   # 過關 → 記錄分數 → 發射 result signal
func fail_level()            # 放棄 → 記錄 30 分 → 發射 result signal
```

### 關卡處理器模式

每個關卡是一個獨立的 `RefCounted` 腳本（`scripts/levels/level_XX_name.gd`），實作五個必要方法。處理器自行擁有 UI 建構、狀態管理、驗證邏輯和計分邏輯，完全自包含。

```gdscript
extends RefCounted

# 必要方法
func get_level_data() -> Resource         # 回傳 LevelData（標題、提示、教學要點）
func setup_desktop(desktop) -> void       # 關卡開始時設定桌面（如閃爍圖示）
func build_app_content(app_name, panel, desktop) -> bool
                                          # 覆寫應用程式內容；回傳 true 表示已處理
func check_completion() -> Dictionary     # 回傳 {passed: bool, details: String}
func calculate_score() -> int             # 回傳 100（首次通過）或 60（重試）

# 選用方法（desktop.gd 透過 has_method() 自動偵測）
func on_file_open(file_name, desktop) -> bool      # 攔截桌面檔案雙擊
func on_ctx_action(action, data, icon_type, target, desktop) -> bool  # 攔截右鍵選單
```

**兩種互動模式**：

| 模式 | 說明 | 範例 |
|------|------|------|
| **Pattern A: App-Based** | 覆寫特定應用程式 UI，在 app 視窗內放置「完成作答」按鈕 | 第 1 關覆寫「郵件」app |
| **Pattern B: Desktop-Based** | 不覆寫任何 app，透過 `on_file_open()` / `on_ctx_action()` 攔截桌面互動 | 第 4 關直接在桌面操作檔案 |

### Signal 驅動的關卡生命週期

```
玩家選擇關卡
       │
       ▼
LevelManager.load_level(id)
  ├── GameState.reset()
  ├── 建立 handler 實例
  └── emit show_intro_requested ──→ desktop.gd 顯示 intro 覆蓋層
       │
       ▼  玩家點擊「開始」
LevelManager.start_level()
  ├── level_active = true
  └── emit level_started ──→ desktop.gd 呼叫 handler.setup_desktop()
       │
       ▼  玩家與桌面互動
desktop.gd ──→ handler.build_app_content() 建構關卡 UI
GameState ←── 記錄玩家操作
       │
       ▼  玩家點擊「完成作答」
handler.check_completion()
  ├── 通過 → LevelManager.complete_level(score)
  │            └── emit show_result_requested ──→ 顯示結果覆蓋層
  └── 失敗 → 顯示 feedback box（≥3 次失敗後出現「查看解答」按鈕）
       │
       ▼
下一關 / 最終成績總覽
```

### Desktop 委派模式

`desktop.gd`（約 2000 行）是整個遊戲的主 UI 控制器，負責：

- **桌面佈局**：app 圖示（左側）、桌面檔案（右側）、工作列（底部）
- **視窗管理**：應用程式視窗的開啟、拖曳、關閉
- **關卡覆蓋層**：intro、result、summary 畫面
- **右鍵選單**：檔案的右鍵操作（開啟、掃描病毒、回報並刪除等）

**委派邏輯**：當玩家在關卡進行中開啟一個 app 時——

```
1. 呼叫 handler.build_app_content(app_name, panel, desktop)
2. handler 回傳 true  → 使用關卡自訂 UI
3. handler 回傳 false → 使用 desktop.gd 預設 app 內容
```

這個設計讓 `desktop.gd` 完全不需要知道任何關卡細節，新增關卡時也不需要修改它的委派邏輯。

### 桌面應用程式

模擬的 Windows 11 桌面提供以下應用程式與檔案：

**應用程式（13 個）**：

| 圖示 | 名稱 | 用途 |
|------|------|------|
| 💻 | 此電腦 | 電腦 |
| 🗑️ | 資源回收筒 | 回收筒 |
| 🌐 | Microsoft Edge | 瀏覽器 |
| 📁 | 檔案總管 | 檔案管理 |
| 📧 | 郵件 | 電子郵件 |
| ⚙️ | 設定 | 系統設定 |
| 💬 | 通訊軟體 | 即時通訊 |
| 🤖 | AI 助手 | AI 助手 |
| 🛡️ | AI客服後台 | AI 後台管理 |
| 🖥️ | 程式碼編輯器 | 程式編輯（模擬 VS Code） |
| 📝 | 記事本 | 記事本 |
| 🔢 | 計算機 | 計算機 |
| 📝 | 關卡提示.docx | 關卡提示檔（自動填入當前關卡提示） |

**桌面檔案（12 個）**：各關卡根據情境選擇性顯示的右側桌面檔案（如可疑執行檔、機密文件等）。

---

## 關卡一覽

| 關卡 | 謎語標題 | 主題 | 類別 | 難度 |
|------|---------|------|------|------|
| 1 | 水面下的鉤子 | 釣魚郵件辨識 | 資安 | ★☆☆ |
| 2 | 紙做的鎖 | 密碼安全設定 | 資安 | ★☆☆ |
| 3 | 窗戶上的寄生蟲 | 瀏覽器擴充套件審查 | 資安 | ★★☆ |
| 4 | 不請自來的客人 | 可疑檔案處理 | 資安 | ★★☆ |
| 5 | 空氣中的陷阱 | 公共 WiFi 安全 | 資安 | ★★☆ |
| 6 | 特洛伊的禮物 | USB 裝置安全 | 資安 | ★★★ |
| 7 | 守門人的選擇 | AI 資料分級 | AI | ★★☆ |
| 8 | 披著羊皮的工具 | AI 工具合規使用 | AI | ★★☆ |
| 9 | 自信的騙子 | AI 幻覺辨識 | AI | ★★☆ |
| 10 | 咒語破解師 | Prompt Injection 攻擊防範 | AI | ★★★ |
| 11 | 正確的配方 | AI 工具正確使用方式 | AI | ★★☆ |
| 12 | 看不見的裂縫 | 程式碼安全審查 | AI | ★★★ |
| 13 | 夾帶的鑰匙 | Git Push 安全 | 資安 | ★★☆ |
| 14 | 門牌掛錯地方 | 電子郵件合規使用 | 資安 | ★☆☆ |
| 15 | 曬在陽光下的秘密 | 機密資料外洩防範 | 資安 | ★★☆ |

---

## 計分系統

| 表現 | 分數 |
|------|------|
| 首次通過，無錯誤操作 | 100 分 |
| 重試後通過 / 有錯誤操作 | 60 分 |
| 放棄（3 次失敗後查看解答） | 30 分 |

- **滿分**：15 關 × 100 = 1500 分
- **及格標準**：總分 ≥ 70%（1050 分）
- 失敗 3 次後會出現「查看解答」按鈕，點擊後自動獲得 30 分並顯示教學內容

---

## 執行與開發

### 前置需求

- [Godot 4.6.2](https://godotengine.org/download/) 或以上版本

### 本地執行

直接用 Godot 編輯器開啟專案資料夾，按 F5 執行。無需額外的建置步驟。

### 新增關卡

1. 閱讀 `docs/levels.md` 和 `docs/puzzle-hints.md` 中的關卡規格
2. 建立 `scripts/levels/level_XX_name.gd`（實作 5 個必要方法）
3. 在 `scripts/level_manager.gd` 的 `level_scripts` 字典中註冊
4. 不需要修改 `desktop.gd`——委派機制自動運作

### 開發者模式

`desktop.gd` 中的 `DEV_MODE` 常數設為 `true` 時，啟動後會直接顯示關卡選擇畫面，方便開發測試。

---

## Web 部署架構

### 部署流程

```
Godot Export (Web) → gzip 壓縮 wasm → git push master → Cloudflare Pages 自動部署
```

執行部署腳本：

```bash
bash deploy.sh "commit 訊息"
```

腳本自動完成：
1. Godot headless export（若有 Godot 執行檔）
2. 偵測並壓縮 `index.wasm`（35MB → 9MB，符合 Cloudflare Pages 25MB 檔案上限）
3. Git commit & push 到 `master`
4. Cloudflare Pages 約 30-40 秒內自動部署

### Cloudflare Pages 架構

```
瀏覽器請求
    │
    ▼
Cloudflare Pages
    │
    ├── /index.wasm ──→ _worker.js（Cloudflare Pages Function）
    │                     ├── 讀取 gzip 壓縮的 wasm
    │                     ├── DecompressionStream 即時解壓
    │                     └── 設定 COOP/COEP 標頭（SharedArrayBuffer 必要）
    │
    └── 其他檔案 ──→ 直接提供靜態資源
                       └── 加上 COOP/COEP 標頭
```

**關鍵設計**：`index.wasm` 以 gzip 格式儲存在 Git 中（繞過 25MB 限制），透過 Cloudflare Pages Function (`_worker.js`) 在 runtime 解壓後回傳給瀏覽器。

### 線上網址

- **主要**：https://game.itsmygo.uk
- **備用**：https://aigame-8jz.pages.dev

---

## 設計文件

| 文件 | 說明 |
|------|------|
| [`docs/game-design.md`](docs/game-design.md) | 遊戲概念、計分機制、UI 設計原則 |
| [`docs/levels.md`](docs/levels.md) | 15 關完整規格（情境、通過條件、教學要點） |
| [`docs/puzzle-hints.md`](docs/puzzle-hints.md) | 各關謎語標題、情境描述、任務提示 |
| [`docs/architecture.md`](docs/architecture.md) | 原始架構規劃文件 |

---

## 授權

本專案為企業內部資安培訓用途開發。
