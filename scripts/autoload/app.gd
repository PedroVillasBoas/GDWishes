extends Node
## Autoload "App" — open project, dirty flag, autosave, recent files, global period,
## and application-level settings (theme / font / autosave).

const RECENT_PATH := "user://recent.json"
const APP_SETTINGS_PATH := "user://app_settings.json"

const PROJECT_EXTENSION := "gdwish"

const DEFAULT_APP_SETTINGS := {
	"theme": "dark_fintech",       # GDTheme.id
	"font_index": -1,              # -1 = use the font declared inside the theme
	"language": "en",              # Lang id
	"date_format": "MM-DD-YYYY",   # DD-MM-YYYY | MM-DD-YYYY | YYYY-MM-DD
	"autosave_enabled": true,
	"autosave_interval": 30.0,     # seconds
	"sidebar_collapsed": false,    # navigation sidebar folded to icons only
}

var project: FinanceProject = null
var project_path: String = ""
var dirty: bool = false

## Application-level settings (NOT part of the .gdwish file — they follow the app, not the project). Persisted in user://app_settings.json.
var app_settings: Dictionary = DEFAULT_APP_SETTINGS.duplicate()

## Global filter period: mode = "month" | "quarter" | "year" | "range" | "all"
var period := {"mode": "month", "from": "", "to": ""}

var _autosave_timer: Timer

func _ready() -> void:
	_load_app_settings()
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(save_project)
	add_child(_autosave_timer)
	var now := Fmt.current_month()
	period.from = now
	period.to = now

func has_project() -> bool:
	return project != null

# --- Project Lifecycle

## Collapses any stack of trailing extensions down to a single ".gdwish".
##
## A native Save dialog appends the extension declared by its filter, so a
## `current_file` that already carries one comes back doubled — and a naive
## `if not ends_with(): path += ext` then adds a third. Rebuilding the name from
## its stem is immune to however many the dialog piles on.
static func normalize_project_path(path: String) -> String:
	var dir := path.get_base_dir()
	var stem := path.get_file()
	while true:
		var ext := stem.get_extension()
		if ext == "":
			break
		# Only strip extensions that belong to us; a project legitimately named
		# "budget.2026" must keep its ".2026".
		if ext.to_lower() != PROJECT_EXTENSION and not ext.to_lower().begins_with(PROJECT_EXTENSION):
			break
		stem = stem.get_basename()
	if stem.is_empty():
		stem = "project"
	var file_name := "%s.%s" % [stem, PROJECT_EXTENSION]
	return file_name if dir.is_empty() else dir.path_join(file_name)

## Creates a project AND writes it to disk immediately. `path` comes from the
## Save dialog shown right after the New Project form is confirmed.
## Returns "" on success, or an error message.
func new_project(pname: String, start_month: String, path: String) -> String:
	path = normalize_project_path(path)
	var fresh := FinanceProject.new()
	fresh.name = pname
	fresh.created_at = Time.get_datetime_string_from_system()
	fresh.start_month = start_month
	_add_default_categories(fresh)
	
	# Write BEFORE swapping state | 
	# if the disk write fails (read-only folder, bad path), the app keeps whatever was open instead of losing it
	var err := ProjectIO.save(fresh, path)
	if err != "":
		return err
	project = fresh
	project_path = path
	dirty = false
	_push_recent(path)
	period.mode = "month"
	period.from = start_month
	period.to = start_month
	EventBus.project_opened.emit()
	return ""

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
		return
	var err := ProjectIO.save(project, project_path)
	if err != "":
		EventBus.toast(err, "error")
		return
	dirty = false
	_push_recent(project_path)
	EventBus.notify("saved")

func save_project_as(path: String) -> void:
	project_path = normalize_project_path(path)
	save_project()

func close_project() -> void:
	project = null
	project_path = ""
	dirty = false
	EventBus.project_closed.emit()

## Call after ANY data change | Marks dirty, schedules autosave, notifies the UI
func touch(what: String) -> void:
	dirty = true
	_schedule_autosave()
	EventBus.notify(what)

func _schedule_autosave() -> void:
	if project_path == "" or not app_settings.autosave_enabled:
		return
	_autosave_timer.start(float(app_settings.autosave_interval))

# --- Application Settings

func set_app_setting(key: String, value) -> void:
	app_settings[key] = value
	_save_app_settings()
	
	# An interval change must affect the timer already counting down, otherwise the new value only takes effect after the next unrelated edit
	if key in ["autosave_interval", "autosave_enabled"]:
		if not app_settings.autosave_enabled:
			_autosave_timer.stop()
		elif dirty:
			_schedule_autosave()

## File name to preload into a Save dialog. Deliberately WITHOUT the extension:
## the native dialog appends the one from its filter, and passing it here is what
## produced the doubled-extension file names.
func suggested_file_name() -> String:
	if project == null or project.name.strip_edges().is_empty():
		return "project"
	return project.name.to_snake_case()

func _load_app_settings() -> void:
	app_settings = DEFAULT_APP_SETTINGS.duplicate()
	if not FileAccess.file_exists(APP_SETTINGS_PATH):
		return
	var f := FileAccess.open(APP_SETTINGS_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		for key in DEFAULT_APP_SETTINGS:   # Ignore unknown / Removed keys
			if data.has(key):
				app_settings[key] = data[key]

func _save_app_settings() -> void:
	var f := FileAccess.open(APP_SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(app_settings, "\t"))
	f.close()

# --- Global Period

func set_period(mode: String, from_key: String, to_key: String) -> void:
	period.mode = mode
	period.from = from_key
	period.to = to_key
	EventBus.period_changed.emit()

## Months in the current period ("all": from start_month to the latest month used)
func period_months() -> Array[String]:
	if period.mode == "all":
		var first: String = project.start_month if project else Fmt.current_month()
		var last := Fmt.current_month()
		for t in (project.transactions if project else []):
			if t.month > last:
				last = t.month
		return Fmt.months_between(first, last)
	return Fmt.months_between(period.from, period.to)

# --- Recent Files

func recent_files() -> Array:
	if not FileAccess.file_exists(RECENT_PATH):
		return []
	var f := FileAccess.open(RECENT_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Array):
		return []
	
	# Drop entries whose file was moved or deleted outside the app
	var alive := []
	for path in data:
		if path is String and FileAccess.file_exists(path):
			alive.append(path)
	return alive

func _push_recent(path: String) -> void:
	var list := recent_files()
	list.erase(path)
	list.push_front(path)
	if list.size() > 6:
		list.resize(6)
	var f := FileAccess.open(RECENT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(list))
	f.close()

# --- Default Categories for a new project

func _add_default_categories(target: FinanceProject) -> void:
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
		target.categories.append(c)
