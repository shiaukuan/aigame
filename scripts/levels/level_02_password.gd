extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

var _password_set := false
var _password_value := ""

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 2
	data.title = "紙做的鎖"
	data.category = "security"
	data.difficulty = 1
	data.puzzle_title = "紙做的鎖"
	data.scenario_text = "你的門一直都有鎖，只是這把鎖……\n任何人都能用一根迴紋針打開它。\n是時候換一把真正的鎖了。"
	data.task_hint = "不是每扇門都需要鑰匙，但你的那扇門需要一把更好的。\n想改變門鎖，得先找到管理這些設定的地方。"
	data.teaching_points = PackedStringArray([
		"密碼長度比複雜度更重要",
		"不要用個人資訊作為密碼",
		"建議使用密碼管理器",
		"不同服務使用不同密碼",
	])
	data.desktop_config = {"highlight_app": "設定"}
	return data

func setup_desktop(_desktop: Node) -> void:
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "設定":
		_content_settings(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	var passed := _password_set and _is_strong_password(_password_value)
	var details := ""
	if not _password_set:
		details = "你還沒有變更密碼。請到設定 → 帳號與安全 → 變更密碼。"
	elif not _is_strong_password(_password_value):
		details = "你設定的密碼不符合公司密碼政策。"
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
#  PASSWORD VALIDATION
# ============================================================
var _common_passwords := [
	"password123!", "Password1!", "Qwerty123!", "Qwerty12345!",
	"P@ssword123!", "Admin12345!", "Welcome123!!", "Changeme123!",
	"abc123456789", "1234567890ab", "password1234", "iloveyou1234",
]

func _is_strong_password(pw: String) -> bool:
	if pw.length() < 12:
		return false
	var has_upper := false
	var has_lower := false
	var has_digit := false
	var has_symbol := false
	for c in pw:
		if c >= "A" and c <= "Z":
			has_upper = true
		elif c >= "a" and c <= "z":
			has_lower = true
		elif c >= "0" and c <= "9":
			has_digit = true
		else:
			has_symbol = true
	if not (has_upper and has_lower and has_digit and has_symbol):
		return false
	if pw.to_lower() in _common_passwords.map(func(p): return p.to_lower()):
		return false
	return true

func _get_strength(pw: String) -> Dictionary:
	var checks := {
		"length": pw.length() >= 12,
		"upper": false,
		"lower": false,
		"digit": false,
		"symbol": false,
	}
	for c in pw:
		if c >= "A" and c <= "Z":
			checks["upper"] = true
		elif c >= "a" and c <= "z":
			checks["lower"] = true
		elif c >= "0" and c <= "9":
			checks["digit"] = true
		else:
			checks["symbol"] = true

	var passed_count := 0
	for v in checks.values():
		if v:
			passed_count += 1

	var is_common := pw.to_lower() in _common_passwords.map(func(p): return p.to_lower())

	var level := 0  # 0=無 1=極弱 2=弱 3=中 4=強
	if passed_count == 5 and not is_common:
		level = 4
	elif passed_count >= 4:
		level = 3
	elif passed_count >= 3:
		level = 2
	elif passed_count >= 1:
		level = 1

	return {
		"checks": checks,
		"level": level,
		"is_common": is_common,
		"valid": passed_count == 5 and not is_common,
	}

# ============================================================
#  SETTINGS UI
# ============================================================
func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _content_settings(p: Panel, _desktop: Node) -> void:
	# Sidebar
	var side := Panel.new()
	side.size = Vector2(170, 408)
	side.add_theme_stylebox_override("panel", _sb(Color(0.94, 0.94, 0.96), 0))
	p.add_child(side)

	var items := ["系統", "藍牙與裝置", "網路與網際網路", "個人化", "應用程式", "帳號與安全", "隱私權與安全性", "Windows Update"]
	for i in items.size():
		var b := Button.new()
		b.text = items[i]
		b.position = Vector2(6, 6 + i * 34)
		b.size = Vector2(158, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		b.add_theme_stylebox_override("normal", _sb(Color(0.85, 0.9, 1.0) if i == 5 else Color(1, 1, 1, 0), 4))
		b.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.06), 4))
		side.add_child(b)

	# Right content area
	var right := Panel.new()
	right.name = "SettingsRight"
	right.position = Vector2(170, 0)
	right.size = Vector2(470, 408)
	right.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1), 0))
	p.add_child(right)

	_build_password_form(right)

func _build_password_form(right: Panel) -> void:
	for child in right.get_children():
		child.queue_free()

	# Title
	var title := Label.new()
	title.text = "帳號與安全"
	title.position = Vector2(20, 12)
	title.size = Vector2(430, 28)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	right.add_child(title)

	# Current password status
	var status_text := "目前密碼強度：極弱 🔴" if not _password_set else "目前密碼強度：強 🟢"
	var status_color := Color(0.8, 0.2, 0.2) if not _password_set else Color(0.15, 0.6, 0.15)
	var status := Label.new()
	status.text = status_text
	status.position = Vector2(20, 48)
	status.size = Vector2(430, 20)
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", status_color)
	right.add_child(status)

	var cur_pw := Label.new()
	cur_pw.text = "目前密碼：password123（不符合公司密碼政策）" if not _password_set else "密碼已更新 ✓"
	cur_pw.position = Vector2(20, 72)
	cur_pw.size = Vector2(430, 18)
	cur_pw.add_theme_font_size_override("font_size", 12)
	cur_pw.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	right.add_child(cur_pw)

	# Separator
	var sep := ColorRect.new()
	sep.position = Vector2(20, 98)
	sep.size = Vector2(430, 1)
	sep.color = Color(0.88, 0.88, 0.88)
	right.add_child(sep)

	# New password label
	var pw_label := Label.new()
	pw_label.text = "新密碼："
	pw_label.position = Vector2(20, 112)
	pw_label.size = Vector2(80, 20)
	pw_label.add_theme_font_size_override("font_size", 13)
	pw_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	right.add_child(pw_label)

	# Password input
	var pw_input := LineEdit.new()
	pw_input.name = "PasswordInput"
	pw_input.position = Vector2(20, 136)
	pw_input.size = Vector2(300, 32)
	pw_input.placeholder_text = "請輸入新密碼（12字元以上）"
	pw_input.secret = true
	pw_input.add_theme_font_size_override("font_size", 13)
	right.add_child(pw_input)

	# Show/hide password toggle
	var toggle := Button.new()
	toggle.text = "👁"
	toggle.position = Vector2(324, 136)
	toggle.size = Vector2(36, 32)
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.93, 0.95), 4))
	toggle.add_theme_stylebox_override("hover", _sb(Color(0.85, 0.85, 0.88), 4))
	toggle.pressed.connect(func():
		pw_input.secret = not pw_input.secret
		toggle.text = "🙈" if not pw_input.secret else "👁"
	)
	right.add_child(toggle)

	# Strength meter bar
	var meter_bg := ColorRect.new()
	meter_bg.name = "MeterBg"
	meter_bg.position = Vector2(20, 176)
	meter_bg.size = Vector2(300, 6)
	meter_bg.color = Color(0.88, 0.88, 0.88)
	right.add_child(meter_bg)

	var meter_fill := ColorRect.new()
	meter_fill.name = "MeterFill"
	meter_fill.position = Vector2(20, 176)
	meter_fill.size = Vector2(0, 6)
	meter_fill.color = Color(0.8, 0.2, 0.2)
	right.add_child(meter_fill)

	# Strength label
	var strength_label := Label.new()
	strength_label.name = "StrengthLabel"
	strength_label.text = ""
	strength_label.position = Vector2(20, 186)
	strength_label.size = Vector2(300, 18)
	strength_label.add_theme_font_size_override("font_size", 11)
	strength_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	right.add_child(strength_label)

	# Policy checklist
	var policy_items := [
		{"key": "length", "text": "至少 12 個字元"},
		{"key": "upper", "text": "包含大寫字母"},
		{"key": "lower", "text": "包含小寫字母"},
		{"key": "digit", "text": "包含數字"},
		{"key": "symbol", "text": "包含特殊符號"},
	]
	for i in policy_items.size():
		var cl := Label.new()
		cl.name = "Check_" + policy_items[i]["key"]
		cl.text = "✗  " + policy_items[i]["text"]
		cl.position = Vector2(24, 210 + i * 22)
		cl.size = Vector2(300, 20)
		cl.add_theme_font_size_override("font_size", 12)
		cl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
		right.add_child(cl)

	# Common password warning (hidden)
	var common_warn := Label.new()
	common_warn.name = "CommonWarn"
	common_warn.text = ""
	common_warn.position = Vector2(24, 322)
	common_warn.size = Vector2(420, 18)
	common_warn.add_theme_font_size_override("font_size", 11)
	common_warn.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	right.add_child(common_warn)

	# Real-time password validation
	var right_ref := right
	pw_input.text_changed.connect(func(new_text: String):
		_update_strength_ui(right_ref, new_text)
	)

	# Save button
	var save := Button.new()
	save.text = "變更密碼"
	save.position = Vector2(20, 348)
	save.size = Vector2(130, 34)
	save.add_theme_font_size_override("font_size", 13)
	save.add_theme_color_override("font_color", Color.WHITE)
	save.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.45, 0.8), 6))
	save.add_theme_stylebox_override("hover", _sb(Color(0.25, 0.5, 0.9), 6))
	save.pressed.connect(func():
		var pw_text := pw_input.text
		_on_save_password(right_ref, pw_text)
	)
	right.add_child(save)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(320, 370)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	finish.pressed.connect(func(): _on_finish_pressed(right_ref))
	right.add_child(finish)

func _update_strength_ui(right: Panel, pw: String) -> void:
	var result := _get_strength(pw)
	var checks: Dictionary = result["checks"]
	var level: int = result["level"]

	# Update checklist
	var check_map := {"length": "length", "upper": "upper", "lower": "lower", "digit": "digit", "symbol": "symbol"}
	var labels := {"length": "至少 12 個字元", "upper": "包含大寫字母", "lower": "包含小寫字母", "digit": "包含數字", "symbol": "包含特殊符號"}
	for key in check_map:
		var cl := right.get_node_or_null("Check_" + key)
		if cl:
			var ok: bool = checks[key]
			cl.text = ("✓  " if ok else "✗  ") + labels[key]
			cl.add_theme_color_override("font_color", Color(0.15, 0.6, 0.15) if ok else Color(0.6, 0.3, 0.3))

	# Update meter
	var meter := right.get_node_or_null("MeterFill")
	if meter:
		var widths := [0, 75, 150, 225, 300]
		var colors := [Color(0.8, 0.2, 0.2), Color(0.9, 0.5, 0.1), Color(0.8, 0.75, 0.1), Color(0.2, 0.7, 0.2), Color(0.15, 0.6, 0.15)]
		meter.size.x = widths[level] if pw.length() > 0 else 0
		meter.color = colors[level]

	# Update strength label
	var sl := right.get_node_or_null("StrengthLabel")
	if sl:
		var labels_str := ["", "極弱", "弱", "中等", "強"]
		sl.text = "密碼強度：" + labels_str[level] if pw.length() > 0 else ""

	# Common password warning
	var cw := right.get_node_or_null("CommonWarn")
	if cw:
		if result["is_common"]:
			cw.text = "⚠️ 這是常見的弱密碼，請更換！"
		else:
			cw.text = ""

func _on_save_password(right: Panel, pw: String) -> void:
	GameState.record_action("change_password", pw)
	var result := _get_strength(pw)

	if not result["valid"]:
		if result["is_common"]:
			GameState.record_wrong_action("common_password", pw)
			_show_feedback_box(right, "這是常見的弱密碼，容易被破解。請設定一組更安全的密碼。")
		else:
			var missing := []
			var checks: Dictionary = result["checks"]
			if not checks["length"]:
				missing.append("長度不足 12 字元")
			if not checks["upper"]:
				missing.append("缺少大寫字母")
			if not checks["lower"]:
				missing.append("缺少小寫字母")
			if not checks["digit"]:
				missing.append("缺少數字")
			if not checks["symbol"]:
				missing.append("缺少特殊符號")
			_show_feedback_box(right, "密碼不符合政策：" + "、".join(missing))
		return

	_password_set = true
	_password_value = pw
	_build_password_form(right)
	_show_feedback_box_success(right, "密碼已成功更新！請點擊「完成作答」提交結果。")

func _on_finish_pressed(right: Panel) -> void:
	if not LevelManager.level_active:
		return
	var lid := LevelManager.current_level
	ScoreManager.increment_attempts(lid)
	var result := check_completion()

	if result["passed"]:
		var score := calculate_score()
		LevelManager.complete_level(score)
	else:
		_show_feedback_box(right, result["details"])
		if ScoreManager.get_attempts(lid) >= 3:
			var existing := right.get_node_or_null("GiveUpBtn")
			if not existing:
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				gub.position = Vector2(160, 370)
				gub.size = Vector2(130, 32)
				gub.add_theme_font_size_override("font_size", 12)
				gub.add_theme_color_override("font_color", Color.WHITE)
				gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
				gub.pressed.connect(func(): LevelManager.fail_level())
				right.add_child(gub)

# ============================================================
#  FEEDBACK BOXES
# ============================================================
func _show_feedback_box(right: Panel, text: String) -> void:
	var old := right.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 350)
	box.size = Vector2(450, 54)
	var box_sb := _sb(Color(1.0, 0.95, 0.9), 8)
	box_sb.border_color = Color(0.9, 0.6, 0.2)
	box_sb.border_width_left = 4
	box_sb.border_width_top = 1
	box_sb.border_width_right = 1
	box_sb.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 10
	right.add_child(box)

	var icon_label := Label.new()
	icon_label.text = "💡"
	icon_label.position = Vector2(12, 8)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 16)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(40, 6)
	msg.size = Vector2(390, 38)
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

func _show_feedback_box_success(right: Panel, text: String) -> void:
	var old := right.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 350)
	box.size = Vector2(450, 54)
	var box_sb := _sb(Color(0.92, 0.98, 0.92), 8)
	box_sb.border_color = Color(0.3, 0.75, 0.3)
	box_sb.border_width_left = 4
	box_sb.border_width_top = 1
	box_sb.border_width_right = 1
	box_sb.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 10
	right.add_child(box)

	var icon_label := Label.new()
	icon_label.text = "✅"
	icon_label.position = Vector2(12, 8)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 16)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(40, 6)
	msg.size = Vector2(390, 38)
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
