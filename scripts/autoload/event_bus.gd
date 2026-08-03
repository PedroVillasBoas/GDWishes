extends Node
## Autoload "EventBus" | Global signals decoupling core <-> UI.

signal project_opened
signal project_closed
signal data_changed(what: String)   # "transactions" | "categories" | "limits" | "wishes" | "recurring" | "settings"
signal period_changed
signal toast_requested(message: String, kind: String)  # kind: "info" | "success" | "error" | "undo"
signal navigate_requested(screen: String)   # Asks shell to switch screens

func notify(what: String) -> void:
	data_changed.emit(what)

func toast(message: String, kind := "info") -> void:
	toast_requested.emit(message, kind)
