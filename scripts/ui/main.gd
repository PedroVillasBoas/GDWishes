extends Control
## Application shell | screen switching, toasts, quit handling

const SCREEN_MENU := "res://scenes/ui/screens/main_menu.tscn"
const SCREEN_SHELL := "res://scenes/ui/screens/project_shell.tscn"

@onready var _host: MarginContainer = $ScreenHost
@onready var _toasts: VBoxContainer = $ToastLayer
@onready var _background: ColorRect = $Background

var _current: Node = null

func _ready() -> void:
	get_tree().auto_accept_quit = false
	
	# The theme is applied window-wide by the Themes autoload
	# Here we only follow the palette for the one thing that is not themed: the raw background rect
	Themes.theme_changed.connect(_sync_background)
	_sync_background()
	
	# CONNECT_DEFERRED is required: these signals fire in the middle of a dialog's
	# "confirmed"/"file_selected" emission, and that dialog is a CHILD of the screen
	# about to be destroyed. Without it the old screen stays visible in the back
	EventBus.project_opened.connect(_go.bind(SCREEN_SHELL), CONNECT_DEFERRED)
	EventBus.project_closed.connect(_go.bind(SCREEN_MENU), CONNECT_DEFERRED)
	EventBus.toast_requested.connect(_show_toast)
	_go(SCREEN_MENU)

func _sync_background() -> void:
	_background.color = Themes.bg

func _go(scene_path: String) -> void:
	if is_instance_valid(_current):
		_host.remove_child(_current)   # Leaves the tree NOW (gone this frame)…
		_current.queue_free()          # …and is freed safely at the end of the frame
	_current = load(scene_path).instantiate()
	_current.modulate.a = 0.0
	_host.add_child(_current)
	create_tween().tween_property(_current, "modulate:a", 1.0, 0.15)

func _show_toast(message: String, kind: String) -> void:
	var toast := preload("res://scenes/ui/components/toast.tscn").instantiate()
	_toasts.add_child(toast)
	toast.setup(message, kind)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if App.has_project() and App.dirty and App.project_path != "":
			App.save_project()   # Silent save on close
		get_tree().quit()
