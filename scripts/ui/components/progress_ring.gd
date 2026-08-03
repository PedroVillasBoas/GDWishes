class_name ProgressRing
extends Control
## Progress ring drawn via _draw(), with animation

@export var thickness := 8.0
@export var ring_color := ThemeBuilder.WISH
@export var track_color := ThemeBuilder.BORDER

var _shown := 0.0    # Displayed progress (animated)
var _target := 0.0

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
		var color := ring_color if _shown < 1.0 else ThemeBuilder.INCOME
		draw_arc(center, radius, from, from + TAU * _shown, 64, color, thickness, true)
	
	# Center percent
	var font := get_theme_default_font()
	var text := "%d%%" % int(round(_shown * 100))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, center - Vector2(text_size.x / 2.0, -text_size.y / 4.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 16, ThemeBuilder.TEXT)
