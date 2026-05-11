extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track player progress through the correct workflow
var _read_guidelines := false   # Step 1: Read AI使用規範.pdf
var _read_requirements := false # Step 2: Read 客戶需求摘要.docx
var _ai_opened := false         # Step 3: Opened AI assistant
var _sent_to_ai := false        # Step 4: Sent request to AI
var _sent_confidential := false # Did player include confidential info?
var _got_draft := false         # Step 5: AI generated draft
var _draft_edited := false      # Step 6: Player edited the draft
var _draft_saved := false       # Step 7: Player saved the proposal

# The AI-generated draft text
var _ai_draft_text := ""

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 11
	data.title = "正確的配方"
	data.category = "ai"
	data.difficulty = 2
	data.puzzle_title = "正確的配方"
	data.scenario_text = "主管急著要一份提案，你決定請 AI 幫忙。\n但公司有規矩——不是打開工具直接丟東西進去就好。\n桌面上散落著各種文件，有些跟這次任務有關，有些只是日常雜物。\n正確的順序，比速度更重要。"
	data.task_hint = "廚師下鍋前要先讀食譜、備好食材。\n桌面上的文件裡，有一份藏著「規矩」，有一份藏著「原料」。\n找到它們，按正確的順序處理——\n而且記住，機器端出來的東西，從來不能直接上桌。"
	data.teaching_points = PackedStringArray([
		"使用 AI 前先確認公司政策",
		"確認輸入內容不含機密",
		"AI 產出必須經過人工審核和修改",
		"要對最終成果負責，不能說「是 AI 寫的」",
	])
	data.desktop_config = {}
	return data

func setup_desktop(desktop: Node) -> void:
	# Show level 11 files plus a few distractors to encourage exploration
	var file_container := desktop.get_node_or_null("DesktopFiles")
	if file_container:
		var visible_files := [
			"AI使用規範.pdf", "客戶需求摘要.docx",
			"會議記錄.docx", "產品使用手冊.pdf",
		]
		for child in file_container.get_children():
			var data = child.get_meta("icon_data")
			var fname: String = data["name"]
			if fname not in visible_files:
				child.visible = false

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "AI 助手":
		_ai_opened = true
		GameState.record_action("open_ai_assistant")
		if not _read_guidelines:
			GameState.record_wrong_action("ai_before_guidelines", "未先閱讀 AI 使用規範就開啟 AI 助手")
		_content_ai_assistant(panel, desktop)
		return true
	if app_name == "記事本":
		if _got_draft:
			_content_notepad_with_draft(panel, desktop)
			return true
	return false

func on_file_open(file_name: String, _desktop: Node) -> bool:
	if file_name == "AI使用規範.pdf":
		_read_guidelines = true
		GameState.record_action("read_guidelines", file_name)
		return false  # Let default file viewer show the content
	if file_name == "客戶需求摘要.docx":
		_read_requirements = true
		GameState.record_action("read_requirements", file_name)
		return false  # Let default file viewer show the content
	return false

func check_completion() -> Dictionary:
	if not _read_guidelines:
		return {
			"passed": false,
			"details": "你還沒有閱讀「AI使用規範.pdf」。使用 AI 前必須先了解公司規範。",
		}
	if not _read_requirements:
		return {
			"passed": false,
			"details": "你還沒有閱讀「客戶需求摘要.docx」。需要先了解客戶需求才能撰寫提案。",
		}
	if not _sent_to_ai:
		return {
			"passed": false,
			"details": "你還沒有使用 AI 助手生成提案草稿。請開啟 AI 助手並輸入需求。",
		}
	if _sent_confidential:
		return {
			"passed": false,
			"details": "你將機密資訊傳送給了 AI！公司規範禁止將機密資料輸入 AI 工具。請改選非機密的需求描述傳送給 AI。",
		}
	if not _got_draft:
		return {
			"passed": false,
			"details": "你還沒有取得 AI 生成的草稿。",
		}
	if not _draft_edited:
		return {
			"passed": false,
			"details": "你還沒有修改 AI 生成的草稿。AI 產出必須經過人工審核和修改，不能原封不動使用。",
		}
	if not _draft_saved:
		return {
			"passed": false,
			"details": "你還沒有儲存修改後的提案。請在記事本中編輯並儲存。",
		}

	# All steps completed correctly
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
#  AI ASSISTANT UI
# ============================================================
func _content_ai_assistant(p: Panel, desktop: Node) -> void:
	# Header
	var header := Panel.new()
	header.size = Vector2(640, 52)
	header.add_theme_stylebox_override("panel", _sb(Color(0.94, 0.96, 0.99), 0))
	p.add_child(header)

	var title := Label.new()
	title.text = "🤖 AI 助手 — 提案撰寫協助"
	title.position = Vector2(16, 6)
	title.size = Vector2(400, 24)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "請輸入客戶需求描述，AI 將協助您生成提案草稿"
	subtitle.position = Vector2(16, 30)
	subtitle.size = Vector2(600, 18)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	header.add_child(subtitle)

	# Content area
	var content_area := Panel.new()
	content_area.name = "AIContentArea"
	content_area.position = Vector2(0, 52)
	content_area.size = Vector2(640, 356)
	content_area.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1), 0))
	p.add_child(content_area)

	# Status panel - show workflow progress
	var status := Panel.new()
	status.position = Vector2(10, 6)
	status.size = Vector2(620, 64)
	status.add_theme_stylebox_override("panel", _sb(Color(0.95, 0.97, 1.0), 6))
	content_area.add_child(status)

	var steps_text := ""
	steps_text += ("✅" if _read_guidelines else "⬜") + " 1. 閱讀 AI 使用規範　"
	steps_text += ("✅" if _read_requirements else "⬜") + " 2. 閱讀客戶需求摘要\n"
	steps_text += ("✅" if _sent_to_ai and not _sent_confidential else "⬜") + " 3. 提供需求給 AI　　"
	steps_text += ("✅" if _draft_edited else "⬜") + " 4. 修改 AI 草稿並儲存"

	var steps_lbl := Label.new()
	steps_lbl.text = steps_text
	steps_lbl.position = Vector2(12, 6)
	steps_lbl.size = Vector2(596, 52)
	steps_lbl.add_theme_font_size_override("font_size", 11)
	steps_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
	status.add_child(steps_lbl)

	if _got_draft:
		# Show the generated draft
		_show_draft_view(content_area, desktop)
	else:
		# Show input options
		_show_input_options(content_area, desktop)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(490, 318)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var panel_ref := p
	finish.pressed.connect(func(): _on_finish_pressed(panel_ref))
	content_area.add_child(finish)

func _show_input_options(area: Panel, desktop: Node) -> void:
	# Instruction
	var instr := Label.new()
	instr.text = "請選擇要提供給 AI 的資訊內容："
	instr.position = Vector2(16, 78)
	instr.size = Vector2(600, 20)
	instr.add_theme_font_size_override("font_size", 13)
	instr.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	area.add_child(instr)

	var options := _get_input_options()

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 102)
	scroll.size = Vector2(620, 208)
	area.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for i in options.size():
		var opt: Dictionary = options[i]

		var card := Panel.new()
		card.custom_minimum_size = Vector2(600, 52)
		var card_sb := _sb(Color(0.99, 0.99, 1.0), 6)
		card_sb.border_color = Color(0.88, 0.88, 0.92)
		card_sb.border_width_bottom = 1
		card.add_theme_stylebox_override("panel", card_sb)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(card)

		var icon_lbl := Label.new()
		icon_lbl.text = opt["icon"]
		icon_lbl.position = Vector2(12, 10)
		icon_lbl.size = Vector2(28, 28)
		icon_lbl.add_theme_font_size_override("font_size", 18)
		card.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = opt["label"]
		name_lbl.position = Vector2(44, 6)
		name_lbl.size = Vector2(360, 20)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		card.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = opt["desc"]
		desc_lbl.position = Vector2(44, 28)
		desc_lbl.size = Vector2(360, 18)
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		card.add_child(desc_lbl)

		# Send button
		var send_btn := Button.new()
		send_btn.text = "傳送給 AI"
		send_btn.position = Vector2(494, 12)
		send_btn.size = Vector2(92, 28)
		send_btn.add_theme_font_size_override("font_size", 11)
		send_btn.add_theme_color_override("font_color", Color.WHITE)
		send_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.55, 0.85), 4))
		send_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 0.9), 4))
		var idx := i
		var area_ref := area
		var desktop_ref := desktop
		send_btn.pressed.connect(func():
			_on_send_to_ai(area_ref, idx, desktop_ref)
		)
		card.add_child(send_btn)

func _show_draft_view(area: Panel, desktop: Node) -> void:
	var draft_panel := Panel.new()
	draft_panel.position = Vector2(10, 78)
	draft_panel.size = Vector2(620, 180)
	draft_panel.add_theme_stylebox_override("panel", _sb(Color(0.97, 0.98, 1.0), 6))
	area.add_child(draft_panel)

	var draft_title := Label.new()
	draft_title.text = "📄 AI 生成的提案草稿"
	draft_title.position = Vector2(12, 6)
	draft_title.size = Vector2(400, 20)
	draft_title.add_theme_font_size_override("font_size", 13)
	draft_title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	draft_panel.add_child(draft_title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 30)
	scroll.size = Vector2(596, 108)
	draft_panel.add_child(scroll)

	var draft_lbl := Label.new()
	draft_lbl.text = _ai_draft_text
	draft_lbl.custom_minimum_size = Vector2(580, 0)
	draft_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	draft_lbl.add_theme_font_size_override("font_size", 11)
	draft_lbl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
	scroll.add_child(draft_lbl)

	var warning_lbl := Label.new()
	warning_lbl.text = "⚠️ AI 生成的內容僅供參考，必須經過人工審核和修改後才能使用。"
	warning_lbl.position = Vector2(12, 144)
	warning_lbl.size = Vector2(596, 30)
	warning_lbl.add_theme_font_size_override("font_size", 11)
	warning_lbl.add_theme_color_override("font_color", Color(0.7, 0.4, 0.1))
	warning_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	draft_panel.add_child(warning_lbl)

	# Edit in notepad button
	var edit_btn := Button.new()
	edit_btn.text = "📝 在記事本中編輯草稿"
	edit_btn.position = Vector2(10, 318)
	edit_btn.size = Vector2(200, 32)
	edit_btn.add_theme_font_size_override("font_size", 12)
	edit_btn.add_theme_color_override("font_color", Color.WHITE)
	edit_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.55, 0.4), 6))
	edit_btn.add_theme_stylebox_override("hover", _sb(Color(0.25, 0.65, 0.5), 6))
	var desktop_ref := desktop
	edit_btn.pressed.connect(func():
		desktop_ref._open_app("記事本", "📝")
	)
	area.add_child(edit_btn)

	# Status
	if _draft_edited and _draft_saved:
		_show_feedback_box_success(area, "✅ 草稿已修改並儲存。你已完成所有步驟，可以按「完成作答」。")
	elif _draft_edited:
		_show_feedback_box(area, "草稿已修改，請記得按「儲存提案」按鈕儲存。")

# ============================================================
#  NOTEPAD WITH DRAFT
# ============================================================
func _content_notepad_with_draft(p: Panel, _desktop: Node) -> void:
	# Header
	var header := Panel.new()
	header.size = Vector2(640, 36)
	header.add_theme_stylebox_override("panel", _sb(Color(0.94, 0.96, 0.99), 0))
	p.add_child(header)

	var title := Label.new()
	title.text = "📝 記事本 — 提案草稿編輯"
	title.position = Vector2(12, 6)
	title.size = Vector2(400, 24)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	header.add_child(title)

	var hint := Label.new()
	hint.text = "⚠️ 請修改 AI 草稿後再儲存，不可原封不動使用"
	hint.position = Vector2(12, 38)
	hint.size = Vector2(620, 18)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.4, 0.1))
	p.add_child(hint)

	# Text edit area
	var edit := TextEdit.new()
	edit.name = "DraftEdit"
	edit.position = Vector2(0, 58)
	edit.size = Vector2(640, 306)
	edit.text = _ai_draft_text
	edit.add_theme_font_size_override("font_size", 12)
	edit.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	p.add_child(edit)

	# Save button
	var save_btn := Button.new()
	save_btn.text = "💾 儲存提案"
	save_btn.position = Vector2(510, 370)
	save_btn.size = Vector2(120, 34)
	save_btn.add_theme_font_size_override("font_size", 13)
	save_btn.add_theme_color_override("font_color", Color.WHITE)
	save_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	save_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var edit_ref := edit
	var panel_ref := p
	save_btn.pressed.connect(func():
		_on_save_draft(edit_ref, panel_ref)
	)
	p.add_child(save_btn)

func _on_save_draft(edit: TextEdit, panel: Panel) -> void:
	var current_text := edit.text.strip_edges()
	var original_text := _ai_draft_text.strip_edges()

	if current_text == original_text:
		_show_feedback_box(panel, "你沒有修改 AI 的草稿！AI 產出必須經過人工審核和修改，不能原封不動提交。")
		GameState.record_wrong_action("saved_unedited_draft", "未修改 AI 草稿就儲存")
		return

	if current_text.length() < 20:
		_show_feedback_box(panel, "修改後的提案內容太短了。請確保提案有足夠的內容。")
		return

	_draft_edited = true
	_draft_saved = true
	GameState.record_action("edited_and_saved_draft")
	_show_feedback_box_success(panel, "提案已儲存！你已完成所有步驟，請回到 AI 助手按「完成作答」。")

# ============================================================
#  INPUT OPTIONS DATA
# ============================================================
func _get_input_options() -> Array:
	return [
		{
			"icon": "📋",
			"label": "客戶需求描述（非機密）",
			"desc": "客戶：○○科技公司，需求：建置企業內部知識管理系統，預算：公開招標範圍",
			"confidential": false,
			"content_type": "requirements",
		},
		{
			"icon": "💰",
			"label": "客戶報價與合約細節",
			"desc": "含合約金額、付款條件、折扣比例等商業機密",
			"confidential": true,
			"content_type": "pricing",
		},
		{
			"icon": "👤",
			"label": "客戶聯絡人個資",
			"desc": "含聯絡人姓名、手機號碼、身分證字號",
			"confidential": true,
			"content_type": "personal_data",
		},
		{
			"icon": "📊",
			"label": "公司內部成本結構",
			"desc": "含人力成本、利潤率、內部定價策略",
			"confidential": true,
			"content_type": "cost_structure",
		},
	]

func _on_send_to_ai(area: Panel, index: int, desktop: Node) -> void:
	var options := _get_input_options()
	var opt: Dictionary = options[index]

	_sent_to_ai = true
	GameState.record_action("sent_to_ai", opt["content_type"])

	if opt["confidential"]:
		_sent_confidential = true
		GameState.record_wrong_action("sent_confidential_to_ai", opt["label"])
		_show_feedback_box(area, "⚠️ 你傳送了機密資訊「%s」給 AI！\n依公司規範，禁止將機密資料輸入 AI 工具。" % opt["label"])
		return

	# Non-confidential - generate the draft
	_sent_confidential = false  # Allow recovery after earlier confidential send
	_got_draft = true
	_ai_draft_text = _generate_ai_draft()
	GameState.record_action("received_ai_draft")

	# Rebuild the AI assistant view
	for child in area.get_children():
		child.queue_free()

	# Re-add status panel
	var status := Panel.new()
	status.position = Vector2(10, 6)
	status.size = Vector2(620, 64)
	status.add_theme_stylebox_override("panel", _sb(Color(0.95, 0.97, 1.0), 6))
	area.add_child(status)

	var steps_text := ""
	steps_text += ("✅" if _read_guidelines else "⬜") + " 1. 閱讀 AI 使用規範　"
	steps_text += ("✅" if _read_requirements else "⬜") + " 2. 閱讀客戶需求摘要\n"
	steps_text += ("✅" if _sent_to_ai and not _sent_confidential else "⬜") + " 3. 提供需求給 AI　　"
	steps_text += ("✅" if _draft_edited else "⬜") + " 4. 修改 AI 草稿並儲存"

	var steps_lbl := Label.new()
	steps_lbl.text = steps_text
	steps_lbl.position = Vector2(12, 6)
	steps_lbl.size = Vector2(596, 52)
	steps_lbl.add_theme_font_size_override("font_size", 11)
	steps_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
	status.add_child(steps_lbl)

	_show_draft_view(area, desktop)

	# Re-add finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(490, 318)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var parent_panel := area.get_parent()
	finish.pressed.connect(func(): _on_finish_pressed(parent_panel))
	area.add_child(finish)

	_show_feedback_box_success(area, "AI 已生成提案草稿！請在記事本中修改後再儲存。")

func _generate_ai_draft() -> String:
	return """企業內部知識管理系統建置提案

一、專案概述
本提案旨在為○○科技公司建置一套企業內部知識管理系統，
以提升組織知識的累積、分享與應用效率。

二、系統架構
建議採用雲端架構，包含以下核心模組：
- 知識文件管理模組
- 全文搜尋引擎
- 協作編輯功能
- 權限管理系統
- 數據分析儀表板

三、實施計畫
第一階段（第 1-2 個月）：需求訪談與系統設計
第二階段（第 3-4 個月）：核心功能開發
第三階段（第 5 個月）：整合測試與使用者培訓
第四階段（第 6 個月）：上線部署與維運支援

四、預期效益
- 減少知識重複建立的時間成本
- 提升跨部門協作效率
- 建立組織知識資產庫

（AI 輔助生成 — 需經人工審核修改）"""

# ============================================================
#  FINISH HANDLER
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
			var existing := parent.get_node_or_null("GiveUpBtn")
			if not existing:
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				gub.position = Vector2(370, 370)
				gub.size = Vector2(110, 32)
				gub.add_theme_font_size_override("font_size", 12)
				gub.add_theme_color_override("font_color", Color.WHITE)
				gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
				gub.pressed.connect(func(): LevelManager.fail_level())
				parent.add_child(gub)

# ============================================================
#  HELPERS
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
