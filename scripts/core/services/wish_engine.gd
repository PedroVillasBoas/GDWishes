class_name WishEngine
extends RefCounted
## Goals, accumulated totals, and progress | Recursive within the wishes tree

## Effective goal | A composite wish (goal_cents < 0) sums the goals of its children
static func goal_of(p: FinanceProject, w: Wish) -> int:
	if not w.is_composite():
		return w.goal_cents
	var total := 0
	for child in p.children_of(w.id):
		if child.status != "archived":
			total += goal_of(p, child)
	return total

## Accumulated total | Direct contributions + accumulated total of children (recursive)
static func saved_of(p: FinanceProject, w: Wish) -> int:
	var total := 0
	for d in p.wish_deposits:
		if d.wish_id == w.id:
			total += d.amount_cents
	for child in p.children_of(w.id):
		if child.status != "archived":
			total += saved_of(p, child)
	return total

static func missing_of(p: FinanceProject, w: Wish) -> int:
	return maxi(goal_of(p, w) - saved_of(p, w), 0)

## 0.0..1.0 | It can exceed 1.0 if contributions went beyond the target goal
static func progress_of(p: FinanceProject, w: Wish) -> float:
	var goal := goal_of(p, w)
	if goal <= 0:
		return 0.0
	return float(saved_of(p, w)) / float(goal)

## Total reserved across ALL active wishes (for the dashboard's "Free Balance")
static func total_reserved(p: FinanceProject) -> int:
	var total := 0
	for w in p.wishes:
		if w.parent_id == "" and w.status == "active":
			total += saved_of(p, w)
	return total

## Adds (or subtracts, if the value is negative) | Returns "" or an error
static func deposit(p: FinanceProject, w: Wish, month: String, amount_cents: int, note := "") -> String:
	if amount_cents == 0:
		return "Valor não pode ser zero."
	if amount_cents < 0 and saved_of(p, w) + amount_cents < 0:
		return "Retirada maior que o acumulado do wish."
	var d := WishDeposit.new()
	d.id = FinanceProject.new_id()
	d.wish_id = w.id
	d.month = month
	d.amount_cents = amount_cents
	d.note = note
	p.wish_deposits.append(d)
	return ""

## Simulator | contributing X/month starting from start_month | In which month does it finish?
## Returns "" if monthly <= 0 or already completed
static func completion_month(p: FinanceProject, w: Wish, monthly_cents: int, start_month: String) -> String:
	var missing := missing_of(p, w)
	if missing <= 0 or monthly_cents <= 0:
		return ""
	@warning_ignore("integer_division")
	var months_needed := int((missing + monthly_cents - 1) / monthly_cents)  # ceil
	return Fmt.add_months(start_month, months_needed - 1)

## "Bought!" | archives the wish (and its children) and optionally generates an outgoing transaction record
static func complete_purchase(p: FinanceProject, w: Wish, category_id: String,
		month: String, create_transaction: bool) -> void:
	var saved := saved_of(p, w)
	_archive_recursive(p, w)
	if create_transaction and saved > 0:
		Ledger.add_transaction(p, {
			"description": "Wish concluído: %s" % w.name,
			"type": "expense", "orig_amount_cents": saved, "currency": "BRL",
			"rate": Money.RATE_ONE, "amount_cents": saved,
			"category_id": category_id, "method": "pix",
			"date": month + "-01", "month": month, "notes": "Gerado pelo GDWishes",
		})

static func _archive_recursive(p: FinanceProject, w: Wish) -> void:
	w.status = "archived"
	for child in p.children_of(w.id):
		_archive_recursive(p, child)
