extends PanelContainer
## Dashboard KPI card with an animated count-up value

@onready var _title: Label = %Title
@onready var _value: Label = %Value

var _shown := 0

## 'color' defaults to the current palette
## Non-constant default arguments are evaluated at call time in GDScript, so the autoload is guaranteed to exist
func setup(title: String, cents: int, color := Themes.text) -> void:
	_title.text = title
	_value.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_method(func(v: int):
		_shown = v
		_value.text = Fmt.money(v), _shown, cents, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
