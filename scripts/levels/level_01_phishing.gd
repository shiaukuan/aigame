extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 1
	data.title = "水面下的鉤子"
	data.category = "security"
	data.difficulty = 1
	data.puzzle_title = "水面下的鉤子"
	data.scenario_text = "早安，新的一天開始了。\n你的桌面看起來一切正常——但有人在你還沒到公司之前，\n已經悄悄地把魚餌放進了你每天都會打開的地方。"
	data.task_hint = "有些信件看起來很正常，但仔細看名字……\n字母裡藏著陷阱。找到它們，在被咬鉤之前。"
	data.teaching_points = PackedStringArray([
		"檢查寄件者地址是否正確",
		"注意網址中的細微拼寫錯誤",
		"不要下載不明附件（尤其是 .exe）",
		"[外部郵件]建立規則資料夾，不要點開可疑郵件",
	])
	data.desktop_config = {}
	return data

func setup_desktop(_desktop: Node) -> void:
	# 第 1 關不添加額外視覺引導——提示文字已足夠引導玩家找到郵件 App
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "郵件":
		_content_email(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	var correct_indices := [1, 3]
	var normal_indices := [0, 2, 4]
	var selected := GameState.selected_emails.duplicate()
	selected.sort()

	var correct_selected := (selected == correct_indices)

	# Check all normal emails have been viewed
	var viewed_emails: Array[int] = []
	for a in GameState.actions_taken:
		if a["action"] == "view_email" and a["detail"] is int:
			if a["detail"] not in viewed_emails:
				viewed_emails.append(a["detail"])
	var all_normal_viewed := true
	for ni in normal_indices:
		if ni not in viewed_emails:
			all_normal_viewed = false
			break

	# Check if report action was taken
	var has_reported := false
	for a in GameState.actions_taken:
		if a["action"] == "report_emails":
			has_reported = true
			break

	var clicked_phishing := false
	for wa in GameState.wrong_actions:
		if wa["action"] == "clicked_phishing_link" or wa["action"] == "clicked_phishing_attachment":
			clicked_phishing = true
			break

	var passed := correct_selected and all_normal_viewed and has_reported
	var details := ""
	if not all_normal_viewed:
		details = "你還沒有查看所有郵件。請先逐一點開每封郵件確認內容。"
	elif not correct_selected:
		if selected.size() < 2:
			details = "你只標記了 %d 封郵件，但收件匣中有 2 封可疑郵件。" % selected.size()
		elif selected.size() > 2:
			details = "你標記了太多郵件。收件匣中只有 2 封是可疑的。"
		else:
			details = "你標記的郵件不完全正確，請再仔細檢查寄件者地址和附件。"
	elif not has_reported:
		details = "請先回報可疑郵件，再完成關卡。"

	return {
		"passed": passed,
		"correct_selected": correct_selected,
		"all_normal_viewed": all_normal_viewed,
		"has_reported": has_reported,
		"clicked_phishing": clicked_phishing,
		"details": details,
	}

func calculate_score() -> int:
	var attempt_count := ScoreManager.get_attempts(LevelManager.current_level)
	var has_wrong := GameState.wrong_actions.size() > 0
	if attempt_count == 1 and not has_wrong:
		return 100
	return 60

# ============================================================
#  EMAIL DATA
# ============================================================
func _get_emails() -> Array:
	return [
		{
			"from": "王小明 <wang@cht.com.tw>",
			"to": "you@cht.com.tw",
			"date": "2024/04/07 09:15",
			"subj": "明天早上10:00 部門會議",
			"body": "Hi，\n\n提醒大家明天早上 10:00 在 3F 會議室 A 有部門週會。\n\n議程：\n1. 上週工作回顧\n2. 本週重點任務分配\n3. Q4 目標討論\n\n請大家準時出席，謝謝！\n\n王小明",
			"is_phishing": false,
			"phishing_link": "",
			"phishing_attachment": "",
		},
		{
			"from": "[外部郵件]IT-Support <it-support@g00gle.com>",
			"to": "you@cht.com.tw",
			"date": "2024/04/07 08:23",
			"subj": "【緊急】請立即重設您的密碼",
			"body": "親愛的使用者，\n\n我們偵測到您的帳戶有異常登入活動。為了保護您的帳號安全，請立即點擊下方連結重設您的密碼。\n\n如果您在 24 小時內未完成重設，您的帳號將被暫時凍結。\n\n感謝您的配合。\n\nIT Support Team",
			"is_phishing": true,
			"phishing_link": "https://g00gle.com/password-reset",
			"phishing_attachment": "",
		},
		{
			"from": "林主管 <lin.mgr@cht.com.tw>",
			"to": "you@cht.com.tw",
			"date": "2024/04/06 17:30",
			"subj": "Q4專案進度更新",
			"body": "各位好，\n\n以下是 Q4 專案的最新進度：\n\n- 前端模組：已完成 80%，預計下週收尾\n- 後端 API：整合測試進行中\n- 文件撰寫：本週開始\n\n下週一會再開一次進度檢討會議，届時請各組報告最新狀況。\n\n林主管",
			"is_phishing": false,
			"phishing_link": "",
			"phishing_attachment": "",
		},
		{
			"from": "[外部郵件]快遞通知 <delivery@fedx-express.com>",
			"to": "you@cht.com.tw",
			"date": "2024/04/07 07:45",
			"subj": "您有一個包裹待領取（附件）",
			"body": "親愛的客戶，\n\n您有一個包裹目前在配送中心等待領取。\n\n請下載附件中的追蹤資訊以確認取件時間和地點。\n如未在 3 天內領取，包裹將被退回。\n\n感謝您使用我們的服務。\n\nFedX Express 客服團隊",
			"is_phishing": true,
			"phishing_link": "",
			"phishing_attachment": "包裹追蹤資訊.exe",
		},
		{
			"from": "HR部門 <hr@cht.com.tw>",
			"to": "you@cht.com.tw",
			"date": "2024/04/05 14:00",
			"subj": "4月份全員月會通知",
			"body": "各位同仁好，\n\n4 月份全員月會將於 4/12（五）下午 2:00 在大會議廳舉行。\n\n本次議題：\n- 公司營運報告\n- 員工福利更新\n- Q&A 時間\n\n請全員務必出席。如有請假需求，請事先向主管報備。\n\nHR 部門",
			"is_phishing": false,
			"phishing_link": "",
			"phishing_attachment": "",
		},
	]

# ============================================================
#  EMAIL UI
# ============================================================
func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _content_email(p: Panel, _desktop: Node) -> void:
	# Sidebar
	var side := Panel.new()
	side.size = Vector2(150, 408)
	side.add_theme_stylebox_override("panel", _sb(Color(0.94, 0.94, 0.96), 0))
	p.add_child(side)

	var folders := ["收件匣 (5)", "寄件備份", "草稿", "垃圾郵件", "已刪除"]
	for i in folders.size():
		var b := Button.new()
		b.text = folders[i]
		b.position = Vector2(6, 6 + i * 34)
		b.size = Vector2(138, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		b.add_theme_stylebox_override("normal", _sb(Color(0.85, 0.9, 1.0) if i == 0 else Color(1, 1, 1, 0), 4))
		b.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.06), 4))
		side.add_child(b)

	# Right content area
	var right := Panel.new()
	right.name = "EmailRight"
	right.position = Vector2(150, 0)
	right.size = Vector2(490, 408)
	right.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1), 0))
	p.add_child(right)

	_build_email_list(right)

func _build_email_list(right: Panel) -> void:
	for child in right.get_children():
		child.queue_free()

	var emails := _get_emails()

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(490, 362)
	right.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for i in emails.size():
		var row := Panel.new()
		row.custom_minimum_size = Vector2(470, 66)
		var bg_color := Color(1.0, 0.95, 0.88) if GameState.is_email_selected(i) else Color(1, 1, 1, 0)
		row.add_theme_stylebox_override("panel", _sb(bg_color, 4))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(row)

		# Checkbox
		var cb := Button.new()
		cb.text = "☑" if GameState.is_email_selected(i) else "☐"
		cb.position = Vector2(6, 18)
		cb.size = Vector2(30, 30)
		cb.add_theme_font_size_override("font_size", 16)
		cb.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		cb.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
		cb.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.08), 4))
		var idx := i
		var right_ref := right
		cb.pressed.connect(func():
			GameState.toggle_email_selected(idx)
			_build_email_list(right_ref)
		)
		row.add_child(cb)

		# Email info
		var info_btn := Button.new()
		info_btn.text = emails[i]["subj"] + "\n" + emails[i]["from"]
		info_btn.position = Vector2(40, 4)
		info_btn.size = Vector2(420, 58)
		info_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		info_btn.add_theme_font_size_override("font_size", 12)
		info_btn.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		info_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
		info_btn.add_theme_stylebox_override("hover", _sb(Color(0.9, 0.93, 1.0), 4))
		info_btn.pressed.connect(func():
			GameState.record_action("view_email", idx)
			_show_email_detail(right_ref, idx)
		)
		row.add_child(info_btn)

	# Report button (action step, not scoring)
	var has_reported := false
	for a in GameState.actions_taken:
		if a["action"] == "report_emails":
			has_reported = true
			break

	var rb := Button.new()
	rb.text = "✅ 已回報" if has_reported else "🚨 建立外部郵件資料夾規則"
	rb.position = Vector2(8, 370)
	rb.size = Vector2(210, 32)
	rb.add_theme_font_size_override("font_size", 12)
	rb.add_theme_color_override("font_color", Color.WHITE)
	if has_reported:
		rb.add_theme_stylebox_override("normal", _sb(Color(0.3, 0.7, 0.3), 6))
		rb.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.7, 0.3), 6))
		rb.disabled = true
	else:
		rb.add_theme_stylebox_override("normal", _sb(Color(0.8, 0.2, 0.2), 6))
		rb.add_theme_stylebox_override("hover", _sb(Color(0.9, 0.3, 0.3), 6))
	var right_ref2 := right
	rb.pressed.connect(func(): _on_report_pressed(right_ref2))
	right.add_child(rb)

	# Finish button
	var fb := Button.new()
	fb.text = "📋 完成作答"
	fb.position = Vector2(350, 370)
	fb.size = Vector2(130, 32)
	fb.add_theme_font_size_override("font_size", 12)
	fb.add_theme_color_override("font_color", Color.WHITE)
	fb.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	fb.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	fb.pressed.connect(func(): _on_finish_pressed(right_ref2))
	right.add_child(fb)

func _show_email_detail(right: Panel, index: int) -> void:
	for child in right.get_children():
		child.queue_free()

	var emails := _get_emails()
	var email: Dictionary = emails[index]

	# Back button
	var back := Button.new()
	back.text = "< 返回收件匣"
	back.position = Vector2(8, 6)
	back.size = Vector2(120, 28)
	back.add_theme_font_size_override("font_size", 12)
	back.add_theme_color_override("font_color", Color(0.2, 0.45, 0.8))
	back.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
	back.add_theme_stylebox_override("hover", _sb(Color(0.9, 0.93, 1.0), 4))
	var right_ref := right
	back.pressed.connect(func(): _build_email_list(right_ref))
	right.add_child(back)

	# Separator
	var sep := ColorRect.new()
	sep.position = Vector2(8, 38)
	sep.size = Vector2(474, 1)
	sep.color = Color(0.85, 0.85, 0.85)
	right.add_child(sep)

	# Headers
	var header_y := 44
	var headers := [
		"From:  " + email["from"],
		"To:  " + email["to"],
		"Date:  " + email["date"],
		"Subject:  " + email["subj"],
	]
	for h in headers:
		var hl := Label.new()
		hl.text = h
		hl.position = Vector2(12, header_y)
		hl.size = Vector2(466, 18)
		hl.add_theme_font_size_override("font_size", 11)
		hl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		right.add_child(hl)
		header_y += 20

	# Separator 2
	var sep2 := ColorRect.new()
	sep2.position = Vector2(8, header_y + 4)
	sep2.size = Vector2(474, 1)
	sep2.color = Color(0.85, 0.85, 0.85)
	right.add_child(sep2)

	# Body
	var body := RichTextLabel.new()
	body.position = Vector2(12, header_y + 12)
	body.size = Vector2(466, 190)
	body.text = email["body"]
	body.bbcode_enabled = false
	body.scroll_active = true
	body.add_theme_font_size_override("normal_font_size", 12)
	body.add_theme_color_override("default_color", Color(0.15, 0.15, 0.15))
	right.add_child(body)

	# Phishing link
	if email["phishing_link"] != "":
		var link_btn := Button.new()
		link_btn.text = "🔗 " + email["phishing_link"]
		link_btn.position = Vector2(12, header_y + 210)
		link_btn.size = Vector2(350, 28)
		link_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		link_btn.add_theme_font_size_override("font_size", 12)
		link_btn.add_theme_color_override("font_color", Color(0.15, 0.4, 0.85))
		link_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
		link_btn.add_theme_stylebox_override("hover", _sb(Color(0.9, 0.93, 1.0), 4))
		var idx := index
		link_btn.pressed.connect(func():
			GameState.record_wrong_action("clicked_phishing_link", idx)
			_show_phishing_warning(right_ref)
		)
		right.add_child(link_btn)

	# Phishing attachment
	if email["phishing_attachment"] != "":
		var att_btn := Button.new()
		att_btn.text = "📎 " + email["phishing_attachment"] + " — 下載"
		att_btn.position = Vector2(12, header_y + 210)
		att_btn.size = Vector2(350, 28)
		att_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		att_btn.add_theme_font_size_override("font_size", 12)
		att_btn.add_theme_color_override("font_color", Color(0.15, 0.4, 0.85))
		att_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
		att_btn.add_theme_stylebox_override("hover", _sb(Color(0.9, 0.93, 1.0), 4))
		var idx := index
		att_btn.pressed.connect(func():
			GameState.record_wrong_action("clicked_phishing_attachment", idx)
			_show_phishing_warning(right_ref)
		)
		right.add_child(att_btn)

func _show_phishing_warning(right: Panel) -> void:
	var existing := right.get_node_or_null("PhishingWarning")
	if existing:
		return
	var warn := Panel.new()
	warn.name = "PhishingWarning"
	warn.position = Vector2(20, 348)
	warn.size = Vector2(450, 52)
	warn.add_theme_stylebox_override("panel", _sb(Color(0.95, 0.85, 0.85), 6))
	right.add_child(warn)

	var wl := Label.new()
	wl.text = "⚠️ 你點擊了可疑的連結/附件！\n真實情況下，這可能導致帳號被盜或電腦中毒。"
	wl.position = Vector2(10, 6)
	wl.size = Vector2(430, 44)
	wl.add_theme_font_size_override("font_size", 11)
	wl.add_theme_color_override("font_color", Color(0.7, 0.15, 0.15))
	warn.add_child(wl)

func _on_report_pressed(right: Panel) -> void:
	if not LevelManager.level_active:
		return
	var selected := GameState.selected_emails.duplicate()
	if selected.size() == 0:
		_show_feedback_box(right, "請先勾選你認為可疑的郵件，再進行回報。")
		return
	GameState.record_action("report_emails", selected.duplicate())
	_build_email_list(right)
	_show_feedback_box_success(right, "已回報 %d 封可疑郵件。請點擊「完成作答」提交結果。" % selected.size())

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
				gub.position = Vector2(228, 370)
				gub.size = Vector2(110, 32)
				gub.add_theme_font_size_override("font_size", 12)
				gub.add_theme_color_override("font_color", Color.WHITE)
				gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
				gub.pressed.connect(func(): LevelManager.fail_level())
				right.add_child(gub)

func _show_feedback_box(right: Panel, text: String) -> void:
	# Remove old feedback box
	var old := right.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 290)
	box.size = Vector2(470, 70)
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
	icon_label.position = Vector2(12, 10)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 18)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(42, 8)
	msg.size = Vector2(416, 54)
	msg.add_theme_font_size_override("font_size", 12)
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
	box.position = Vector2(10, 290)
	box.size = Vector2(470, 70)
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
	icon_label.position = Vector2(12, 10)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 18)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(42, 8)
	msg.size = Vector2(416, 54)
	msg.add_theme_font_size_override("font_size", 12)
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
