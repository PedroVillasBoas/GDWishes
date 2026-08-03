class_name LimitEngine
extends RefCounted
## available(m) = ceiling + surplus(m-1) + adjustments(m);  surplus(m) = available(m) - expenditure(m)

## Status of a limit in a month
## {"cap": int, "carry": int, "adjustments": int, "available": int, "spent": int, "leftover": int}
static func state_for(p: FinanceProject, limit: Limit, month: String) -> Dictionary:
	if month < limit.active_from:
		return {"cap": 0, "carry": 0, "adjustments": 0, "available": 0, "spent": 0, "leftover": 0}
	var carry := 0
	var state := {}
	for m in Fmt.months_between(limit.active_from, month):
		var adj := _adjustments_in(p, limit.id, m)
		var available := limit.monthly_cap_cents + carry + adj
		var spent := Ledger.spent_in_category(p, limit.category_id, m)
		var leftover := available - spent
		state = {"cap": limit.monthly_cap_cents, "carry": carry, "adjustments": adj,
			"available": available, "spent": spent, "leftover": leftover}
		carry = leftover   # The surplus (or negative overrun) carries over to the following month
	return state

## Sum of adjustments affecting this limit for the month (inflows are positive, outflows are negative)
static func _adjustments_in(p: FinanceProject, limit_id: String, month: String) -> int:
	var total := 0
	for a in p.limit_adjustments:
		if a.month != month:
			continue
		if a.to_limit == limit_id:
			total += a.amount_cents
		if a.from_limit == limit_id:
			total -= a.amount_cents
	return total

## Creates a transfer between limits | Returns "" or an error message
static func transfer(p: FinanceProject, from_limit: Limit, to_limit: Limit,
		month: String, amount_cents: int, note := "") -> String:
	if amount_cents <= 0:
		return "Valor deve ser maior que zero."
	if from_limit.id == to_limit.id:
		return "Origem e destino são o mesmo limite."
	var origin_state := state_for(p, from_limit, month)
	if origin_state.leftover < amount_cents:
		return "Origem tem apenas %s disponíveis." % Fmt.money(origin_state.leftover)
	var a := LimitAdjustment.new()
	a.id = FinanceProject.new_id()
	a.month = month
	a.from_limit = from_limit.id
	a.to_limit = to_limit.id
	a.amount_cents = amount_cents
	a.note = note
	p.limit_adjustments.append(a)
	return ""
