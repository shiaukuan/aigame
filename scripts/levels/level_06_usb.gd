extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track player actions
var _opened_files: Array[String] = []
var _browsed_usb := false
var _ejected := false
var _reported := false

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 6
	data.title = "特洛伊的禮物"
	data.category = "security"
	data.difficulty = 3
	data.puzzle_title = "特洛伊的禮物"
	data.scenario_text = "停車場的地上躺著一個小東西。\n上面貼的標籤寫著一個讓人很想看的字眼。\n你撿起了它，現在它已經插在你的電腦上了。\n螢幕上彈出了一個視窗。"
	data.task_hint = "好奇心害死貓——也害死硬碟。\n這個視窗裡的東西看起來很誘人，但你只有一個正確動作：\n讓它離開你的電腦，然後告訴該知道的人。"
	data.teaching_points = PackedStringArray([
		"不要把來路不明的 USB 插入電腦（最佳做法）",
		"USB 可能含有自動執行的惡意程式",
		"「好奇心」是社交工程最常利用的弱點",
		"發現可疑裝置應立即回報 IT 部門",
	])
	data.desktop_config = {}
	return data

func setup_desktop(desktop: Node) -> void:
	# Show USB detection notification toast (primary visual cue)
	_show_usb_notification(desktop)

	# Hide desktop files not relevant to this level
	var file_container := desktop.get_node_or_null("DesktopFiles")
	if file_container:
		for child in file_container.get_children():
			child.visible = false

func _show_usb_notification(desktop: Node) -> void:
	var toast := Panel.new()
	toast.name = "USBNotification"
	toast.position = Vector2(380, 580)
	toast.size = Vector2(520, 56)
	var tsb := _sb(Color(0.98, 0.98, 1.0), 10)
	tsb.shadow_color = Color(0, 0, 0, 0.25)
	tsb.shadow_size = 8
	tsb.border_color = Color(0.2, 0.5, 0.9)
	tsb.border_width_left = 4
	tsb.border_width_top = 1
	tsb.border_width_right = 1
	tsb.border_width_bottom = 1
	toast.add_theme_stylebox_override("panel", tsb)
	toast.z_index = 180
	desktop.add_child(toast)

	var icon := Label.new()
	icon.text = "🔌"
	icon.position = Vector2(12, 10)
	icon.size = Vector2(32, 32)
	icon.add_theme_font_size_override("font_size", 22)
	toast.add_child(icon)

	var msg := Label.new()
	msg.text = "偵測到新的 USB 裝置：USB 隨身碟 (E:)\n標籤：Q4財報_機密"
	msg.position = Vector2(50, 8)
	msg.size = Vector2(420, 40)
	msg.add_theme_font_size_override("font_size", 12)
	msg.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	toast.add_child(msg)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(488, 4)
	close_btn.size = Vector2(24, 24)
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	close_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
	close_btn.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.08), 4))
	close_btn.pressed.connect(func(): toast.queue_free())
	toast.add_child(close_btn)

	# Auto-dismiss after 6 seconds
	var dismiss_timer := Timer.new()
	dismiss_timer.name = "USBNotifyDismiss"
	dismiss_timer.wait_time = 6.0
	dismiss_timer.one_shot = true
	dismiss_timer.autostart = true
	desktop.add_child(dismiss_timer)
	dismiss_timer.timeout.connect(func():
		if is_instance_valid(toast):
			toast.queue_free()
		dismiss_timer.queue_free()
	)

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "檔案總管":
		_browsed_usb = true
		GameState.record_action("open_file_manager")
		_content_file_manager_usb(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	var has_opened_files := _opened_files.size() > 0

	if not _ejected:
		return {
			"passed": false,
			"details": "你還沒有安全退出 USB 裝置。請在檔案總管中找到安全退出的選項。",
		}

	# Pass if ejected (opening files is wrong but doesn't block passing)
	var passed := true
	var details := ""

	if has_opened_files:
		details = "你打開了 USB 中的檔案，這在真實情況下可能導致電腦中毒。但你最終有安全退出 USB。"

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
#  USB FILE DATA
# ============================================================
func _get_usb_files() -> Array:
	return [
		{
			"name": "Q4財報_機密.xlsx",
			"size": "2.4 MB",
			"type": "Excel 活頁簿",
			"icon": "📊",
			"dangerous": true,
			"warning": "這個檔案可能包含惡意巨集，開啟後可能自動執行惡意程式碼。",
		},
		{
			"name": "員工通訊錄.xlsx",
			"size": "156 KB",
			"type": "Excel 活頁簿",
			"icon": "📊",
			"dangerous": true,
			"warning": "來路不明的 Excel 檔案可能包含隱藏的惡意巨集。",
		},
		{
			"name": "重要公告.docx",
			"size": "89 KB",
			"type": "Word 文件",
			"icon": "📄",
			"dangerous": true,
			"warning": "不明來源的 Word 文件可能利用巨集或漏洞執行惡意程式。",
		},
		{
			"name": "專案企劃書.pptx",
			"size": "5.7 MB",
			"type": "PowerPoint 簡報",
			"icon": "📙",
			"dangerous": true,
			"warning": "PowerPoint 檔案也可能被嵌入惡意程式碼。",
		},
		{
			"name": "autorun.inf",
			"size": "1 KB",
			"type": "設定資訊",
			"icon": "⚙️",
			"dangerous": true,
			"warning": "autorun.inf 是自動執行設定檔，常被惡意程式利用來自動感染電腦！",
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

func _content_file_manager_usb(p: Panel, desktop: Node) -> void:
	# Nav bar
	var nav := Panel.new()
	nav.size = Vector2(640, 34)
	nav.add_theme_stylebox_override("panel", _sb(Color(0.96, 0.96, 0.98), 0))
	p.add_child(nav)

	var nav_label := Label.new()
	nav_label.text = "📁 > 本機 > USB 隨身碟 (E:)"
	nav_label.position = Vector2(12, 6)
	nav_label.size = Vector2(400, 22)
	nav_label.add_theme_font_size_override("font_size", 12)
	nav_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	nav.add_child(nav_label)

	# Tree sidebar
	var tree := Panel.new()
	tree.position = Vector2(0, 34)
	tree.size = Vector2(150, 374)
	tree.add_theme_stylebox_override("panel", _sb(Color(0.97, 0.97, 0.98), 0))
	p.add_child(tree)

	var tree_items := ["▼ 本機", "  📁 桌面", "  📁 文件", "  📁 下載", "  📁 圖片", "  💿 本機磁碟(C:)", "  🔌 USB磁碟(E:)"]
	for i in tree_items.size():
		var tl := Label.new()
		tl.text = tree_items[i]
		tl.position = Vector2(6, 6 + i * 24)
		tl.size = Vector2(138, 20)
		tl.add_theme_font_size_override("font_size", 11)
		# Highlight the USB drive entry
		if i == 6:
			tl.add_theme_color_override("font_color", Color(0.15, 0.35, 0.7))
		else:
			tl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		tree.add_child(tl)

	# Right content area
	var right := Panel.new()
	right.name = "USBContent"
	right.position = Vector2(150, 34)
	right.size = Vector2(490, 374)
	right.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1), 0))
	p.add_child(right)

	_build_usb_content(right, p, desktop)

func _build_usb_content(right: Panel, p: Panel, desktop: Node) -> void:
	for child in right.get_children():
		child.queue_free()

	# USB warning banner
	var banner := Panel.new()
	banner.position = Vector2(0, 0)
	banner.size = Vector2(490, 40)
	var banner_sb := _sb(Color(1.0, 0.96, 0.9), 0)
	banner_sb.border_color = Color(0.9, 0.6, 0.2)
	banner_sb.border_width_bottom = 2
	banner.add_theme_stylebox_override("panel", banner_sb)
	right.add_child(banner)

	var warn_icon := Label.new()
	warn_icon.text = "⚠️"
	warn_icon.position = Vector2(8, 6)
	warn_icon.size = Vector2(24, 24)
	warn_icon.add_theme_font_size_override("font_size", 16)
	banner.add_child(warn_icon)

	var warn_text := Label.new()
	warn_text.text = "USB 隨身碟 (E:)  |  標籤：Q4財報_機密  |  容量：16 GB"
	warn_text.position = Vector2(34, 10)
	warn_text.size = Vector2(380, 20)
	warn_text.add_theme_font_size_override("font_size", 11)
	warn_text.add_theme_color_override("font_color", Color(0.4, 0.25, 0.05))
	banner.add_child(warn_text)

	# Header row
	var hdr := Panel.new()
	hdr.position = Vector2(0, 40)
	hdr.size = Vector2(490, 24)
	hdr.add_theme_stylebox_override("panel", _sb(Color(0.94, 0.94, 0.96), 0))
	right.add_child(hdr)

	var hdr_name := Label.new()
	hdr_name.text = "名稱"
	hdr_name.position = Vector2(8, 2)
	hdr_name.size = Vector2(100, 20)
	hdr_name.add_theme_font_size_override("font_size", 11)
	hdr_name.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hdr.add_child(hdr_name)

	var hdr_size := Label.new()
	hdr_size.text = "大小"
	hdr_size.position = Vector2(240, 2)
	hdr_size.size = Vector2(60, 20)
	hdr_size.add_theme_font_size_override("font_size", 11)
	hdr_size.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hdr.add_child(hdr_size)

	var hdr_type := Label.new()
	hdr_type.text = "類型"
	hdr_type.position = Vector2(330, 2)
	hdr_type.size = Vector2(100, 20)
	hdr_type.add_theme_font_size_override("font_size", 11)
	hdr_type.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hdr.add_child(hdr_type)

	# File list
	var usb_files := _get_usb_files()
	for i in usb_files.size():
		var file: Dictionary = usb_files[i]
		var row := Button.new()
		row.text = file["icon"] + " " + file["name"]
		row.position = Vector2(0, 64 + i * 28)
		row.size = Vector2(490, 26)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		row.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 2))
		row.add_theme_stylebox_override("hover", _sb(Color(0.9, 0.93, 1.0), 2))
		right.add_child(row)

		var size_label := Label.new()
		size_label.text = file["size"]
		size_label.position = Vector2(240, 3)
		size_label.size = Vector2(60, 20)
		size_label.add_theme_font_size_override("font_size", 11)
		size_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(size_label)

		var type_label := Label.new()
		type_label.text = file["type"]
		type_label.position = Vector2(330, 3)
		type_label.size = Vector2(120, 20)
		type_label.add_theme_font_size_override("font_size", 11)
		type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(type_label)

		# Double-click to open file (wrong action)
		var fname: String = file["name"]
		var fwarn: String = file["warning"]
		var right_ref := right
		var p_ref := p
		var desktop_ref := desktop
		row.pressed.connect(func():
			_on_open_usb_file(fname, fwarn, right_ref, p_ref, desktop_ref)
		)

	# --- Action buttons at the bottom ---
	# Safe eject button (correct action)
	var eject_btn := Button.new()
	eject_btn.text = "⏏ 安全退出 USB"
	eject_btn.position = Vector2(10, 334)
	eject_btn.size = Vector2(150, 32)
	eject_btn.add_theme_font_size_override("font_size", 12)
	eject_btn.add_theme_color_override("font_color", Color.WHITE)
	eject_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.65, 0.35), 6))
	eject_btn.add_theme_stylebox_override("hover", _sb(Color(0.25, 0.75, 0.4), 6))
	var right_ref2 := right
	var p_ref2 := p
	var desktop_ref2 := desktop
	eject_btn.pressed.connect(func():
		_on_eject_usb(right_ref2, p_ref2, desktop_ref2)
	)
	right.add_child(eject_btn)

	# Report button
	var report_btn := Button.new()
	report_btn.text = "📢 回報 IT 部門"
	report_btn.position = Vector2(170, 334)
	report_btn.size = Vector2(150, 32)
	report_btn.add_theme_font_size_override("font_size", 12)
	report_btn.add_theme_color_override("font_color", Color.WHITE)
	report_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	report_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var p_ref3 := p
	report_btn.pressed.connect(func():
		_on_report_usb(p_ref3)
	)
	right.add_child(report_btn)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(350, 334)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var p_ref4 := p
	finish.pressed.connect(func(): _on_finish_pressed(p_ref4))
	right.add_child(finish)

func _on_open_usb_file(fname: String, warning: String, _right: Panel, p: Panel, _desktop: Node) -> void:
	if not LevelManager.level_active:
		return
	if fname not in _opened_files:
		_opened_files.append(fname)
	GameState.record_wrong_action("opened_usb_file", fname)
	_show_feedback_box(p, "⚠️ 你打開了「%s」！\n%s" % [fname, warning])

func _on_eject_usb(right: Panel, p: Panel, _desktop: Node) -> void:
	if not LevelManager.level_active:
		return
	_ejected = true
	GameState.record_action("eject_usb")

	# Replace USB content with ejected message
	for child in right.get_children():
		child.queue_free()

	var icon := Label.new()
	icon.text = "✅"
	icon.position = Vector2(200, 100)
	icon.size = Vector2(60, 60)
	icon.add_theme_font_size_override("font_size", 40)
	right.add_child(icon)

	var msg := Label.new()
	msg.text = "USB 裝置已安全退出"
	msg.position = Vector2(130, 160)
	msg.size = Vector2(300, 30)
	msg.add_theme_font_size_override("font_size", 17)
	msg.add_theme_color_override("font_color", Color(0.15, 0.5, 0.2))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(msg)

	var sub_msg := Label.new()
	sub_msg.text = "你可以安全地拔除 USB 隨身碟。\n建議將撿到的 USB 交給 IT 部門處理。"
	sub_msg.position = Vector2(100, 200)
	sub_msg.size = Vector2(340, 50)
	sub_msg.add_theme_font_size_override("font_size", 12)
	sub_msg.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	sub_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(sub_msg)

	# Report button (still available after ejecting)
	if not _reported:
		var report_btn := Button.new()
		report_btn.text = "📢 回報 IT 部門"
		report_btn.position = Vector2(100, 270)
		report_btn.size = Vector2(150, 32)
		report_btn.add_theme_font_size_override("font_size", 12)
		report_btn.add_theme_color_override("font_color", Color.WHITE)
		report_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
		report_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
		var p_ref := p
		report_btn.pressed.connect(func():
			_on_report_usb(p_ref)
		)
		right.add_child(report_btn)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(260, 270)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var p_ref2 := p
	finish.pressed.connect(func(): _on_finish_pressed(p_ref2))
	right.add_child(finish)

	_show_feedback_box_success(p, "USB 裝置已安全退出。記得回報 IT 部門！")

func _on_report_usb(p: Panel) -> void:
	if not LevelManager.level_active:
		return
	_reported = true
	GameState.record_action("report_usb_to_it")
	_show_feedback_box_success(p, "已回報 IT 部門！他們會調查這個可疑的 USB 裝置。")

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
			var existing := parent.get_node_or_null("GiveUpBtn")
			if not existing:
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				gub.position = Vector2(10, 310)
				gub.size = Vector2(130, 32)
				gub.add_theme_font_size_override("font_size", 12)
				gub.add_theme_color_override("font_color", Color.WHITE)
				gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
				gub.pressed.connect(func(): LevelManager.fail_level())
				parent.add_child(gub)

# ============================================================
#  FEEDBACK BOXES
# ============================================================
func _show_feedback_box(parent: Panel, text: String) -> void:
	var old := parent.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 350)
	box.size = Vector2(620, 56)
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
	msg.position = Vector2(12, 6)
	msg.size = Vector2(580, 42)
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
	box.position = Vector2(10, 350)
	box.size = Vector2(620, 56)
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
	msg.position = Vector2(12, 6)
	msg.size = Vector2(580, 42)
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
