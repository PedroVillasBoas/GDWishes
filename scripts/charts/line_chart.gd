class_name LineChart
extends ChartBase
## points: [{"label": "Abr 26", "value": cents}]

var points: Array[Dictionary] = []

func set_data(data: Array[Dictionary]) -> void:
	points = data
	play_intro()

func _draw() -> void:
	if points.size() < 2:
		return
	var max_v := 1.0
	var min_v := 0.0
	for pt in points:
		max_v = maxf(max_v, float(pt.value))
		min_v = minf(min_v, float(pt.value))
	draw_grid_and_axis(max_v)
	var r := plot_rect()
	var span := maxf(max_v - min_v, 1.0)
	var pos_list: PackedVector2Array = []
	var shown := int(ceil(points.size() * anim))
	for i in shown:
		var x := r.position.x + r.size.x * float(i) / (points.size() - 1)
		var y := r.end.y - r.size.y * (float(points[i].value) - min_v) / span
		pos_list.append(Vector2(x, y))
	
	# Area filled with a fake gradient (transparency)
	if pos_list.size() >= 2:
		var poly := pos_list.duplicate()
		poly.append(Vector2(pos_list[-1].x, r.end.y))
		poly.append(Vector2(pos_list[0].x, r.end.y))
		draw_colored_polygon(poly, Color(ThemeBuilder.ACCENT, 0.12))
		draw_polyline(pos_list, ThemeBuilder.ACCENT, 2.5, true)
	for pos in pos_list:
		draw_circle(pos, 3.5, ThemeBuilder.ACCENT)
	
	# X-axis labels (max. 8 to avoid clutter)
	var font := get_theme_default_font()
	var step := maxi(1, int(points.size() / 8.0))
	for i in range(0, points.size(), step):
		var x := r.position.x + r.size.x * float(i) / (points.size() - 1)
		draw_string(font, Vector2(x - 20, size.y - 8), points[i].label,
			HORIZONTAL_ALIGNMENT_CENTER, 48, 11, ThemeBuilder.TEXT_DIM)
	draw_chart_tooltip()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and points.size() >= 2:
		var r := plot_rect()
		var idx := int(round((event.position.x - r.position.x) / r.size.x * (points.size() - 1)))
		if idx >= 0 and idx < points.size():
			set_tooltip_at("%s: %s" % [points[idx].label, Fmt.money(points[idx].value)],
				event.position)
