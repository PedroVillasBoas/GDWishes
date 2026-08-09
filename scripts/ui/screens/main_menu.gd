extends Control
## Main menu | Create a project (name -> month -> save location), open one, or pick from recents

@onready var _recent_list: VBoxContainer = $Center/Column/RecentList
@onready var _open_dialog: FileDialog = $OpenDialog
@onready var _save_dialog: FileDialog = $SaveDialog
@onready var _new_dialog: ConfirmationDialog = $NewDialog
@onready var _name_edit: LineEdit = $NewDialog/Form/NameEdit
@onready var _month_edit: LineEdit = $NewDialog/Form/MonthEdit

## Form data held between the New Project dialog and the Save dialog
var _pending_name := ""
var _pending_month := ""

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	$Center/Column/NewButton.pressed.connect(_on_new_pressed)
	$Center/Column/OpenButton.pressed.connect(
		_open_dialog.popup_centered.bind(Vector2i(800, 500)))
	_open_dialog.file_selected.connect(_on_file_selected)
	_save_dialog.file_selected.connect(_on_save_location_chosen)
	_new_dialog.confirmed.connect(_on_new_confirmed)
	_apply_icons()
	_fill_recents()
	
	# Logo intro animation
	var logo := $Center/Column/Logo
	logo.pivot_offset = logo.size / 2.0
	logo.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(logo, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _apply_icons() -> void:
	# Icons live in code, not in the .tscn, so swapping the icon set is a one-line change
	Icons.decorate($Center/Column/NewButton, "wishes", "Novo Projeto")
	Icons.decorate($Center/Column/OpenButton, "open", "Abrir…")

func _fill_recents() -> void:
	for child in _recent_list.get_children():
		child.queue_free()
	var recents := App.recent_files()
	$Center/Column/RecentTitle.visible = not recents.is_empty()
	for path in recents:
		var b := Button.new()
		b.text = "%s   —   %s" % [path.get_file().get_basename(), path.get_base_dir()]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = Icons.get_icon("save")
		b.tooltip_text = path
		b.pressed.connect(_on_file_selected.bind(path))
		_recent_list.add_child(b)

# --- New project | Form -> Save Location -> Create

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
	if not month.match("????-??") or not month.substr(0, 4).is_valid_int():
		EventBus.toast("Mês inicial deve ser AAAA-MM (ex.: 2026-04).", "error")
		return
	_pending_name = pname
	_pending_month = month
	
	# Ask where to save BEFORE creating anything, so the project exists on disk from the very first frame and autosave has a path to write to
	_save_dialog.current_file = pname.to_snake_case() + ".gdwish"
	_save_dialog.popup_centered(Vector2i(800, 500))

func _on_save_location_chosen(path: String) -> void:
	var err := App.new_project(_pending_name, _pending_month, path)
	if err != "":
		EventBus.toast(err, "error")

func _on_file_selected(path: String) -> void:
	var err := App.open_project(path)
	if err != "":
		EventBus.toast(err, "error")
		_fill_recents()   # A dead entry was just pruned | Refresh the list
