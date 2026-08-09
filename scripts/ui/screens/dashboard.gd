extends ScrollContainer
## Dashboard | KPI cards, three charts, wish/limit summaries and the cash flow table

# Unique names (%)
@onready var _card_balance: PanelContainer = %CardBalance
@onready var _card_free: PanelContainer = %CardFree
@onready var _card_income: PanelContainer = %CardIncome
@onready var _card_expense: PanelContainer = %CardExpense
@onready var _line: Control = %Line
@onready var _donut: Control = %Donut
@onready var _bars: Control = %Bars
@onready var _wish_list: VBoxContainer = %WishList
@onready var _lim_list: VBoxContainer = %LimList
@onready var _cf_table: Tree = %CfTable

var _welcome: EmptyState = null

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	EventBus.period_changed.connect(_refresh)
	EventBus.data_changed.connect(func(_w): _refresh())
	Themes.theme_changed.connect(_refresh)
	_donut.slice_clicked.connect(_on_slice_clicked)
	_refresh()

func _refresh() -> void:
	var p := App.project
	var months := App.period_months()
	if months.is_empty():
		return
	var t := Ledger.totals(Ledger.transactions_in_range(p, months[0], months[-1]))
	var balance := Ledger.balance_until(p, months[-1])
	var free := balance - WishEngine.total_reserved(p)

	_card_balance.setup("SALDO TOTAL", balance)
	_card_free.setup("SALDO LIVRE", free, Themes.accent)
	_card_income.setup("ENTRADAS", t.income, Themes.income)
	_card_expense.setup("SAÍDAS", t.expense, Themes.expense)

	# Line | balance month by month
	var line_points: Array[Dictionary] = []
	for m in months:
		line_points.append({"label": Fmt.month_label(m, true), "value": Ledger.balance_until(p, m)})
	_line.set_data(line_points)

	# Donut | expenses per category
	var by_cat := Ledger.expenses_by_category(p, months[0], months[-1])
	var slices: Array[Dictionary] = []
	for cid in by_cat:
		var cat := p.category_by_id(cid)
		slices.append({"label": cat.name if cat else "?", "value": by_cat[cid],
			"color": Color(cat.color) if cat else Themes.text_dim})
	_donut.set_data(slices)

	# Bars | income vs expense per month
	var bar_points: Array[Dictionary] = []
	for m in months:
		var mt := Ledger.totals(Ledger.transactions_in_month(p, m))
		bar_points.append({"label": Fmt.month_label(m, true),
			"income": mt.income, "expense": mt.expense})
	_bars.set_data(bar_points)

	# A brand new project has nothing to plot | Hide the charts rather than showing three empty frames on first launch
	var has_data := not p.transactions.is_empty()
	_line.get_parent().get_parent().visible = has_data       # LinePanel
	_donut.get_parent().get_parent().visible = has_data      # DonutPanel
	_bars.get_parent().get_parent().visible = has_data       # BarPanel
	_update_welcome(has_data)

	_refresh_wishes()
	_refresh_limits(months[-1])
	_refresh_cashflow(months)

## Empty state for the whole dashboard | a freshly created project has NOTHING
func _update_welcome(has_data: bool) -> void:
	if not has_data and not is_instance_valid(_welcome):
		_welcome = EmptyState.make("welcome", "Bem-vindo ao %s!\nComece lançando sua primeira \
movimentação — os gráficos aparecem sozinhos." % App.project.name,
			"Primeiro lançamento",
			func(): EventBus.navigate_requested.emit("transactions"))
		$Col.add_child(_welcome)
		$Col.move_child(_welcome, 1) # Right below the stat cards
	elif has_data and is_instance_valid(_welcome):
		_welcome.queue_free()
		_welcome = null

func _refresh_wishes() -> void:
	var list := _wish_list
	for c in list.get_children():
		c.queue_free()
	var roots := App.project.wishes.filter(func(w): return w.parent_id == "" and w.status == "active")
	if roots.is_empty():
		list.add_child(EmptyState.make("wishes", "Nenhum wish ainda.",
			"Criar wish", func(): EventBus.navigate_requested.emit("wishes"), true))
		return
	roots.sort_custom(func(a, b):
		return WishEngine.progress_of(App.project, a) > WishEngine.progress_of(App.project, b))
	for i in mini(3, roots.size()):
		var w: Wish = roots[i]
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = w.name
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var pct := Label.new()
		pct.text = Fmt.pct(WishEngine.progress_of(App.project, w))
		pct.modulate = Themes.wish
		row.add_child(pct)
		list.add_child(row)

func _refresh_limits(month: String) -> void:
	var list := _lim_list
	for c in list.get_children():
		c.queue_free()
	if App.project.limits.is_empty():
		list.add_child(EmptyState.make("target", "Nenhum limite definido.",
			"Definir limites", func(): EventBus.navigate_requested.emit("categories"), true))
		return
	for lim in App.project.limits:
		var cat := App.project.category_by_id(lim.category_id)
		var s := LimitEngine.state_for(App.project, lim, month)
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = cat.name if cat else "?"
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var v := Label.new()
		v.text = Fmt.money(s.leftover)
		v.modulate = Themes.income if s.leftover >= 0 else Themes.expense
		row.add_child(v)
		list.add_child(row)

func _refresh_cashflow(months: Array[String]) -> void:
	var table: Tree = _cf_table
	table.clear()
	table.columns = 5
	for pair in [[0, "Mês"], [1, "Saldo Anterior"], [2, "Entradas"], [3, "Saídas"], [4, "Resultado"]]:
		table.set_column_title(pair[0], pair[1])
	var root := table.create_item()
	
	# Extend three months into the future to expose the projection
	var extended := months.duplicate()
	for i in 3:
		extended.append(Fmt.add_months(months[-1], i + 1))
	for row_data in Cashflow.rows(App.project, extended[0], extended[-1]):
		var item := table.create_item(root)
		item.set_text(0, Fmt.month_label(row_data.month, true) + (" *" if row_data.projected else ""))
		item.set_text(1, Fmt.money(row_data.opening))
		item.set_text(2, Fmt.money(row_data.income))
		item.set_custom_color(2, Themes.income)
		item.set_text(3, Fmt.money(row_data.expense))
		item.set_custom_color(3, Themes.expense)
		item.set_text(4, Fmt.money(row_data.closing))
		if row_data.projected:
			for col in 5:
				item.set_custom_bg_color(col, Themes.surface_hi)

func _on_slice_clicked(label: String) -> void:
	EventBus.toast("Filtro: %s — abra Lançamentos e selecione a categoria." % label)
