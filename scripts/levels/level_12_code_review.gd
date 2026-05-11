extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track which code segments the player has flagged as vulnerable
var _flagged: Array[int] = []

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 12
	data.title = "看不見的裂縫"
	data.category = "ai"
	data.difficulty = 3
	data.puzzle_title = "看不見的裂縫"
	data.scenario_text = "開發團隊很興奮：「AI 幫我們寫完了，可以上線了！」\n資安部門攔住了他們：「先讓人看過。」\n那個「人」就是你。程式碼看起來完美無瑕，\n但完美的外表下可能藏著讓整棟大樓倒塌的裂縫。"
	data.task_hint = "開發者的工具就在桌面上，找到那個能打開原始碼的地方。\n五段程式碼看似正常，但有三個致命的裂縫藏在其中。\n一個會讓別人偷走資料，一個把秘密裸露在外，一個把鑰匙焊死在門上。\n找到它們，標記它們。"
	data.teaching_points = PackedStringArray([
		"AI 生成的程式碼可能包含安全漏洞",
		"常見問題：注入攻擊、明文密碼、硬編碼密鑰",
		"AI 程式碼一定要經過安全審查才能部署",
		"使用自動化工具（SAST）輔助檢查",
	])
	data.desktop_config = {}
	return data

func setup_desktop(_desktop: Node) -> void:
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "程式碼編輯器":
		_content_code_review(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	var correct_indices := [0, 2, 3]  # SQL injection, plaintext password, hardcoded API key
	if _flagged.size() == 0:
		return {
			"passed": false,
			"details": "你還沒有標記任何程式碼區段。請仔細審查程式碼，找出有安全漏洞的部分並標記。",
		}

	var flagged_sorted := _flagged.duplicate()
	flagged_sorted.sort()
	var correct_sorted := correct_indices.duplicate()
	correct_sorted.sort()

	var passed := (flagged_sorted == correct_sorted)

	var details := ""
	if not passed:
		var wrong_flags := 0
		var missed := 0
		for idx in _flagged:
			if idx not in correct_indices:
				wrong_flags += 1
		for idx in correct_indices:
			if idx not in _flagged:
				missed += 1

		if _flagged.size() < 3 and wrong_flags == 0:
			details = "你只找到了 %d 個漏洞，但程式碼中共有 3 個安全問題。請繼續仔細檢查。" % _flagged.size()
		elif _flagged.size() > 3:
			details = "你標記了 %d 個區段，但只有 3 個有安全漏洞。有些安全的程式碼被誤標了。" % _flagged.size()
		elif wrong_flags > 0 and missed > 0:
			details = "你的標記不完全正確。有 %d 個安全的程式碼被誤標，還有 %d 個漏洞未被發現。" % [wrong_flags, missed]
		elif wrong_flags > 0:
			details = "你標記了一些安全的程式碼。請再次確認每段程式碼是否真的有安全問題。"
		else:
			details = "還有安全漏洞沒有被找到。注意檢查 SQL 查詢、密碼儲存方式和密鑰管理。"

	return {
		"passed": passed,
		"details": details,
	}

func calculate_score() -> int:
	var attempt_count := ScoreManager.get_attempts(LevelManager.current_level)
	var has_wrong := GameState.wrong_actions.size() > 0
	if attempt_count == 1 and not has_wrong:
		return 100
	return 60

# ============================================================
#  CODE SEGMENTS DATA
# ============================================================
func _get_code_segments() -> Array:
	return [
		{
			"title": "① 用戶查詢功能",
			"code": "def get_user(username):\n    db = sqlite3.connect(\"users.db\")\n    query = \"SELECT * FROM users\n            WHERE name='\" + username + \"'\"\n    return db.execute(query).fetchall()",
			"has_vulnerability": true,
			"vuln_type": "SQL Injection",
			"explanation": "使用者輸入直接拼接到 SQL 查詢中，攻擊者可輸入惡意字串竊取或刪除資料庫資料。應使用參數化查詢（Parameterized Query）。",
		},
		{
			"title": "② 輸入驗證功能",
			"code": "def validate_input(data):\n    if not data or len(data) > 1000:\n        return False\n    # 過濾特殊字元\n    allowed = set('abcdefghijklmnopqrstuvwxyz\n                   ABCDEFGHIJKLMNOPQRSTUVWXYZ\n                   0123456789_-@.')\n    return all(c in allowed for c in data)",
			"has_vulnerability": false,
			"vuln_type": "",
			"explanation": "",
		},
		{
			"title": "③ 密碼儲存功能",
			"code": "def save_user(name, password):\n    db = sqlite3.connect(\"users.db\")\n    db.execute(\n        \"INSERT INTO users VALUES (?,?)\",\n        (name, password))\n    db.commit()",
			"has_vulnerability": true,
			"vuln_type": "密碼明文儲存",
			"explanation": "密碼沒有經過雜湊（Hash）處理就直接存入資料庫。一旦資料庫被入侵，所有用戶密碼將直接暴露。應使用 bcrypt 等演算法加密後儲存。",
		},
		{
			"title": "④ API 設定",
			"code": "# API 設定\nAPI_KEY = \"sk-abc123secret456key789\"\nAPI_URL = \"https://api.example.com/v1\"\n\ndef call_api(endpoint, data):\n    headers = {\"Authorization\":\n               f\"Bearer {API_KEY}\"}\n    return requests.post(\n        API_URL + endpoint,\n        headers=headers, json=data)",
			"has_vulnerability": true,
			"vuln_type": "API 金鑰寫死",
			"explanation": "API 金鑰直接寫死在程式碼中（Hard-coded）。程式碼一旦上傳至版本控制系統，金鑰即被公開。應使用環境變數或金鑰管理服務。",
		},
		{
			"title": "⑤ Token 雜湊功能",
			"code": "def hash_token(token):\n    import hashlib\n    salt = os.urandom(32)\n    return hashlib.pbkdf2_hmac(\n        'sha256',\n        token.encode(),\n        salt, 100000\n    ).hex()",
			"has_vulnerability": false,
			"vuln_type": "",
			"explanation": "",
		},
	]

# ============================================================
#  UI
# ============================================================
func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _content_code_review(p: Panel, _desktop: Node) -> void:
	# Tab bar (VS Code style)
	var tab := Panel.new()
	tab.size = Vector2(640, 28)
	tab.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.18, 0.22), 0))
	p.add_child(tab)

	var tab_lbl := Label.new()
	tab_lbl.text = "  server.py  ✕     🔍 Code Review Mode"
	tab_lbl.position = Vector2(0, 4)
	tab_lbl.size = Vector2(500, 20)
	tab_lbl.add_theme_font_size_override("font_size", 11)
	tab_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	tab.add_child(tab_lbl)

	# Instruction label in tab bar
	var hint_lbl := Label.new()
	hint_lbl.text = "請找出 3 個安全漏洞"
	hint_lbl.position = Vector2(460, 4)
	hint_lbl.size = Vector2(170, 20)
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	tab.add_child(hint_lbl)

	# Content area (dark code background)
	var content_area := Panel.new()
	content_area.name = "CodeReviewArea"
	content_area.position = Vector2(0, 28)
	content_area.size = Vector2(640, 380)
	content_area.add_theme_stylebox_override("panel", _sb(Color(0.12, 0.12, 0.16), 0))
	p.add_child(content_area)

	_build_code_review(content_area)

func _build_code_review(area: Panel) -> void:
	for child in area.get_children():
		child.queue_free()

	var segments := _get_code_segments()

	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4, 4)
	scroll.size = Vector2(632, 326)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for i in segments.size():
		var seg: Dictionary = segments[i]
		var is_flagged := (i in _flagged)

		var card_bg: Color
		var border_color: Color
		if is_flagged:
			card_bg = Color(0.22, 0.12, 0.12)
			border_color = Color(0.85, 0.3, 0.3)
		else:
			card_bg = Color(0.15, 0.15, 0.19)
			border_color = Color(0.25, 0.25, 0.3)
		var card_sb := _sb(card_bg, 4)
		card_sb.border_color = border_color
		card_sb.border_width_left = 3 if is_flagged else 1
		card_sb.border_width_top = 1
		card_sb.border_width_right = 1
		card_sb.border_width_bottom = 1
		card_sb.content_margin_left = 10
		card_sb.content_margin_right = 10
		card_sb.content_margin_top = 6
		card_sb.content_margin_bottom = 6

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", card_sb)
		vbox.add_child(card)

		# Internal VBox for card content
		var card_vbox := VBoxContainer.new()
		card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(card_vbox)

		# Segment title
		var title_lbl := Label.new()
		title_lbl.text = seg["title"]
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
		card_vbox.add_child(title_lbl)

		# Code content (monospace look)
		var code_lbl := Label.new()
		code_lbl.text = seg["code"]
		code_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		code_lbl.add_theme_font_size_override("font_size", 11)
		code_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
		card_vbox.add_child(code_lbl)

		# Button row
		var btn_row := HBoxContainer.new()
		btn_row.custom_minimum_size = Vector2(0, 28)
		btn_row.alignment = BoxContainer.ALIGNMENT_END
		card_vbox.add_child(btn_row)

		if is_flagged:
			var status_lbl := Label.new()
			status_lbl.text = "🚩 已標記為漏洞"
			status_lbl.add_theme_font_size_override("font_size", 10)
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_row.add_child(status_lbl)

			var unflag_btn := Button.new()
			unflag_btn.text = "取消標記"
			unflag_btn.custom_minimum_size = Vector2(80, 24)
			unflag_btn.add_theme_font_size_override("font_size", 10)
			unflag_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			unflag_btn.add_theme_stylebox_override("normal", _sb(Color(0.25, 0.25, 0.3), 4))
			unflag_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.3, 0.35), 4))
			var idx := i
			var area_ref := area
			unflag_btn.pressed.connect(func():
				_on_unflag(area_ref, idx)
			)
			btn_row.add_child(unflag_btn)
		else:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_row.add_child(spacer)

			var flag_btn := Button.new()
			flag_btn.text = "🚩 標記為漏洞"
			flag_btn.custom_minimum_size = Vector2(110, 24)
			flag_btn.add_theme_font_size_override("font_size", 10)
			flag_btn.add_theme_color_override("font_color", Color.WHITE)
			flag_btn.add_theme_stylebox_override("normal", _sb(Color(0.8, 0.35, 0.25), 4))
			flag_btn.add_theme_stylebox_override("hover", _sb(Color(0.9, 0.4, 0.3), 4))
			var idx2 := i
			var area_ref2 := area
			flag_btn.pressed.connect(func():
				_on_flag(area_ref2, idx2)
			)
			btn_row.add_child(flag_btn)

		# Spacer between cards
		if i < segments.size() - 1:
			var card_spacer := Control.new()
			card_spacer.custom_minimum_size = Vector2(0, 3)
			vbox.add_child(card_spacer)

	# Bottom bar
	var bottom := Panel.new()
	bottom.position = Vector2(0, 336)
	bottom.size = Vector2(640, 44)
	bottom.add_theme_stylebox_override("panel", _sb(Color(0.15, 0.15, 0.19), 0))
	area.add_child(bottom)

	# Status summary
	var summary := Label.new()
	summary.text = "已標記: %d / 5 段  |  共有 3 個安全漏洞" % _flagged.size()
	summary.position = Vector2(12, 8)
	summary.size = Vector2(280, 20)
	summary.add_theme_font_size_override("font_size", 10)
	summary.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	bottom.add_child(summary)

	# Give-up button (after 3 failed attempts)
	var lid := LevelManager.current_level
	var btn_x := 290  # Starting x for buttons
	if ScoreManager.get_attempts(lid) >= 3:
		var gub := Button.new()
		gub.name = "GiveUpBtn"
		gub.text = "查看解答"
		gub.position = Vector2(btn_x, 8)
		gub.size = Vector2(80, 28)
		gub.add_theme_font_size_override("font_size", 11)
		gub.add_theme_color_override("font_color", Color.WHITE)
		gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
		gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
		gub.pressed.connect(func(): LevelManager.fail_level())
		bottom.add_child(gub)
		btn_x += 88

	# Reset button
	if _flagged.size() > 0:
		var reset_btn := Button.new()
		reset_btn.text = "重新標記"
		reset_btn.position = Vector2(btn_x, 8)
		reset_btn.size = Vector2(80, 28)
		reset_btn.add_theme_font_size_override("font_size", 11)
		reset_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		reset_btn.add_theme_stylebox_override("normal", _sb(Color(0.22, 0.22, 0.26), 4))
		reset_btn.add_theme_stylebox_override("hover", _sb(Color(0.28, 0.28, 0.32), 4))
		var area_ref := area
		reset_btn.pressed.connect(func():
			_flagged.clear()
			_build_code_review(area_ref)
		)
		bottom.add_child(reset_btn)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(500, 6)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var area_ref_finish := area
	finish.pressed.connect(func(): _on_finish_pressed(area_ref_finish))
	bottom.add_child(finish)

func _on_flag(area: Panel, index: int) -> void:
	if index not in _flagged:
		_flagged.append(index)
		GameState.record_action("flag_code_segment", index)
		var segments := _get_code_segments()
		if not segments[index]["has_vulnerability"]:
			GameState.record_wrong_action("flagged_safe_code", index)
	_build_code_review(area)

func _on_unflag(area: Panel, index: int) -> void:
	_flagged.erase(index)
	GameState.record_action("unflag_code_segment", index)
	_build_code_review(area)

func _on_finish_pressed(area: Panel) -> void:
	if not LevelManager.level_active:
		return
	var lid := LevelManager.current_level
	ScoreManager.increment_attempts(lid)
	var result := check_completion()

	if result["passed"]:
		var score := calculate_score()
		LevelManager.complete_level(score)
	else:
		# Rebuild to update bottom bar (shows give-up button after 3 attempts)
		_build_code_review(area)
		_show_feedback_box(area, result["details"])

# ============================================================
#  FEEDBACK BOXES
# ============================================================
func _show_feedback_box(parent: Panel, text: String) -> void:
	var old := parent.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 290)
	box.size = Vector2(620, 42)
	var box_sb := _sb(Color(1.0, 0.95, 0.9), 8)
	box_sb.border_color = Color(0.9, 0.6, 0.2)
	box_sb.border_width_left = 4
	box_sb.border_width_top = 1
	box_sb.border_width_right = 1
	box_sb.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 10
	parent.add_child(box)

	var icon_label := Label.new()
	icon_label.text = "💡"
	icon_label.position = Vector2(12, 6)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 16)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(40, 4)
	msg.size = Vector2(552, 34)
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
	box.position = Vector2(10, 290)
	box.size = Vector2(620, 42)
	var box_sb := _sb(Color(0.92, 0.98, 0.92), 8)
	box_sb.border_color = Color(0.3, 0.75, 0.3)
	box_sb.border_width_left = 4
	box_sb.border_width_top = 1
	box_sb.border_width_right = 1
	box_sb.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 10
	parent.add_child(box)

	var icon_label := Label.new()
	icon_label.text = "✅"
	icon_label.position = Vector2(12, 6)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 16)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(40, 4)
	msg.size = Vector2(552, 34)
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
