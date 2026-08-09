extends ScrollContainer
## Settings screen | application preferences (theme / font / autosave), per-project variables, and the Google Sheet CSV importer

@onready var _theme_select: OptionButton = %ThemeSelect
@onready var _font_select: OptionButton = %FontSelect
@onready var _autosave_check: CheckButton = %AutosaveCheck
@onready var _autosave_spin: SpinBox = %AutosaveSpin
@onready var _name_edit: LineEdit = %NameEdit
@onready var _rate_edit: LineEdit = %RateEdit
@onready var _salary_usd: LineEdit = %SalaryUsdEdit
@onready var _salary_brl: LineEdit = %SalaryBrlEdit
@onready var _hours_spin: SpinBox = %HoursSpin
@onready var _apply_button: Button = %ApplyButton
@onready var _import_button: Button = %ImportButton
@onready var _import_dialog: FileDialog = $Col/ImportDialog

func _ready() -> void:
	# A FileDialog left visible in the editor opens the moment this screen loads —
	# that was the "Settings instantly opens the file system" bug.
	UiUtils.hide_dialogs(self)
	_fill_app_settings()
	_fill_project_settings()
	Icons.decorate(_apply_button, "save", "Aplicar")
	Icons.decorate(_import_button, "open", "Importar pasta de CSVs…")
	_apply_button.pressed.connect(_apply_project_settings)
	_import_button.pressed.connect(
		_import_dialog.popup_centered.bind(Vector2i(800, 500)))
	_import_dialog.dir_selected.connect(_import_folder)

# --- Application Settings

func _fill_app_settings() -> void:
	# Both lists come from the ThemeRegistry resource 
	# Adding a theme or a font there is enough to make it selectable here, with no code change
	_theme_select.clear()
	for entry in Themes.available_themes():
		if entry == null:
			continue
		_theme_select.add_item(entry.display_name if entry.display_name != "" else String(entry.id))
		_theme_select.set_item_metadata(_theme_select.item_count - 1, entry.id)
		if entry.id == Themes.current_theme_id:
			_theme_select.selected = _theme_select.item_count - 1

	_font_select.clear()
	for entry in Themes.available_fonts():
		_font_select.add_item(entry.name)
		_font_select.set_item_metadata(_font_select.item_count - 1, entry.index)
		if entry.index == Themes.current_font_index:
			_font_select.selected = _font_select.item_count - 1

	_autosave_check.button_pressed = App.app_settings.autosave_enabled
	_autosave_spin.value = float(App.app_settings.autosave_interval)
	_autosave_spin.editable = _autosave_check.button_pressed

	_theme_select.item_selected.connect(_on_theme_selected)
	_font_select.item_selected.connect(_on_font_selected)
	_autosave_check.toggled.connect(_on_autosave_toggled)
	_autosave_spin.value_changed.connect(_on_autosave_interval_changed)

func _on_theme_selected(index: int) -> void:
	Themes.set_theme_id(_theme_select.get_item_metadata(index))
	EventBus.toast("Tema aplicado.", "success")

func _on_font_selected(index: int) -> void:
	Themes.set_font_index(int(_font_select.get_item_metadata(index)))
	EventBus.toast("Fonte aplicada.", "success")

func _on_autosave_toggled(enabled: bool) -> void:
	App.set_app_setting("autosave_enabled", enabled)
	_autosave_spin.editable = enabled

func _on_autosave_interval_changed(value: float) -> void:
	App.set_app_setting("autosave_interval", value)

# --- Project Settings

func _fill_project_settings() -> void:
	var p := App.project
	_name_edit.text = p.name
	_rate_edit.text = Fmt.rate(p.rate_usd_brl)
	_salary_usd.text = Fmt.money(p.base_salary_usd_cents, "")
	_salary_brl.text = Fmt.money(p.base_salary_brl_cents, "")
	_hours_spin.value = p.hours_per_day

func _apply_project_settings() -> void:
	var p := App.project
	var new_name := _name_edit.text.strip_edges()
	if new_name.is_empty():
		EventBus.toast("O projeto precisa de um nome.", "error")
		return
	p.name = new_name
	p.rate_usd_brl = Money.parse_rate(_rate_edit.text)
	p.base_salary_usd_cents = Money.parse_brl(_salary_usd.text)
	p.base_salary_brl_cents = Money.parse_brl(_salary_brl.text)
	p.hours_per_day = int(_hours_spin.value)
	App.touch("settings")
	EventBus.toast("Configurações aplicadas.", "success")

# --- CSV Import | This will change later

func _import_folder(folder: String) -> void:
	var result := SheetImporter.import_folder(App.project, folder)
	if not result.ok:
		EventBus.toast(result.error, "error")
		return
	App.touch("transactions")
	App.touch("categories")
	EventBus.toast(result.report.strip_edges(), "success")
