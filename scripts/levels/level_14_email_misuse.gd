extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track which sites have had their email changed to personal
var _changed: Array[int] = []

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 14
	data.title = "門牌掛錯地方"
	data.category = "security"
	data.difficulty = 1
	data.puzzle_title = "門牌掛錯地方"
	data.scenario_text = "你的公司門牌被掛到了好幾個跟工作無關的地方。\n有些是辦公室大門，有些是自家後院，還有些是路邊攤。\n如果哪天這些地方失火了，火會順著門牌上的地址燒回公司。"
	data.task_hint = "你的身分印記散落在各種角落——有些是你自己留下的，有些是該留的。\n找到記錄這些足跡的地方，分辨哪些門牌該掛、哪些該摘下來換成自己的。"
	data.teaching_points = PackedStringArray([
		"公司電子信箱僅限公務使用，不得用於註冊非公務相關網站或服務",
		"使用公司信箱註冊外部服務，若該服務發生資料外洩，可能連帶影響公司資安",
		"離職後公司信箱將被停用，註冊在上面的個人服務也將無法登入",
		"個人事務請使用私人信箱，公私分明是基本資安素養",
	])
	data.desktop_config = {}
	return data

func setup_desktop(_desktop: Node) -> void:
	pass

func build_app_content(app_name: String, panel: Panel, desktop: Node) -> bool:
	if app_name == "Microsoft Edge":
		_content_browser(panel, desktop)
		return true
	return false

func check_completion() -> Dictionary:
	var should_change := [1, 3, 4]  # Shopee, Netflix, Forum
	var should_keep := [0, 2]       # Company portal, Microsoft 365

	var changed_sorted := _changed.duplicate()
	changed_sorted.sort()

	var correct_changed := (changed_sorted == should_change)

	# Check no business ones were changed
	var wrongly_changed := false
	for idx in _changed:
		if idx in should_keep:
			wrongly_changed = true
			break

	var passed := correct_changed and not wrongly_changed
	var details := ""
	if wrongly_changed:
		details = "你變更了公務系統的信箱設定！公務系統應使用公司信箱，請勿變更。"
	elif changed_sorted.size() < 3:
		details = "還有 %d 個非公務網站的信箱尚未改為私人信箱。" % (3 - changed_sorted.size())
	elif not correct_changed:
		details = "你變更的網站不完全正確，請再檢查一次。"

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
#  SITE DATA
# ============================================================
func _get_sites() -> Array:
	return [
		{
			"name": "公司內部系統",
			"url": "portal.cht.com.tw",
			"icon": "🏢",
			"email": "employee@cht.com.tw",
			"is_business": true,
			"desc": "公司內部入口網站，公務系統",
			"reason": "公務系統 — 應使用公司信箱登入",
		},
		{
			"name": "蝦皮購物",
			"url": "shopee.tw",
			"icon": "🛒",
			"email": "employee@cht.com.tw",
			"is_business": false,
			"desc": "個人購物網站",
			"reason": "非公務用途 — 個人購物網站不應使用公司信箱註冊",
		},
		{
			"name": "Microsoft 365",
			"url": "office.com",
			"icon": "📊",
			"email": "employee@cht.com.tw",
			"is_business": true,
			"desc": "公務辦公工具（Word、Excel、Outlook 等）",
			"reason": "公務工具 — 應使用公司信箱登入",
		},
		{
			"name": "Netflix",
			"url": "netflix.com",
			"icon": "🎬",
			"email": "employee@cht.com.tw",
			"is_business": false,
			"desc": "個人影音串流平台",
			"reason": "非公務用途 — 個人娛樂平台不應使用公司信箱註冊",
		},
		{
			"name": "巴哈姆特",
			"url": "forum.gamer.com.tw",
			"icon": "💬",
			"email": "employee@cht.com.tw",
			"is_business": false,
			"desc": "個人興趣論壇",
			"reason": "非公務用途 — 個人論壇不應使用公司信箱註冊",
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
	url.text = "edge://passwords"
	url.position = Vector2(78, 4)
	url.size = Vector2(556, 30)
	url.editable = false
	url.add_theme_font_size_override("font_size", 12)
	url_bar.add_child(url)

	# Page content
	var page := Panel.new()
	page.name = "BrowserPage"
	page.position = Vector2(0, 38)
	page.size = Vector2(640, 370)
	page.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1), 0))
	p.add_child(page)

	# Show accounts management page
	_build_accounts_page(page)

func _build_accounts_page(page: Panel) -> void:
	for child in page.get_children():
		child.queue_free()

	# Page title
	var title := Label.new()
	title.text = "🔑  已儲存的帳號"
	title.position = Vector2(20, 8)
	title.size = Vector2(400, 28)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "以下網站皆使用公司信箱（@cht.com.tw）登入"
	subtitle.position = Vector2(20, 34)
	subtitle.size = Vector2(600, 18)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	page.add_child(subtitle)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 56)
	scroll.size = Vector2(620, 264)
	page.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var sites := _get_sites()
	for i in sites.size():
		var site: Dictionary = sites[i]
		var row := Panel.new()
		row.custom_minimum_size = Vector2(604, 66)
		var row_sb := _sb(Color(1, 1, 1), 6)
		row_sb.border_color = Color(0.88, 0.88, 0.9)
		row_sb.border_width_bottom = 1
		row.add_theme_stylebox_override("panel", row_sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(row)

		# Icon
		var icon := Label.new()
		icon.text = site["icon"]
		icon.position = Vector2(12, 12)
		icon.size = Vector2(30, 30)
		icon.add_theme_font_size_override("font_size", 20)
		row.add_child(icon)

		# Name + URL
		var name_label := Label.new()
		name_label.text = site["name"]
		name_label.position = Vector2(48, 6)
		name_label.size = Vector2(200, 20)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		row.add_child(name_label)

		var url_label := Label.new()
		url_label.text = site["url"]
		url_label.position = Vector2(48, 28)
		url_label.size = Vector2(200, 16)
		url_label.add_theme_font_size_override("font_size", 10)
		url_label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.7))
		row.add_child(url_label)

		# Email display
		var email_label := Label.new()
		email_label.name = "EmailLabel_%d" % i
		var already_changed := i in _changed
		email_label.text = "myemail@gmail.com" if already_changed else site["email"]
		email_label.position = Vector2(260, 6)
		email_label.size = Vector2(200, 20)
		email_label.add_theme_font_size_override("font_size", 12)
		if already_changed:
			email_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.3))
		else:
			email_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
		row.add_child(email_label)

		# Description
		var desc_label := Label.new()
		desc_label.text = site["desc"]
		desc_label.position = Vector2(260, 28)
		desc_label.size = Vector2(200, 16)
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(desc_label)

		# Status badge (only shown after change)
		if already_changed:
			var badge := Panel.new()
			badge.position = Vector2(260, 46)
			badge.size = Vector2(72, 16)
			badge.add_theme_stylebox_override("panel", _sb(Color(0.2, 0.65, 0.35), 4))
			var badge_text := Label.new()
			badge_text.text = "已變更"
			badge_text.position = Vector2(2, 0)
			badge_text.size = Vector2(68, 16)
			badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_text.add_theme_font_size_override("font_size", 9)
			badge_text.add_theme_color_override("font_color", Color.WHITE)
			badge.add_child(badge_text)
			row.add_child(badge)

		# Change email button (only for sites not yet changed)
		if not already_changed:
			var change_btn := Button.new()
			change_btn.text = "變更信箱"
			change_btn.position = Vector2(500, 18)
			change_btn.size = Vector2(90, 28)
			change_btn.add_theme_font_size_override("font_size", 11)
			change_btn.add_theme_color_override("font_color", Color.WHITE)
			change_btn.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
			change_btn.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
			var idx := i
			var page_ref := page
			change_btn.pressed.connect(func():
				_on_change_email(page_ref, idx)
			)
			row.add_child(change_btn)

	# Finish button
	var finish := Button.new()
	finish.text = "📋 完成作答"
	finish.position = Vector2(490, 332)
	finish.size = Vector2(130, 32)
	finish.add_theme_font_size_override("font_size", 12)
	finish.add_theme_color_override("font_color", Color.WHITE)
	finish.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.5, 0.9), 6))
	finish.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.6, 1.0), 6))
	var page_ref_finish := page
	finish.pressed.connect(func(): _on_finish_pressed(page_ref_finish))
	page.add_child(finish)

func _on_change_email(page: Panel, index: int) -> void:
	if index in _changed:
		return
	var sites := _get_sites()
	var site: Dictionary = sites[index]

	if site["is_business"]:
		GameState.record_wrong_action("changed_business_email", site["name"])
		_show_feedback_box(page, "「%s」是公務系統，應使用公司信箱登入，不應變更！" % site["name"])
		return

	_changed.append(index)
	GameState.record_action("change_email", site["name"])
	_build_accounts_page(page)
	_show_feedback_box_success(page, "已將「%s」的登入信箱改為私人信箱。" % site["name"])

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
