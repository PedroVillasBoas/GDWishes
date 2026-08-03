extends Control
## Application shell | screen switching + toasts + exit confirmation

const SCREEN_MENU := "res://scenes/ui/screens/main_menu.tscn"
const SCREEN_SHELL := "res://scenes/ui/screens/project_shell.tscn"

@onready var _host: MarginContainer = $ScreenHost
@onready var _toasts: VBoxContainer = $ToastLayer

var _current: Node = null

func _ready() -> void:
	theme = ThemeBuilder.build()
	get_tree().auto_accept_quit = false
	# CONNECT_DEFERRED is mandatory
	# These signals are emitted in the MIDDLE of the emission of "confirmed"/"file_selected" from dialogs that are children of the screen being destroyed. 
	# Without deferred, the MainMenu is destroyed while still executing its own code and remains visible in the background.
	EventBus.project_opened.connect(_go.bind(SCREEN_SHELL), CONNECT_DEFERRED)
	EventBus.project_closed.connect(_go.bind(SCREEN_MENU), CONNECT_DEFERRED)
	EventBus.toast_requested.connect(_show_toast)
	_go(SCREEN_MENU)

func _go(scene_path: String) -> void:
	if is_instance_valid(_current):
		_host.remove_child(_current)   # get off the tree RIGHT NOW (disappear from the screen in this frame) and is safely released at the end of the frame
		_current.queue_free()
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
			App.save_project() # silently saves upon closing
		get_tree().quit()
