extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track file upload decisions
var _uploaded: Array[int] = []
var _blocked: Array[int] = []

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 7
	data.title = "守門人的選擇"
	data.category = "ai"
	data.difficulty = 2
	data.puzzle_title = "守門人的選擇"
	data.scenario_text = "主管丟來一疊資料，要你送進那台什麼都能讀的機器裡做摘要。\n但不是每份文件都該離開公司的門。\n你是守門人——有些東西一旦交出去，就再也收不回來。"
	data.task_hint = "仔細閱讀每份檔案的名稱與說明，判斷其內容是否適合提供給 AI。\n有些資料可以大方交出去，有些即便是內部文件也不行。\n找到那台機器，只放行應該放行的。"
	data.teaching_points = PackedStringArray([
		"上傳 AI 之資料須先進行安全等級識別，機密級以上須實施適當存取保護機制",
		"非審查通過之 AI 應用，不得提供限閱級以上之資訊",
		"病歷、健康檢查等特種個人資料，除法律規定或當事人同意外，不得上傳 AI 應用",
		"即使 AI 已通過合規審查，仍需依資料等級判斷可否上傳",
	])
	data.desktop_config = {}
	return data

func setup_desktop(_desktop: Node) -> void:
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "AI 助手":
		_content_ai_upload(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	var should_upload := [0, 3]   # 公開新聞稿, 產品規格說明書
	var should_block := [1, 2, 4] # 客戶個資名冊, 內部教育訓練簡報, 員工健檢報告

	# Check all 5 files have been decided
	var total_decided := _uploaded.size() + _blocked.size()
	if total_decided < 5:
		return {
			"passed": false,
			"details": "還有 %d 份檔案尚未處理。請對每份檔案做出上傳或退回的決定。" % (5 - total_decided),
		}

	# Check uploaded list
	var uploaded_sorted := _uploaded.duplicate()
	uploaded_sorted.sort()
	var correct_upload := (uploaded_sorted == should_upload)

	# Check blocked list
	var blocked_sorted := _blocked.duplicate()
	blocked_sorted.sort()
	var correct_block := (blocked_sorted == should_block)

	# Check if any sensitive file was uploaded
	var uploaded_sensitive := false
	for idx in _uploaded:
		if idx in should_block:
			uploaded_sensitive = true
			break

	var passed := correct_upload and correct_block
	var details := ""
	if uploaded_sensitive:
		details = "你上傳了不應上傳的機密或敏感資料！請重新檢查每份檔案的安全等級。"
	elif not correct_upload:
		details = "你退回了一些可以上傳的公開檔案。已對外公開的資料是可以提供給 AI 的。"
	elif not correct_block:
		details = "你的攔截名單不完全正確，請再確認每份檔案的安全等級。"

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
#  FILE DATA
# ============================================================
func _get_files() -> Array:
	return [
		{
			"name": "公開新聞稿.pdf",
			"icon": "📰",
			"level": "一般級",
			"level_color": Color(0.2, 0.65, 0.35),
			"desc": "已對外公開之新聞稿",
			"detail": "本檔案為公司已於官方網站及媒體發布之新聞稿，屬公開資訊。",
			"can_upload": true,
		},
		{
			"name": "客戶個資名冊.xlsx",
			"icon": "📊",
			"level": "機密級",
			"level_color": Color(0.8, 0.2, 0.2),
			"desc": "含客戶姓名、電話、身分證字號",
			"detail": "本檔案包含客戶姓名、電話號碼及身分證字號等個人資料。",
			"can_upload": false,
		},
		{
			"name": "內部教育訓練簡報.pptx",
			"icon": "📙",
			"level": "限閱級",
			"level_color": Color(0.85, 0.55, 0.1),
			"desc": "員工培訓用內部教材",
			"detail": "本檔案為公司內部員工教育訓練使用之簡報資料，僅限內部使用。",
			"can_upload": false,
		},
		{
			"name": "產品規格說明書.pdf",
			"icon": "📘",
			"level": "一般級",
			"level_color": Color(0.2, 0.65, 0.35),
			"desc": "已公開之產品資訊",
			"detail": "本檔案為已對外公開之產品規格說明書，屬公開資訊。",
			"can_upload": true,
		},
		{
			"name": "員工健檢報告.pdf",
			"icon": "🏥",
			"level": "特種個資",
			"level_color": Color(0.6, 0.1, 0.1),
			"desc": "含員工健康檢查資料",
			"detail": "本檔案包含員工健康檢查結果，依個資法需特別保護。",
			"can_upload": false,
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

func _content_ai_upload(p: Panel, _desktop: Node) -> void:
	# Header area
	var header := Panel.new()
	header.size = Vector2(640, 52)
	header.add_theme_stylebox_override("panel", _sb(Color(0.94, 0.96, 0.99), 0))
	p.add_child(header)

	var title := Label.new()
	title.text = "🤖 AI 助手 — 資料上傳審查"
	title.position = Vector2(16, 6)
	title.size = Vector2(400, 24)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "請審查以下檔案的資料安全等級，決定是否上傳至 AI 進行摘要分析"
	subtitle.position = Vector2(16, 30)
	subtitle.size = Vector2(600, 18)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	header.add_child(subtitle)

	# File list area
	var list_area := Panel.new()
	list_area.name = "FileListArea"
	list_area.position = Vector2(0, 52)
	list_area.size = Vector2(640, 356)
	list_area.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1), 0))
	p.add_child(list_area)

	_build_file_list(list_area)

func _build_file_list(area: Panel) -> void:
	for child in area.get_children():
		child.queue_free()

	var files := _get_files()

	# Scroll container for file cards
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 4)
	scroll.size = Vector2(624, 306)
	area.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for i in files.size():
		var f: Dictionary = files[i]
		var decided := (i in _uploaded) or (i in _blocked)
		var is_uploaded := (i in _uploaded)
		var is_blocked := (i in _blocked)

		var card := Panel.new()
		card.custom_minimum_size = Vector2(604, 56)
		var card_bg := Color(0.93, 0.97, 0.93) if is_uploaded else (Color(0.97, 0.93, 0.93) if is_blocked else Color(1, 1, 1))
		var card_sb := _sb(card_bg, 6)
		card_sb.border_color = Color(0.88, 0.88, 0.9)
		card_sb.border_width_bottom = 1
		card.add_theme_stylebox_override("panel", card_sb)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(card)

		# Icon
		var icon_lbl := Label.new()
		icon_lbl.text = f["icon"]
		icon_lbl.position = Vector2(10, 10)
		icon_lbl.size = Vector2(28, 28)
		icon_lbl.add_theme_font_size_override("font_size", 20)
		card.add_child(icon_lbl)

		# File name
		var name_lbl := Label.new()
		name_lbl.text = f["name"]
		name_lbl.position = Vector2(42, 6)
		name_lbl.size = Vector2(200, 20)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		card.add_child(name_lbl)

		# Description
		var desc_lbl := Label.new()
		desc_lbl.text = f["desc"]
		desc_lbl.position = Vector2(42, 28)
		desc_lbl.size = Vector2(270, 18)
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		card.add_child(desc_lbl)

		# Detail button (view file info)
		var detail_btn := Button.new()
		detail_btn.text = "檢視"
		detail_btn.position = Vector2(330, 14)
		detail_btn.size = Vector2(54, 26)
		detail_btn.add_theme_font_size_override("font_size", 11)
		detail_btn.add_theme_color_override("font_color", Color(0.2, 0.45, 0.8))
		detail_btn.add_theme_stylebox_override("normal", _sb(Color(0.92, 0.95, 1.0), 4))
		detail_btn.add_theme_stylebox_override("hover", _sb(Color(0.85, 0.9, 1.0), 4))
		var idx := i
		var area_ref := area
		detail_btn.pressed.connect(func():
			_show_file_detail(area_ref, idx)
		)
		card.add_child(detail_btn)

		if decided:
			# Show status label
			var status_lbl := Label.new()
			if is_uploaded:
				status_lbl.text = "✅ 已上傳"
				status_lbl.add_theme_color_override("font_color", Color(0.15, 0.55, 0.25))
			else:
				status_lbl.text = "🚫 已退回"
				status_lbl.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))
			status_lbl.position = Vector2(460, 16)
			status_lbl.size = Vector2(130, 22)
			status_lbl.add_theme_font_size_override("font_size", 12)
			card.add_child(status_lbl)
		else:
			# Upload button
			var upload_btn := Button.new()
			upload_btn.text = "上傳"
			upload_btn.position = Vector2(398, 14)
			upload_btn.size = Vector2(62, 26)
			upload_btn.add_theme_font_size_override("font_size", 11)
			upload_btn.add_theme_color_override("font_color", Color.WHITE)
			upload_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.55, 0.85), 4))
			upload_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 0.9), 4))
			var idx2 := i
			var area_ref2 := area
			upload_btn.pressed.connect(func():
				_on_upload_file(area_ref2, idx2)
			)
			card.add_child(upload_btn)

			# Block button
			var block_btn := Button.new()
			block_btn.text = "退回"
			block_btn.position = Vector2(470, 14)
			block_btn.size = Vector2(62, 26)
			block_btn.add_theme_font_size_override("font_size", 11)
			block_btn.add_theme_color_override("font_color", Color.WHITE)
			block_btn.add_theme_stylebox_override("normal", _sb(Color(0.7, 0.25, 0.25), 4))
			block_btn.add_theme_stylebox_override("hover", _sb(Color(0.8, 0.35, 0.35), 4))
			var idx3 := i
			var area_ref3 := area
			block_btn.pressed.connect(func():
				_on_block_file(area_ref3, idx3)
			)
			card.add_child(block_btn)

			# Reset button (to undo decision) — not needed for undecided

	# Status summary (row 1 of footer)
	var summary := Label.new()
	summary.text = "已上傳: %d  |  已退回: %d  |  待處理: %d" % [_uploaded.size(), _blocked.size(), 5 - _uploaded.size() - _blocked.size()]
	summary.position = Vector2(12, 310)
	summary.size = Vector2(400, 16)
	summary.add_theme_font_size_override("font_size", 10)
	summary.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	area.add_child(summary)

	# Buttons row (row 2 of footer, y=328)
	# Reset button
	if _uploaded.size() + _blocked.size() > 0:
		var reset_btn := Button.new()
		reset_btn.text = "重新選擇"
		reset_btn.position = Vector2(380, 328)
		reset_btn.size = Vector2(80, 26)
		reset_btn.add_theme_font_size_override("font_size", 11)
		reset_btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
		reset_btn.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.93, 0.95), 4))
		reset_btn.add_theme_stylebox_override("hover", _sb(Color(0.88, 0.88, 0.92), 4))
		var area_ref := area
		reset_btn.pressed.connect(func():
			_uploaded.clear()
			_blocked.clear()
			_build_file_list(area_ref)
		)
		area.add_child(reset_btn)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(500, 326)
	finish.size = Vector2(126, 28)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var area_ref_finish := area
	finish.pressed.connect(func(): _on_finish_pressed(area_ref_finish))
	area.add_child(finish)

func _show_file_detail(area: Panel, index: int) -> void:
	var files := _get_files()
	var f: Dictionary = files[index]

	# Show detail as a feedback-style overlay
	var old := area.get_node_or_null("FileDetail")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FileDetail"
	box.position = Vector2(60, 60)
	box.size = Vector2(520, 200)
	var box_sb := _sb(Color(0.98, 0.98, 1.0), 10)
	box_sb.border_color = Color(0.7, 0.75, 0.85)
	box_sb.border_width_left = 2
	box_sb.border_width_top = 2
	box_sb.border_width_right = 2
	box_sb.border_width_bottom = 2
	box_sb.shadow_color = Color(0, 0, 0, 0.15)
	box_sb.shadow_size = 8
	box.add_theme_stylebox_override("panel", box_sb)
	box.z_index = 15
	area.add_child(box)

	# File icon and name
	var file_title := Label.new()
	file_title.text = f["icon"] + "  " + f["name"]
	file_title.position = Vector2(16, 12)
	file_title.size = Vector2(450, 26)
	file_title.add_theme_font_size_override("font_size", 16)
	file_title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	box.add_child(file_title)

	# Detail description
	var detail := Label.new()
	detail.text = f["detail"]
	detail.position = Vector2(16, 50)
	detail.size = Vector2(488, 40)
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)

	# Regulation reference
	var reg := Label.new()
	if f["can_upload"]:
		reg.text = "📋 此份文件屬已對外公開之資料，可提供至核准之 AI 應用進行分析。"
	else:
		match f["name"]:
			"客戶個資名冊.xlsx":
				reg.text = "📋 依個資法規定：含客戶個人資料之文件，未經適當脫敏處理前，不得上傳至 AI 系統。"
			"內部教育訓練簡報.pptx":
				reg.text = "📋 依公司規定：僅供內部使用之資料，不得提供至 AI 應用處理。"
			"員工健檢報告.pdf":
				reg.text = "📋 依個資法規定：員工健康檢查等特殊類型個人資料，除法律規定外，不得上傳 AI 應用。"
			_:
				reg.text = "📋 此份文件含有敏感資訊，不得上傳至 AI 系統。"
	reg.position = Vector2(16, 100)
	reg.size = Vector2(488, 40)
	reg.add_theme_font_size_override("font_size", 11)
	reg.add_theme_color_override("font_color", Color(0.35, 0.35, 0.55))
	reg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(reg)

	# Close button
	var close := Button.new()
	close.text = "✕"
	close.position = Vector2(488, 6)
	close.size = Vector2(24, 24)
	close.add_theme_font_size_override("font_size", 12)
	close.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	close.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
	close.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.08), 4))
	close.pressed.connect(func(): box.queue_free())
	box.add_child(close)

	GameState.record_action("view_file_detail", f["name"])

func _on_upload_file(area: Panel, index: int) -> void:
	var files := _get_files()
	var f: Dictionary = files[index]

	_uploaded.append(index)
	GameState.record_action("upload_file", f["name"])

	if not f["can_upload"]:
		GameState.record_wrong_action("uploaded_sensitive_file", f["name"])

	_build_file_list(area)
	_show_feedback_box_success(area, "已將「%s」加入上傳清單。" % f["name"])

func _on_block_file(area: Panel, index: int) -> void:
	var files := _get_files()
	var f: Dictionary = files[index]

	_blocked.append(index)
	GameState.record_action("block_file", f["name"])

	if f["can_upload"]:
		GameState.record_wrong_action("blocked_safe_file", f["name"])

	_build_file_list(area)
	_show_feedback_box(area, "已將「%s」退回，不上傳至 AI。" % f["name"])

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
		_show_feedback_box(area, result["details"])
		if ScoreManager.get_attempts(lid) >= 3:
			var existing := area.get_node_or_null("GiveUpBtn")
			if not existing:
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				gub.position = Vector2(270, 328)
				gub.size = Vector2(100, 26)
				gub.add_theme_font_size_override("font_size", 12)
				gub.add_theme_color_override("font_color", Color.WHITE)
				gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
				gub.pressed.connect(func(): LevelManager.fail_level())
				area.add_child(gub)

# ============================================================
#  FEEDBACK BOXES
# ============================================================
func _show_feedback_box(parent: Panel, text: String) -> void:
	var old := parent.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 260)
	box.size = Vector2(620, 48)
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
	icon_label.position = Vector2(12, 8)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 16)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(40, 6)
	msg.size = Vector2(552, 36)
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
	box.position = Vector2(10, 260)
	box.size = Vector2(620, 48)
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
	icon_label.position = Vector2(12, 8)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 16)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(40, 6)
	msg.size = Vector2(552, 36)
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
