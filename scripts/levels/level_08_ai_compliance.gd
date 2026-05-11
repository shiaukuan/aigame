extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track which apps have been removed
var _removed: Array[int] = []

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 8
	data.title = "披著羊皮的工具"
	data.category = "ai"
	data.difficulty = 2
	data.puzzle_title = "披著羊皮的工具"
	data.scenario_text = "你的電腦裡裝了好幾個 AI 助手，每個都說自己很好用。\n但公司有一份清單——只有上面的工具才是「合法住戶」。\n其他的，不管多好用，都是未經邀請的訪客。"
	data.task_hint = "你的電腦裡住了不少 AI，但你平常不會在桌面上看到它們的蹤影。\n想想看，電腦裡有個地方可以看到所有已安裝的東西。\n對照那份清單，把不該在的請出去。"
	data.teaching_points = PackedStringArray([
		"依公司辦法規定，AI 應用應使用「中華電信生成式 AI 合規清單」內之工具",
		"DeepSeek 屬主管機關禁用之 AI 模型，嚴禁使用",
		"未經合規審查的 AI 工具可能導致公司機敏資料外洩",
		"如有研究需求使用禁用工具，須經機構首長核准、獨立設備、獨立網段，並指派專人當責",
	])
	data.desktop_config = {}
	return data

func setup_desktop(_desktop: Node) -> void:
	# Level 8 is challenge-tier (8-11): no visual cues, player discovers via hints alone
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "設定":
		_content_settings(panel)
		return true
	return false

func check_completion() -> Dictionary:
	var should_remove := [1, 3, 4]  # DeepSeek, 某不明AI翻譯工具, ChatGPT 個人版
	var should_keep := [0, 2]       # CHT AI 助理, Microsoft Copilot（企業版）

	var removed_sorted := _removed.duplicate()
	removed_sorted.sort()

	var correct_removed := (removed_sorted == should_remove)

	# Check no approved ones were removed
	var wrongly_removed := false
	for idx in _removed:
		if idx in should_keep:
			wrongly_removed = true
			break

	var passed := correct_removed and not wrongly_removed
	var details := ""
	if wrongly_removed:
		details = "你移除了公司核准的 AI 應用程式！請只移除未經合規審查或被禁用的項目。"
	elif removed_sorted.size() < 3:
		details = "還有 %d 個未經核准的 AI 應用程式需要移除。" % (3 - removed_sorted.size())
	elif not correct_removed:
		details = "你移除的應用程式不完全正確，請再檢查一次。"

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
#  APP DATA
# ============================================================
func _get_apps() -> Array:
	return [
		{
			"name": "CHT AI 助理",
			"desc": "公司自建 AI 平台",
			"source": "中華電信",
			"approved": true,
			"icon": "🏢",
			"detail": "公司自建之生成式 AI 平台，已通過合規審查並列入「中華電信生成式 AI 合規清單」。",
		},
		{
			"name": "DeepSeek",
			"desc": "中國大型語言模型",
			"source": "DeepSeek AI",
			"approved": false,
			"icon": "🔍",
			"detail": "中國開發之大型語言模型，主管機關已明令禁止使用。使用該工具可能導致資料傳輸至境外伺服器，嚴重違反公司資安政策。",
		},
		{
			"name": "Microsoft Copilot（企業版）",
			"desc": "辦公室 AI 助手",
			"source": "Microsoft Corporation",
			"approved": true,
			"icon": "🤖",
			"detail": "Microsoft 提供之企業版 AI 助手，已通過合規審查並列入「中華電信生成式 AI 合規清單」。資料處理符合企業安全標準。",
		},
		{
			"name": "某不明 AI 翻譯工具",
			"desc": "來源不明的免費 AI 翻譯",
			"source": "Unknown Developer",
			"approved": false,
			"icon": "🌐",
			"detail": "來源不明的免費 AI 翻譯工具，未經公司合規審查。輸入的文字內容可能被第三方蒐集或用於模型訓練，存在資料外洩風險。",
		},
		{
			"name": "ChatGPT 個人版",
			"desc": "個人帳號登入使用",
			"source": "OpenAI",
			"approved": false,
			"icon": "💬",
			"detail": "以個人帳號登入之 ChatGPT，未經公司合規審查。對話內容可能被用於模型訓練，且無法保證資料不會外洩。公務使用應使用企業版或公司核准之 AI 工具。",
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

func _content_settings(p: Panel) -> void:
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
		# Highlight "應用程式" (index 4) as active
		b.add_theme_stylebox_override("normal", _sb(Color(0.85, 0.9, 1.0) if i == 4 else Color(1, 1, 1, 0), 4))
		b.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.06), 4))
		var idx := i
		var p_ref := p
		b.pressed.connect(func():
			_on_sidebar_click(p_ref, idx)
		)
		side.add_child(b)

	# Right content — show 應用程式 page by default
	var content := Panel.new()
	content.name = "SettingsContent"
	content.position = Vector2(170, 0)
	content.size = Vector2(470, 408)
	content.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1), 0))
	p.add_child(content)

	_build_apps_page(content)

func _on_sidebar_click(p: Panel, index: int) -> void:
	var content := p.get_node_or_null("SettingsContent")
	if not content:
		return
	# Clear content
	for child in content.get_children():
		child.queue_free()

	if index == 4:
		# 應用程式
		_build_apps_page(content)
	else:
		# Other settings pages — show placeholder
		var items := ["系統", "藍牙與裝置", "網路與網際網路", "個人化", "應用程式", "帳號與安全", "隱私權與安全性", "Windows Update"]
		var title := Label.new()
		title.text = items[index]
		title.position = Vector2(20, 12)
		title.size = Vector2(400, 28)
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		content.add_child(title)

		var placeholder := Label.new()
		placeholder.text = "此頁面目前無需操作。\n請前往「應用程式」頁面檢查已安裝的 AI 工具。"
		placeholder.position = Vector2(20, 52)
		placeholder.size = Vector2(420, 60)
		placeholder.add_theme_font_size_override("font_size", 12)
		placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(placeholder)

func _build_apps_page(content: Panel) -> void:
	for child in content.get_children():
		child.queue_free()

	# Page title
	var title := Label.new()
	title.text = "已安裝的應用程式"
	title.position = Vector2(20, 8)
	title.size = Vector2(400, 28)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "以下是電腦中已安裝的 AI 應用程式"
	subtitle.position = Vector2(20, 34)
	subtitle.size = Vector2(430, 18)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	content.add_child(subtitle)

	# Scroll area for app list
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 56)
	scroll.size = Vector2(450, 296)
	content.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var apps := _get_apps()
	for i in apps.size():
		if i in _removed:
			continue  # Already removed, don't show

		var app: Dictionary = apps[i]
		var row := Panel.new()
		row.custom_minimum_size = Vector2(436, 66)
		var row_sb := _sb(Color(1, 1, 1), 6)
		row_sb.border_color = Color(0.88, 0.88, 0.9)
		row_sb.border_width_bottom = 1
		row.add_theme_stylebox_override("panel", row_sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(row)

		# Icon
		var icon := Label.new()
		icon.text = app["icon"]
		icon.position = Vector2(12, 12)
		icon.size = Vector2(30, 30)
		icon.add_theme_font_size_override("font_size", 20)
		row.add_child(icon)

		# Name
		var name_label := Label.new()
		name_label.text = app["name"]
		name_label.position = Vector2(48, 6)
		name_label.size = Vector2(196, 20)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)

		# Description + source
		var desc_label := Label.new()
		desc_label.text = app["desc"] + "  —  " + app["source"]
		desc_label.position = Vector2(48, 30)
		desc_label.size = Vector2(280, 18)
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		desc_label.clip_text = true
		desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(desc_label)

		# Detail button
		var detail_btn := Button.new()
		detail_btn.text = "檢視"
		detail_btn.position = Vector2(310, 18)
		detail_btn.size = Vector2(42, 28)
		detail_btn.add_theme_font_size_override("font_size", 11)
		detail_btn.add_theme_color_override("font_color", Color(0.2, 0.45, 0.8))
		detail_btn.add_theme_stylebox_override("normal", _sb(Color(0.92, 0.95, 1.0), 4))
		detail_btn.add_theme_stylebox_override("hover", _sb(Color(0.85, 0.9, 1.0), 4))
		var idx := i
		var content_ref := content
		detail_btn.pressed.connect(func():
			_show_app_detail(content_ref, idx)
		)
		row.add_child(detail_btn)

		# Remove button
		var remove_btn := Button.new()
		remove_btn.text = "解除安裝"
		remove_btn.position = Vector2(358, 18)
		remove_btn.size = Vector2(68, 28)
		remove_btn.add_theme_font_size_override("font_size", 11)
		remove_btn.add_theme_color_override("font_color", Color.WHITE)
		remove_btn.add_theme_stylebox_override("normal", _sb(Color(0.75, 0.25, 0.25), 4))
		remove_btn.add_theme_stylebox_override("hover", _sb(Color(0.85, 0.35, 0.35), 4))
		var idx2 := i
		var content_ref2 := content
		remove_btn.pressed.connect(func():
			_on_remove_app(content_ref2, idx2)
		)
		row.add_child(remove_btn)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(330, 362)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var content_ref_finish := content
	finish.pressed.connect(func(): _on_finish_pressed(content_ref_finish))
	content.add_child(finish)

func _show_app_detail(content: Panel, index: int) -> void:
	var apps := _get_apps()
	var app: Dictionary = apps[index]

	var old := content.get_node_or_null("AppDetail")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "AppDetail"
	box.position = Vector2(20, 60)
	box.size = Vector2(430, 220)
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
	content.add_child(box)

	# App icon and name
	var app_title := Label.new()
	app_title.text = app["icon"] + "  " + app["name"]
	app_title.position = Vector2(16, 12)
	app_title.size = Vector2(370, 26)
	app_title.add_theme_font_size_override("font_size", 16)
	app_title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	box.add_child(app_title)

	# Source
	var source_label := Label.new()
	source_label.text = "開發者：" + app["source"]
	source_label.position = Vector2(16, 46)
	source_label.size = Vector2(400, 20)
	source_label.add_theme_font_size_override("font_size", 12)
	source_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	box.add_child(source_label)

	# Detail description
	var detail := Label.new()
	detail.text = app["detail"]
	detail.position = Vector2(16, 74)
	detail.size = Vector2(398, 60)
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)

	# Regulation note
	var reg := Label.new()
	if app["approved"]:
		reg.text = "📋 此工具已列入「中華電信生成式 AI 合規清單」，可正常使用。"
	else:
		reg.text = "📋 此工具未經公司合規審查，不得用於處理公務資料。請立即解除安裝。"
	reg.position = Vector2(16, 140)
	reg.size = Vector2(398, 40)
	reg.add_theme_font_size_override("font_size", 11)
	reg.add_theme_color_override("font_color", Color(0.35, 0.35, 0.55))
	reg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(reg)

	# Close button
	var close := Button.new()
	close.text = "✕"
	close.position = Vector2(398, 6)
	close.size = Vector2(24, 24)
	close.add_theme_font_size_override("font_size", 12)
	close.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	close.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
	close.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.08), 4))
	close.pressed.connect(func(): box.queue_free())
	box.add_child(close)

	GameState.record_action("view_app_detail", app["name"])

func _on_remove_app(content: Panel, index: int) -> void:
	var apps := _get_apps()
	var app: Dictionary = apps[index]

	if app["approved"]:
		GameState.record_wrong_action("removed_approved_app", app["name"])
		_show_feedback_box(content, "「%s」是公司核准的 AI 應用程式，不應解除安裝！" % app["name"])
		return

	_removed.append(index)
	GameState.record_action("remove_app", app["name"])
	_build_apps_page(content)
	_show_feedback_box_success(content, "已解除安裝「%s」。" % app["name"])

func _on_finish_pressed(content: Panel) -> void:
	if not LevelManager.level_active:
		return
	var lid := LevelManager.current_level
	ScoreManager.increment_attempts(lid)
	var result := check_completion()

	if result["passed"]:
		var score := calculate_score()
		LevelManager.complete_level(score)
	else:
		_show_feedback_box(content, result["details"])
		if ScoreManager.get_attempts(lid) >= 3:
			var existing := content.get_node_or_null("GiveUpBtn")
			if not existing:
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				gub.position = Vector2(180, 362)
				gub.size = Vector2(140, 32)
				gub.add_theme_font_size_override("font_size", 12)
				gub.add_theme_color_override("font_color", Color.WHITE)
				gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
				gub.pressed.connect(func(): LevelManager.fail_level())
				content.add_child(gub)

# ============================================================
#  FEEDBACK BOXES
# ============================================================
func _show_feedback_box(parent: Panel, text: String) -> void:
	var old := parent.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 310)
	box.size = Vector2(450, 48)
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
	msg.size = Vector2(382, 36)
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
	box.position = Vector2(10, 310)
	box.size = Vector2(450, 48)
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
	msg.size = Vector2(382, 36)
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
