class_name Transaction
extends RefCounted

var id: String = ""
var date: String = ""              # "YYYY-MM-DD"
var description: String = ""
var category_id: String = ""
var type: String = "expense"       # "income" | "expense"
var orig_amount_cents: int = 0
var currency: String = "BRL"       # "BRL" | "USD"
var rate: int = Money.RATE_ONE     # micro-units
var amount_cents: int = 0          # converted to base currency
var method: String = "credit"      # "credit" | "debit" | "pix" | "cash"
var installments: Dictionary = {}  # empty, or {"total": 3, "current": 1, "group_id": "g1"}
var month: String = ""             # "YYYY-MM" (reference month)
var notes: String = ""

func to_dict() -> Dictionary:
	return {"id": id, "date": date, "description": description, "category_id": category_id,
		"type": type, "orig_amount_cents": orig_amount_cents, "currency": currency,
		"rate": rate, "amount_cents": amount_cents, "method": method,
		"installments": installments, "month": month, "notes": notes}

static func from_dict(d: Dictionary) -> Transaction:
	var t := Transaction.new()
	t.id = d.get("id", "")
	t.date = d.get("date", "")
	t.description = d.get("description", "")
	t.category_id = d.get("category_id", "")
	t.type = d.get("type", "expense")
	t.orig_amount_cents = int(d.get("orig_amount_cents", 0))
	t.currency = d.get("currency", "BRL")
	t.rate = int(d.get("rate", Money.RATE_ONE))
	t.amount_cents = int(d.get("amount_cents", 0))
	t.method = d.get("method", "credit")
	t.installments = d.get("installments", {}) if d.get("installments") is Dictionary else {}
	t.month = d.get("month", "")
	t.notes = d.get("notes", "")
	return t
