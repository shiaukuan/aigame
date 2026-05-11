extends RefCounted

## Builds a full-screen summary overlay with Excel-style score sheet.
## Call show(desktop) to display it.

func show(desktop: Control) -> void:
	var overlay := Panel.new()
	overlay.name = "SummaryOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 200
	overlay.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.75), 0))
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	desktop.add_child(overlay)

	var card := Panel.new()
	card.size = Vector2(660, 520)
	card.position = Vector2(310, 100)
	var card_sb := _sb(Color(1, 1, 1), 12)
	card_sb.shadow_color = Color(0, 0, 0, 0.35)
	card_sb.shadow_size = 20
	card.add_theme_stylebox_override("panel", card_sb)
	overlay.add_child(card)

	# Excel green toolbar
	var toolbar := Panel.new()
	toolbar.size = Vector2(660, 32)
	toolbar.add_theme_stylebox_override("panel", _sb(Color(0.13, 0.54, 0.33), 0))
	card.add_child(toolbar)
	var toolbar_title := Label.new()
	toolbar_title.text = "  📊  分數紀錄.xlsx — 遊戲結束"
	toolbar_title.position = Vector2(0, 5)
	toolbar_title.size = Vector2(400, 22)
	toolbar_title.add_theme_font_size_override("font_size", 13)
	toolbar_title.add_theme_color_override("font_color", Color.WHITE)
	toolbar.add_child(toolbar_title)

	# Column layout
	var col_x := [0, 36, 136, 340, 444, 550]
	var col_w := [36, 100, 204, 104, 106, 110]

	# Column headers (A-E)
	var col_letters := ["", "A", "B", "C", "D", "E"]
	var ch_row := Panel.new()
	ch_row.position = Vector2(0, 32)
	ch_row.size = Vector2(660, 20)
	ch_row.add_theme_stylebox_override("panel", _sb(Color(0.93, 0.93, 0.95), 0))
	card.add_child(ch_row)
	for i in col_letters.size():
		var ch := Label.new()
		ch.text = col_letters[i]
		ch.position = Vector2(col_x[i], 1)
		ch.size = Vector2(col_w[i], 18)
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch.add_theme_font_size_override("font_size", 10)
		ch.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		ch_row.add_child(ch)

	# Table header
	var table_headers := ["", "關卡", "標題", "分數", "嘗試次數", "狀態"]
	var hdr := Panel.new()
	hdr.position = Vector2(0, 52)
	hdr.size = Vector2(660, 24)
	hdr.add_theme_stylebox_override("panel", _sb(Color(0.22, 0.47, 0.22), 0))
	card.add_child(hdr)
	for i in table_headers.size():
		var hl := Label.new()
		hl.text = table_headers[i]
		hl.position = Vector2(col_x[i], 3)
		hl.size = Vector2(col_w[i], 18)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if i > 0 else HORIZONTAL_ALIGNMENT_RIGHT
		hl.add_theme_font_size_override("font_size", 11)
		hl.add_theme_color_override("font_color", Color.WHITE)
		hdr.add_child(hl)

	# Data rows
	var total_levels := LevelManager.level_scripts.size()
	var completed := 0
	var total_score := 0
	var row_y := 76
	var row_num := 2
	for lid in LevelManager.level_scripts:
		var handler = LevelManager.level_scripts[lid].new()
		var data = handler.get_level_data()
		var score := ScoreManager.get_score(lid)
		var att := ScoreManager.get_attempts(lid)
		total_score += score
		var status_text := ""
		if score > 0:
			completed += 1
			if score == 100:
				status_text = "★ 完美"
			elif score >= 60:
				status_text = "✓ 通過"
			else:
				status_text = "△ 查看解答"
		else:
			status_text = "— 未完成"

		var row_bg := Color(0.97, 0.97, 0.98) if lid % 2 == 0 else Color(1, 1, 1)
		var row := Panel.new()
		row.position = Vector2(0, row_y)
		row.size = Vector2(660, 20)
		row.add_theme_stylebox_override("panel", _sb(row_bg, 0))
		card.add_child(row)

		var rn := Label.new()
		rn.text = str(row_num)
		rn.position = Vector2(0, 1)
		rn.size = Vector2(36, 18)
		rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rn.add_theme_font_size_override("font_size", 10)
		rn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(rn)

		var cells := [str(lid), data.title, str(score) if score > 0 else "", str(att) if att > 0 else "", status_text]
		for ci in cells.size():
			var cell := Label.new()
			cell.text = cells[ci]
			cell.position = Vector2(col_x[ci + 1], 1)
			cell.size = Vector2(col_w[ci + 1], 18)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if ci != 1 else HORIZONTAL_ALIGNMENT_LEFT
			cell.add_theme_font_size_override("font_size", 11)
			var clr := Color(0.15, 0.15, 0.15)
			if ci == 4:
				if "完美" in cells[ci]:
					clr = Color(0.15, 0.55, 0.2)
				elif "通過" in cells[ci]:
					clr = Color(0.2, 0.45, 0.75)
				elif "解答" in cells[ci]:
					clr = Color(0.7, 0.5, 0.1)
				else:
					clr = Color(0.55, 0.55, 0.55)
			cell.add_theme_color_override("font_color", clr)
			row.add_child(cell)
		row_y += 20
		row_num += 1

	# Grid lines — vertical
	for i in range(1, col_x.size()):
		var vline := ColorRect.new()
		vline.position = Vector2(col_x[i], 52)
		vline.size = Vector2(1, row_y - 52)
		vline.color = Color(0.85, 0.85, 0.87)
		card.add_child(vline)

	# Summary row
	row_y += 4
	var summary := Panel.new()
	summary.position = Vector2(0, row_y)
	summary.size = Vector2(660, 28)
	summary.add_theme_stylebox_override("panel", _sb(Color(0.93, 0.96, 0.93), 0))
	card.add_child(summary)

	var sum_lbl := Label.new()
	sum_lbl.text = "合計"
	sum_lbl.position = Vector2(col_x[2], 5)
	sum_lbl.size = Vector2(col_w[2], 18)
	sum_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sum_lbl.add_theme_font_size_override("font_size", 12)
	sum_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	summary.add_child(sum_lbl)

	var sum_score := Label.new()
	sum_score.text = str(total_score) + " / " + str(total_levels * 100)
	sum_score.position = Vector2(col_x[3], 5)
	sum_score.size = Vector2(col_w[3], 18)
	sum_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_score.add_theme_font_size_override("font_size", 12)
	sum_score.add_theme_color_override("font_color", Color(0.13, 0.54, 0.33))
	summary.add_child(sum_score)

	var sum_status := Label.new()
	sum_status.text = "完成 %d / %d 關" % [completed, total_levels]
	sum_status.position = Vector2(col_x[5], 5)
	sum_status.size = Vector2(col_w[5], 18)
	sum_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_status.add_theme_font_size_override("font_size", 12)
	sum_status.add_theme_color_override("font_color", Color(0.2, 0.45, 0.75))
	summary.add_child(sum_status)

	# 「遊戲結束 確認重來」 button
	var restart_btn := Button.new()
	restart_btn.text = "遊戲結束　確認重來"
	restart_btn.position = Vector2(210, 472)
	restart_btn.size = Vector2(240, 38)
	restart_btn.add_theme_font_size_override("font_size", 15)
	restart_btn.add_theme_color_override("font_color", Color.WHITE)
	var rb_sb := _sb(Color(0.75, 0.22, 0.22), 8)
	rb_sb.shadow_color = Color(0.75, 0.22, 0.22, 0.3)
	rb_sb.shadow_size = 4
	restart_btn.add_theme_stylebox_override("normal", rb_sb)
	restart_btn.add_theme_stylebox_override("hover", _sb(Color(0.85, 0.3, 0.3), 8))
	restart_btn.pressed.connect(func():
		overlay.queue_free()
		GameState.reset()
		# 重置倒數計時器
		desktop._countdown_active = false
		var cdl := desktop.get_node_or_null("CountdownLabel")
		if cdl:
			cdl.visible = false
		desktop._start_countdown()
		if LevelManager.play_mode == "random":
			LevelManager.start_random_run()
		else:
			ScoreManager.reset_all()
			LevelManager.load_level(1)
	)
	card.add_child(restart_btn)

func _sb(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s
