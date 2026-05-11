extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

var _removed: Array[int] = []
var _wifi_panel: Panel = null
var _content_bottom_y: float = 0.0

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 5
	data.title = "空氣中的陷阱"
	data.category = "security"
	data.difficulty = 2
	data.puzzle_title = "空氣中的陷阱"
	data.scenario_text = "你不在辦公室。周圍是咖啡的香氣和鍵盤敲擊聲。\n你需要上網處理一件急事，但你的網路還沒連上。\n空氣中飄著好幾條看不見的線，有些是蜘蛛網。"
	data.task_hint = "免費的東西往往最貴。\n你平常靠什麼連上這個世界？那個訊號的入口，今天要特別小心選擇。"
	data.teaching_points = PackedStringArray([
		"避免使用無密碼的公共 WiFi",
		"處理公事一定要連公司 VPN 或 OA 網路",
		"注意名稱可疑的 WiFi（可能是 Evil Twin 攻擊）",
		"手機熱點是相對安全的替代連線方式",
	])
	data.desktop_config = {}
	return data

func setup_desktop(desktop: Node) -> void:
	# Replace WiFi panel content with level-specific interactive list
	_wifi_panel = desktop.get_node_or_null("WiFiPanel")
	if _wifi_panel:
		# Clear default content
		for child in _wifi_panel.get_children():
			child.queue_free()
		# Make panel taller to fit all networks + buttons + feedback area
		_wifi_panel.size = Vector2(320, 460)
		_wifi_panel.position = Vector2(940, 210)
		# Rebuild with interactive content
		_build_wifi_content()

func build_app_content(app_name: String, _panel: Panel, _desktop: Node) -> bool:
	return false

func check_completion() -> Dictionary:
	var unsafe_indices := [0, 2]  # Cafe_Free_WiFi, Free_Internet_Fast
	var safe_indices := [1, 3, 4]

	var removed_unsafe := 0
	var removed_safe := 0
	for idx in _removed:
		if idx in unsafe_indices:
			removed_unsafe += 1
		if idx in safe_indices:
			removed_safe += 1

	var passed := removed_unsafe == 2 and removed_safe == 0
	var details := ""
	if removed_safe > 0:
		details = "你移除了安全的網路！請只移除不安全的 WiFi 連線。"
	elif removed_unsafe < 2:
		details = "還有 %d 個不安全的 WiFi 網路需要移除。" % (2 - removed_unsafe)

	return {"passed": passed, "details": details}

func calculate_score() -> int:
	var attempt_count := ScoreManager.get_attempts(LevelManager.current_level)
	var has_wrong := GameState.wrong_actions.size() > 0
	if attempt_count == 1 and not has_wrong:
		return 100
	return 60

# ============================================================
#  WIFI NETWORK DATA
# ============================================================
func _get_networks() -> Array:
	return [
		{"name": "Cafe_Free_WiFi", "encrypted": false, "detail": "開放網路・無加密", "safe": false,
		 "reason": "無密碼的公共 WiFi，任何人都能監聽你的網路流量"},
		{"name": "CHT Wi-Fi(HiNet)", "encrypted": true, "detail": "WPA2 加密・需要密碼", "safe": true,
		 "reason": "電信業者提供的加密 WiFi，相對安全"},
		{"name": "Free_Internet_Fast", "encrypted": false, "detail": "開放網路・無加密", "safe": false,
		 "reason": "名稱可疑的免費 WiFi，可能是 Evil Twin 攻擊"},
		{"name": "自己的手機熱點", "encrypted": true, "detail": "WPA2 加密・個人熱點", "safe": true,
		 "reason": "你自己的手機熱點，安全可靠"},
		{"name": "CHT Wi-Fi OA", "encrypted": true, "detail": "WPA2-Enterprise・公司網路", "safe": true,
		 "reason": "公司 OA 網路，處理公事最安全的選擇"},
	]

# ============================================================
#  UI HELPERS
# ============================================================
func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _build_wifi_content() -> void:
	if not is_instance_valid(_wifi_panel):
		return

	# Clear existing
	for child in _wifi_panel.get_children():
		child.queue_free()

	# Title
	var title := Label.new()
	title.text = "📶 Wi-Fi — 選擇安全的網路"
	title.position = Vector2(14, 8)
	title.size = Vector2(290, 24)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_wifi_panel.add_child(title)

	# Status
	var status := Label.new()
	status.text = "⚠️ 目前未連線 — 請移除不安全的網路"
	status.position = Vector2(14, 32)
	status.size = Vector2(290, 18)
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	_wifi_panel.add_child(status)

	# Separator
	var sep := ColorRect.new()
	sep.position = Vector2(10, 54)
	sep.size = Vector2(300, 1)
	sep.color = Color(0.85, 0.85, 0.85)
	_wifi_panel.add_child(sep)

	# Network list
	var networks := _get_networks()
	var y_offset := 60
	for i in networks.size():
		if i in _removed:
			continue
		var net: Dictionary = networks[i]

		var row := Panel.new()
		row.position = Vector2(6, y_offset)
		row.size = Vector2(308, 52)
		var row_sb := _sb(Color(1, 1, 1, 0.6), 6)
		row.add_theme_stylebox_override("panel", row_sb)
		_wifi_panel.add_child(row)

		# Lock / warning icon
		var icon := Label.new()
		icon.text = "🔒" if net["encrypted"] else "⚠️"
		icon.position = Vector2(8, 6)
		icon.size = Vector2(24, 24)
		icon.add_theme_font_size_override("font_size", 14)
		row.add_child(icon)

		# Network name
		var name_lbl := Label.new()
		name_lbl.text = net["name"]
		name_lbl.position = Vector2(34, 4)
		name_lbl.size = Vector2(190, 20)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		row.add_child(name_lbl)

		# Detail
		var detail := Label.new()
		detail.text = net["detail"]
		detail.position = Vector2(34, 26)
		detail.size = Vector2(190, 16)
		detail.add_theme_font_size_override("font_size", 10)
		detail.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5) if net["encrypted"] else Color(0.8, 0.4, 0.1))
		row.add_child(detail)

		# Remove button
		var rm_btn := Button.new()
		rm_btn.text = "清除"
		rm_btn.position = Vector2(236, 12)
		rm_btn.size = Vector2(62, 26)
		rm_btn.add_theme_font_size_override("font_size", 11)
		rm_btn.add_theme_color_override("font_color", Color.WHITE)
		rm_btn.add_theme_stylebox_override("normal", _sb(Color(0.75, 0.25, 0.25), 5))
		rm_btn.add_theme_stylebox_override("hover", _sb(Color(0.85, 0.35, 0.35), 5))
		var idx := i
		rm_btn.pressed.connect(func(): _on_forget_network(idx))
		row.add_child(rm_btn)

		y_offset += 56

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(180, y_offset + 8)
	finish.size = Vector2(120, 30)
	finish.add_theme_font_size_override("font_size", 11)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	finish.pressed.connect(func(): _on_finish_pressed())
	_wifi_panel.add_child(finish)
	_content_bottom_y = y_offset + 8 + 30 + 6  # finish button bottom + spacing

func _on_forget_network(index: int) -> void:
	if not LevelManager.level_active:
		return
	var networks := _get_networks()
	var net: Dictionary = networks[index]

	if net["safe"]:
		GameState.record_wrong_action("removed_safe_network", net["name"])
		_show_feedback_box("⚠️ 「%s」是安全的網路！\n%s" % [net["name"], net["reason"]])
		return

	_removed.append(index)
	GameState.record_action("forget_network", net["name"])
	# Rebuild first, then show success message on the freshly rebuilt panel
	_build_wifi_content()
	_show_feedback_box_success("已移除「%s」\n%s" % [net["name"], net["reason"]])

func _on_finish_pressed() -> void:
	if not LevelManager.level_active:
		return
	var lid := LevelManager.current_level
	ScoreManager.increment_attempts(lid)
	var result := check_completion()

	if result["passed"]:
		var score := calculate_score()
		LevelManager.complete_level(score)
	else:
		_show_feedback_box(result["details"])
		if ScoreManager.get_attempts(lid) >= 3:
			if is_instance_valid(_wifi_panel) and not _wifi_panel.get_node_or_null("GiveUpBtn"):
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				gub.position = Vector2(14, _content_bottom_y + 46)
				gub.size = Vector2(100, 28)
				gub.add_theme_font_size_override("font_size", 11)
				gub.add_theme_color_override("font_color", Color.WHITE)
				gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 5))
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 5))
				gub.pressed.connect(func(): LevelManager.fail_level())
				_wifi_panel.add_child(gub)

# ============================================================
#  FEEDBACK BOXES
# ============================================================
func _show_feedback_box(text: String) -> void:
	if not is_instance_valid(_wifi_panel):
		return
	var old := _wifi_panel.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(6, _content_bottom_y)
	box.size = Vector2(308, 40)
	var box_sb := _sb(Color(1.0, 0.95, 0.9), 6)
	box_sb.border_color = Color(0.9, 0.6, 0.2)
	box_sb.border_width_left = 3
	box_sb.border_width_top = 1
	box_sb.border_width_right = 1
	box_sb.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 10
	_wifi_panel.add_child(box)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(10, 4)
	msg.size = Vector2(268, 32)
	msg.add_theme_font_size_override("font_size", 10)
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

func _show_feedback_box_success(text: String) -> void:
	if not is_instance_valid(_wifi_panel):
		return
	var old := _wifi_panel.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(6, _content_bottom_y)
	box.size = Vector2(308, 40)
	var box_sb := _sb(Color(0.92, 0.98, 0.92), 6)
	box_sb.border_color = Color(0.3, 0.75, 0.3)
	box_sb.border_width_left = 3
	box_sb.border_width_top = 1
	box_sb.border_width_right = 1
	box_sb.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 10
	_wifi_panel.add_child(box)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(10, 4)
	msg.size = Vector2(268, 32)
	msg.add_theme_font_size_override("font_size", 10)
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
