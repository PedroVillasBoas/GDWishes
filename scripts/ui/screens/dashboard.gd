extends ScrollContainer
## Dashboard | KPI cards, three charts, wish/limit summaries and the cash flow table.
##
## The cash flow panel can be expanded: the inline panel hides and a full-screen
## overlay takes the whole dashboard area, since a 12-month projection is unreadable
## in a 200px strip.

@onready var _col: VBoxContainer = %Col
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
@onready var _cf_panel: PanelContainer = %CashflowPanel
@onready var _cf_title: Label = %CfTitle
@onready var _cf_expand: Button = %CfExpandButton
@onready var _line_title: Label = %LineTitle
@onready var _donut_title: Label = %DonutTitle
@onready var _bar_title: Label = %BarTitle
@onready var _wish_title: Label = %WishTitle
@onready var _lim_title: Label = %LimTitle

var _welcome: EmptyState = null
var _overlay: PanelContainer = null    # expanded cash flow, built on demand
var _overlay_table: Tree = null

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	_apply_language()
	EventBus.period_changed.connect(_refresh)
	EventBus.data_changed.connect(func(_w): _refresh())
	Themes.theme_changed.connect(_refresh)
	Lang.language_changed.connect(func(): _apply_language(); _refresh())
	_donut.slice_clicked.connect(_on_slice_clicked)
	_cf_expand.pressed.connect(_expand_cashflow)
	_refresh()

func _apply_language() -> void:
	_line_title.text = Lang.t("dash.balance_evolution")
	_donut_title.text = Lang.t("dash.by_category")
	_bar_title.text = Lang.t("dash.in_out")
	_wish_title.text = Lang.t("dash.top_wishes")
	_lim_title.text = Lang.t("dash.month_limits")
	_cf_title.text = Lang.t("dash.cashflow")
	_cf_expand.icon = Icons.get_icon("search")
	_cf_expand.tooltip_text = Lang.t("generic.expand")

func _refresh() -> void:
	var p := App.project
	var months := App.period_months()
	if months.is_empty():
		return
	var t := Ledger.totals(Ledger.transactions_in_range(p, months[0], months[-1]))
	var balance := Ledger.balance_until(p, months[-1])
	var free := balance - WishEngine.total_reserved(p)

	_card_balance.setup(Lang.t("dash.balance"), balance)
	_card_free.setup(Lang.t("dash.free"), free, Themes.accent)
	_card_income.setup(Lang.t("dash.income"), t.income, Themes.income)
	_card_expense.setup(Lang.t("dash.expense"), t.expense, Themes.expense)

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
	_fill_cashflow(_cf_table, months)
	if is_instance_valid(_overlay_table):
		_fill_cashflow(_overlay_table, months)

## Empty state for the whole dashboard | a freshly created project has NOTHING
func _update_welcome(has_data: bool) -> void:
	if not has_data and not is_instance_valid(_welcome):
		_welcome = EmptyState.make("welcome", Lang.t("dash.welcome") % App.project.name,
			Lang.t("dash.first_transaction"),
			func(): EventBus.navigate_requested.emit("transactions"))
		_col.add_child(_welcome)
		_col.move_child(_welcome, 1) # Right below the stat cards
	elif has_data and is_instance_valid(_welcome):
		_welcome.queue_free()
		_welcome = null

func _refresh_wishes() -> void:
	for c in _wish_list.get_children():
		c.queue_free()
	var roots := App.project.wishes.filter(func(w): return w.parent_id == "" and w.status == "active")
	if roots.is_empty():
		_wish_list.add_child(EmptyState.make("wishes", Lang.t("dash.no_wishes"),
			Lang.t("dash.create_wish"), func(): EventBus.navigate_requested.emit("wishes"), true))
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
		_wish_list.add_child(row)

func _refresh_limits(month: String) -> void:
	for c in _lim_list.get_children():
		c.queue_free()
	if App.project.limits.is_empty():
		_lim_list.add_child(EmptyState.make("target", Lang.t("dash.no_limits"),
			Lang.t("dash.set_limits"), func(): EventBus.navigate_requested.emit("categories"), true))
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
		_lim_list.add_child(row)

# --- Cash flow

func _fill_cashflow(table: Tree, months: Array[String]) -> void:
	if not is_instance_valid(table):
		return
	table.clear()
	table.columns = 5
	table.column_titles_visible = true
	var titles := ["dash.cf_month", "dash.cf_opening", "dash.cf_income",
		"dash.cf_expense", "dash.cf_closing"]
	for i in titles.size():
		table.set_column_title(i, Lang.t(titles[i]))
		# Cell text is left-aligned, so the headers match it instead of centring.
		table.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
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

## Builds the expanded view on top of the whole dashboard and hides the inline one.
func _expand_cashflow() -> void:
	if is_instance_valid(_overlay):
		return
	_cf_panel.visible = false

	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Painted background: the dashboard keeps scrolling underneath otherwise.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Themes.bg
	bg.set_corner_radius_all(0)
	_overlay.add_theme_stylebox_override("panel", bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_overlay.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	col.add_child(header)
	var title := Label.new()
	title.text = Lang.t("dash.cashflow")
	title.theme_type_variation = "H1"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_b := Button.new()
	Icons.decorate(close_b, "close", Lang.t("generic.close"))
	close_b.pressed.connect(_collapse_cashflow)
	header.add_child(close_b)

	_overlay_table = Tree.new()
	_overlay_table.hide_root = true
	_overlay_table.column_titles_visible = true
	_overlay_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_overlay_table)

	# Parented to the ScrollContainer's parent so the overlay does not scroll away.
	var host := get_parent()
	if host == null:
		host = self
	host.add_child(_overlay)
	_fill_cashflow(_overlay_table, App.period_months())
	_overlay.modulate.a = 0.0
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.12)

func _collapse_cashflow() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_overlay_table = null
	_cf_panel.visible = true

func _exit_tree() -> void:
	# The overlay lives outside this node, so leaving the screen must take it along.
	if is_instance_valid(_overlay):
		_overlay.queue_free()

func _on_slice_clicked(label: String) -> void:
	EventBus.toast(Lang.t("dash.filter_hint") % label)
