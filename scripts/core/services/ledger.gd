class_name Ledger
extends RefCounted
## Calculations derived from transactions | NEVER stores state

## One month's transactions
static func transactions_in_month(p: FinanceProject, month: String) -> Array[Transaction]:
	var result: Array[Transaction] = []
	for t in p.transactions:
		if t.month == month:
			result.append(t)
	return result

## Transactions within a range of months (inclusive)
static func transactions_in_range(p: FinanceProject, from_m: String, to_m: String) -> Array[Transaction]:
	var result: Array[Transaction] = []
	for t in p.transactions:
		if t.month >= from_m and t.month <= to_m:
			result.append(t)
	return result

## {"income": int, "expense": int, "net": int} from a list of transactions
static func totals(list: Array[Transaction]) -> Dictionary:
	var income := 0
	var expense := 0
	for t in list:
		if t.type == "income":
			income += t.amount_cents
		else:
			expense += t.amount_cents
	return {"income": income, "expense": expense, "net": income - expense}

## Accumulated balance up to the end of a month (sum of everything since the beginning)
static func balance_until(p: FinanceProject, month: String) -> int:
	var balance := 0
	for t in p.transactions:
		if t.month <= month:
			balance += t.amount_cents if t.type == "income" else -t.amount_cents
	return balance

## Spending (outflows) for a category in a month
static func spent_in_category(p: FinanceProject, category_id: String, month: String) -> int:
	var total := 0
	for t in p.transactions:
		if t.month == month and t.type == "expense" and t.category_id == category_id:
			total += t.amount_cents
	return total

## {category_id: cents} of outflows by category within a given period
static func expenses_by_category(p: FinanceProject, from_m: String, to_m: String) -> Dictionary:
	var result := {}
	for t in transactions_in_range(p, from_m, to_m):
		if t.type == "expense":
			result[t.category_id] = int(result.get(t.category_id, 0)) + t.amount_cents
	return result

## Creates a transaction (with installments, if necessary) and adds it to the project
## Returns the created transactions (1 or N)
static func add_transaction(p: FinanceProject, data: Dictionary) -> Array[Transaction]:
	var created: Array[Transaction] = []
	var n_installments := int(data.get("installments_total", 0))
	if n_installments >= 2:
		var parts := Money.split_installments(int(data.amount_cents), n_installments)
		var group := FinanceProject.new_id()
		for i in n_installments:
			var t := _build(data)
			t.amount_cents = parts[i]
			t.orig_amount_cents = parts[i] if data.currency == "BRL" else t.orig_amount_cents
			t.month = Fmt.add_months(String(data.month), i)
			t.installments = {"total": n_installments, "current": i + 1, "group_id": group}
			t.description = "%s (%d/%d)" % [data.description, i + 1, n_installments]
			p.transactions.append(t)
			created.append(t)
	else:
		var t := _build(data)
		p.transactions.append(t)
		created.append(t)
	return created

static func _build(data: Dictionary) -> Transaction:
	var t := Transaction.new()
	t.id = FinanceProject.new_id()
	t.date = data.get("date", "")
	t.description = data.get("description", "")
	t.category_id = data.get("category_id", "")
	t.type = data.get("type", "expense")
	t.orig_amount_cents = int(data.get("orig_amount_cents", 0))
	t.currency = data.get("currency", "BRL")
	t.rate = int(data.get("rate", Money.RATE_ONE))
	t.amount_cents = int(data.get("amount_cents", 0))
	t.method = data.get("method", "credit")
	t.month = data.get("month", "")
	t.notes = data.get("notes", "")
	return t
