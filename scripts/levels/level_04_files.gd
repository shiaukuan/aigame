extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Suspicious file names (must be deleted)
var _suspicious := ["薪資表_2024.xlsx.exe", "free_vpn_setup.exe", "system_update.bat"]
# Safe file names (must NOT be deleted)
var _safe := ["會議記錄.docx", "照片.jpg"]
# Deleted files
var _deleted: Array[String] = []

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 4
	data.title = "不請自來的客人"
	data.category = "security"
	data.difficulty = 2
	data.puzzle_title = "不請自來的客人"
	data.scenario_text = "你確定昨天下班前桌面是乾淨的。\n但今天早上，多了幾個你不記得放過的東西。\n有些看起來人畜無害，有些……穿著別人的衣服。"
	data.task_hint = "名字會騙人。一個叫「報告」的東西，不一定真的是報告。\n看清楚它們的「真面目」——尤其是最後幾個字。\n千萬不要好奇地打開它們，找到正確的處理方式。"
	data.teaching_points = PackedStringArray([
		"注意雙重副檔名（.xlsx.exe）",
		"不要執行來路不明的 .exe、.bat",
		"發現可疑檔案先回報，不要自己處理",
	])
	data.desktop_config = {}
	return data

func setup_desktop(desktop: Node) -> void:
	# Hide non-relevant desktop files, show only level 4 files
	var file_container := desktop.get_node_or_null("DesktopFiles")
	if file_container:
		for child in file_container.get_children():
			var data = child.get_meta("icon_data")
			var fname: String = data["name"]
			if fname not in _suspicious and fname not in _safe:
				child.visible = false

	# Floating "完成作答" button (top area)
	var finish := Button.new()
	finish.name = "Level4Finish"
	finish.text = "📋 完成作答"
	finish.position = Vector2(1120, 16)
	finish.size = Vector2(140, 36)
	finish.z_index = 50
	finish.add_theme_font_size_override("font_size", 13)
	finish.add_theme_color_override("font_color", Color.WHITE)
	var fsb := _sb(Color(0.2, 0.5, 0.9), 8)
	fsb.shadow_color = Color(0, 0, 0, 0.2)
	fsb.shadow_size = 6
	finish.add_theme_stylebox_override("normal", fsb)
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 8))
	finish.pressed.connect(func(): _on_finish_pressed(desktop))
	desktop.add_child(finish)

func build_app_content(_app_name: String, _panel: Panel, _desktop: Node) -> bool:
	return false

# Called by desktop.gd when player double-clicks a file
func on_file_open(file_name: String, desktop: Node) -> bool:
	if file_name in _suspicious:
		GameState.record_wrong_action("opened_suspicious_file", file_name)
		_show_desktop_warning(desktop, "⚠️ 你打開了可疑檔案「%s」！\n真實情況下，這可能讓電腦中毒。" % file_name)
		return true
	if file_name in _safe:
		GameState.record_action("opened_safe_file", file_name)
	return false

# Called by desktop.gd for right-click context menu actions
func on_ctx_action(action: String, data: Dictionary, icon_type: String, target: Control, desktop: Node) -> bool:
	if icon_type != "file":
		return false
	var fname: String = data["name"]

	match action:
		"開啟", "以系統管理員身分執行":
			if fname in _suspicious:
				GameState.record_wrong_action("opened_suspicious_file", fname)
				var warn_msg := "⚠️ 你以系統管理員身分執行了可疑檔案「%s」！\n這比普通開啟更危險，惡意程式將取得最高權限。" % fname if action == "以系統管理員身分執行" else "⚠️ 你打開了可疑檔案「%s」！\n真實情況下，這可能讓電腦中毒。" % fname
				_show_desktop_warning(desktop, warn_msg)
				return true
			return false
		"檢視內容":
			GameState.record_action("inspect_file", fname)
			_show_file_properties(desktop, fname)
			return true
		"刪除", "回報並刪除":
			_on_delete_file(fname, target, desktop)
			return true
		"掃描病毒":
			GameState.record_action("scan_file", fname)
			var is_sus := fname in _suspicious
			var msg := "🔴 偵測到威脅！「%s」為可疑檔案。" % fname if is_sus else "🟢 「%s」安全，未偵測到威脅。" % fname
			if is_sus:
				_show_desktop_warning(desktop, msg)
			else:
				_show_desktop_success(desktop, msg)
			return true

	return false

func _on_delete_file(fname: String, target: Control, desktop: Node) -> void:
	if fname in _safe:
		GameState.record_wrong_action("deleted_safe_file", fname)
		_show_desktop_warning(desktop, "「%s」是正常檔案，不應該刪除！" % fname)
		return

	if fname not in _deleted:
		_deleted.append(fname)
	GameState.record_action("delete_file", fname)
	_show_desktop_success(desktop, "已刪除「%s」。" % fname)

	# Hide the icon from desktop
	if is_instance_valid(target):
		target.queue_free()

func check_completion() -> Dictionary:
	var all_suspicious_deleted := true
	for s in _suspicious:
		if s not in _deleted:
			all_suspicious_deleted = false
			break

	var deleted_safe := false
	for wa in GameState.wrong_actions:
		if wa["action"] == "deleted_safe_file":
			deleted_safe = true
			break

	var opened_suspicious := false
	for wa in GameState.wrong_actions:
		if wa["action"] == "opened_suspicious_file":
			opened_suspicious = true
			break

	var passed := all_suspicious_deleted
	var details := ""
	if not all_suspicious_deleted:
		var remaining := 0
		for s in _suspicious:
			if s not in _deleted:
				remaining += 1
		details = "桌面上還有 %d 個可疑檔案需要刪除。" % remaining
	return {
		"passed": passed,
		"opened_suspicious": opened_suspicious,
		"details": details,
	}

func calculate_score() -> int:
	var attempt_count := ScoreManager.get_attempts(LevelManager.current_level)
	var has_wrong := GameState.wrong_actions.size() > 0
	if attempt_count == 1 and not has_wrong:
		return 100
	return 60

func _on_finish_pressed(desktop: Node) -> void:
	if not LevelManager.level_active:
		return
	var lid := LevelManager.current_level
	ScoreManager.increment_attempts(lid)
	var result := check_completion()

	if result["passed"]:
		var score := calculate_score()
		# Clean up level UI
		var finish_btn := desktop.get_node_or_null("Level4Finish")
		if finish_btn:
			finish_btn.queue_free()
		LevelManager.complete_level(score)
	else:
		_show_desktop_warning(desktop, result["details"])
		if ScoreManager.get_attempts(lid) >= 3:
			var existing := desktop.get_node_or_null("GiveUpBtn")
			if not existing:
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				gub.position = Vector2(1120, 58)
				gub.size = Vector2(140, 34)
				gub.z_index = 50
				gub.add_theme_font_size_override("font_size", 12)
				gub.add_theme_color_override("font_color", Color.WHITE)
				var gsb := _sb(Color(0.5, 0.5, 0.55), 8)
				gsb.shadow_color = Color(0, 0, 0, 0.15)
				gsb.shadow_size = 4
				gub.add_theme_stylebox_override("normal", gsb)
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 8))
				gub.pressed.connect(func():
					var fb := desktop.get_node_or_null("Level4Finish")
					if fb:
						fb.queue_free()
					gub.queue_free()
					LevelManager.fail_level()
				)
				desktop.add_child(gub)

# ============================================================
#  FILE PROPERTIES DIALOG
# ============================================================
func _show_file_properties(desktop: Node, fname: String) -> void:
	var old := desktop.get_node_or_null("FilePropsOverlay")
	if old:
		old.queue_free()

	var info := _get_file_info(fname)

	var overlay := Panel.new()
	overlay.name = "FilePropsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	overlay.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.3), 0))
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	desktop.add_child(overlay)

	var card := Panel.new()
	card.size = Vector2(340, 260)
	card.position = Vector2(470, 230)
	var card_sb := _sb(Color(0.97, 0.97, 0.98), 8)
	card_sb.shadow_color = Color(0, 0, 0, 0.25)
	card_sb.shadow_size = 12
	card_sb.border_color = Color(0.82, 0.82, 0.85)
	card_sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", card_sb)
	overlay.add_child(card)

	var title := Label.new()
	title.text = "📋  檔案內容"
	title.position = Vector2(14, 10)
	title.size = Vector2(280, 24)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	card.add_child(title)

	var sep := ColorRect.new()
	sep.position = Vector2(14, 38)
	sep.size = Vector2(312, 1)
	sep.color = Color(0.85, 0.85, 0.87)
	card.add_child(sep)

	var fields := [
		["檔案名稱：", info["name"]],
		["檔案類型：", info["type"]],
		["副檔名：", info["ext"]],
		["檔案大小：", info["size"]],
		["建立日期：", info["date"]],
		["來源：", info["source"]],
	]
	var y := 48
	for f in fields:
		var lbl := Label.new()
		lbl.text = f[0]
		lbl.position = Vector2(18, y)
		lbl.size = Vector2(90, 18)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		card.add_child(lbl)

		var val := Label.new()
		val.text = f[1]
		val.position = Vector2(110, y)
		val.size = Vector2(216, 18)
		val.add_theme_font_size_override("font_size", 12)
		val.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		card.add_child(val)
		y += 24

	# Warning for suspicious files
	if fname in _suspicious:
		var warn := Label.new()
		warn.text = "⚠️ 此檔案的副檔名可能有偽裝！"
		warn.position = Vector2(18, y + 4)
		warn.size = Vector2(300, 18)
		warn.add_theme_font_size_override("font_size", 11)
		warn.add_theme_color_override("font_color", Color(0.8, 0.4, 0.1))
		card.add_child(warn)

	# Close button
	var close := Button.new()
	close.text = "關閉"
	close.position = Vector2(130, 220)
	close.size = Vector2(80, 30)
	close.add_theme_font_size_override("font_size", 13)
	close.add_theme_color_override("font_color", Color.WHITE)
	close.add_theme_stylebox_override("normal", _sb(Color(0.4, 0.4, 0.45), 6))
	close.add_theme_stylebox_override("hover", _sb(Color(0.5, 0.5, 0.55), 6))
	close.pressed.connect(func(): overlay.queue_free())
	card.add_child(close)

func _get_file_info(fname: String) -> Dictionary:
	match fname:
		"會議記錄.docx":
			return {"name": fname, "type": "Microsoft Word 文件", "ext": ".docx", "size": "45 KB", "date": "2024/04/05", "source": "內部建立"}
		"薪資表_2024.xlsx.exe":
			return {"name": fname, "type": "應用程式 (.exe)", "ext": ".xlsx.exe（雙重副檔名）", "size": "2.3 MB", "date": "2024/04/07", "source": "不明"}
		"free_vpn_setup.exe":
			return {"name": fname, "type": "應用程式 (.exe)", "ext": ".exe", "size": "18.7 MB", "date": "2024/04/07", "source": "不明"}
		"照片.jpg":
			return {"name": fname, "type": "JPEG 影像", "ext": ".jpg", "size": "1.2 MB", "date": "2024/03/28", "source": "內部建立"}
		"system_update.bat":
			return {"name": fname, "type": "批次檔 (.bat)", "ext": ".bat", "size": "856 bytes", "date": "2024/04/07", "source": "不明"}
		_:
			return {"name": fname, "type": "未知", "ext": "—", "size": "—", "date": "—", "source": "—"}

# ============================================================
#  DESKTOP TOAST NOTIFICATIONS
# ============================================================
func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _show_desktop_warning(desktop: Node, text: String) -> void:
	_show_desktop_toast(desktop, text, Color(1.0, 0.95, 0.9), Color(0.9, 0.6, 0.2), Color(0.4, 0.25, 0.05))

func _show_desktop_success(desktop: Node, text: String) -> void:
	_show_desktop_toast(desktop, text, Color(0.92, 0.98, 0.92), Color(0.3, 0.75, 0.3), Color(0.1, 0.4, 0.1))

func _show_desktop_toast(desktop: Node, text: String, bg: Color, border: Color, font_color: Color) -> void:
	var old := desktop.get_node_or_null("LevelToast")
	if old:
		old.queue_free()

	var toast := Panel.new()
	toast.name = "LevelToast"
	toast.position = Vector2(380, 580)
	toast.size = Vector2(520, 56)
	toast.z_index = 180
	var toast_sb := _sb(bg, 8)
	toast_sb.border_color = border
	toast_sb.border_width_left = 4
	toast_sb.border_width_top = 1
	toast_sb.border_width_right = 1
	toast_sb.border_width_bottom = 1
	toast_sb.shadow_color = Color(0, 0, 0, 0.2)
	toast_sb.shadow_size = 8
	toast.add_theme_stylebox_override("panel", toast_sb)
	desktop.add_child(toast)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(16, 6)
	msg.size = Vector2(460, 44)
	msg.add_theme_font_size_override("font_size", 12)
	msg.add_theme_color_override("font_color", font_color)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_child(msg)

	var close := Button.new()
	close.text = "✕"
	close.position = Vector2(488, 4)
	close.size = Vector2(24, 24)
	close.add_theme_font_size_override("font_size", 11)
	close.add_theme_color_override("font_color", font_color)
	close.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
	close.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.08), 4))
	close.pressed.connect(func(): toast.queue_free())
	toast.add_child(close)

	# Auto-dismiss after 4 seconds
	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	timer.autostart = true
	toast.add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(toast):
			toast.queue_free()
	)
