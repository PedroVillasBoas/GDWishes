class_name ChartBase
extends Control
## Base for charts: margins, grid, intro animation and tooltip.

const MARGIN := Rect2(56, 16, -72, -44)  # Left / Top offsets and right / Bottom shrink

var anim := 0.0          # 0..1 - intro animation progress | not sure if this will stay like this
var _tooltip_text := ""
var _tooltip_pos := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(queue_redraw)
	Themes.theme_changed.connect(queue_redraw)
	play_intro()

func play_intro() -> void:
	anim = 0.0
	var tw := create_tween()
	tw.tween_method(func(v): anim = v; queue_redraw(), 0.0, 1.0, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Usable plotting rectangle
func plot_rect() -> Rect2:
	return Rect2(MARGIN.position, size + MARGIN.size)

func draw_grid_and_axis(max_value: float, steps := 4) -> void:
	var r := plot_rect()
	var font := get_theme_default_font()
	for i in steps + 1:
		var y := r.position.y + r.size.y * (1.0 - float(i) / steps)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Themes.border, 1)
		var value := int(max_value * float(i) / steps)
		draw_string(font, Vector2(4, y + 4), _short_money(value),
			HORIZONTAL_ALIGNMENT_LEFT, 52, 11, Themes.text_dim)

func _short_money(cents: int) -> String:   # 1_234_500 -> "12,3k"
	var reais := float(cents) / 100.0
	if absf(reais) >= 1000.0:
		return "%.1fk" % (reais / 1000.0)
	return "%d" % int(reais)

func set_tooltip_at(text: String, pos: Vector2) -> void:
	_tooltip_text = text
	_tooltip_pos = pos
	queue_redraw()

func draw_chart_tooltip() -> void:
	if _tooltip_text == "":
		return
	var font := get_theme_default_font()
	var text_size := font.get_string_size(_tooltip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var rect := Rect2(_tooltip_pos + Vector2(10, -28), text_size + Vector2(16, 12))
	rect.position.x = clampf(rect.position.x, 0, size.x - rect.size.x)
	draw_rect(rect, Themes.surface_hi, true)
	draw_rect(rect, Themes.border, false, 1)
	draw_string(font, rect.position + Vector2(8, text_size.y + 1), _tooltip_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Themes.text)
