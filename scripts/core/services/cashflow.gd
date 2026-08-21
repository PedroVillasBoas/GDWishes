class_name Cashflow
extends RefCounted
## Monthly cash flow: past = actual transactions; future = projection including recurring items.

## Flow line for one month:
## {"month", "opening": int, "income": int, "expense": int, "closing": int, "projected": bool}
static func rows(p: FinanceProject, from_m: String, to_m: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current := Fmt.current_month()
	var opening := Ledger.balance_until(p, Fmt.add_months(from_m, -1))
	for m in Fmt.months_between(from_m, to_m):
		var income := 0
		var expense := 0
		var projected := m > current
		if projected:
			for ri in p.recurring_incomes:
				if ri.is_active_in(m):
					income += _to_brl(p, ri.amount_cents, ri.currency)
			for rc in p.recurring_costs:
				if rc.is_active_in(m):
					expense += rc.amount_for(m)
		else:
			var t := Ledger.totals(Ledger.transactions_in_month(p, m))
			income = t.income
			expense = t.expense
		var closing := opening + income - expense
		result.append({"month": m, "opening": opening, "income": income,
			"expense": expense, "closing": closing, "projected": projected})
		opening = closing
	return result

static func _to_brl(p: FinanceProject, cents: int, currency: String) -> int:
	return cents if currency == "BRL" else Money.convert_cents(cents, p.rate_usd_brl)

## Recurring payments not yet confirmed for the month (no transaction generated)
## Returns [{"kind": "income"|"cost", "obj": RecurringIncome|RecurringCost}]
static func pending_confirmations(p: FinanceProject, month: String) -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for ri in p.recurring_incomes:
		if ri.is_active_in(month) and not _has_generated(p, ri.id, month):
			pending.append({"kind": "income", "obj": ri})
	for rc in p.recurring_costs:
		if rc.is_active_in(month) and not _has_generated(p, rc.id, month):
			pending.append({"kind": "cost", "obj": rc})
	return pending

static func _has_generated(p: FinanceProject, recurring_id: String, month: String) -> bool:
	for t in p.transactions:
		if t.month == month and t.recurring_id == recurring_id:
			return true
	return false

## Confirms a recurring item for the month -> generates the actual transaction.
## The link back to the recurring entry lives in `recurring_id`, so the user's
## notes field stays empty and under their control.
static func confirm(p: FinanceProject, entry: Dictionary, month: String, amount_cents: int) -> void:
	var obj = entry.obj
	var is_income: bool = entry.kind == "income"
	if not is_income and obj.kind == "fixed_variable":
		obj.monthly_overrides[month] = amount_cents   # Stores the actual value for the month
	Ledger.add_transaction(p, {
		"description": obj.name,
		"type": "income" if is_income else "expense",
		"orig_amount_cents": amount_cents, "currency": "BRL",
		"rate": Money.RATE_ONE, "amount_cents": amount_cents,
		"category_id": obj.category_id, "method": "pix",
		"date": month + "-01", "month": month,
		"notes": "",
		"recurring_id": obj.id,
	})
