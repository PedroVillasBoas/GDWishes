class_name DonutChart
extends ChartBase
## Slices: [{"label": String, "value": cents, "color": Color}]

signal slice_clicked(label: String)

var slices: Array[Dictionary] = []
var _hover := -1

func set_data(data: Array[Dictionary]) -> void:
	slices = data
	slices.sort_custom(func(a, b): return a.value > b.value)
	play_intro()

func _total() -> int:
	var t := 0
	for s in slices: t += s.value
	return maxi(t, 1)

func _draw() -> void:
	if slices.is_empty():
		return
	var center := Vector2(size.y / 2.0 + 8, size.y / 2.0)
	var radius := size.y / 2.0 - 20
	var thickness := radius * 0.42
	var start := -PI / 2.0
	var total := _total()
	var font := get_theme_default_font()
	for i in slices.size():
		var sweep := TAU * float(slices[i].value) / total * anim
		var col: Color = slices[i].color
		if i == _hover:
			col = col.lightened(0.2)
		draw_arc(center, radius - thickness / 2.0, start, start + sweep, 48, col, thickness, true)
		start += sweep
	
	# Total in the center
	var text := Fmt.money(total)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	draw_string(font, center - Vector2(ts.x / 2.0, -4), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 15, ThemeBuilder.TEXT)
	
	# Legend on the right
	var ly := 20.0
	for i in mini(slices.size(), 8):
		var lx := size.y + 24
		draw_rect(Rect2(lx, ly - 9, 12, 12), slices[i].color, true)
		draw_string(font, Vector2(lx + 18, ly + 2), "%s — %s" % [slices[i].label,
			Fmt.money(slices[i].value)], HORIZONTAL_ALIGNMENT_LEFT, size.x - lx - 24, 13,
			ThemeBuilder.TEXT if i != _hover else Color.WHITE)
		ly += 22
	draw_chart_tooltip()

func _slice_at(pos: Vector2) -> int:
	var center := Vector2(size.y / 2.0 + 8, size.y / 2.0)
	var radius := size.y / 2.0 - 20
	var d := pos.distance_to(center)
	if d > radius or d < radius * 0.58:
		return -1
	var angle := fposmod((pos - center).angle() + PI / 2.0, TAU)
	var start := 0.0
	var total := _total()
	for i in slices.size():
		var sweep := TAU * float(slices[i].value) / total
		if angle >= start and angle < start + sweep:
			return i
		start += sweep
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var idx := _slice_at(event.position)
		if idx != _hover:
			_hover = idx
			queue_redraw()
		if idx >= 0:
			set_tooltip_at("%s: %s (%s)" % [slices[idx].label, Fmt.money(slices[idx].value),
				Fmt.pct(float(slices[idx].value) / _total())], event.position)
		else:
			set_tooltip_at("", event.position)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _slice_at(event.position)
		if idx >= 0:
			slice_clicked.emit(slices[idx].label)
