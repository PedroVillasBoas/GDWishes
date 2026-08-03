extends VBoxContainer

@onready var _list: VBoxContainer = $CatList
@onready var _dialog: ConfirmationDialog = $CatDialog

var _editing: Category = null
var _limit_cat: Category = null

func _ready() -> void:
	$Toolbar/AddCatButton.pressed.connect(_open_dialog.bind(null))
	_dialog.confirmed.connect(_save_dialog)
	$LimitsHeader/LimitMonth.month_changed.connect(func(_m): _refresh_limits())
	$LimitsHeader/TransferButton.pressed.connect(_open_transfer)
	$LimitDialog.confirmed.connect(_save_limit)
	$TransferDialog.confirmed.connect(_do_transfer)
	EventBus.data_changed.connect(_on_data_changed)
	_refresh()
	_refresh_limits()

func _on_data_changed(what: String) -> void:
	if what == "categories":
		_refresh()
	if what in ["categories", "limits", "transactions"]:
		_refresh_limits()

# --- Categories

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	# empty-state: The list is cleared on every refresh, so just add it here
	if App.project.categories.is_empty():
		_list.add_child(EmptyState.make("🏷", "Sem categorias — crie a primeira.",
			"＋ Categoria", _open_dialog.bind(null), true))
	for cat in App.project.categories:
		_list.add_child(_make_row(cat))

func _make_row(cat: Category) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = Color(cat.color)
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var name_l := Label.new()
	name_l.text = cat.name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var type_l := Label.new()
	type_l.text = "Entrada" if cat.type == "income" else "Saída"
	type_l.modulate = ThemeBuilder.INCOME if cat.type == "income" else ThemeBuilder.EXPENSE
	row.add_child(type_l)
	if cat.type == "expense":
		var lim_b := Button.new()
		var lim := App.project.limit_for_category(cat.id)
		lim_b.text = ("Limite: " + Fmt.money(lim.monthly_cap_cents)) if lim else "＋ Limite"
		lim_b.pressed.connect(_open_limit_dialog.bind(cat))
		row.add_child(lim_b)
	var edit_b := Button.new()
	edit_b.text = "Editar"
	edit_b.pressed.connect(_open_dialog.bind(cat))
	row.add_child(edit_b)
	var del_b := Button.new()
	del_b.text = "Excluir"
	del_b.theme_type_variation = "DangerButton"
	del_b.pressed.connect(_delete.bind(cat))
	row.add_child(del_b)
	return panel

func _open_dialog(cat: Category) -> void:
	_editing = cat
	$CatDialog/Form/NameEdit.text = cat.name if cat else ""
	$CatDialog/Form/TypeSelect.selected = (1 if cat.type == "income" else 0) if cat else 0
	$CatDialog/Form/ColorPick.color = Color(cat.color) if cat else ThemeBuilder.ACCENT
	_dialog.popup_centered(Vector2i(380, 240))

func _save_dialog() -> void:
	var cname: String = $CatDialog/Form/NameEdit.text.strip_edges()
	if cname.is_empty():
		EventBus.toast("Nome é obrigatório.", "error"); return
	var target := _editing
	if target == null:
		target = Category.new()
		target.id = FinanceProject.new_id()
		App.project.categories.append(target)
	target.name = cname
	target.type = "income" if $CatDialog/Form/TypeSelect.selected == 1 else "expense"
	target.color = "#" + $CatDialog/Form/ColorPick.color.to_html(false)
	App.touch("categories")

func _delete(cat: Category) -> void:
	for t in App.project.transactions:
		if t.category_id == cat.id:
			EventBus.toast("Categoria em uso por lançamentos — edite-os antes de excluir.", "error")
			return
	App.project.categories.erase(cat)
	var limit := App.project.limit_for_category(cat.id)
	if limit:
		App.project.limits.erase(limit)
	App.touch("categories")

# --- Limits

func _open_limit_dialog(cat: Category) -> void:
	_limit_cat = cat
	var lim := App.project.limit_for_category(cat.id)
	$LimitDialog/Form/CapEdit.text = Fmt.money(lim.monthly_cap_cents, "") if lim else ""
	$LimitDialog.title = "Limite mensal — " + cat.name
	$LimitDialog.popup_centered(Vector2i(360, 180))

func _save_limit() -> void:
	var cap := Money.parse_brl($LimitDialog/Form/CapEdit.text)
	var lim := App.project.limit_for_category(_limit_cat.id)
	if cap <= 0:
		if lim:
			App.project.limits.erase(lim)   # Zero/empty ceiling removes the limit
	elif lim:
		lim.monthly_cap_cents = cap
	else:
		lim = Limit.new()
		lim.id = FinanceProject.new_id()
		lim.category_id = _limit_cat.id
		lim.monthly_cap_cents = cap
		lim.active_from = App.project.start_month
		App.project.limits.append(lim)
	App.touch("limits")
	_refresh() # Updates the button text in the category rows
	_refresh_limits()

func _refresh_limits() -> void:
	var list := $LimitsList
	for c in list.get_children():
		c.queue_free()
	var month: String = $LimitsHeader/LimitMonth.month
	
	# empty-state
	if App.project.limits.is_empty():
		list.add_child(EmptyState.make("🎯",
			"Nenhum limite ainda — use o botão \"＋ Limite\" em uma categoria de Saída.",
			"", Callable(), true))
		return
	for lim in App.project.limits:
		var cat := App.project.category_by_id(lim.category_id)
		if cat == null:
			continue
		var s := LimitEngine.state_for(App.project, lim, month)
		list.add_child(_make_limit_row(cat, s))

## Row: Name | Cap | +Rollover | Spent | Available | colored progress bar
func _make_limit_row(cat: Category, s: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var name_l := Label.new()
	name_l.text = cat.name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	for pair in [["Teto", s.cap], ["Sobras", s.carry + s.adjustments],
			["Gasto", s.spent], ["Disponível", s.leftover]]:
		var l := Label.new()
		l.text = "%s: %s" % [pair[0], Fmt.money(pair[1])]
		l.theme_type_variation = "Dim"
		if pair[0] == "Disponível":
			l.theme_type_variation = ""
			l.modulate = ThemeBuilder.INCOME if pair[1] >= 0 else ThemeBuilder.EXPENSE
		row.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = maxf(float(s.available), 1.0)
	bar.value = float(s.spent)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	var ratio := float(s.spent) / maxf(float(s.available), 1.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ThemeBuilder.INCOME if ratio < 0.75 \
		else (ThemeBuilder.WARN if ratio <= 1.0 else ThemeBuilder.EXPENSE)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	col.add_child(bar)
	return panel

# --- Transfer

func _open_transfer() -> void:
	if App.project.limits.size() < 2:
		EventBus.toast("Crie pelo menos dois limites para transferir.", "error")
		return
	for sel in [$TransferDialog/Form/FromSelect, $TransferDialog/Form/ToSelect]:
		sel.clear()
		for lim in App.project.limits:
			var cat := App.project.category_by_id(lim.category_id)
			sel.add_item(cat.name if cat else "?")
			sel.set_item_metadata(sel.item_count - 1, lim.id)
	$TransferDialog/Form/AmountEdit.text = ""
	$TransferDialog/Form/NoteEdit.text = ""
	$TransferDialog.popup_centered(Vector2i(380, 260))

func _do_transfer() -> void:
	var from_sel := $TransferDialog/Form/FromSelect
	var to_sel := $TransferDialog/Form/ToSelect
	var from_lim: Limit = null
	var to_lim: Limit = null
	for lim in App.project.limits:
		if lim.id == from_sel.get_item_metadata(from_sel.selected): from_lim = lim
		if lim.id == to_sel.get_item_metadata(to_sel.selected): to_lim = lim
	var err := LimitEngine.transfer(App.project, from_lim, to_lim,
		$LimitsHeader/LimitMonth.month,
		Money.parse_brl($TransferDialog/Form/AmountEdit.text),
		$TransferDialog/Form/NoteEdit.text)
	if err != "":
		EventBus.toast(err, "error")
		return
	App.touch("limits")
	EventBus.toast("Transferência registrada.", "success")
