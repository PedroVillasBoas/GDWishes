extends VBoxContainer

@onready var _grid: GridContainer = $Scroll/CardGrid
@onready var _wish_dialog: ConfirmationDialog = $WishDialog
@onready var _deposit_dialog: ConfirmationDialog = $DepositDialog

var _editing: Wish = null
var _deposit_target: Wish = null
var _detail_wish: Wish = null
var _progress_before := {}      # wish_id -> float (to detect 100% overlap)
var _empty: EmptyState = null   # empty-state

func _ready() -> void:
	$Toolbar/AddWishButton.pressed.connect(_open_wish_dialog.bind(null))
	$Toolbar/ShowArchived.toggled.connect(func(_v): _refresh())
	_wish_dialog.confirmed.connect(_save_wish)
	_deposit_dialog.confirmed.connect(_do_deposit)
	$WishDialog/Form/CompositeCheck.toggled.connect(
		func(on): $WishDialog/Form/GoalEdit.editable = not on)
	EventBus.data_changed.connect(func(w): if w == "wishes": _refresh())
	_refresh()

func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	if is_instance_valid(_empty):
		_empty.queue_free()
		_empty = null
	var show_archived: bool = $Toolbar/ShowArchived.button_pressed
	var shown := 0
	for w in App.project.wishes:
		if w.parent_id != "":
			continue   # The grid shows only the root items | children appear in the card/detail view
		if w.status == "archived" and not show_archived:
			continue
		_grid.add_child(_make_card(w))
		shown += 1
	
	# empty-state | new project always lands here
	if shown == 0:
		_empty = EmptyState.make("✨", "Nenhum wish ainda — crie seu primeiro sonho.",
			"✦ Novo Wish", _open_wish_dialog.bind(null))
		$Scroll.visible = false
		add_child(_empty)
	else:
		$Scroll.visible = true

func _make_card(w: Wish) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 190)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	var name_l := Label.new()
	name_l.text = ("🏆 " if w.status != "active" else "✦ ") + w.name
	name_l.theme_type_variation = "H2"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var ring := ProgressRing.new()
	ring.custom_minimum_size = Vector2(72, 72)
	top.add_child(ring)
	ring.set_progress(WishEngine.progress_of(App.project, w))

	var goal := WishEngine.goal_of(App.project, w)
	var saved := WishEngine.saved_of(App.project, w)
	var info := Label.new()
	info.text = "%s de %s   ·   falta %s" % [Fmt.money(saved), Fmt.money(goal),
		Fmt.money(WishEngine.missing_of(App.project, w))]
	info.theme_type_variation = "Dim"
	col.add_child(info)
	if w.target_month != "":
		var target := Label.new()
		target.text = "🎯 alvo: " + Fmt.month_label(w.target_month, true)
		target.theme_type_variation = "Dim"
		col.add_child(target)
	for child in App.project.children_of(w.id):
		if child.status == "archived": continue
		var cl := Label.new()
		cl.text = "   • %s — %s / %s" % [child.name,
			Fmt.money(WishEngine.saved_of(App.project, child)),
			Fmt.money(WishEngine.goal_of(App.project, child))]
		cl.theme_type_variation = "Dim"
		col.add_child(cl)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	if w.status == "active":
		var dep_b := Button.new()
		dep_b.text = "＋ Aportar"
		dep_b.theme_type_variation = "PrimaryButton"
		dep_b.pressed.connect(_open_deposit.bind(w))
		buttons.add_child(dep_b)
		if WishEngine.progress_of(App.project, w) >= 1.0:
			var buy_b := Button.new()
			buy_b.text = "🛒 Comprei!"
			buy_b.pressed.connect(_complete.bind(w))
			buttons.add_child(buy_b)
	var det_b := Button.new()
	det_b.text = "Detalhes"
	det_b.pressed.connect(_open_detail.bind(w))
	buttons.add_child(det_b)
	card.mouse_entered.connect(func():
		create_tween().tween_property(card, "modulate", Color(1.06, 1.06, 1.1), 0.1))
	card.mouse_exited.connect(func():
		create_tween().tween_property(card, "modulate", Color.WHITE, 0.1))
	return card

# --- Create | Edit

func _open_wish_dialog(w: Wish) -> void:
	_editing = w
	var form := $WishDialog/Form
	form.get_node("NameEdit").text = w.name if w else ""
	form.get_node("CompositeCheck").button_pressed = w.is_composite() if w else false
	form.get_node("GoalEdit").text = Fmt.money(w.goal_cents, "") if (w and not w.is_composite()) else ""
	form.get_node("GoalEdit").editable = not (w and w.is_composite())
	form.get_node("TargetEdit").text = w.target_month if w else ""
	var parent_sel: OptionButton = form.get_node("ParentSelect")
	parent_sel.clear()
	parent_sel.add_item("— sem pai (wish raiz) —")
	for cand in App.project.wishes:
		if cand.is_composite() and cand.status == "active" and (w == null or cand.id != w.id):
			parent_sel.add_item(cand.name)
			parent_sel.set_item_metadata(parent_sel.item_count - 1, cand.id)
			if w and w.parent_id == cand.id:
				parent_sel.selected = parent_sel.item_count - 1
	_wish_dialog.popup_centered(Vector2i(420, 320))

func _save_wish() -> void:
	var form := $WishDialog/Form
	var wname: String = form.get_node("NameEdit").text.strip_edges()
	if wname.is_empty():
		EventBus.toast("Nome é obrigatório.", "error"); return
	var composite: bool = form.get_node("CompositeCheck").button_pressed
	var goal := Money.parse_brl(form.get_node("GoalEdit").text)
	if not composite and goal <= 0:
		EventBus.toast("Defina a meta (ou marque como composto).", "error"); return
	var target := _editing
	if target == null:
		target = Wish.new()
		target.id = FinanceProject.new_id()
		App.project.wishes.append(target)
	target.name = wname
	target.goal_cents = -1 if composite else goal
	target.target_month = form.get_node("TargetEdit").text.strip_edges()
	var parent_sel: OptionButton = form.get_node("ParentSelect")
	target.parent_id = "" if parent_sel.selected <= 0 \
		else parent_sel.get_item_metadata(parent_sel.selected)
	App.touch("wishes")

# --- Contributions

func _open_deposit(w: Wish) -> void:
	_deposit_target = w
	_progress_before[w.id] = WishEngine.progress_of(App.project, _root_of(w))
	$DepositDialog/Form/AmountEdit.text = ""
	$DepositDialog/Form/MonthEdit.text = Fmt.current_month()
	var free := Ledger.balance_until(App.project, Fmt.current_month()) \
		- WishEngine.total_reserved(App.project)
	$DepositDialog/Form/FreeBalanceLabel.text = "Saldo livre: " + Fmt.money(free)
	$DepositDialog.title = "Aportar — " + w.name
	$DepositDialog.popup_centered(Vector2i(380, 220))

func _do_deposit() -> void:
	var amount := Money.parse_brl($DepositDialog/Form/AmountEdit.text)
	var month: String = $DepositDialog/Form/MonthEdit.text.strip_edges()
	var free := Ledger.balance_until(App.project, Fmt.current_month()) \
		- WishEngine.total_reserved(App.project)
	var err := WishEngine.deposit(App.project, _deposit_target, month, amount)
	if err != "":
		EventBus.toast(err, "error"); return
	if amount > free:
		EventBus.toast("Atenção: aporte maior que o saldo livre (%s)." % Fmt.money(free), "error")
	App.touch("wishes")
	var root := _root_of(_deposit_target)
	var before: float = _progress_before.get(root.id, 0.0)
	if before < 1.0 and WishEngine.progress_of(App.project, root) >= 1.0:
		_celebrate(root)

func _root_of(w: Wish) -> Wish:
	var cur := w
	while cur.parent_id != "":
		var parent := App.project.wish_by_id(cur.parent_id)
		if parent == null: break
		cur = parent
	return cur

# --- Details | Simulator

func _open_detail(w: Wish) -> void:
	_detail_wish = w
	var col := $DetailDialog/Col
	for c in col.get_node("HistoryList").get_children():
		c.queue_free()
	var deposits := App.project.wish_deposits.filter(func(d): return d.wish_id == w.id)
	deposits.sort_custom(func(a, b): return a.month > b.month)
	if deposits.is_empty():
		col.get_node("HistoryList").add_child(EmptyState.make("📥",
			"Nenhum aporte ainda.", "", Callable(), true))
	for d in deposits:
		var l := Label.new()
		l.text = "%s   %s" % [Fmt.month_label(d.month, true), Fmt.money(d.amount_cents)]
		l.modulate = ThemeBuilder.INCOME if d.amount_cents > 0 else ThemeBuilder.EXPENSE
		col.get_node("HistoryList").add_child(l)
	var slider: HSlider = col.get_node("SimRow/SimSlider")
	if not slider.value_changed.is_connected(_update_sim):
		slider.value_changed.connect(_update_sim)
	slider.value = 200
	_update_sim(slider.value)
	$DetailDialog.title = w.name
	$DetailDialog.popup_centered(Vector2i(520, 480))

func _update_sim(value: float) -> void:
	var col := $DetailDialog/Col
	var monthly := int(value) * 100   # slider em reais -> centavos
	col.get_node("SimRow/SimValue").text = Fmt.money(monthly)
	var done := WishEngine.completion_month(App.project, _detail_wish, monthly, Fmt.current_month())
	if done == "":
		col.get_node("SimResult").text = "—"
	else:
		col.get_node("SimResult").text = "Aportando %s/mês, você conclui em %s 🎉" % \
			[Fmt.money(monthly), Fmt.month_label(done)]

# --- Conclude | Celebration

func _complete(w: Wish) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Comprei! 🛒"
	dlg.dialog_text = "Gerar um lançamento de saída de %s e arquivar \"%s\"?" % \
		[Fmt.money(WishEngine.saved_of(App.project, w)), w.name]
	dlg.ok_button_text = "Gerar e arquivar"
	dlg.add_button("Só arquivar", true, "archive_only")
	add_child(dlg)
	var cat_id: String = App.project.categories[0].id if not App.project.categories.is_empty() else ""
	for c in App.project.categories:
		if c.name == "Misc": cat_id = c.id
	dlg.confirmed.connect(func():
		WishEngine.complete_purchase(App.project, w, cat_id, Fmt.current_month(), true)
		App.touch("wishes"); App.touch("transactions"))
	dlg.custom_action.connect(func(_a):
		WishEngine.complete_purchase(App.project, w, cat_id, Fmt.current_month(), false)
		App.touch("wishes")
		dlg.hide())
	dlg.popup_centered()

func _celebrate(w: Wish) -> void:
	var p: CPUParticles2D = $Celebration
	p.global_position = get_viewport_rect().size / 2.0
	p.restart()
	EventBus.toast("🎉 %s completo! Meta atingida!" % w.name, "success")
