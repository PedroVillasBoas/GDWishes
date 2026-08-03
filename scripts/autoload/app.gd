extends Node
## Autoload "App" | open project, dirty flag, autosave, recent, global period

const RECENT_PATH := "user://recent.json"
const AUTOSAVE_DELAY := 30.0

var project: FinanceProject = null
var project_path: String = ""
var dirty: bool = false

## Global period filter: mode = "month" | "quarter" | "year" | "range" | "all"
var period := {"mode": "month", "from": "", "to": ""}

var _autosave_timer: Timer

func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(save_project)
	add_child(_autosave_timer)
	var now := Fmt.current_month()
	period.from = now
	period.to = now

func has_project() -> bool:
	return project != null

# --- Project life cycle

func new_project(pname: String, start_month: String) -> void:
	project = FinanceProject.new()
	project.name = pname
	project.created_at = Time.get_datetime_string_from_system()
	project.start_month = start_month
	_add_default_categories()
	project_path = ""   # No save file yet | 1st save prompts for location
	dirty = true
	period.mode = "month"
	period.from = start_month
	period.to = start_month
	EventBus.project_opened.emit()

func open_project(path: String) -> String:
	var result := ProjectIO.load_file(path)
	if result.has("error"):
		return result.error
	project = result.project
	project_path = path
	dirty = false
	_push_recent(path)
	var now := Fmt.current_month()
	period.mode = "month"
	period.from = now
	period.to = now
	EventBus.project_opened.emit()
	return ""

func save_project() -> void:
	if project == null or project_path == "":
		return  # No path yet | the UI calls save_project_as()
	var err := ProjectIO.save(project, project_path)
	if err != "":
		EventBus.toast(err, "error")
		return
	dirty = false
	_push_recent(project_path)
	EventBus.notify("saved")

func save_project_as(path: String) -> void:
	if not path.ends_with(".gdwish"):
		path += ".gdwish"
	project_path = path
	save_project()

func close_project() -> void:
	project = null
	project_path = ""
	dirty = false
	EventBus.project_closed.emit()

## Call after ANY data change | Mark as dirty + schedule autosave + notify UI
func touch(what: String) -> void:
	dirty = true
	if project_path != "":
		_autosave_timer.start(AUTOSAVE_DELAY)
	EventBus.notify(what)

# --- Global period

func set_period(mode: String, from_key: String, to_key: String) -> void:
	period.mode = mode
	period.from = from_key
	period.to = to_key
	EventBus.period_changed.emit()

## Meses do período atual (para "all": do start_month até o mês atual/último lançamento).
func period_months() -> Array[String]:
	if period.mode == "all":
		var first: String = project.start_month if project else Fmt.current_month()
		var last := Fmt.current_month()
		for t in (project.transactions if project else []):
			if t.month > last:
				last = t.month
		return Fmt.months_between(first, last)
	return Fmt.months_between(period.from, period.to)

# --- Recents

func recent_files() -> Array:
	if not FileAccess.file_exists(RECENT_PATH):
		return []
	var f := FileAccess.open(RECENT_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if data is Array else []

func _push_recent(path: String) -> void:
	var list := recent_files()
	list.erase(path)
	list.push_front(path)
	if list.size() > 6:
		list.resize(6)
	var f := FileAccess.open(RECENT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(list))
	f.close()

# --- New design pattern categories

func _add_default_categories() -> void:
	var defaults := [
		["Salário", "income", "#3FB950"], ["Freelance", "income", "#2EA8E8"],
		["Saldo Inicial", "income", "#8B949E"],
		["Alimentação", "expense", "#E8A33D"], ["Transporte", "expense", "#2EA8E8"],
		["Assinaturas", "expense", "#7C6FF0"], ["Lazer", "expense", "#D65CC0"],
		["Misc", "expense", "#8B949E"],
	]
	for row in defaults:
		var c := Category.new()
		c.id = FinanceProject.new_id()
		c.name = row[0]
		c.type = row[1]
		c.color = row[2]
		project.categories.append(c)
