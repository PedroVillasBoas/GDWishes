extends VBoxContainer
## Wishes screen | card grid with foldable cards, sub-wishes, contributions,
## detail dialog with simulator, and celebration.

## Ring color thresholds: below 33% cold, below 66% warm, then gold, green at 100%.
const RING_STEPS := [0.33, 0.66, 1.0]

@onready var _grid: GridContainer = %CardGrid
@onready var _scroll: ScrollContainer = %Scroll
@onready var _toolbar_add: Button = %AddWishButton
@onready var _show_archived: CheckBox = %ShowArchived
@onready var _wish_dialog: ConfirmationDialog = %WishDialog
@onready var _wish_name: LineEdit = %WishNameEdit
@onready var _parent_select: OptionButton = %ParentSelect
@onready var _composite_check: CheckBox = %CompositeCheck
@onready var _goal_edit: LineEdit = %GoalEdit
@onready var _target_edit: LineEdit = %TargetEdit
@onready var _priority_select: OptionButton = %PrioritySelect
@onready var _icon_color: ColorPickerButton = %IconColorPick
@onready var _deposit_dialog: ConfirmationDialog = %DepositDialog
@onready var _deposit_target_select: OptionButton = %DepositTargetSelect
@onready var _deposit_amount: LineEdit = %DepositAmountEdit
@onready var _deposit_month: LineEdit = %DepositMonthEdit
@onready var _free_balance: Label = %FreeBalanceLabel
@onready var _detail_dialog: AcceptDialog = %DetailDialog
@onready var _history_list: VBoxContainer = %HistoryList
@onready var _sim_slider: HSlider = %SimSlider
@onready var _sim_value: LineEdit = %SimValueEdit
@onready var _sim_result: Label = %SimResult
@onready var _celebration: CPUParticles2D = %Celebration

var _editing: Wish = null
var _deposit_root: Wish = null      # card the deposit dialog was opened from
var _detail_wish: Wish = null
var _progress_before := {}          # wish_id -> float, to detect crossing 100%
var _empty: EmptyState = null
var _syncing_sim := false           # guards the slider <-> text two-way binding

func _ready() -> void:
	UiUtils.hide_dialogs(self)
	_apply_language()
	_toolbar_add.pressed.connect(func(): _open_wish_dialog(null, ""))
	_show_archived.toggled.connect(func(_v): _refresh())
	_wish_dialog.confirmed.connect(_save_wish)
	_deposit_dialog.confirmed.connect(_do_deposit)
	_composite_check.toggled.connect(_on_composite_toggled)
	_sim_slider.value_changed.connect(_on_sim_slider_changed)
	_sim_value.text_submitted.connect(_on_sim_text_submitted)
	_sim_value.focus_exited.connect(func(): _on_sim_text_submitted(_sim_value.text))
	EventBus.data_changed.connect(func(w): if w == "wishes": _refresh())
	Themes.theme_changed.connect(_refresh)
	Lang.language_changed.connect(func(): _apply_language(); _refresh())
	_refresh()

func _apply_language() -> void:
	Icons.decorate(_toolbar_add, "wishes", Lang.t("wish.new"))
	_show_archived.text = Lang.t("wish.show_archived")
	_composite_check.text = Lang.t("wish.composite")
	_priority_select.clear()
	for p in Wish.PRIORITIES:
		_priority_select.add_item(Lang.t("wish.priority_" + p))

# --- Grid

func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	if is_instance_valid(_empty):
		_empty.queue_free()
		_empty = null
	var roots: Array = App.project.wishes.filter(func(w):
		return w.parent_id == "" and (w.status != "archived" or _show_archived.button_pressed))
	# Highest priority first, then closest to completion.
	roots.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		return WishEngine.progress_of(App.project, a) > WishEngine.progress_of(App.project, b))
	for w in roots:
		_grid.add_child(_make_card(w))
	if roots.is_empty():
		_empty = EmptyState.make("wishes", Lang.t("wish.empty"),
			Lang.t("wish.new"), func(): _open_wish_dialog(null, ""))
		_scroll.visible = false
		add_child(_empty)
	else:
		_scroll.visible = true

## Ring color by completion, so a card reads as "far / halfway / nearly there" at a glance.
func _ring_color(progress: float) -> Color:
	if progress >= RING_STEPS[2]:
		return Themes.income
	if progress >= RING_STEPS[1]:
		return Themes.wish
	if progress >= RING_STEPS[0]:
		return Themes.warn
	return Themes.accent

func _wish_tint(w: Wish) -> Color:
	if w.icon_color != "":
		return Color(w.icon_color)
	return Themes.wish if w.status != "active" else Themes.accent

func _make_card(w: Wish) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var goal := WishEngine.goal_of(App.project, w)
	var saved := WishEngine.saved_of(App.project, w)
	var progress := WishEngine.progress_of(App.project, w)

	# --- header: always visible, in both folded and unfolded states
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(Icons.make_texture_rect(
		"trophy" if w.status != "active" else w.icon, 20, _wish_tint(w)))
	var name_l := Label.new()
	name_l.text = w.name
	name_l.theme_type_variation = "H2"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_l)
	if w.priority != 1:
		var pri := Label.new()
		pri.text = Lang.t("wish.priority_" + w.priority_id())
		pri.theme_type_variation = "Dim"
		pri.modulate = Themes.warn if w.priority > 1 else Themes.text_dim
		title_row.add_child(pri)
	top.add_child(title_row)

	var fold_b := Button.new()
	fold_b.flat = true
	fold_b.tooltip_text = Lang.t("generic.expand") if w.collapsed else Lang.t("generic.collapse")
	fold_b.icon = Icons.get_icon("chevron_right" if w.collapsed else "chevron_left")
	fold_b.pressed.connect(func():
		w.collapsed = not w.collapsed
		App.touch("wishes"))
	top.add_child(fold_b)

	var ring := ProgressRing.new()
	ring.custom_minimum_size = Vector2(72, 72)
	ring.ring_color = _ring_color(progress)
	top.add_child(ring)
	ring.set_progress(progress)

	# Money summary stays visible when folded — it is the whole point of the card.
	var info := Label.new()
	info.text = "%s   ·   %s" % [
		Lang.t("wish.of") % [Fmt.money(saved), Fmt.money(goal)],
		Lang.t("wish.missing") % Fmt.money(WishEngine.missing_of(App.project, w))]
	info.theme_type_variation = "Dim"
	col.add_child(info)

	if w.collapsed:
		card.custom_minimum_size = Vector2(0, 0)
		_add_card_hover(card)
		return card

	# --- unfolded body
	card.custom_minimum_size = Vector2(0, 190)
	if w.target_month != "":
		var target_row := HBoxContainer.new()
		target_row.add_theme_constant_override("separation", 6)
		target_row.add_child(Icons.make_texture_rect("target", 14, Themes.text_dim))
		var target_l := Label.new()
		target_l.text = Lang.t("wish.target") % Fmt.month_label(w.target_month, true)
		target_l.theme_type_variation = "Dim"
		target_row.add_child(target_l)
		col.add_child(target_row)

	for child in App.project.children_of(w.id):
		if child.status == "archived":
			continue
		col.add_child(_make_child_row(child))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	if w.status == "active":
		if w.is_composite():
			# Sub-wishes are created from their parent, so the parent never has to
			# be picked from a dropdown.
			var sub_b := Button.new()
			Icons.decorate(sub_b, "add", Lang.t("wish.add_sub"))
			sub_b.pressed.connect(func(): _open_wish_dialog(null, w.id))
			buttons.add_child(sub_b)
		var dep_b := Button.new()
		dep_b.theme_type_variation = "PrimaryButton"
		Icons.decorate(dep_b, "deposit", Lang.t("wish.deposit"))
		dep_b.pressed.connect(func(): _open_deposit(w))
		buttons.add_child(dep_b)
		if progress >= 1.0:
			var buy_b := Button.new()
			Icons.decorate(buy_b, "cart", Lang.t("wish.bought"))
			buy_b.pressed.connect(func(): _complete(w))
			buttons.add_child(buy_b)
	var edit_b := Button.new()
	Icons.decorate(edit_b, "edit", Lang.t("generic.edit"))
	edit_b.pressed.connect(func(): _open_wish_dialog(w, w.parent_id))
	buttons.add_child(edit_b)
	var det_b := Button.new()
	Icons.decorate(det_b, "search", Lang.t("generic.details"))
	det_b.pressed.connect(func(): _open_detail(w))
	buttons.add_child(det_b)
	# Archive is offered only while the wish is active; an archived card is already
	# out of the way and only needs the destructive option.
	if w.status == "active":
		var arch_b := Button.new()
		Icons.decorate(arch_b, "close", Lang.t("wish.archive"))
		arch_b.pressed.connect(func(): _confirm_archive(w))
		buttons.add_child(arch_b)
	var del_b := Button.new()
	del_b.theme_type_variation = "DangerButton"
	Icons.decorate(del_b, "delete", Lang.t("wish.delete"))
	del_b.pressed.connect(func(): _confirm_delete(w))
	buttons.add_child(del_b)

	_add_card_hover(card)
	return card

## One line per sub-wish, with its own deposit button.
func _make_child_row(child: Wish) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(Icons.make_texture_rect(child.icon, 14, _wish_tint(child)))
	var l := Label.new()
	l.text = "%s — %s / %s" % [child.name,
		Fmt.money(WishEngine.saved_of(App.project, child)),
		Fmt.money(WishEngine.goal_of(App.project, child))]
	l.theme_type_variation = "Dim"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var dep_b := Button.new()
	dep_b.flat = true
	dep_b.icon = Icons.get_icon("deposit")
	dep_b.tooltip_text = Lang.t("wish.deposit")
	dep_b.pressed.connect(func(): _open_deposit(child))
	row.add_child(dep_b)
	var edit_b := Button.new()
	edit_b.flat = true
	edit_b.icon = Icons.get_icon("edit")
	edit_b.tooltip_text = Lang.t("generic.edit")
	edit_b.pressed.connect(func(): _open_wish_dialog(child, child.parent_id))
	row.add_child(edit_b)
	var arch_b := Button.new()
	arch_b.flat = true
	arch_b.icon = Icons.get_icon("close")
	arch_b.tooltip_text = Lang.t("wish.archive")
	arch_b.pressed.connect(func(): _confirm_archive(child))
	row.add_child(arch_b)
	var del_b := Button.new()
	del_b.flat = true
	del_b.icon = Icons.get_icon("delete")
	del_b.tooltip_text = Lang.t("wish.delete")
	del_b.pressed.connect(func(): _confirm_delete(child))
	row.add_child(del_b)
	return row

func _add_card_hover(card: PanelContainer) -> void:
	card.mouse_entered.connect(func():
		create_tween().tween_property(card, "modulate", Color(1.06, 1.06, 1.1), 0.1))
	card.mouse_exited.connect(func():
		create_tween().tween_property(card, "modulate", Color.WHITE, 0.1))

# --- Create | Edit

## `force_parent` pre-selects (and locks) the parent when adding from a card.
func _open_wish_dialog(w: Wish, force_parent: String) -> void:
	_editing = w
	_wish_name.text = w.name if w else ""
	_target_edit.text = w.target_month if w else ""
	_priority_select.selected = w.priority if w else 1
	_icon_color.color = Color(w.icon_color) if (w and w.icon_color != "") else Themes.accent

	var is_child := force_parent != ""
	# A composite may only hold leaf wishes, so the checkbox is off and locked
	# whenever a parent is involved.
	var composite: bool = w.is_composite() if w else false
	if is_child:
		composite = false
	_composite_check.button_pressed = composite
	_composite_check.disabled = is_child
	_goal_edit.text = Fmt.money(w.goal_cents, "") if (w and not w.is_composite()) else ""
	_goal_edit.editable = not composite

	_parent_select.clear()
	_parent_select.add_item(Lang.t("generic.none"))
	_parent_select.set_item_metadata(0, "")
	for cand in App.project.wishes:
		if not cand.is_composite() or cand.status != "active":
			continue
		if w != null and cand.id == w.id:
			continue                       # a wish cannot parent itself
		_parent_select.add_item(cand.name)
		_parent_select.set_item_metadata(_parent_select.item_count - 1, cand.id)
	var wanted := force_parent if is_child else (w.parent_id if w else "")
	for i in _parent_select.item_count:
		if _parent_select.get_item_metadata(i) == wanted:
			_parent_select.selected = i
	# Locked when adding from a card: the parent is implied by the button pressed.
	_parent_select.disabled = is_child and w == null

	_wish_dialog.title = Lang.t("wish.new_sub") if (is_child and w == null) \
		else (Lang.t("generic.edit") if w else Lang.t("wish.new"))
	_wish_dialog.popup_centered(Vector2i(440, 380))

func _on_composite_toggled(on: bool) -> void:
	_goal_edit.editable = not on
	if on:
		_goal_edit.text = ""
		# A composite cannot itself be a child, so the parent choice is cleared.
		_parent_select.selected = 0
	_parent_select.disabled = on

func _save_wish() -> void:
	var wname := _wish_name.text.strip_edges()
	if wname.is_empty():
		EventBus.toast(Lang.t("generic.required"), "error"); return
	var composite := _composite_check.button_pressed
	var goal := Money.parse_brl(_goal_edit.text)
	if not composite and goal <= 0:
		EventBus.toast(Lang.t("wish.goal_required"), "error"); return
	var target := _editing
	if target == null:
		target = Wish.new()
		target.id = FinanceProject.new_id()
		App.project.wishes.append(target)
	target.name = wname
	target.goal_cents = -1 if composite else goal
	target.target_month = _target_edit.text.strip_edges()
	target.priority = _priority_select.selected
	target.icon_color = "#" + _icon_color.color.to_html(false)
	var parent_id: String = "" if _parent_select.selected < 0 \
		else String(_parent_select.get_item_metadata(_parent_select.selected))
	# Guard the rule even if the UI is bypassed: composites stay at the root.
	target.parent_id = "" if composite else parent_id
	App.touch("wishes")

# --- Contributions

## Opens the deposit dialog. For a composite, the dropdown lists every leaf
## sub-wish so money can go into any of them without leaving the card.
func _open_deposit(w: Wish) -> void:
	_deposit_root = w
	_progress_before[_root_of(w).id] = WishEngine.progress_of(App.project, _root_of(w))
	_deposit_target_select.clear()
	var options := _deposit_options(w)
	for entry in options:
		_deposit_target_select.add_item(entry.label)
		_deposit_target_select.set_item_metadata(_deposit_target_select.item_count - 1, entry.id)
	# One option means nothing to choose; the row is noise then.
	_deposit_target_select.visible = options.size() > 1
	_deposit_amount.text = ""
	_deposit_month.text = Fmt.current_month()
	_free_balance.text = Lang.t("wish.free_balance") % Fmt.money(_free_balance_cents())
	_deposit_dialog.title = "%s — %s" % [Lang.t("wish.deposit"), w.name]
	_deposit_dialog.popup_centered(Vector2i(420, 260))

## A composite holds no money itself, so only its leaves are valid targets.
func _deposit_options(w: Wish) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not w.is_composite():
		out.append({"id": w.id, "label": w.name})
		return out
	for child in App.project.children_of(w.id):
		if child.status == "archived":
			continue
		if child.is_composite():
			out.append_array(_deposit_options(child))
		else:
			out.append({"id": child.id, "label": child.name})
	return out

func _free_balance_cents() -> int:
	return Ledger.balance_until(App.project, Fmt.current_month()) \
		- WishEngine.total_reserved(App.project)

func _do_deposit() -> void:
	if _deposit_target_select.item_count == 0:
		EventBus.toast(Lang.t("wish.pick_target"), "error"); return
	var target_id: String = String(_deposit_target_select.get_item_metadata(
		maxi(_deposit_target_select.selected, 0)))
	var target := App.project.wish_by_id(target_id)
	if target == null:
		EventBus.toast(Lang.t("wish.pick_target"), "error"); return
	var amount := Money.parse_brl(_deposit_amount.text)
	var month := _deposit_month.text.strip_edges()
	var free := _free_balance_cents()
	var err := WishEngine.deposit(App.project, target, month, amount)
	if err != "":
		EventBus.toast(err, "error"); return
	if amount > free:
		EventBus.toast(Lang.t("wish.over_free") % Fmt.money(free), "error")
	App.touch("wishes")
	var root := _root_of(target)
	var before: float = _progress_before.get(root.id, 0.0)
	if before < 1.0 and WishEngine.progress_of(App.project, root) >= 1.0:
		_celebrate(root)

func _root_of(w: Wish) -> Wish:
	var cur := w
	while cur.parent_id != "":
		var parent := App.project.wish_by_id(cur.parent_id)
		if parent == null:
			break
		cur = parent
	return cur

# --- Detail + Simulator

func _open_detail(w: Wish) -> void:
	_detail_wish = w
	for c in _history_list.get_children():
		c.queue_free()
	# A composite's history is the union of its children's deposits.
	var ids := _collect_ids(w)
	var deposits := App.project.wish_deposits.filter(func(d): return d.wish_id in ids)
	deposits.sort_custom(func(a, b): return a.month > b.month)
	if deposits.is_empty():
		_history_list.add_child(EmptyState.make("deposit",
			Lang.t("wish.no_deposits"), "", Callable(), true))
	for d in deposits:
		var target := App.project.wish_by_id(d.wish_id)
		var l := Label.new()
		var suffix := "" if (target == null or target.id == w.id) else "  (%s)" % target.name
		l.text = "%s   %s%s" % [Fmt.month_label(d.month, true), Fmt.money(d.amount_cents), suffix]
		l.modulate = Themes.income if d.amount_cents > 0 else Themes.expense
		_history_list.add_child(l)
	_sim_slider.min_value = 0
	_sim_slider.max_value = 5000
	_sim_slider.step = 50
	_sim_slider.value = 200
	_update_sim(200 * 100)
	_detail_dialog.title = w.name
	_detail_dialog.popup_centered(Vector2i(560, 500))

func _collect_ids(w: Wish) -> Array[String]:
	var ids: Array[String] = [w.id]
	for child in App.project.children_of(w.id):
		ids.append_array(_collect_ids(child))
	return ids

func _on_sim_slider_changed(value: float) -> void:
	if _syncing_sim:
		return
	_update_sim(int(value) * 100)   # slider is in whole currency units -> cents

## Typing an exact amount is the point here: the slider is a coarse control, and
## a goal like 137.50/month is unreachable with a step of 50.
func _on_sim_text_submitted(text: String) -> void:
	if _syncing_sim:
		return
	_update_sim(Money.parse_brl(text))

func _update_sim(monthly_cents: int) -> void:
	_syncing_sim = true
	_sim_value.text = Fmt.money(monthly_cents, "")
	_sim_slider.value = clampf(float(monthly_cents) / 100.0,
		_sim_slider.min_value, _sim_slider.max_value)
	_syncing_sim = false
	var done := WishEngine.completion_month(App.project, _detail_wish, monthly_cents, Fmt.current_month())
	if done == "":
		_sim_result.text = "—"
	else:
		_sim_result.text = Lang.t("wish.sim_result") % [Fmt.money(monthly_cents), Fmt.month_label(done)]

# --- Archive | Delete

## Money held by a wish is only "reserved", never spent: the Free Balance is
## total balance minus everything reserved by ACTIVE root wishes. So both archiving
## and deleting hand the money straight back — archiving because archived wishes stop
## being counted, deleting because the deposits go away with them.
func _release_note(w: Wish) -> String:
	var released := WishEngine.releasable_of(App.project, w)
	if released <= 0:
		return ""
	var key := "wish.release_note_sub" if w.is_composite() else "wish.release_note"
	return Lang.t(key) % Fmt.money(released)

func _confirm_archive(w: Wish) -> void:
	_confirm_removal(w, Lang.t("wish.archive_title"),
		Lang.t("wish.archive_confirm") % w.name, Lang.t("wish.archive"),
		func():
			var released := WishEngine.archive(App.project, w)
			App.touch("wishes")
			_report(Lang.t("wish.archived_toast") % w.name, released))

func _confirm_delete(w: Wish) -> void:
	_confirm_removal(w, Lang.t("wish.delete_title"),
		Lang.t("wish.delete_confirm") % w.name, Lang.t("wish.delete"),
		func():
			var released := WishEngine.delete(App.project, w)
			# The detail dialog may be showing the wish that just vanished.
			if _detail_wish != null and _detail_wish.id == w.id:
				_detail_dialog.hide()
				_detail_wish = null
			App.touch("wishes")
			_report(Lang.t("wish.deleted_toast") % w.name, released))

## Shared confirmation popup. The released amount is spelled out in the body so the
## consequence is visible before the click, not only after it.
func _confirm_removal(w: Wish, title: String, body: String, ok_text: String,
		on_confirm: Callable) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = title
	dlg.dialog_text = body + _release_note(w)
	dlg.ok_button_text = ok_text
	dlg.cancel_button_text = Lang.t("generic.cancel")
	add_child(dlg)
	dlg.confirmed.connect(on_confirm)
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	dlg.popup_centered()

func _report(message: String, released: int) -> void:
	var suffix := "" if released <= 0 else Lang.t("wish.released_toast") % Fmt.money(released)
	EventBus.toast(message + suffix, "success")

# --- Complete + Celebration

func _complete(w: Wish) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = Lang.t("wish.complete_title")
	dlg.dialog_text = Lang.t("wish.complete_body") % [
		Fmt.money(WishEngine.saved_of(App.project, w)), w.name]
	dlg.ok_button_text = Lang.t("wish.complete_ok")
	dlg.add_button(Lang.t("wish.complete_archive"), true, "archive_only")
	add_child(dlg)
	var cat_id: String = App.project.categories[0].id if not App.project.categories.is_empty() else ""
	for c in App.project.categories:
		if c.name == "Misc":
			cat_id = c.id
	dlg.confirmed.connect(func():
		WishEngine.complete_purchase(App.project, w, cat_id, Fmt.current_month(), true)
		App.touch("wishes"); App.touch("transactions"))
	dlg.custom_action.connect(func(_a):
		WishEngine.complete_purchase(App.project, w, cat_id, Fmt.current_month(), false)
		App.touch("wishes")
		dlg.hide())
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	dlg.popup_centered()

func _celebrate(w: Wish) -> void:
	_celebration.global_position = get_viewport_rect().size / 2.0
	_celebration.restart()
	EventBus.toast(Lang.t("wish.completed") % w.name, "success")
