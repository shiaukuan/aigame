extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track which paragraphs the player has flagged as problematic
var _flagged: Array[int] = []
var _show_give_up := false

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 9
	data.title = "自信的騙子"
	data.category = "ai"
	data.difficulty = 2
	data.puzzle_title = "自信的騙子"
	data.scenario_text = "新同事交了一份報告，說「AI 幫我寫的，資料很齊全」。\n主管看了幾眼就覺得哪裡怪怪的，把它丟給你審查。\n這份報告寫得很好——引經據典、數據豐富。\n但有些引經據典的「經」和「典」……根本不存在。"
	data.task_hint = "那份報告就藏在 AI 助手的對話紀錄裡。\n像偵探一樣逐段審視——越是自信滿滿的數字，越要懷疑。\n越是精確的引用，越可能是精心編造的謊言。\n找出那些「看起來很真，但查無此事」的段落。"
	data.teaching_points = PackedStringArray([
		"AI 會很有自信地說出錯誤資訊（幻覺）",
		"引用的論文、數據、法規一定要查證",
		"越具體的數字越需要驗證",
		"AI 適合起草，但人類負責事實查核",
	])
	data.desktop_config = {}
	return data

func setup_desktop(desktop: Node) -> void:
	# Flash the AI assistant taskbar icon to draw attention
	var taskbar := desktop.get_node_or_null("Taskbar")
	if taskbar:
		for child in taskbar.get_children():
			if child is Button and child.text.find("🤖") >= 0:
				var timer := Timer.new()
				timer.name = "Level09FlashTimer"
				timer.wait_time = 0.6
				timer.autostart = true
				desktop.add_child(timer)
				var btn := child
				timer.timeout.connect(func():
					if is_instance_valid(btn):
						btn.modulate = Color.YELLOW if btn.modulate == Color.WHITE else Color.WHITE
				)
				break

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "AI 助手":
		# Stop the flash timer when app is opened
		var timer := desktop.get_node_or_null("Level09FlashTimer")
		if timer:
			timer.queue_free()
		# Reset taskbar button color
		var taskbar := desktop.get_node_or_null("Taskbar")
		if taskbar:
			for child in taskbar.get_children():
				if child is Button and child.text.find("🤖") >= 0:
					child.modulate = Color.WHITE
					break
		_content_ai_chat(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	var correct_indices := [1, 3, 5]  # paragraphs with hallucinations (0-indexed)
	if _flagged.size() == 0:
		return {
			"passed": false,
			"details": "你還沒有標記任何段落。請仔細閱讀 AI 的回答，找出有問題的段落並點選「🚩 標記可疑」。",
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
			details = "你只找到了 %d 個問題，但 AI 回答中共有 3 個幻覺。請繼續仔細檢查。" % _flagged.size()
		elif _flagged.size() > 3:
			details = "你標記了 %d 個段落，但只有 3 個是有問題的。有些正確的內容被誤標了。" % _flagged.size()
		elif wrong_flags > 0 and missed > 0:
			details = "你的標記不完全正確。有 %d 個正確段落被誤標，還有 %d 個問題段落未被發現。" % [wrong_flags, missed]
		elif wrong_flags > 0:
			details = "你標記了一些正確的段落。請再次確認每個段落的引用和數據是否可靠。"
		else:
			details = "還有問題段落沒有被找到。注意檢查論文引用、統計數字和法規條文。"

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
#  REPORT DATA
# ============================================================
func _get_paragraphs() -> Array:
	return [
		{
			"title": "一、研究背景",
			"content": "隨著生成式 AI 技術的快速發展，越來越多企業開始在日常營運中導入 AI 工具來提升效率。從文件撰寫、客戶服務到資料分析，AI 的應用範圍持續擴大，已成為企業數位轉型的重要趨勢。",
			"has_hallucination": false,
			"explanation": "",
		},
		{
			"title": "二、AI 生成內容的可靠性研究",
			"content": "根據 Dr. Michael Chen 與 Dr. Sarah Williams 於 2024 年發表在《Journal of Artificial Intelligence Governance》第 12 卷的論文〈Reliability Metrics for LLM-Generated Enterprise Reports〉指出，大型語言模型在生成企業報告時，約有 23% 的統計數據存在不同程度的偏差。",
			"has_hallucination": true,
			"explanation": "此論文、作者及期刊均為 AI 捏造。《Journal of Artificial Intelligence Governance》並非真實存在的學術期刊。",
		},
		{
			"title": "三、企業資安現況",
			"content": "資料外洩事件對企業造成的損失相當可觀，包括直接的財務損失、商譽受損以及法律責任。其中因內部人員疏忽或不當操作所導致的資安事件佔了相當比例，因此加強員工的資安意識培訓至關重要。",
			"has_hallucination": false,
			"explanation": "",
		},
		{
			"title": "四、AI 工具使用普及率",
			"content": "根據 2024 年全球資訊長協會（Global CIO Alliance）的年度調查，目前已有 95% 的世界五百強企業全面導入生成式 AI 於核心業務流程中，且預計在 2025 年底前這一比例將達到 99%。",
			"has_hallucination": true,
			"explanation": "此統計數字為 AI 編造。「全球資訊長協會」並非真實組織，且實際上 2024 年全面導入 AI 的企業比例約為 60%，遠低於 95%。",
		},
		{
			"title": "五、資安培訓建議",
			"content": "為提升員工資安意識，建議企業定期進行資安教育訓練，內容涵蓋社交工程防禦、密碼管理、以及資料分級處理等核心議題。持續性的培訓有助於建立良好的組織安全文化，降低人為疏失造成的資安風險。",
			"has_hallucination": false,
			"explanation": "",
		},
		{
			"title": "六、AI 法規遵循",
			"content": "依據我國《個人資料保護法》第 87 條規定，企業在使用 AI 處理個人資料時，須事先取得當事人之書面同意，並建立獨立的 AI 資料處理稽核機制，違反者將處以新台幣 500 萬元以上之罰鍰。",
			"has_hallucination": true,
			"explanation": "《個人資料保護法》全文僅有 56 條，不存在第 87 條。此條文內容及罰則均為 AI 捏造。",
		},
	]

# ============================================================
#  AI CHAT UI
# ============================================================
func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _content_ai_chat(p: Panel, _desktop: Node) -> void:
	# Header bar
	var header := Panel.new()
	header.size = Vector2(640, 48)
	var hdr_sb := _sb(Color(0.13, 0.15, 0.22), 0)
	header.add_theme_stylebox_override("panel", hdr_sb)
	p.add_child(header)

	var bot_icon := Label.new()
	bot_icon.text = "🤖"
	bot_icon.position = Vector2(12, 8)
	bot_icon.size = Vector2(30, 30)
	bot_icon.add_theme_font_size_override("font_size", 20)
	header.add_child(bot_icon)

	var bot_name := Label.new()
	bot_name.text = "AI 助手"
	bot_name.position = Vector2(46, 5)
	bot_name.size = Vector2(200, 20)
	bot_name.add_theme_font_size_override("font_size", 15)
	bot_name.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	header.add_child(bot_name)

	var bot_sub := Label.new()
	bot_sub.text = "請點選 AI 回答中有問題的段落，標記為可疑"
	bot_sub.position = Vector2(46, 26)
	bot_sub.size = Vector2(560, 18)
	bot_sub.add_theme_font_size_override("font_size", 11)
	bot_sub.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	header.add_child(bot_sub)

	# Chat area (scrollable)
	var chat_area := Panel.new()
	chat_area.name = "ChatArea"
	chat_area.position = Vector2(0, 48)
	chat_area.size = Vector2(640, 310)
	chat_area.add_theme_stylebox_override("panel", _sb(Color(0.95, 0.96, 0.98), 0))
	p.add_child(chat_area)

	_build_chat(chat_area)

	# Bottom bar with status + finish button
	var bottom := Panel.new()
	bottom.name = "BottomBar"
	bottom.position = Vector2(0, 358)
	bottom.size = Vector2(640, 50)
	bottom.add_theme_stylebox_override("panel", _sb(Color(0.93, 0.94, 0.97), 0))
	p.add_child(bottom)

	var status_lbl := Label.new()
	status_lbl.name = "StatusLbl"
	status_lbl.text = "已標記：%d / 6 段　|　共有 3 個 AI 幻覺需找出" % _flagged.size()
	status_lbl.position = Vector2(14, 15)
	status_lbl.size = Vector2(360, 20)
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	bottom.add_child(status_lbl)

	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(496, 9)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var panel_ref := p
	finish.pressed.connect(func(): _on_finish_pressed(panel_ref))
	bottom.add_child(finish)

func _build_chat(chat_area: Panel) -> void:
	for child in chat_area.get_children():
		child.queue_free()

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(640, 310)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_area.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(624, 0)
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# ------------------------------------------------------------
	# User message bubble (right-aligned)
	# ------------------------------------------------------------
	var user_row_margin := MarginContainer.new()
	user_row_margin.add_theme_constant_override("margin_top", 12)
	user_row_margin.add_theme_constant_override("margin_bottom", 6)
	user_row_margin.add_theme_constant_override("margin_left", 90)
	user_row_margin.add_theme_constant_override("margin_right", 14)
	user_row_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(user_row_margin)

	var user_row := HBoxContainer.new()
	user_row.alignment = BoxContainer.ALIGNMENT_END
	user_row_margin.add_child(user_row)

	var user_bubble := PanelContainer.new()
	var ub_sb := _sb(Color(0.22, 0.48, 0.88), 10)
	ub_sb.corner_radius_bottom_right = 2
	ub_sb.content_margin_left = 14
	ub_sb.content_margin_right = 14
	ub_sb.content_margin_top = 10
	ub_sb.content_margin_bottom = 10
	user_bubble.add_theme_stylebox_override("panel", ub_sb)
	user_row.add_child(user_bubble)

	var user_lbl := Label.new()
	user_lbl.text = "請幫我撰寫一份關於 AI 技術應用現況的技術報告，需包含研究數據與法規引用。"
	user_lbl.custom_minimum_size = Vector2(360, 0)
	user_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	user_lbl.add_theme_font_size_override("font_size", 12)
	user_lbl.add_theme_color_override("font_color", Color.WHITE)
	user_bubble.add_child(user_lbl)

	# ------------------------------------------------------------
	# AI response header
	# ------------------------------------------------------------
	var ai_header_margin := MarginContainer.new()
	ai_header_margin.add_theme_constant_override("margin_top", 10)
	ai_header_margin.add_theme_constant_override("margin_bottom", 4)
	ai_header_margin.add_theme_constant_override("margin_left", 14)
	ai_header_margin.add_theme_constant_override("margin_right", 14)
	vbox.add_child(ai_header_margin)

	var ai_header_row := HBoxContainer.new()
	ai_header_row.add_theme_constant_override("separation", 6)
	ai_header_margin.add_child(ai_header_row)

	var ai_avatar := Label.new()
	ai_avatar.text = "🤖"
	ai_avatar.add_theme_font_size_override("font_size", 18)
	ai_header_row.add_child(ai_avatar)

	var ai_name_lbl := Label.new()
	ai_name_lbl.text = "AI 助手"
	ai_name_lbl.add_theme_font_size_override("font_size", 13)
	ai_name_lbl.add_theme_color_override("font_color", Color(0.25, 0.35, 0.6))
	ai_header_row.add_child(ai_name_lbl)

	# Instruction label
	var instr_margin := MarginContainer.new()
	instr_margin.add_theme_constant_override("margin_left", 14)
	instr_margin.add_theme_constant_override("margin_right", 14)
	instr_margin.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(instr_margin)

	var instr_lbl := Label.new()
	instr_lbl.text = "以下是根據您的需求生成的技術報告。請點選各段落旁的按鈕標記可疑內容："
	instr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instr_lbl.add_theme_font_size_override("font_size", 12)
	instr_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.38))
	instr_margin.add_child(instr_lbl)

	# ------------------------------------------------------------
	# Paragraph cards
	# ------------------------------------------------------------
	var paragraphs := _get_paragraphs()

	for i in paragraphs.size():
		var para: Dictionary = paragraphs[i]
		var is_flagged := (i in _flagged)

		var para_margin := MarginContainer.new()
		para_margin.add_theme_constant_override("margin_left", 14)
		para_margin.add_theme_constant_override("margin_right", 14)
		para_margin.add_theme_constant_override("margin_bottom", 10)
		para_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(para_margin)

		# Use PanelContainer so the inner VBoxContainer is auto-sized to card width.
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_bg := Color(1.0, 0.93, 0.91) if is_flagged else Color(1.0, 1.0, 1.0)
		var card_sb := _sb(card_bg, 8)
		if is_flagged:
			card_sb.border_color = Color(0.85, 0.3, 0.25)
			card_sb.border_width_left = 4
			card_sb.border_width_top = 1
			card_sb.border_width_right = 1
			card_sb.border_width_bottom = 1
		else:
			card_sb.border_color = Color(0.85, 0.87, 0.92)
			card_sb.border_width_left = 1
			card_sb.border_width_top = 1
			card_sb.border_width_right = 1
			card_sb.border_width_bottom = 1
		card_sb.content_margin_left = 14
		card_sb.content_margin_right = 12
		card_sb.content_margin_top = 12
		card_sb.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", card_sb)
		para_margin.add_child(card)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 8)
		card.add_child(card_vbox)

		# Title row (title + flag button)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 10)
		card_vbox.add_child(title_row)

		var title_lbl := Label.new()
		title_lbl.text = para["title"]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.add_theme_color_override("font_color", Color(0.1, 0.12, 0.18) if not is_flagged else Color(0.6, 0.15, 0.1))
		title_row.add_child(title_lbl)

		# Flag / unflag button in title row
		if is_flagged:
			var unflag_btn := Button.new()
			unflag_btn.text = "✕ 取消標記"
			unflag_btn.custom_minimum_size = Vector2(100, 30)
			unflag_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			unflag_btn.add_theme_font_size_override("font_size", 11)
			unflag_btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
			unflag_btn.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.93, 0.95), 5))
			unflag_btn.add_theme_stylebox_override("hover", _sb(Color(0.86, 0.86, 0.9), 5))
			var idx := i
			var area_ref := chat_area
			unflag_btn.pressed.connect(func():
				_on_unflag(area_ref, idx)
			)
			title_row.add_child(unflag_btn)
		else:
			var flag_btn := Button.new()
			flag_btn.text = "🚩 標記可疑"
			flag_btn.custom_minimum_size = Vector2(100, 30)
			flag_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			flag_btn.add_theme_font_size_override("font_size", 11)
			flag_btn.add_theme_color_override("font_color", Color.WHITE)
			flag_btn.add_theme_stylebox_override("normal", _sb(Color(0.75, 0.25, 0.2), 5))
			flag_btn.add_theme_stylebox_override("hover", _sb(Color(0.88, 0.32, 0.25), 5))
			var idx2 := i
			var area_ref2 := chat_area
			flag_btn.pressed.connect(func():
				_on_flag(area_ref2, idx2)
			)
			title_row.add_child(flag_btn)

		# Content
		var content_lbl := Label.new()
		content_lbl.text = para["content"]
		content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_lbl.add_theme_font_size_override("font_size", 12)
		content_lbl.add_theme_constant_override("line_spacing", 4)
		content_lbl.add_theme_color_override("font_color", Color(0.22, 0.22, 0.3) if not is_flagged else Color(0.45, 0.18, 0.14))
		card_vbox.add_child(content_lbl)

		# Flagged badge
		if is_flagged:
			var badge := Label.new()
			badge.text = "🚩 已標記為可疑內容"
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(0.7, 0.2, 0.15))
			card_vbox.add_child(badge)

	# Bottom padding in scroll
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(600, 12)
	vbox.add_child(pad)

func _on_flag(chat_area: Panel, index: int) -> void:
	if index not in _flagged:
		_flagged.append(index)
		GameState.record_action("flag_paragraph", index)
		var paragraphs := _get_paragraphs()
		if not paragraphs[index]["has_hallucination"]:
			GameState.record_wrong_action("flagged_correct_paragraph", index)
	_build_chat(chat_area)
	_update_status(chat_area)

func _on_unflag(chat_area: Panel, index: int) -> void:
	_flagged.erase(index)
	GameState.record_action("unflag_paragraph", index)
	_build_chat(chat_area)
	_update_status(chat_area)

func _update_status(chat_area: Panel) -> void:
	# Update status label in the bottom bar (sibling of chat_area)
	var p := chat_area.get_parent()
	if p:
		var bottom := p.get_node_or_null("BottomBar")
		if bottom:
			var lbl := bottom.get_node_or_null("StatusLbl")
			if lbl:
				lbl.text = "已標記：%d / 6 段　|　共有 3 個 AI 幻覺需找出" % _flagged.size()

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
		if ScoreManager.get_attempts(lid) >= 3 and not _show_give_up:
			_show_give_up = true
		_show_feedback_box(parent, result["details"])
		if _show_give_up:
			var bottom := parent.get_node_or_null("BottomBar")
			if bottom:
				var existing := bottom.get_node_or_null("GiveUpBtn")
				if not existing:
					var gub := Button.new()
					gub.name = "GiveUpBtn"
					gub.text = "查看解答"
					gub.position = Vector2(370, 9)
					gub.size = Vector2(110, 32)
					gub.add_theme_font_size_override("font_size", 11)
					gub.add_theme_color_override("font_color", Color.WHITE)
					gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
					gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
					gub.pressed.connect(func(): LevelManager.fail_level())
					bottom.add_child(gub)

# ============================================================
#  FEEDBACK BOXES
# ============================================================
func _show_feedback_box(parent: Panel, text: String) -> void:
	var old := parent.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 308)
	box.size = Vector2(620, 44)
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
	icon_label.position = Vector2(10, 8)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 15)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(36, 5)
	msg.size = Vector2(572, 34)
	msg.add_theme_font_size_override("font_size", 11)
	msg.add_theme_color_override("font_color", Color(0.4, 0.25, 0.05))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)

	var _timer := Timer.new()
	_timer.wait_time = 4.0
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
	box.position = Vector2(10, 308)
	box.size = Vector2(620, 44)
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
	icon_label.position = Vector2(10, 8)
	icon_label.size = Vector2(24, 24)
	icon_label.add_theme_font_size_override("font_size", 15)
	box.add_child(icon_label)

	var msg := Label.new()
	msg.text = text
	msg.position = Vector2(36, 5)
	msg.size = Vector2(572, 34)
	msg.add_theme_font_size_override("font_size", 11)
	msg.add_theme_color_override("font_color", Color(0.1, 0.4, 0.1))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)

	var _timer := Timer.new()
	_timer.wait_time = 4.0
	_timer.one_shot = true
	_timer.autostart = true
	box.add_child(_timer)
	_timer.timeout.connect(func():
		if is_instance_valid(box):
			box.queue_free()
	)
