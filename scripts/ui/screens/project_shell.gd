extends Control
## Project shell | collapsible navigation sidebar + header + screen host.

const SCREENS := {
	"dashboard": {"key": "nav.dashboard", "scene": "res://scenes/ui/screens/dashboard.tscn"},
	"transactions": {"key": "nav.transactions", "scene": "res://scenes/ui/screens/transactions.tscn"},
	"wishes": {"key": "nav.wishes", "scene": "res://scenes/ui/screens/wishes.tscn"},
	"categories": {"key": "nav.categories", "scene": "res://scenes/ui/screens/categories.tscn"},
	"recurring": {"key": "nav.recurring", "scene": "res://scenes/ui/screens/recurring.tscn"},
	"settings": {"key": "nav.settings", "scene": "res://scenes/ui/screens/settings.tscn"},
}

## Screen key -> IconSet slot name
const NAV_ICONS := {
	"dashboard": "dashboard", "transactions": "transactions", "wishes": "wishes",
	"categories": "categories", "recurring": "recurring", "settings": "settings",
}

const SIDEBAR_WIDTH_EXPANDED := 220
const SIDEBAR_WIDTH_COLLAPSED := 60

@onready var _sidebar: PanelContainer = %Sidebar
@onready var _project_name: Label = %ProjectName
@onready var _host: MarginContainer = %ScreenHost
@onready var _title: Label = %ScreenTitle
@onready var _save_state: Label = %SaveState
@onready var _save_dialog: FileDialog = %SaveDialog
@onready var _save_button: Button = %SaveButton
@onready var _close_button: Button = %CloseButton
@onready var _collapse_button: Button = %CollapseButton

var _nav_buttons := {}
var _current: Node = null
var _current_key := "dashboard"
var _collapsed := false

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	_project_name.text = App.project.name
	_nav_buttons = {
		"dashboard": %NavDashboard,
		"transactions": %NavTransactions,
		"wishes": %NavWishes,
		"categories": %NavCategories,
		"recurring": %NavRecurring,
		"settings": %NavSettings,
	}
	for key in _nav_buttons:
		_nav_buttons[key].pressed.connect(show_screen.bind(key))
		_nav_buttons[key].alignment = HORIZONTAL_ALIGNMENT_LEFT
	_save_button.pressed.connect(_save)
	_close_button.pressed.connect(_close)
	_collapse_button.pressed.connect(_toggle_sidebar)
	_save_dialog.file_selected.connect(App.save_project_as)

	# Deferred | Screens request navigation from inside buttons that the switch destroys
	EventBus.navigate_requested.connect(show_screen, CONNECT_DEFERRED)
	EventBus.data_changed.connect(func(_w): _update_save_state())
	Lang.language_changed.connect(_on_language_changed)

	_collapsed = bool(App.app_settings.get("sidebar_collapsed", false))
	_apply_sidebar_state(false)
	show_screen("dashboard")
	_update_save_state()

func _on_language_changed() -> void:
	_apply_sidebar_state(false)
	_title.text = Lang.t(SCREENS[_current_key].key)
	_update_save_state()

# --- Sidebar folding

func _toggle_sidebar() -> void:
	_collapsed = not _collapsed
	App.set_app_setting("sidebar_collapsed", _collapsed)
	_apply_sidebar_state(true)

## Collapsed keeps the icons and drops every label, so the nav stays usable at 60px.
func _apply_sidebar_state(animate: bool) -> void:
	for key in _nav_buttons:
		var b: Button = _nav_buttons[key]
		var label: String = "" if _collapsed else Lang.t(SCREENS[key].key)
		Icons.decorate(b, NAV_ICONS[key], label)
		b.text = label
		b.tooltip_text = Lang.t(SCREENS[key].key)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER if _collapsed else HORIZONTAL_ALIGNMENT_LEFT
	Icons.decorate(_save_button, "save", "" if _collapsed else Lang.t("nav.save_project"))
	_save_button.text = "" if _collapsed else Lang.t("nav.save_project")
	_save_button.tooltip_text = Lang.t("nav.save_project")
	Icons.decorate(_close_button, "back", "" if _collapsed else Lang.t("nav.close_project"))
	_close_button.text = "" if _collapsed else Lang.t("nav.close_project")
	_close_button.tooltip_text = Lang.t("nav.close_project")

	_collapse_button.icon = Icons.get_icon("chevron_right" if _collapsed else "chevron_left")
	_collapse_button.text = ""
	_collapse_button.tooltip_text = Lang.t("nav.expand") if _collapsed else Lang.t("nav.collapse")

	_project_name.visible = not _collapsed
	_save_state.visible = not _collapsed

	var target := SIDEBAR_WIDTH_COLLAPSED if _collapsed else SIDEBAR_WIDTH_EXPANDED
	if animate:
		create_tween().tween_property(_sidebar, "custom_minimum_size:x", float(target), 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_sidebar.custom_minimum_size.x = target

# --- Screens

func show_screen(key: String) -> void:
	if not SCREENS.has(key):
		return
	if not ResourceLoader.exists(SCREENS[key].scene):
		EventBus.toast("Screen '%s' not implemented yet." % Lang.t(SCREENS[key].key))
		return
	_current_key = key
	for k in _nav_buttons:
		_nav_buttons[k].set_pressed_no_signal(k == key)
	_title.text = Lang.t(SCREENS[key].key)
	if is_instance_valid(_current):
		_host.remove_child(_current)
		_current.queue_free()
	_current = load(SCREENS[key].scene).instantiate()
	_current.modulate.a = 0.0
	_host.add_child(_current)
	create_tween().tween_property(_current, "modulate:a", 1.0, 0.15)

func _save() -> void:
	if App.project_path == "":
		# No extension here: the native dialog appends the one from its filter.
		_save_dialog.current_file = App.suggested_file_name()
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
		var suffix: String = "" if App.app_settings.autosave_enabled else "  " + Lang.t("nav.autosave_off")
		_save_state.text = "● " + Lang.t("nav.unsaved") + suffix
		_save_state.modulate = Themes.warn
	else:
		_save_state.text = Lang.t("nav.saved")
		_save_state.modulate = Themes.text_dim

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_S:
			_save()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_B:
			_toggle_sidebar()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6 and not event.ctrl_pressed:
			var keys := SCREENS.keys()
			show_screen(keys[event.keycode - KEY_1])
