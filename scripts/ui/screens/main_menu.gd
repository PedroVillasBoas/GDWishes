extends Control

@onready var _recent_list: VBoxContainer = $Center/Column/RecentList
@onready var _open_dialog: FileDialog = $OpenDialog
@onready var _new_dialog: ConfirmationDialog = $NewDialog
@onready var _name_edit: LineEdit = $NewDialog/Form/NameEdit
@onready var _month_edit: LineEdit = $NewDialog/Form/MonthEdit

func _ready() -> void:
	$Center/Column/NewButton.pressed.connect(_on_new_pressed)
	$Center/Column/OpenButton.pressed.connect(_open_dialog.popup_centered.bind(Vector2i(800, 500)))
	_open_dialog.file_selected.connect(_on_file_selected)
	_new_dialog.confirmed.connect(_on_new_confirmed)
	_fill_recents()
	
	# Logo entry animation
	var logo := $Center/Column/Logo
	logo.scale = Vector2(0.9, 0.9)
	logo.pivot_offset = logo.size / 2.0
	create_tween().tween_property(logo, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fill_recents() -> void:
	for child in _recent_list.get_children():
		child.queue_free()
	var recents := App.recent_files()
	$Center/Column/RecentTitle.visible = not recents.is_empty()
	for path in recents:
		var b := Button.new()
		b.text = "%s   —   %s" % [path.get_file().get_basename(), path.get_base_dir()]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = path
		b.pressed.connect(_on_file_selected.bind(path))
		_recent_list.add_child(b)

func _on_new_pressed() -> void:
	_name_edit.text = ""
	_month_edit.text = Fmt.current_month()
	_new_dialog.popup_centered(Vector2i(420, 260))
	_name_edit.grab_focus()

func _on_new_confirmed() -> void:
	var pname := _name_edit.text.strip_edges()
	var month := _month_edit.text.strip_edges()
	if pname.is_empty():
		EventBus.toast("Dê um nome ao projeto.", "error")
		return
	if not month.match("????-??"):
		EventBus.toast("Mês inicial deve ser AAAA-MM (ex.: 2026-04).", "error")
		return
	App.new_project(pname, month)

func _on_file_selected(path: String) -> void:
	var err := App.open_project(path)
	if err != "":
		EventBus.toast(err, "error")
		_fill_recents()
