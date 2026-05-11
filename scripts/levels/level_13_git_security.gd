extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# State tracking
var _viewed_env: bool = false          # Player has viewed .env file
var _gitignore_has_env: bool = false   # Player added .env to .gitignore
var _env_unstaged: bool = false        # .env removed from staged list
var _committed: bool = false           # Player clicked commit & push
var _pushed_with_env: bool = false     # Player pushed without fixing .gitignore
var _show_give_up: bool = false        # Show give-up button in git view

# File data
var _files := [
	{"name": "index.js", "icon": "📄", "safe": true, "staged": true},
	{"name": "package.json", "icon": "📦", "safe": true, "staged": true},
	{"name": ".env", "icon": "🔑", "safe": false, "staged": true},
	{"name": "README.md", "icon": "📝", "safe": true, "staged": true},
	{"name": ".gitignore", "icon": "⚙️", "safe": true, "staged": true},
]

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 13
	data.title = "夾帶的鑰匙"
	data.category = "security"
	data.difficulty = 2
	data.puzzle_title = "夾帶的鑰匙"
	data.scenario_text = "你的程式碼寫好了，準備打包寄出去。\n但包裹裡不小心放了一串鑰匙——你家的、公司的、保險箱的。\n一旦寄出去，全世界都能複製這串鑰匙。"
	data.task_hint = "桌面上有個工具，平常用來寫程式、也用來寄包裹。\n打開它，翻翻你即將寄出的東西——有一把鑰匙混在裡面。\n找到那張「禁止攜帶清單」，把鑰匙的名字寫上去，再寄出包裹。"
	data.teaching_points = PackedStringArray([
		".env 檔案常用於存放 API 金鑰、密碼等機密資訊，絕不可推送至公開儲存庫",
		".gitignore 檔案用於指定 Git 應忽略的檔案，是防止機密外洩的第一道防線",
		"一旦機密資訊被推送至 GitHub，即使事後刪除，仍可從歷史記錄中被找到",
		"建議使用 .env.example 提供範例格式，不包含實際金鑰值",
	])
	data.desktop_config = {}
	return data

func setup_desktop(_desktop: Node) -> void:
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "程式碼編輯器":
		_content_vscode(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	if _pushed_with_env:
		return {
			"passed": false,
			"details": "你在沒有將 .env 加入 .gitignore 的情況下推送了程式碼！機密資訊已外洩。請重新操作。",
		}
	if not _gitignore_has_env:
		return {
			"passed": false,
			"details": "你還沒有將 .env 加入 .gitignore。請先編輯 .gitignore 檔案，將 .env 加入忽略清單。",
		}
	if not _env_unstaged:
		return {
			"passed": false,
			"details": ".env 仍在 Git 追蹤清單中。請確認 .env 已從追蹤清單移除後再推送。",
		}
	if not _committed:
		return {
			"passed": false,
			"details": "你已正確設定 .gitignore，但還沒有執行 Commit & Push。請完成推送。",
		}
	return {
		"passed": true,
		"details": "",
	}

func calculate_score() -> int:
	var attempt_count := ScoreManager.get_attempts(LevelManager.current_level)
	var has_wrong := GameState.wrong_actions.size() > 0
	if attempt_count == 1 and not has_wrong:
		return 100
	return 60

# ============================================================
#  UI HELPER
# ============================================================
func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

# ============================================================
#  VS CODE UI
# ============================================================
var _current_view: String = "explorer"  # "explorer", "git"
var _current_file: String = ""          # Currently open file in editor
var _gitignore_content: String = "node_modules/\ndist/\n*.log"

func _content_vscode(p: Panel, _desktop: Node) -> void:
	# Tab bar (VS Code style)
	var tab := Panel.new()
	tab.name = "TabBar"
	tab.size = Vector2(640, 28)
	tab.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.18, 0.22), 0))
	p.add_child(tab)

	var tab_lbl := Label.new()
	tab_lbl.text = "  my-project — Visual Studio Code"
	tab_lbl.position = Vector2(0, 4)
	tab_lbl.size = Vector2(400, 20)
	tab_lbl.add_theme_font_size_override("font_size", 11)
	tab_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	tab.add_child(tab_lbl)

	# Main area
	var main := Panel.new()
	main.name = "MainArea"
	main.position = Vector2(0, 28)
	main.size = Vector2(640, 380)
	main.add_theme_stylebox_override("panel", _sb(Color(0.12, 0.12, 0.16), 0))
	p.add_child(main)

	# Activity bar (far left icons)
	var activity := Panel.new()
	activity.name = "ActivityBar"
	activity.position = Vector2(0, 0)
	activity.size = Vector2(36, 380)
	activity.add_theme_stylebox_override("panel", _sb(Color(0.15, 0.15, 0.19), 0))
	main.add_child(activity)

	# Explorer icon
	var explore_btn := Button.new()
	explore_btn.text = "📁"
	explore_btn.position = Vector2(2, 4)
	explore_btn.size = Vector2(32, 32)
	explore_btn.add_theme_font_size_override("font_size", 16)
	explore_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
	explore_btn.add_theme_stylebox_override("hover", _sb(Color(1, 1, 1, 0.1), 4))
	activity.add_child(explore_btn)

	# Git icon
	var git_btn := Button.new()
	git_btn.text = "🔀"
	git_btn.position = Vector2(2, 40)
	git_btn.size = Vector2(32, 32)
	git_btn.add_theme_font_size_override("font_size", 16)
	git_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
	git_btn.add_theme_stylebox_override("hover", _sb(Color(1, 1, 1, 0.1), 4))
	activity.add_child(git_btn)

	# Badge on git icon showing file count
	var badge := Label.new()
	badge.name = "GitBadge"
	badge.text = str(_get_staged_count())
	badge.position = Vector2(22, 40)
	badge.size = Vector2(14, 14)
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity.add_child(badge)

	var badge_bg := Panel.new()
	badge_bg.position = Vector2(22, 40)
	badge_bg.size = Vector2(14, 14)
	badge_bg.add_theme_stylebox_override("panel", _sb(Color(0.2, 0.5, 0.9), 7))
	badge_bg.z_index = -1
	activity.add_child(badge_bg)

	# Content area (right of activity bar)
	var content := Panel.new()
	content.name = "ContentArea"
	content.position = Vector2(36, 0)
	content.size = Vector2(604, 380)
	content.add_theme_stylebox_override("panel", _sb(Color(0.12, 0.12, 0.16), 0))
	main.add_child(content)

	# Wire activity buttons
	var p_ref := p
	explore_btn.pressed.connect(func():
		_current_view = "explorer"
		_rebuild_content(p_ref)
	)
	git_btn.pressed.connect(func():
		_current_view = "git"
		_rebuild_content(p_ref)
	)

	_rebuild_content(p)

func _rebuild_content(p: Panel) -> void:
	var main := p.get_node_or_null("MainArea")
	if not main:
		return
	var content := main.get_node_or_null("ContentArea")
	if not content:
		return
	for child in content.get_children():
		child.queue_free()

	# Update git badge
	var badge := main.get_node_or_null("ActivityBar/GitBadge")
	if badge:
		badge.text = str(_get_staged_count())

	if _current_view == "explorer":
		_build_explorer_view(content, p)
	else:
		_build_git_view(content, p)

func _get_staged_count() -> int:
	var count := 0
	for f in _files:
		if f["staged"]:
			count += 1
	return count

# ============================================================
#  EXPLORER VIEW (file tree + editor)
# ============================================================
func _build_explorer_view(content: Panel, p: Panel) -> void:
	# Sidebar
	var sidebar := Panel.new()
	sidebar.name = "Sidebar"
	sidebar.position = Vector2(0, 0)
	sidebar.size = Vector2(160, 380)
	sidebar.add_theme_stylebox_override("panel", _sb(Color(0.16, 0.16, 0.2), 0))
	content.add_child(sidebar)

	var sidebar_title := Label.new()
	sidebar_title.text = "  檔案總管"
	sidebar_title.position = Vector2(0, 4)
	sidebar_title.size = Vector2(160, 18)
	sidebar_title.add_theme_font_size_override("font_size", 10)
	sidebar_title.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	sidebar.add_child(sidebar_title)

	var folder_lbl := Label.new()
	folder_lbl.text = "  📂 my-project"
	folder_lbl.position = Vector2(4, 24)
	folder_lbl.size = Vector2(152, 18)
	folder_lbl.add_theme_font_size_override("font_size", 11)
	folder_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	sidebar.add_child(folder_lbl)

	for i in _files.size():
		var f: Dictionary = _files[i]
		var file_btn := Button.new()
		file_btn.text = "    %s %s" % [f["icon"], f["name"]]
		file_btn.position = Vector2(4, 44 + i * 26)
		file_btn.size = Vector2(152, 24)
		file_btn.add_theme_font_size_override("font_size", 11)
		file_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var is_selected: bool = (_current_file == f["name"])
		if is_selected:
			file_btn.add_theme_color_override("font_color", Color.WHITE)
			file_btn.add_theme_stylebox_override("normal", _sb(Color(0.25, 0.25, 0.35), 3))
		else:
			file_btn.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
			file_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 3))
		file_btn.add_theme_stylebox_override("hover", _sb(Color(0.22, 0.22, 0.3), 3))

		var fname: String = f["name"]
		var p_ref := p
		file_btn.pressed.connect(func():
			_current_file = fname
			GameState.record_action("open_file", fname)
			if fname == ".env":
				_viewed_env = true
			_rebuild_content(p_ref)
		)
		sidebar.add_child(file_btn)

	# Editor area
	var editor := Panel.new()
	editor.name = "EditorArea"
	editor.position = Vector2(160, 0)
	editor.size = Vector2(444, 380)
	editor.add_theme_stylebox_override("panel", _sb(Color(0.12, 0.12, 0.16), 0))
	content.add_child(editor)

	if _current_file == "":
		_build_welcome(editor)
	elif _current_file == ".env":
		_build_env_view(editor)
	elif _current_file == ".gitignore":
		_build_gitignore_editor(editor, p)
	elif _current_file == "index.js":
		_build_indexjs_view(editor)
	elif _current_file == "package.json":
		_build_packagejson_view(editor)
	elif _current_file == "README.md":
		_build_readme_view(editor)

func _build_welcome(editor: Panel) -> void:
	var lbl := Label.new()
	lbl.text = "選擇左側檔案以檢視內容"
	lbl.position = Vector2(100, 160)
	lbl.size = Vector2(250, 30)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor.add_child(lbl)

func _build_env_view(editor: Panel) -> void:
	# Tab
	var tab := Panel.new()
	tab.size = Vector2(444, 26)
	tab.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.18, 0.22), 0))
	editor.add_child(tab)

	var tab_lbl := Label.new()
	tab_lbl.text = "  🔑 .env"
	tab_lbl.position = Vector2(4, 4)
	tab_lbl.size = Vector2(200, 18)
	tab_lbl.add_theme_font_size_override("font_size", 11)
	tab_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	tab.add_child(tab_lbl)

	# Warning banner
	var warn := Panel.new()
	warn.position = Vector2(8, 32)
	warn.size = Vector2(428, 36)
	var warn_sb := _sb(Color(0.35, 0.18, 0.15), 4)
	warn_sb.border_color = Color(0.9, 0.4, 0.3)
	warn_sb.border_width_left = 3
	warn_sb.border_width_top = 1
	warn_sb.border_width_right = 1
	warn_sb.border_width_bottom = 1
	warn.add_theme_stylebox_override("panel", warn_sb)
	editor.add_child(warn)

	var warn_lbl := Label.new()
	warn_lbl.text = "⚠️ 此檔案包含機密資訊！不應推送至公開的程式碼庫。"
	warn_lbl.position = Vector2(10, 8)
	warn_lbl.size = Vector2(408, 20)
	warn_lbl.add_theme_font_size_override("font_size", 11)
	warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.6))
	warn.add_child(warn_lbl)

	# File content
	var code := Label.new()
	code.text = "# 應用程式環境變數\n\nAPI_KEY=sk-proj-a8Kx92mNpQ7rT3vW5yZ1\nDB_HOST=db.company-internal.com\nDB_PASSWORD=Super$ecret!Pass2026\nDB_NAME=production_db\nJWT_SECRET=eyJhbGciOiJIUzI1NiJ9\nSMTP_PASSWORD=mail_p@ss_2026\nAWS_SECRET_KEY=wJalrXUtnFEMI/K7MDENG"
	code.position = Vector2(12, 76)
	code.size = Vector2(420, 280)
	code.add_theme_font_size_override("font_size", 11)
	code.add_theme_color_override("font_color", Color(0.82, 0.72, 0.55))
	editor.add_child(code)

	# Line numbers
	var lines := Label.new()
	lines.text = " 1\n 2\n 3\n 4\n 5\n 6\n 7\n 8\n 9"
	lines.position = Vector2(0, 76)
	lines.size = Vector2(24, 280)
	lines.add_theme_font_size_override("font_size", 11)
	lines.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	editor.add_child(lines)

func _build_gitignore_editor(editor: Panel, p: Panel) -> void:
	# Tab
	var tab := Panel.new()
	tab.size = Vector2(444, 26)
	tab.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.18, 0.22), 0))
	editor.add_child(tab)

	var tab_lbl := Label.new()
	tab_lbl.text = "  ⚙️ .gitignore"
	tab_lbl.position = Vector2(4, 4)
	tab_lbl.size = Vector2(200, 18)
	tab_lbl.add_theme_font_size_override("font_size", 11)
	tab_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	tab.add_child(tab_lbl)

	# Editable text area
	var text_edit := TextEdit.new()
	text_edit.name = "GitignoreEdit"
	text_edit.text = _gitignore_content
	text_edit.position = Vector2(8, 32)
	text_edit.size = Vector2(428, 240)
	text_edit.add_theme_font_size_override("font_size", 12)
	text_edit.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))

	var edit_sb := _sb(Color(0.14, 0.14, 0.18), 4)
	edit_sb.border_color = Color(0.25, 0.25, 0.3)
	edit_sb.border_width_left = 1
	edit_sb.border_width_top = 1
	edit_sb.border_width_right = 1
	edit_sb.border_width_bottom = 1
	text_edit.add_theme_stylebox_override("normal", edit_sb)
	text_edit.add_theme_stylebox_override("focus", edit_sb)
	editor.add_child(text_edit)

	# Hint label
	var hint := Label.new()
	hint.text = "提示：在此檔案中加入需要被 Git 忽略的檔案名稱（每行一個）"
	hint.position = Vector2(8, 278)
	hint.size = Vector2(428, 18)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	editor.add_child(hint)

	# Save button
	var save_btn := Button.new()
	save_btn.text = "💾 儲存 .gitignore"
	save_btn.position = Vector2(260, 300)
	save_btn.size = Vector2(170, 32)
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.add_theme_color_override("font_color", Color.WHITE)
	save_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	save_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var p_ref := p
	save_btn.pressed.connect(func():
		_on_save_gitignore(text_edit, editor, p_ref)
	)
	editor.add_child(save_btn)

	# Status indicator
	if _gitignore_has_env:
		var status := Label.new()
		status.text = "✅ .gitignore 已包含 .env"
		status.position = Vector2(8, 304)
		status.size = Vector2(240, 20)
		status.add_theme_font_size_override("font_size", 11)
		status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		editor.add_child(status)

func _on_save_gitignore(text_edit: TextEdit, editor: Panel, p: Panel) -> void:
	var content := text_edit.text
	_gitignore_content = content

	# Check if .env is in the gitignore
	var lines := content.split("\n")
	var has_env := false
	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed == ".env" or trimmed == ".env\r":
			has_env = true
			break

	var feedback_text := ""
	var feedback_success := false
	if has_env:
		_gitignore_has_env = true
		# Also unstage .env
		_env_unstaged = true
		_files[2]["staged"] = false
		# Reset pushed_with_env so player can recover after fixing gitignore
		_pushed_with_env = false
		_committed = false
		GameState.record_action("add_env_to_gitignore")
		feedback_text = ".gitignore 已儲存！.env 已從 Git 追蹤清單中移除。"
		feedback_success = true
	else:
		_gitignore_has_env = false
		_env_unstaged = false
		_files[2]["staged"] = true
		GameState.record_action("save_gitignore_without_env")
		feedback_text = ".gitignore 已儲存，但未包含 .env。機密檔案仍會被推送！"

	_rebuild_content(p)

	# Show feedback on the newly-built editor panel (after rebuild)
	var new_editor := p.get_node_or_null("MainArea/ContentArea/EditorArea")
	if new_editor:
		if feedback_success:
			_show_feedback_box_success(new_editor, feedback_text)
		else:
			_show_feedback_box(new_editor, feedback_text)

func _build_indexjs_view(editor: Panel) -> void:
	var tab := Panel.new()
	tab.size = Vector2(444, 26)
	tab.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.18, 0.22), 0))
	editor.add_child(tab)

	var tab_lbl := Label.new()
	tab_lbl.text = "  📄 index.js"
	tab_lbl.position = Vector2(4, 4)
	tab_lbl.size = Vector2(200, 18)
	tab_lbl.add_theme_font_size_override("font_size", 11)
	tab_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	tab.add_child(tab_lbl)

	var code := Label.new()
	code.text = "const express = require('express');\nconst app = express();\nconst db = require('./db');\n\napp.get('/api/users', async (req, res) => {\n  const users = await db.getUsers();\n  res.json(users);\n});\n\napp.post('/api/login', async (req, res) => {\n  const { username, password } = req.body;\n  const user = await db.authenticate(\n    username, password\n  );\n  if (user) {\n    res.json({ token: generateToken(user) });\n  } else {\n    res.status(401).json(\n      { error: 'Invalid credentials' }\n    );\n  }\n});\n\napp.listen(3000, () => {\n  console.log('Server running on port 3000');\n});"
	code.position = Vector2(28, 32)
	code.size = Vector2(408, 340)
	code.add_theme_font_size_override("font_size", 11)
	code.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	editor.add_child(code)

	var lines := Label.new()
	var line_text := ""
	for i in range(1, 26):
		line_text += "%2d\n" % i
	lines.text = line_text
	lines.position = Vector2(4, 32)
	lines.size = Vector2(22, 340)
	lines.add_theme_font_size_override("font_size", 11)
	lines.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	editor.add_child(lines)

func _build_packagejson_view(editor: Panel) -> void:
	var tab := Panel.new()
	tab.size = Vector2(444, 26)
	tab.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.18, 0.22), 0))
	editor.add_child(tab)

	var tab_lbl := Label.new()
	tab_lbl.text = "  📦 package.json"
	tab_lbl.position = Vector2(4, 4)
	tab_lbl.size = Vector2(200, 18)
	tab_lbl.add_theme_font_size_override("font_size", 11)
	tab_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	tab.add_child(tab_lbl)

	var code := Label.new()
	code.text = "{\n  \"name\": \"my-project\",\n  \"version\": \"1.0.0\",\n  \"description\": \"Web API Server\",\n  \"main\": \"index.js\",\n  \"scripts\": {\n    \"start\": \"node index.js\",\n    \"dev\": \"nodemon index.js\"\n  },\n  \"dependencies\": {\n    \"express\": \"^4.18.2\",\n    \"dotenv\": \"^16.3.1\",\n    \"jsonwebtoken\": \"^9.0.2\"\n  }\n}"
	code.position = Vector2(28, 32)
	code.size = Vector2(408, 300)
	code.add_theme_font_size_override("font_size", 11)
	code.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	editor.add_child(code)

	var lines := Label.new()
	var line_text := ""
	for i in range(1, 16):
		line_text += "%2d\n" % i
	lines.text = line_text
	lines.position = Vector2(4, 32)
	lines.size = Vector2(22, 300)
	lines.add_theme_font_size_override("font_size", 11)
	lines.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	editor.add_child(lines)

func _build_readme_view(editor: Panel) -> void:
	var tab := Panel.new()
	tab.size = Vector2(444, 26)
	tab.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.18, 0.22), 0))
	editor.add_child(tab)

	var tab_lbl := Label.new()
	tab_lbl.text = "  📝 README.md"
	tab_lbl.position = Vector2(4, 4)
	tab_lbl.size = Vector2(200, 18)
	tab_lbl.add_theme_font_size_override("font_size", 11)
	tab_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	tab.add_child(tab_lbl)

	var code := Label.new()
	code.text = "# My Project\n\nA simple web API server built with Express.js.\n\n## Setup\n\n1. Clone this repository\n2. Run `npm install`\n3. Create a `.env` file with your credentials\n4. Run `npm start`\n\n## API Endpoints\n\n- GET /api/users — List all users\n- POST /api/login — Authenticate user"
	code.position = Vector2(28, 32)
	code.size = Vector2(408, 300)
	code.add_theme_font_size_override("font_size", 11)
	code.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	editor.add_child(code)

# ============================================================
#  GIT VIEW
# ============================================================
func _build_git_view(content: Panel, p: Panel) -> void:
	# Sidebar: Source Control
	var sidebar := Panel.new()
	sidebar.name = "GitSidebar"
	sidebar.position = Vector2(0, 0)
	sidebar.size = Vector2(604, 380)
	sidebar.add_theme_stylebox_override("panel", _sb(Color(0.14, 0.14, 0.18), 0))
	content.add_child(sidebar)

	var title := Label.new()
	title.text = "  原始檔控制 (Source Control)"
	title.position = Vector2(4, 6)
	title.size = Vector2(400, 20)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	sidebar.add_child(title)

	# Commit message input
	var commit_lbl := Label.new()
	commit_lbl.text = "提交訊息："
	commit_lbl.position = Vector2(12, 34)
	commit_lbl.size = Vector2(100, 18)
	commit_lbl.add_theme_font_size_override("font_size", 11)
	commit_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	sidebar.add_child(commit_lbl)

	var commit_input := LineEdit.new()
	commit_input.name = "CommitMsg"
	commit_input.text = "Initial commit"
	commit_input.position = Vector2(12, 54)
	commit_input.size = Vector2(444, 28)
	commit_input.add_theme_font_size_override("font_size", 12)
	commit_input.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	var input_sb := _sb(Color(0.18, 0.18, 0.22), 4)
	input_sb.border_color = Color(0.3, 0.3, 0.35)
	input_sb.border_width_left = 1
	input_sb.border_width_top = 1
	input_sb.border_width_right = 1
	input_sb.border_width_bottom = 1
	commit_input.add_theme_stylebox_override("normal", input_sb)
	sidebar.add_child(commit_input)

	# Commit & Push button
	var push_btn := Button.new()
	push_btn.name = "PushBtn"
	push_btn.text = "✓ Commit & Push"
	push_btn.position = Vector2(462, 54)
	push_btn.size = Vector2(130, 28)
	push_btn.add_theme_font_size_override("font_size", 11)
	push_btn.add_theme_color_override("font_color", Color.WHITE)
	push_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	push_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var p_ref := p
	push_btn.pressed.connect(func():
		_on_commit_push(sidebar, p_ref)
	)
	sidebar.add_child(push_btn)

	# Staged Changes section
	var staged_title := Label.new()
	staged_title.text = "已暫存的變更 (Staged Changes)"
	staged_title.position = Vector2(12, 94)
	staged_title.size = Vector2(400, 20)
	staged_title.add_theme_font_size_override("font_size", 12)
	staged_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	sidebar.add_child(staged_title)

	var y_offset := 118
	for i in _files.size():
		var f: Dictionary = _files[i]
		if not f["staged"]:
			continue

		var row := Panel.new()
		row.position = Vector2(8, y_offset)
		row.size = Vector2(588, 30)
		row.add_theme_stylebox_override("panel", _sb(Color(0.16, 0.16, 0.2), 3))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		sidebar.add_child(row)

		var file_lbl := Label.new()
		file_lbl.text = "  %s %s" % [f["icon"], f["name"]]
		file_lbl.position = Vector2(8, 5)
		file_lbl.size = Vector2(350, 20)
		file_lbl.add_theme_font_size_override("font_size", 11)

		# Highlight .env in red if still staged
		if f["name"] == ".env":
			file_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		else:
			file_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		row.add_child(file_lbl)

		# Status tag
		var status := Label.new()
		status.text = "A" if f["name"] != ".gitignore" or not _gitignore_has_env else "M"
		status.position = Vector2(540, 5)
		status.size = Vector2(20, 20)
		status.add_theme_font_size_override("font_size", 11)
		status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		row.add_child(status)

		y_offset += 34

	# Show unstaged .env if it was removed from staged
	if _env_unstaged:
		var unstaged_title := Label.new()
		unstaged_title.text = "已忽略的檔案 (Ignored)"
		unstaged_title.position = Vector2(12, y_offset + 8)
		unstaged_title.size = Vector2(400, 20)
		unstaged_title.add_theme_font_size_override("font_size", 12)
		unstaged_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		sidebar.add_child(unstaged_title)

		y_offset += 32

		var ignored_row := Panel.new()
		ignored_row.position = Vector2(8, y_offset)
		ignored_row.size = Vector2(588, 30)
		ignored_row.add_theme_stylebox_override("panel", _sb(Color(0.14, 0.16, 0.14), 3))
		sidebar.add_child(ignored_row)

		var ignored_lbl := Label.new()
		ignored_lbl.text = "  🔑 .env  (已被 .gitignore 排除)"
		ignored_lbl.position = Vector2(8, 5)
		ignored_lbl.size = Vector2(400, 20)
		ignored_lbl.add_theme_font_size_override("font_size", 11)
		ignored_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		ignored_row.add_child(ignored_lbl)

		var check_icon := Label.new()
		check_icon.text = "✓"
		check_icon.position = Vector2(540, 5)
		check_icon.size = Vector2(20, 20)
		check_icon.add_theme_font_size_override("font_size", 11)
		check_icon.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
		ignored_row.add_child(check_icon)

		y_offset += 34

	# Warning if .env is still staged
	if not _env_unstaged:
		var warn := Panel.new()
		warn.position = Vector2(8, y_offset + 8)
		warn.size = Vector2(588, 36)
		var warn_sb := _sb(Color(0.35, 0.18, 0.15), 4)
		warn_sb.border_color = Color(0.9, 0.4, 0.3)
		warn_sb.border_width_left = 3
		warn_sb.border_width_top = 1
		warn_sb.border_width_right = 1
		warn_sb.border_width_bottom = 1
		warn.add_theme_stylebox_override("panel", warn_sb)
		sidebar.add_child(warn)

		var warn_lbl := Label.new()
		warn_lbl.text = "⚠️ 警告：.env 檔案包含機密資訊，目前仍在推送清單中！"
		warn_lbl.position = Vector2(10, 8)
		warn_lbl.size = Vector2(568, 20)
		warn_lbl.add_theme_font_size_override("font_size", 11)
		warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.6))
		warn.add_child(warn_lbl)

	# Finish button at bottom
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(462, 340)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	finish.pressed.connect(func(): _on_finish_pressed(sidebar))
	sidebar.add_child(finish)

	# Re-add give-up button if already earned
	if _show_give_up:
		_add_give_up_btn(sidebar)

func _on_commit_push(git_panel: Panel, p: Panel) -> void:
	if not LevelManager.level_active:
		return

	GameState.record_action("commit_push")

	var feedback_text := ""
	var feedback_success := false
	if not _gitignore_has_env or not _env_unstaged:
		# Pushing with .env — bad!
		_pushed_with_env = true
		GameState.record_wrong_action("pushed_with_env_exposed")
		feedback_text = "已推送！但 .env 檔案也被推送了！\nAPI 金鑰和密碼已外洩至 GitHub。"
		feedback_success = false
	else:
		_committed = true
		feedback_text = "推送成功！.env 已被 .gitignore 排除，\n機密資訊安全無虞。"
		feedback_success = true

	_rebuild_content(p)

	# Show feedback on the newly-built git sidebar (after rebuild)
	var new_git := p.get_node_or_null("MainArea/ContentArea/GitSidebar")
	if new_git:
		if feedback_success:
			_show_feedback_box_success(new_git, feedback_text)
		else:
			_show_feedback_box(new_git, feedback_text)

# ============================================================
#  FINISH & FEEDBACK
# ============================================================
func _on_finish_pressed(parent: Panel) -> void:
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
		if ScoreManager.get_attempts(lid) >= 3:
			_show_give_up = true
			var existing := parent.get_node_or_null("GiveUpBtn")
			if not existing:
				_add_give_up_btn(parent)

func _add_give_up_btn(parent: Panel) -> void:
	var gub := Button.new()
	gub.name = "GiveUpBtn"
	gub.text = "查看解答"
	gub.position = Vector2(320, 340)
	gub.size = Vector2(130, 32)
	gub.add_theme_font_size_override("font_size", 12)
	gub.add_theme_color_override("font_color", Color.WHITE)
	gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
	gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
	gub.pressed.connect(func(): LevelManager.fail_level())
	parent.add_child(gub)

func _show_feedback_box(parent: Panel, text: String) -> void:
	var old := parent.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(8, 324)
	box.size = Vector2(428, 52)
	var box_sb := _sb(Color(1.0, 0.95, 0.9), 8)
	box_sb.border_color = Color(0.9, 0.6, 0.2)
	box_sb.border_width_left = 4
	box_sb.border_width_top = 1
	box_sb.border_width_right = 1
	box_sb.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 10
	parent.add_child(box)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(12, 4)
	msg.size = Vector2(388, 44)
	msg.add_theme_font_size_override("font_size", 11)
	msg.add_theme_color_override("font_color", Color(0.4, 0.25, 0.05))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)

	var _timer := Timer.new()
	_timer.wait_time = 3.0
	_timer.one_shot = true
	_timer.autostart = true
	box.add_child(_timer)
	_timer.timeout.connect(func():
		if is_instance_valid(box):
			box.queue_free()
	)

func _show_feedback_box_success(parent: Panel, text: String) -> void:
	var old := parent.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(8, 324)
	box.size = Vector2(428, 52)
	var box_sb := _sb(Color(0.92, 0.98, 0.92), 8)
	box_sb.border_color = Color(0.3, 0.75, 0.3)
	box_sb.border_width_left = 4
	box_sb.border_width_top = 1
	box_sb.border_width_right = 1
	box_sb.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 10
	parent.add_child(box)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(12, 4)
	msg.size = Vector2(388, 44)
	msg.add_theme_font_size_override("font_size", 11)
	msg.add_theme_color_override("font_color", Color(0.1, 0.4, 0.1))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)

	var _timer := Timer.new()
	_timer.wait_time = 3.0
	_timer.one_shot = true
	_timer.autostart = true
	box.add_child(_timer)
	_timer.timeout.connect(func():
		if is_instance_valid(box):
			box.queue_free()
	)
