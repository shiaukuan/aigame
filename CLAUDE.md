# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CyberDesk: A Godot 4.6 cybersecurity awareness training game that simulates a Windows 11 desktop. Players complete levels by interacting with desktop apps (email, settings, chat, etc.) to demonstrate security knowledge.

- **Engine**: Godot 4.6.2, GDScript, GL Compatibility renderer
- **Design resolution**: 1280x720 (content_scale_size), window 2560x1440
- **UI language**: Traditional Chinese
- **Single scene**: `desktop.tscn` — all UI is built programmatically in GDScript

## Running the Project

```bash
# Via Godot MCP
mcp__godot__run_project(projectPath="C:\Users\User\work\work2026\aigame")
mcp__godot__get_debug_output()
mcp__godot__stop_project()
```

No build step required. The project runs directly from Godot.

## Architecture

### Autoload Singletons (project.godot)

| Singleton | File | Responsibility |
|-----------|------|----------------|
| `GameState` | `scripts/game_state.gd` | Per-level state: player actions, email selections, wrong actions. Reset each level. |
| `ScoreManager` | `scripts/score_manager.gd` | Persistent across levels: scores, attempts, pass/fail (70% threshold). |
| `LevelManager` | `scripts/level_manager.gd` | Level lifecycle: load/start/complete/fail. Holds `current_handler` and emits signals. |

### Level Handler Pattern

Each level is a `RefCounted` script in `scripts/levels/` with this interface:

```gdscript
func get_level_data() -> Resource          # LevelData with title, hints, teaching points
func setup_desktop(desktop: Node) -> void  # Configure desktop (e.g., flash taskbar icon)
func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool
                                           # Override app content; return true if handled
func check_completion() -> Dictionary      # Return {passed: bool, details: String, ...}
func calculate_score() -> int              # Return 100 (first try) or 60 (retry)
```

Handlers are self-contained: they own their UI building, data, validation, and scoring. They access `GameState`, `ScoreManager`, `LevelManager` as globals.

### Adding a New Level

1. Create `scripts/levels/level_XX_name.gd` extending `RefCounted`
2. Implement the 5 handler methods above
3. Add to `level_manager.gd`'s `level_scripts` dict:
   ```gdscript
   XX: preload("res://scripts/levels/level_XX_name.gd"),
   ```
4. No changes needed to `desktop.gd` — delegation is automatic
5. Level flow (intro → next level → summary) is handled generically

### Signal-Driven Level Lifecycle

```
LevelManager.load_level(id)
  → GameState.reset()
  → emit show_intro_requested → desktop shows intro overlay
  → player clicks "開始"
  → LevelManager.start_level()
    → emit level_started → desktop calls handler.setup_desktop()
  → player interacts → GameState records actions
  → player clicks "完成作答" → handler.check_completion()
  → LevelManager.complete_level(score)
    → emit show_result_requested → desktop shows result overlay
  → "下一關 →" or summary_screen.gd if last level
```

### Desktop.gd Delegation

`desktop.gd` (~2000 lines) is the main UI controller. When opening an app during an active level:

1. `LevelManager.current_handler.build_app_content(title, panel, self)` is called first
2. If handler returns `true`, it built the content (level-specific UI)
3. If `false`, desktop falls back to its default app content builder

### Level Hints File on Desktop

The desktop has a `關卡提示.docx` icon (left side, col 2 row 0 in `app_icons`). When opened, it shows the current level's `puzzle_title`, `scenario_text`, and `task_hint` from `get_level_data()`. This is implemented in `_get_level_hint_content()` in `desktop.gd`. Every level must populate these three fields in its `get_level_data()` so the hints file works.

### Key Conventions

- All UI is built programmatically (no `.tscn` for apps/windows)
- `_sb(color, radius)` helper creates `StyleBoxFlat` instances
- Level handlers include their own copy of `_sb()` since they're `RefCounted`, not scene nodes
- Feedback boxes use two styles: `_show_feedback_box()` (warning, orange) and `_show_feedback_box_success()` (success, green)
- `LevelData` uses `preload("res://scripts/level_data.gd")` as `LevelDataScript` because `class_name` discovery can fail without editor import

## Web Deployment (Cloudflare Pages)

- **URL**: `https://game.itsmygo.uk` (also `https://aigame-8jz.pages.dev`)
- **CD**: Push to `master` triggers auto-deploy via Cloudflare Pages
- **Repo**: `skcht/aigame` on GitHub

### Deploying code changes to web

After modifying GDScript, you must re-export and deploy:

1. **Export Web** in Godot (Project → Export → Web → Export Project to `build/web/`)
2. **Run deploy script**: `bash deploy.sh`

The script handles: gzip compress `index.wasm` (35MB→9MB, Cloudflare Pages has 25MB file limit) → git commit → push to master.

### Web build architecture

- `build/web/_worker.js` — Cloudflare Pages Function that:
  - Decompresses gzipped `index.wasm` via `DecompressionStream` at runtime
  - Sets `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers (required by Godot for `SharedArrayBuffer`)
- `build/web/_headers` — Fallback headers config
- `build/web/index.wasm` — Stored as gzip-compressed (not raw wasm) to fit under 25MB limit

## Design Documents

- `docs/game-design.md` — Game concept, scoring system (100/60/30), UI principles
- `docs/levels.md` — All 15 level specs (scenarios, pass conditions, teaching points)
- `docs/puzzle-hints.md` — Riddle titles, scenario text, task hints per level
- `docs/architecture.md` — Original architecture plan (partially outdated)

---

## Level Development Guide (獨立開發關卡用)

This section provides everything needed to independently develop a new level (5→15). Read this entire section before starting.

### Step-by-Step: Creating a New Level

1. **Read the level spec** in `docs/levels.md` and `docs/puzzle-hints.md` for your assigned level number
2. Create `scripts/levels/level_XX_name.gd` (e.g., `level_05_wifi.gd`)
3. Register in `scripts/level_manager.gd` → add to `level_scripts` dict:
   ```gdscript
   XX: preload("res://scripts/levels/level_XX_name.gd"),
   ```
4. If the level needs new desktop files or apps, add them to the `desktop_files` or `app_icons` arrays in `desktop.gd` (at the top of the file)
5. **Do NOT modify** `desktop.gd`'s delegation logic — it's already generic

### Required File Template

Every level handler MUST follow this exact structure:

```gdscript
extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Level-specific state vars here (e.g., var _removed: Array[int] = [])

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = XX
	data.title = "謎語標題"        # From docs/puzzle-hints.md
	data.category = "security"     # or "ai"
	data.difficulty = 1            # 1-3
	data.puzzle_title = "謎語標題"  # MUST match title — shown in hints file
	data.scenario_text = "..."     # MUST populate — shown in hints file
	data.task_hint = "..."         # MUST populate — shown in hints file
	data.teaching_points = PackedStringArray([...])
	data.desktop_config = {}       # {"highlight_app": "AppName"} or {}
	return data

func setup_desktop(desktop: Node) -> void:
	# Called once when level starts (after player clicks 開始)
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	# Return true if you built custom content, false to use default
	return false

func check_completion() -> Dictionary:
	# MUST return {"passed": bool, "details": String, ...}
	return {"passed": false, "details": "..."}

func calculate_score() -> int:
	var attempt_count := ScoreManager.get_attempts(LevelManager.current_level)
	var has_wrong := GameState.wrong_actions.size() > 0
	if attempt_count == 1 and not has_wrong:
		return 100
	return 60

# MUST include this helper (RefCounted can't inherit from scene nodes)
func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s
```

### Two Level Interaction Patterns

**Pattern A: App-Based (Levels 1-3, 5-15 most levels)**
- Override a specific app via `build_app_content()` returning `true`
- Build UI inside the `panel` parameter (size ~640×408)
- Place a `📋 完成作答` button inside the app window
- Example: Level 1 overrides "郵件", Level 2 overrides "設定", Level 3 overrides "Microsoft Edge"

**Pattern B: Desktop-Based (Level 4)**
- `build_app_content()` returns `false` for all apps
- Uses optional methods `on_file_open()` and `on_ctx_action()` to intercept desktop interactions
- Places floating `📋 完成作答` button directly on desktop (z_index=50)
- desktop.gd checks `handler.has_method("on_file_open")` / `handler.has_method("on_ctx_action")` before calling

### Optional Handler Methods (desktop.gd auto-detects via has_method)

```gdscript
# Intercept double-click on desktop file icons
# Return true if handled (prevents default behavior)
func on_file_open(file_name: String, desktop: Node) -> bool:

# Intercept right-click context menu actions on desktop icons
# action: "開啟"|"檢視內容"|"掃描病毒"|"回報並刪除"|"刪除"|"重新命名"|"以系統管理員身分執行"
# icon_type: "app" or "file"
func on_ctx_action(action: String, data: Dictionary, icon_type: String, target: Control, desktop: Node) -> bool:
```

### Available Global APIs

**GameState** (reset each level automatically):
- `GameState.record_action(action: String, detail: Variant = null)` — record a correct/neutral player action
- `GameState.record_wrong_action(action: String, detail: Variant = null)` — record a mistake
- `GameState.actions_taken: Array[Dictionary]` — `[{"action": str, "detail": variant}, ...]`
- `GameState.wrong_actions: Array[Dictionary]` — same format
- `GameState.selected_emails` / `toggle_email_selected()` / `is_email_selected()` — only used by Level 1

**ScoreManager** (persistent across levels):
- `ScoreManager.increment_attempts(level_id)` — call in `_on_finish_pressed` before checking
- `ScoreManager.get_attempts(level_id) -> int`

**LevelManager**:
- `LevelManager.level_active: bool` — check this in button handlers
- `LevelManager.current_level: int`
- `LevelManager.complete_level(score: int)` — call when passed (triggers result overlay)
- `LevelManager.fail_level()` — call from give-up button (scores 30 points)

### Standard _on_finish_pressed Pattern (MUST follow)

Every level needs this exact flow in its finish button handler:

```gdscript
func _on_finish_pressed(parent: Panel) -> void:  # or (desktop: Node) for Pattern B
	if not LevelManager.level_active:
		return
	var lid := LevelManager.current_level
	ScoreManager.increment_attempts(lid)
	var result := check_completion()

	if result["passed"]:
		var score := calculate_score()
		LevelManager.complete_level(score)
	else:
		_show_feedback_box(parent, result["details"])
		# Show give-up button after 3 failed attempts
		if ScoreManager.get_attempts(lid) >= 3:
			var existing := parent.get_node_or_null("GiveUpBtn")
			if not existing:
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				# ... position/style ...
				gub.pressed.connect(func(): LevelManager.fail_level())
				parent.add_child(gub)
```

### Standard Feedback Box Pattern (copy into every handler)

Every handler MUST include both `_show_feedback_box()` (orange/warning) and `_show_feedback_box_success()` (green). Copy the implementation from any existing level (e.g., Level 1 lines 456-548). Key specs:
- Box name: `"FeedbackBox"` (always remove old one first via `get_node_or_null`)
- Warning: bg `Color(1.0, 0.95, 0.9)`, border `Color(0.9, 0.6, 0.2)`, text `Color(0.4, 0.25, 0.05)`
- Success: bg `Color(0.92, 0.98, 0.92)`, border `Color(0.3, 0.75, 0.3)`, text `Color(0.1, 0.4, 0.1)`
- Include ✕ close button
- `z_index = 10`

### setup_desktop Common Patterns

**Flashing taskbar icon** (draws attention to the target app):
```gdscript
func setup_desktop(desktop: Node) -> void:
	var taskbar := desktop.get_node_or_null("Taskbar")
	if taskbar:
		for child in taskbar.get_children():
			if child is Button and child.text.find("EMOJI") >= 0:  # e.g., "📧", "⚙️", "🌐"
				var timer := Timer.new()
				timer.name = "UniqueTimerName"
				timer.wait_time = 0.6
				timer.autostart = true
				desktop.add_child(timer)
				var btn := child
				timer.timeout.connect(func():
					if is_instance_valid(btn):
						btn.modulate = Color.YELLOW if btn.modulate == Color.WHITE else Color.WHITE
				)
				break
```

**Hiding irrelevant desktop files** (for desktop-interaction levels):
```gdscript
var file_container := desktop.get_node_or_null("DesktopFiles")
if file_container:
	for child in file_container.get_children():
		var data = child.get_meta("icon_data")
		# Hide files not relevant to this level
		if data["name"] not in my_relevant_files:
			child.visible = false
```

### Available Desktop Apps (app_icons in desktop.gd)

| Name | Emoji | Purpose |
|------|-------|---------|
| 此電腦 | 💻 | Computer |
| 資源回收筒 | 🗑️ | Recycle Bin |
| Microsoft Edge | 🌐 | Browser |
| 檔案總管 | 📁 | File Explorer |
| 郵件 | 📧 | Email |
| 設定 | ⚙️ | Settings |
| 通訊軟體 | 💬 | Chat/Messaging |
| AI 助手 | 🤖 | AI Assistant |
| AI客服後台 | 🛡️ | AI Customer Service Backend |
| 程式碼編輯器 | 🖥️ | Code Editor (simulated VS Code) |
| 記事本 | 📝 | Notepad |
| 計算機 | 🔢 | Calculator |
| 關卡提示.docx | 📝 | Level hints (auto-populated) |

### Available Desktop Files (desktop_files in desktop.gd)

Files on the right side of the desktop. Some are used by specific levels:
- Level 4 files: 會議記錄.docx, 薪資表_2024.xlsx.exe, free_vpn_setup.exe, 照片.jpg, system_update.bat
- Level 7 files: 公開新聞稿.docx, 客戶個資名冊.xlsx, 產品使用手冊.pdf, 未公開財報.xlsx, 內部薪資結構.docx
- Level 11 files: AI使用規範.pdf, 客戶需求摘要.docx

If your level needs additional files, add them to the `desktop_files` array in `desktop.gd` (follow existing format with col/row positioning).

### Context Menu Actions Available

When player right-clicks a desktop icon, these actions appear:
`"開啟"`, `"以系統管理員身分執行"`, `"檢視內容"`, `"掃描病毒"`, `"回報並刪除"`, `"重新命名"`, `"刪除"`

### UI Style Conventions

- **Font sizes**: titles 17-22, body 12-13, secondary text 11
- **Colors**: dark text `Color(0.1-0.2)`, secondary text `Color(0.4-0.5)`, links `Color(0.15, 0.35, 0.7)`
- **Buttons**: primary blue `Color(0.2, 0.5, 0.9)`, danger red `Color(0.75-0.8, 0.2-0.25, 0.2-0.25)`, disabled gray `Color(0.5, 0.5, 0.55)`
- **App window panel size**: ~640×408 (the `panel` param in `build_app_content`)
- **Sidebar pattern**: width ~150-170px, bg `Color(0.94, 0.94, 0.96)`, items 34px height
- **Toast notifications** (for Pattern B): position around `Vector2(380, 580)`, size `Vector2(520, 56)`, z_index=180, auto-dismiss 4s

### Critical Gotchas

1. **Must use `const LevelDataScript = preload("res://scripts/level_data.gd")`** — do NOT use `LevelData` class_name directly
2. **Must copy `_sb()` into every handler** — `RefCounted` can't access scene tree helpers
3. **Must copy feedback box methods** into every handler — they're not shared
4. **puzzle_title, scenario_text, task_hint are REQUIRED** — the 關卡提示.docx file reads them
5. **check_completion() MUST return `{"passed": bool, "details": String}`** — `details` is shown to player on failure
6. **Call `ScoreManager.increment_attempts()` BEFORE `check_completion()`** in `_on_finish_pressed`
7. **Always check `LevelManager.level_active`** at the start of button handlers
8. **Stop flash timers** when the target app is opened (see Level 2-3 for examples)
9. **Lambda captures**: when connecting signals in loops, capture loop vars with `var idx := i` before the lambda
10. **All UI text must be Traditional Chinese (繁體中文)**
11. **Scoring is standardized**: 100 (first try, no wrong actions), 60 (retry or had wrong actions), 30 (give up)
12. **Give-up button** appears after `ScoreManager.get_attempts(lid) >= 3`, calls `LevelManager.fail_level()`
13. **desktop.gd node paths**: taskbar is `"Taskbar"`, desktop files container is `"DesktopFiles"`, each icon has `get_meta("icon_data")` and `get_meta("icon_type")`
