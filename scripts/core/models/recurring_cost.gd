class_name RecurringCost
extends RefCounted

var id: String = ""
var name: String = ""
var kind: String = "fixed" # "fixed" | "fixed_variable"
var amount_cents: int = 0 # default value
var category_id: String = ""
var active_from: String = ""
var active_to: String = ""
var monthly_overrides: Dictionary = {}  # {"2026-06": 220000} for fixed_variable

func is_active_in(month: String) -> bool:
	return month >= active_from and (active_to == "" or month <= active_to)

func amount_for(month: String) -> int:
	return int(monthly_overrides.get(month, amount_cents))

func to_dict() -> Dictionary:
	return {"id": id, "name": name, "kind": kind, "amount_cents": amount_cents,
		"category_id": category_id, "active_from": active_from, "active_to": active_to,
		"monthly_overrides": monthly_overrides}

static func from_dict(d: Dictionary) -> RecurringCost:
	var r := RecurringCost.new()
	r.id = d.get("id", "")
	r.name = d.get("name", "")
	r.kind = d.get("kind", "fixed")
	r.amount_cents = int(d.get("amount_cents", 0))
	r.category_id = d.get("category_id", "")
	r.active_from = d.get("active_from", "")
	r.active_to = d.get("active_to", "")
	r.monthly_overrides = d.get("monthly_overrides", {}) if d.get("monthly_overrides") is Dictionary else {}
	return r
