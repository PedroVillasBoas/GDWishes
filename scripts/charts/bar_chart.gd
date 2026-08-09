class_name BarChart
extends ChartBase
## Points | [{"label": "Abr 26", "income": cents, "expense": cents}]

var points: Array[Dictionary] = []

func set_data(data: Array[Dictionary]) -> void:
	points = data
	play_intro()

func _draw() -> void:
	if points.is_empty():
		return
	var max_v := 1.0
	for pt in points:
		max_v = maxf(max_v, float(maxi(pt.income, pt.expense)))
	draw_grid_and_axis(max_v)
	var r := plot_rect()
	var group_w := r.size.x / points.size()
	var bar_w := minf(group_w * 0.32, 26.0)
	var font := get_theme_default_font()
	for i in points.size():
		var cx := r.position.x + group_w * (i + 0.5)
		for pair in [[points[i].income, Themes.income, -bar_w - 2],
				[points[i].expense, Themes.expense, 2]]:
			var h := r.size.y * float(pair[0]) / max_v * anim
			draw_rect(Rect2(cx + pair[2], r.end.y - h, bar_w, h), pair[1], true)
		draw_string(font, Vector2(cx - 24, size.y - 8), points[i].label,
			HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Themes.text_dim)
	draw_chart_tooltip()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not points.is_empty():
		var r := plot_rect()
		var idx := clampi(int((event.position.x - r.position.x) / (r.size.x / points.size())),
			0, points.size() - 1)
		set_tooltip_at("%s  +%s  -%s" % [points[idx].label,
			Fmt.money(points[idx].income), Fmt.money(points[idx].expense)], event.position)
