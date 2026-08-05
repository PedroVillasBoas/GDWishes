extends VBoxContainer

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	
	var p := App.project
	$Card/Grid/NameEdit.text = p.name
	$Card/Grid/RateEdit.text = Fmt.rate(p.rate_usd_brl)
	$Card/Grid/SalaryUsdEdit.text = Fmt.money(p.base_salary_usd_cents, "")
	$Card/Grid/SalaryBrlEdit.text = Fmt.money(p.base_salary_brl_cents, "")
	$Card/Grid/HoursSpin.value = p.hours_per_day
	$Card/Grid/ApplyButton.pressed.connect(_apply)
	$ImportCard/ImpCol/ImportButton.pressed.connect(
		func(): $ImportDialog.popup_centered(Vector2i(800, 500)))
	$ImportDialog.dir_selected.connect(_import_folder)

func _apply() -> void:
	var p := App.project
	p.name = $Card/Grid/NameEdit.text.strip_edges()
	p.rate_usd_brl = Money.parse_rate($Card/Grid/RateEdit.text)
	p.base_salary_usd_cents = Money.parse_brl($Card/Grid/SalaryUsdEdit.text)
	p.base_salary_brl_cents = Money.parse_brl($Card/Grid/SalaryBrlEdit.text)
	p.hours_per_day = int($Card/Grid/HoursSpin.value)
	App.touch("settings")
	EventBus.toast("Configurações aplicadas.", "success")

func _import_folder(folder: String) -> void:
	var result := SheetImporter.import_folder(App.project, folder)
	if not result.ok:
		EventBus.toast(result.error, "error")
		return
	App.touch("transactions")
	App.touch("categories")
	EventBus.toast(result.report.strip_edges(), "success")
