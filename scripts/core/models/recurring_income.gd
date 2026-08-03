class_name RecurringIncome
extends RefCounted

var id: String = ""
var name: String = ""
var kind: String = "fixed" # "fixed" | "variable"
var amount_cents: int = 0
var currency: String = "BRL"
var category_id: String = ""
var active_from: String = ""
var active_to: String = "" # "" = no end

func is_active_in(month: String) -> bool:
	return month >= active_from and (active_to == "" or month <= active_to)

func to_dict() -> Dictionary:
	return {"id": id, "name": name, "kind": kind, "amount_cents": amount_cents,
		"currency": currency, "category_id": category_id,
		"active_from": active_from, "active_to": active_to}

static func from_dict(d: Dictionary) -> RecurringIncome:
	var r := RecurringIncome.new()
	r.id = d.get("id", "")
	r.name = d.get("name", "")
	r.kind = d.get("kind", "fixed")
	r.amount_cents = int(d.get("amount_cents", 0))
	r.currency = d.get("currency", "BRL")
	r.category_id = d.get("category_id", "")
	r.active_from = d.get("active_from", "")
	r.active_to = d.get("active_to", "")
	return r
