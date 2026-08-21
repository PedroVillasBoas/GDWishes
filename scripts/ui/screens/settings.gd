extends TabContainer
## Settings screen | grouped into tabs:
##   Appearance  — theme, font
##   Preferences — language, date format, autosave
##   Project     — per-project variables
##
## Tab titles are set from code because TabContainer otherwise shows raw node names,
## which cannot be translated.

const TAB_KEYS := ["set.tab_appearance", "set.tab_preferences", "set.tab_project"]

@onready var _theme_label: Label = %LTheme
@onready var _font_label: Label = %LFont
@onready var _language_label: Label = %LLanguage
@onready var _date_label: Label = %LDateFormat
@onready var _autosave_label: Label = %LAutosave
@onready var _interval_label: Label = %LInterval
@onready var _theme_select: OptionButton = %ThemeSelect
@onready var _font_select: OptionButton = %FontSelect
@onready var _language_select: OptionButton = %LanguageSelect
@onready var _date_select: OptionButton = %DateFormatSelect
@onready var _autosave_check: CheckButton = %AutosaveCheck
@onready var _autosave_spin: SpinBox = %AutosaveSpin
@onready var _name_label: Label = %L1
@onready var _rate_label: Label = %L2
@onready var _salary_usd_label: Label = %L3
@onready var _salary_brl_label: Label = %L4
@onready var _hours_label: Label = %L5
@onready var _name_edit: LineEdit = %NameEdit
@onready var _rate_edit: LineEdit = %RateEdit
@onready var _salary_usd: LineEdit = %SalaryUsdEdit
@onready var _salary_brl: LineEdit = %SalaryBrlEdit
@onready var _hours_spin: SpinBox = %HoursSpin
@onready var _apply_button: Button = %ApplyButton

func _ready() -> void:
	# A FileDialog left visible in the editor opens the moment this screen loads —
	# that was the "Settings instantly opens the file system" bug.
	UiUtils.hide_dialogs(self)
	_apply_language()
	_fill_app_settings()
	_fill_project_settings()
	_apply_button.pressed.connect(_apply_project_settings)
	Lang.language_changed.connect(_on_language_changed)

func _apply_language() -> void:
	for i in mini(TAB_KEYS.size(), get_tab_count()):
		set_tab_title(i, Lang.t(TAB_KEYS[i]))
	_theme_label.text = Lang.t("set.theme")
	_font_label.text = Lang.t("set.font")
	_language_label.text = Lang.t("set.language")
	_date_label.text = Lang.t("set.date_format")
	_autosave_label.text = Lang.t("set.autosave")
	_interval_label.text = Lang.t("set.autosave_interval")
	_name_label.text = Lang.t("set.project_name")
	_rate_label.text = Lang.t("set.rate")
	_salary_usd_label.text = Lang.t("set.salary_usd")
	_salary_brl_label.text = Lang.t("set.salary_brl")
	_hours_label.text = Lang.t("set.hours")
	Icons.decorate(_apply_button, "save", Lang.t("generic.apply"))

## The language switch rebuilds this screen too, otherwise the settings page would
## be the only one still showing the previous language.
func _on_language_changed() -> void:
	_apply_language()
	var font_index := _font_select.selected
	_font_select.set_item_text(0, Lang.t("set.theme_default_font"))
	_font_select.selected = font_index

# --- Appearance + Preferences

func _fill_app_settings() -> void:
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

	_language_select.clear()
	for entry in Lang.LANGUAGES:
		_language_select.add_item(entry.name)
		_language_select.set_item_metadata(_language_select.item_count - 1, entry.id)
		if entry.id == Lang.current:
			_language_select.selected = _language_select.item_count - 1

	_date_select.clear()
	for fmt in DateMask.available_formats():
		_date_select.add_item(fmt)
		_date_select.set_item_metadata(_date_select.item_count - 1, fmt)
		if fmt == DateMask.current_format():
			_date_select.selected = _date_select.item_count - 1

	_autosave_check.button_pressed = App.app_settings.autosave_enabled
	_autosave_spin.min_value = 5
	_autosave_spin.max_value = 600
	_autosave_spin.step = 5
	_autosave_spin.value = float(App.app_settings.autosave_interval)
	_autosave_spin.editable = _autosave_check.button_pressed

	# Values are assigned first and the signals connected afterwards: setting
	# `button_pressed` / `value` from code emits them, which would immediately
	# write the current settings back to disk and pop a toast on every open.
	_theme_select.item_selected.connect(_on_theme_selected)
	_font_select.item_selected.connect(_on_font_selected)
	_language_select.item_selected.connect(_on_language_selected)
	_date_select.item_selected.connect(_on_date_format_selected)
	_autosave_check.toggled.connect(_on_autosave_toggled)
	_autosave_spin.value_changed.connect(_on_autosave_interval_changed)

func _on_theme_selected(index: int) -> void:
	Themes.set_theme_id(_theme_select.get_item_metadata(index))
	EventBus.toast(Lang.t("set.theme_applied"), "success")

func _on_font_selected(index: int) -> void:
	Themes.set_font_index(int(_font_select.get_item_metadata(index)))
	EventBus.toast(Lang.t("set.font_applied"), "success")

func _on_language_selected(index: int) -> void:
	Lang.set_language(String(_language_select.get_item_metadata(index)))
	EventBus.toast(Lang.t("set.language_applied"), "success")

func _on_date_format_selected(index: int) -> void:
	App.set_app_setting("date_format", String(_date_select.get_item_metadata(index)))
	# Every date field re-reads the format when its screen is rebuilt.
	EventBus.notify("settings")
	EventBus.toast(Lang.t("set.date_applied"), "success")

func _on_autosave_toggled(enabled: bool) -> void:
	App.set_app_setting("autosave_enabled", enabled)
	_autosave_spin.editable = enabled

func _on_autosave_interval_changed(value: float) -> void:
	App.set_app_setting("autosave_interval", value)

# --- Project

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
		EventBus.toast(Lang.t("set.name_required"), "error")
		return
	p.name = new_name
	p.rate_usd_brl = Money.parse_rate(_rate_edit.text)
	p.base_salary_usd_cents = Money.parse_brl(_salary_usd.text)
	p.base_salary_brl_cents = Money.parse_brl(_salary_brl.text)
	p.hours_per_day = int(_hours_spin.value)
	App.touch("settings")
	EventBus.toast(Lang.t("set.applied"), "success")
