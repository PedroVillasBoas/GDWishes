class_name ProgressRing
extends Control
## Progress ring drawn via _draw(), with an animated fill

@export var thickness := 8.0

## Colors are NOT @export defaults: those are evaluated before autoloads exist, so the palette is read in _ready() instead. TRANSPARENT means "unset"
var ring_color := Color.TRANSPARENT
var track_color := Color.TRANSPARENT

var _shown := 0.0    # displayed progress (animated)
var _target := 0.0

func _ready() -> void:
	_sync_palette()
	Themes.theme_changed.connect(func():
		ring_color = Color.TRANSPARENT
		track_color = Color.TRANSPARENT
		_sync_palette()
		queue_redraw())

func _sync_palette() -> void:
	if ring_color == Color.TRANSPARENT:
		ring_color = Themes.wish
	if track_color == Color.TRANSPARENT:
		track_color = Themes.border

func set_progress(ratio: float, animate := true) -> void:
	_target = clampf(ratio, 0.0, 1.0)
	if animate:
		var tw := create_tween()
		tw.tween_method(_set_shown, _shown, _target, 0.6)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_set_shown(_target)

func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - thickness
	draw_arc(center, radius, 0, TAU, 64, track_color, thickness, true)
	if _shown > 0.0:
		var from := -PI / 2.0
		var color := ring_color if _shown < 1.0 else Themes.income
		draw_arc(center, radius, from, from + TAU * _shown, 64, color, thickness, true)
	
	# Percentage in the middle
	var font := get_theme_default_font()
	var text := "%d%%" % int(round(_shown * 100))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, center - Vector2(text_size.x / 2.0, -text_size.y / 4.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Themes.text)
