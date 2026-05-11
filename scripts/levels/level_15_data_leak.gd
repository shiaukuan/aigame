extends RefCounted

const LevelDataScript = preload("res://scripts/level_data.gd")

# Track which platforms have had their files removed / unshared
var _removed: Array[int] = []
var _giveup_visible := false

func get_level_data() -> Resource:
	var data := LevelDataScript.new()
	data.level_id = 15
	data.title = "曬在陽光下的秘密"
	data.category = "security"
	data.difficulty = 2
	data.puzzle_title = "曬在陽光下的秘密"
	data.scenario_text = "有人把公司的秘密文件曬在了陽光下——\n不是真的陽光，是比陽光更亮的地方：網際網路。\n任何人只要有那條連結，就能看到不該看的東西。"
	data.task_hint = "你的文件散落在不同的地方——有些是自家院子，有些是大馬路。\n分辨哪些圍牆裡面是安全的，哪些正被路人圍觀。\n找到那些暴露在外的東西，在更多人看到之前收回來。"
	data.teaching_points = PackedStringArray([
		"公司機敏資料嚴禁上傳至 Internet 公開分享平台（Google Drive、Dropbox、免費空間等）",
		"即使設定「僅限連結存取」，連結一旦外流仍無法控制存取範圍",
		"含個資之檔案上傳至境外雲端平台，可能違反個人資料保護法之跨境傳輸規定",
		"檔案分享應使用公司核准之內部平台（SharePoint、公司 FTP 等），並設定適當存取權限",
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
	var should_remove := [0, 1, 3]  # Google Drive, Dropbox, free file sharing
	var should_keep := [2, 4]       # SharePoint, internal FTP

	var removed_sorted := _removed.duplicate()
	removed_sorted.sort()

	var correct_removed := (removed_sorted == should_remove)

	# Check no company-approved ones were removed
	var wrongly_removed := false
	for idx in _removed:
		if idx in should_keep:
			wrongly_removed = true
			break

	var passed := correct_removed and not wrongly_removed
	var details := ""
	if wrongly_removed:
		details = "你移除了不該移除的檔案，請再確認哪些平台本來就是合理的檔案存放位置。"
	elif removed_sorted.size() < 3:
		details = "還有 %d 個檔案暴露在不該放置的地方尚未處理。" % (3 - removed_sorted.size())
	elif not correct_removed:
		details = "你處理的平台不完全正確，請再檢查一次。"

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
#  PLATFORM DATA
# ============================================================
func _get_platforms() -> Array:
	return [
		{
			"name": "Google Drive",
			"url": "drive.google.com/shared",
			"icon": "📁",
			"file_name": "年度營運計畫.pptx",
			"share_status": "公開連結 — 任何人皆可存取",
			"is_company": false,
			"desc": "雲端協作空間",
		},
		{
			"name": "Dropbox",
			"url": "dropbox.com/shared",
			"icon": "📦",
			"file_name": "員工通訊錄.xlsx",
			"share_status": "公開資料夾 — 所有人可見",
			"is_company": false,
			"desc": "雲端儲存服務",
		},
		{
			"name": "公司 SharePoint",
			"url": "cht.sharepoint.com",
			"icon": "🏢",
			"file_name": "部門週報.docx",
			"share_status": "僅限公司內部存取",
			"is_company": true,
			"desc": "企業協作平台",
		},
		{
			"name": "免費檔案分享網站",
			"url": "freeshare.io/public/12345",
			"icon": "🌐",
			"file_name": "系統架構圖.png",
			"share_status": "公開下載 — 無需登入即可下載",
			"is_company": false,
			"desc": "檔案分享服務",
		},
		{
			"name": "公司內部 FTP",
			"url": "ftp.cht.com.tw",
			"icon": "🖥️",
			"file_name": "教育訓練教材.pdf",
			"share_status": "僅限公司內網存取",
			"is_company": true,
			"desc": "FTP 檔案伺服器",
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

func _content_browser(p: Panel, desktop: Node) -> void:
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
	url.text = "edge://file-sharing"
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

	# Show platforms page
	_build_platforms_page(page)

func _build_platforms_page(page: Panel) -> void:
	for child in page.get_children():
		child.queue_free()

	# Page title
	var title := Label.new()
	title.text = "🔍  雲端分享平台檢查"
	title.position = Vector2(20, 6)
	title.size = Vector2(400, 28)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "以下是公司檔案目前存放的平台，請檢查並處理不該出現在這裡的檔案。"
	subtitle.position = Vector2(20, 32)
	subtitle.size = Vector2(600, 18)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	page.add_child(subtitle)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 54)
	scroll.size = Vector2(620, 268)
	page.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var platforms := _get_platforms()
	for i in platforms.size():
		var plat: Dictionary = platforms[i]
		var already_removed := i in _removed

		var row := Panel.new()
		row.custom_minimum_size = Vector2(604, 82)
		var row_sb := _sb(Color(1, 1, 1), 6)
		row_sb.border_color = Color(0.88, 0.88, 0.9)
		row_sb.border_width_bottom = 1
		row.add_theme_stylebox_override("panel", row_sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.add_child(row)

		# Icon
		var icon := Label.new()
		icon.text = plat["icon"]
		icon.position = Vector2(12, 12)
		icon.size = Vector2(30, 30)
		icon.add_theme_font_size_override("font_size", 20)
		row.add_child(icon)

		# Platform name
		var name_label := Label.new()
		name_label.text = plat["name"]
		name_label.position = Vector2(48, 4)
		name_label.size = Vector2(240, 20)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		row.add_child(name_label)

		# URL
		var url_label := Label.new()
		url_label.text = plat["url"]
		url_label.position = Vector2(48, 24)
		url_label.size = Vector2(240, 16)
		url_label.add_theme_font_size_override("font_size", 10)
		url_label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.7))
		row.add_child(url_label)

		# File name
		var file_label := Label.new()
		if already_removed:
			file_label.text = "（已移除）"
			file_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			file_label.text = "📄 " + plat["file_name"]
			file_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
		file_label.position = Vector2(300, 8)
		file_label.size = Vector2(240, 20)
		file_label.add_theme_font_size_override("font_size", 12)
		row.add_child(file_label)

		# Share status (neutral color — no red/green hint)
		var share_label := Label.new()
		share_label.text = plat["share_status"] if not already_removed else ""
		share_label.position = Vector2(300, 30)
		share_label.size = Vector2(240, 16)
		share_label.add_theme_font_size_override("font_size", 10)
		share_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		row.add_child(share_label)

		# Description
		var desc_label := Label.new()
		desc_label.text = plat["desc"]
		desc_label.position = Vector2(48, 62)
		desc_label.size = Vector2(300, 16)
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(desc_label)

		# Remove / unshare button (uniform styling — no visual hint)
		if not already_removed:
			var action_btn := Button.new()
			action_btn.text = "移除檔案"
			action_btn.position = Vector2(510, 28)
			action_btn.size = Vector2(90, 28)
			action_btn.add_theme_font_size_override("font_size", 11)
			action_btn.add_theme_color_override("font_color", Color.WHITE)
			action_btn.add_theme_stylebox_override("normal", _sb(Color(0.4, 0.45, 0.55), 6))
			action_btn.add_theme_stylebox_override("hover", _sb(Color(0.5, 0.55, 0.65), 6))
			var idx := i
			var page_ref := page
			action_btn.pressed.connect(func():
				_on_remove_file(page_ref, idx)
			)
			row.add_child(action_btn)

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

	# Re-create GiveUp button if it was previously shown
	if _giveup_visible:
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

func _on_remove_file(page: Panel, index: int) -> void:
	var platforms := _get_platforms()
	var plat: Dictionary = platforms[index]

	if plat["is_company"]:
		GameState.record_wrong_action("removed_company_platform_file", plat["name"])
		_show_feedback_box(page, "「%s」是公司核准的內部平台，上面的檔案不需要移除！" % plat["name"])
		return

	if index in _removed:
		return
	_removed.append(index)
	GameState.record_action("remove_shared_file", plat["name"] + " / " + plat["file_name"])
	_build_platforms_page(page)
	_show_feedback_box_success(page, "已從「%s」移除「%s」。" % [plat["name"], plat["file_name"]])

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
			_giveup_visible = true
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
	box.position = Vector2(10, 318)
	box.size = Vector2(470, 50)
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
	msg.position = Vector2(12, 4)
	msg.size = Vector2(430, 40)
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
	box.position = Vector2(10, 318)
	box.size = Vector2(470, 50)
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
	msg.position = Vector2(12, 4)
	msg.size = Vector2(430, 40)
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
