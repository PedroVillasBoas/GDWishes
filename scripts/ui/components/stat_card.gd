extends PanelContainer

var _shown := 0

func setup(title: String, cents: int, color := ThemeBuilder.TEXT) -> void:
	$Col/Title.text = title
	$Col/Value.add_theme_color_override("font_color", color)
	
	# Count animation
	var tw := create_tween()
	tw.tween_method(func(v: int):
		_shown = v
		$Col/Value.text = Fmt.money(v), _shown, cents, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
