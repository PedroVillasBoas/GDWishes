extends Control
## Project shell | navigation sidebar + header + screen host

const SCREENS := {
	"dashboard": {"title": "Dashboard", "scene": "res://scenes/ui/screens/dashboard.tscn"},
	"transactions": {"title": "Lançamentos", "scene": "res://scenes/ui/screens/transactions.tscn"},
	"wishes": {"title": "Wishes", "scene": "res://scenes/ui/screens/wishes.tscn"},
	"categories": {"title": "Categorias & Limites", "scene": "res://scenes/ui/screens/categories.tscn"},
	"recurring": {"title": "Recorrentes", "scene": "res://scenes/ui/screens/recurring.tscn"},
	"settings": {"title": "Configurações", "scene": "res://scenes/ui/screens/settings.tscn"},
}

## Screen key -> IconSet slot name
const NAV_ICONS := {
	"dashboard": "dashboard", "transactions": "transactions", "wishes": "wishes",
	"categories": "categories", "recurring": "recurring", "settings": "settings",
}

@onready var _host: MarginContainer = $Layout/Content/ScreenHost
@onready var _title: Label = $Layout/Content/Header/HeaderRow/ScreenTitle
@onready var _save_state: Label = $Layout/Sidebar/SideCol/SaveState
@onready var _save_dialog: FileDialog = $SaveDialog

var _nav_buttons := {}
var _current: Node = null

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	$Layout/Sidebar/SideCol/ProjectName.text = App.project.name
	_nav_buttons = {
		"dashboard": $Layout/Sidebar/SideCol/NavDashboard,
		"transactions": $Layout/Sidebar/SideCol/NavTransactions,
		"wishes": $Layout/Sidebar/SideCol/NavWishes,
		"categories": $Layout/Sidebar/SideCol/NavCategories,
		"recurring": $Layout/Sidebar/SideCol/NavRecurring,
		"settings": $Layout/Sidebar/SideCol/NavSettings,
	}
	for key in _nav_buttons:
		_nav_buttons[key].pressed.connect(show_screen.bind(key))
		Icons.decorate(_nav_buttons[key], NAV_ICONS[key], SCREENS[key].title)
		_nav_buttons[key].alignment = HORIZONTAL_ALIGNMENT_LEFT
	Icons.decorate($Layout/Sidebar/SideCol/SaveButton, "save", "Salvar   Ctrl+S")
	Icons.decorate($Layout/Sidebar/SideCol/CloseButton, "back", "Fechar projeto")
	$Layout/Sidebar/SideCol/SaveButton.pressed.connect(_save)
	$Layout/Sidebar/SideCol/CloseButton.pressed.connect(_close)
	_save_dialog.file_selected.connect(App.save_project_as)
	
	# Deferred | Screens request navigation from inside buttons that the switch destroys
	EventBus.navigate_requested.connect(show_screen, CONNECT_DEFERRED)
	EventBus.data_changed.connect(func(_w): _update_save_state())
	show_screen("dashboard")
	_update_save_state()

func show_screen(key: String) -> void:
	if not SCREENS.has(key):
		return
	if not ResourceLoader.exists(SCREENS[key].scene):
		EventBus.toast("Tela '%s' ainda não implementada." % SCREENS[key].title)
		return
	for k in _nav_buttons:
		_nav_buttons[k].set_pressed_no_signal(k == key)
	_title.text = SCREENS[key].title
	if is_instance_valid(_current):
		_host.remove_child(_current)
		_current.queue_free()
	_current = load(SCREENS[key].scene).instantiate()
	_current.modulate.a = 0.0
	_host.add_child(_current)
	create_tween().tween_property(_current, "modulate:a", 1.0, 0.15)

func _save() -> void:
	if App.project_path == "":
		_save_dialog.current_file = App.project.name.to_snake_case() + ".gdwish"
		_save_dialog.popup_centered(Vector2i(800, 500))
	else:
		App.save_project()
	_update_save_state()

func _close() -> void:
	if App.dirty and App.project_path != "":
		App.save_project()
	App.close_project()

func _update_save_state() -> void:
	if App.dirty:
		# Warn explicitly when autosave cannot rescue unsaved work
		var suffix := "" if App.app_settings.autosave_enabled else "  (autosave off)"
		_save_state.text = "● alterações não salvas" + suffix
		_save_state.modulate = Themes.warn
	else:
		_save_state.text = "salvo"
		_save_state.modulate = Themes.text_dim

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_S:
			_save()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6 and not event.ctrl_pressed:
			var keys := SCREENS.keys()
			show_screen(keys[event.keycode - KEY_1])
