extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track which extensions have been removed
var _removed: Array[int] = []

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 3
	data.title = "窗戶上的寄生蟲"
	data.category = "security"
	data.difficulty = 2
	data.puzzle_title = "窗戶上的寄生蟲"
	data.scenario_text = "你的窗戶看起來很乾淨，但仔細看——\n上面黏了好幾個小東西。有些是你裝的紗窗，有些……\n是不知道什麼時候爬上來的。\n它們安靜地待在那裡，但每一個都在偷看你房間裡的東西。"
	data.task_hint = "打開那扇你每天用來看世界的窗。\n窗框的角落藏著一塊拼圖——那裡記錄了所有攀附在上面的東西。\n分辨哪些是紗窗，哪些是蟲，然後動手清理。"
	data.teaching_points = PackedStringArray([
		"瀏覽器擴充程式可能存取你的瀏覽資料和帳號資訊",
		"只安裝公司核准的擴充程式",
		"LINE 等通訊軟體的瀏覽器版本可能導致訊息在公司設備上殘留",
		"Google Drive 個人帳號可能導致公司檔案被同步到私人空間",
		"來源不明的擴充程式可能包含惡意程式碼",
	])
	data.desktop_config = {"highlight_app": "Microsoft Edge"}
	return data

func setup_desktop(_desktop: Node) -> void:
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "Microsoft Edge":
		_content_browser(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	var should_remove := [1, 2, 4]  # LINE, Google Drive, P2P
	var should_keep := [0, 3]       # React Dev Tools, Video Speed Controller

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
		details = "你移除了公司核准的擴充程式！請只移除未經核准的項目。"
	elif removed_sorted.size() < 3:
		details = "還有 %d 個未經核准的擴充程式需要移除。" % (3 - removed_sorted.size())
	elif not correct_removed:
		details = "你移除的擴充程式不完全正確，請再檢查一次。"

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
#  EXTENSION DATA
# ============================================================
func _get_extensions() -> Array:
	return [
		{
			"name": "React Developer Tools",
			"desc": "React 開發除錯工具",
			"source": "Meta Platforms, Inc.",
			"approved": true,
			"icon": "⚛️",
			"reason": "公司核准 — 前端開發必備工具",
		},
		{
			"name": "LINE",
			"desc": "LINE 通訊軟體瀏覽器版",
			"source": "LINE Corporation",
			"approved": false,
			"icon": "💬",
			"reason": "未經核准 — 個人通訊軟體，訊息可能殘留在公司設備",
		},
		{
			"name": "Google Drive",
			"desc": "Google 雲端硬碟整合",
			"source": "Google LLC",
			"approved": false,
			"icon": "📁",
			"reason": "未經核准 — 個人雲端帳號可能導致公司檔案同步至私人空間",
		},
		{
			"name": "Video Speed Controller",
			"desc": "影片播放速度控制器",
			"source": "igrigorik",
			"approved": true,
			"icon": "⏩",
			"reason": "公司核准 — 教育訓練影片加速工具",
		},
		{
			"name": "P2P Download Manager",
			"desc": "P2P 檔案下載管理器",
			"source": "Unknown Developer",
			"approved": false,
			"icon": "⬇️",
			"reason": "未經核准 — P2P 下載有資料外洩與版權風險",
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

func _content_browser(p: Panel, _desktop: Node) -> void:
	# URL bar
	var url_bar := Panel.new()
	url_bar.name = "UrlBar"
	url_bar.size = Vector2(640, 38)
	url_bar.add_theme_stylebox_override("panel", _sb(Color(0.94, 0.94, 0.96), 0))
	p.add_child(url_bar)

	# Nav buttons
	for nav in [["←", 8], ["→", 40]]:
		var nb := Button.new()
		nb.text = nav[0]
		nb.position = Vector2(nav[1], 3)
		nb.size = Vector2(30, 32)
		nb.add_theme_font_size_override("font_size", 16)
		nb.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
		nb.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.06), 4))
		url_bar.add_child(nb)

	# URL input
	var url := LineEdit.new()
	url.name = "UrlInput"
	url.text = "https://www.company-portal.com"
	url.position = Vector2(78, 4)
	url.size = Vector2(516, 30)
	url.editable = false
	url.add_theme_font_size_override("font_size", 12)
	url_bar.add_child(url)

	# Extensions button (right of URL bar)
	var ext_btn := Button.new()
	ext_btn.text = "🧩"
	ext_btn.position = Vector2(600, 3)
	ext_btn.size = Vector2(34, 32)
	ext_btn.add_theme_font_size_override("font_size", 16)
	ext_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0), 4))
	ext_btn.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.08), 4))
	ext_btn.z_index = 5
	url_bar.add_child(ext_btn)

	# Page content
	var page := Panel.new()
	page.name = "BrowserPage"
	page.position = Vector2(0, 38)
	page.size = Vector2(640, 370)
	page.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1), 0))
	p.add_child(page)

	# Show homepage by default
	_build_homepage(page)

	# Wire extensions button
	var p_ref := p
	ext_btn.pressed.connect(func():
		_navigate_to_extensions(p_ref)
	)

func _build_homepage(page: Panel) -> void:
	for child in page.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "公司入口網站"
	title.position = Vector2(20, 12)
	title.size = Vector2(400, 30)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	page.add_child(title)

	var links := ["📋 公司公告", "📊 業績報表", "📖 員工手冊", "🎓 教育訓練", "💼 差勤系統", "🔒 資安專區"]
	for i in links.size():
		var lb := Button.new()
		lb.text = links[i]
		lb.position = Vector2(20 + (i % 3) * 200, 50 + (i / 3) * 48)
		lb.size = Vector2(185, 40)
		lb.add_theme_font_size_override("font_size", 14)
		lb.add_theme_color_override("font_color", Color(0.15, 0.35, 0.7))
		lb.add_theme_stylebox_override("normal", _sb(Color(0.95, 0.97, 1.0), 6))
		lb.add_theme_stylebox_override("hover", _sb(Color(0.9, 0.93, 1.0), 6))
		page.add_child(lb)

	var news := Label.new()
	news.text = "📢 最新消息\n\n• 2026/04/01 — 第二季資安宣導週開始\n• 2026/03/28 — AI 使用規範 v2.0 發布\n• 2026/03/25 — 密碼政策更新通知"
	news.position = Vector2(20, 160)
	news.size = Vector2(600, 200)
	news.add_theme_font_size_override("font_size", 13)
	news.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	page.add_child(news)

func _navigate_to_extensions(p: Panel) -> void:
	# Update URL
	var url_input := p.get_node_or_null("UrlBar/UrlInput")
	if url_input:
		url_input.text = "edge://extensions"

	# Switch page content
	var page := p.get_node_or_null("BrowserPage")
	if page:
		GameState.record_action("open_extensions_page")
		_build_extensions_list(page)

func _build_extensions_list(page: Panel) -> void:
	for child in page.get_children():
		child.queue_free()

	# Page title
	var title := Label.new()
	title.text = "🧩  擴充功能管理"
	title.position = Vector2(20, 8)
	title.size = Vector2(400, 28)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	page.add_child(title)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 42)
	scroll.size = Vector2(620, 280)
	page.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var extensions := _get_extensions()
	for i in extensions.size():
		if i in _removed:
			continue  # Already removed, don't show

		var ext: Dictionary = extensions[i]
		var row := Panel.new()
		row.custom_minimum_size = Vector2(600, 62)
		var row_sb := _sb(Color(1, 1, 1), 6)
		row_sb.border_color = Color(0.88, 0.88, 0.9)
		row_sb.border_width_bottom = 1
		row.add_theme_stylebox_override("panel", row_sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(row)

		# Icon
		var icon := Label.new()
		icon.text = ext["icon"]
		icon.position = Vector2(12, 12)
		icon.size = Vector2(30, 30)
		icon.add_theme_font_size_override("font_size", 20)
		row.add_child(icon)

		# Name + desc
		var name_label := Label.new()
		name_label.text = ext["name"]
		name_label.position = Vector2(48, 8)
		name_label.size = Vector2(300, 20)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		row.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = ext["desc"] + "  —  " + ext["source"]
		desc_label.position = Vector2(48, 30)
		desc_label.size = Vector2(350, 18)
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(desc_label)

		# Remove button
		var remove_btn := Button.new()
		remove_btn.text = "移除"
		remove_btn.position = Vector2(520, 16)
		remove_btn.size = Vector2(70, 28)
		remove_btn.add_theme_font_size_override("font_size", 12)
		remove_btn.add_theme_color_override("font_color", Color.WHITE)
		remove_btn.add_theme_stylebox_override("normal", _sb(Color(0.75, 0.25, 0.25), 6))
		remove_btn.add_theme_stylebox_override("hover", _sb(Color(0.85, 0.35, 0.35), 6))
		var idx := i
		var page_ref := page
		remove_btn.pressed.connect(func():
			_on_remove_extension(page_ref, idx)
		)
		row.add_child(remove_btn)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(490, 332)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	finish.pressed.connect(func(): _on_finish_pressed(page))
	page.add_child(finish)

func _on_remove_extension(page: Panel, index: int) -> void:
	var extensions := _get_extensions()
	var ext: Dictionary = extensions[index]

	if ext["approved"]:
		GameState.record_wrong_action("removed_approved_extension", ext["name"])
		_show_feedback_box(page, "⚠️ 「%s」是公司核准的擴充程式，不應移除！" % ext["name"])
		return

	_removed.append(index)
	GameState.record_action("remove_extension", ext["name"])
	_build_extensions_list(page)
	_show_feedback_box_success(page, "已移除「%s」。" % ext["name"])

func _on_finish_pressed(page: Panel) -> void:
	if not LevelManager.level_active:
		return
	var lid := LevelManager.current_level
	ScoreManager.increment_attempts(lid)
	var result := check_completion()

	if result["passed"]:
		var score := calculate_score()
		LevelManager.complete_level(score)
	else:
		_show_feedback_box(page, result["details"])
		if ScoreManager.get_attempts(lid) >= 3:
			var existing := page.get_node_or_null("GiveUpBtn")
			if not existing:
				var gub := Button.new()
				gub.name = "GiveUpBtn"
				gub.text = "查看解答"
				gub.position = Vector2(340, 332)
				gub.size = Vector2(140, 32)
				gub.add_theme_font_size_override("font_size", 12)
				gub.add_theme_color_override("font_color", Color.WHITE)
				gub.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.5, 0.55), 6))
				gub.add_theme_stylebox_override("hover", _sb(Color(0.6, 0.6, 0.65), 6))
				gub.pressed.connect(func(): LevelManager.fail_level())
				page.add_child(gub)

# ============================================================
#  FEEDBACK BOXES
# ============================================================
func _show_feedback_box(parent: Panel, text: String) -> void:
	var old := parent.get_node_or_null("FeedbackBox")
	if old:
		old.queue_free()

	var box := Panel.new()
	box.name = "FeedbackBox"
	box.position = Vector2(10, 332)
	box.size = Vector2(470, 36)
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
	msg.size = Vector2(430, 24)
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
	box.position = Vector2(10, 332)
	box.size = Vector2(470, 36)
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
	msg.size = Vector2(430, 24)
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
