class_name Limit
extends RefCounted

var id: String = ""
var category_id: String = ""
var monthly_cap_cents: int = 0
var active_from: String = ""   # "YYYY-MM"

func to_dict() -> Dictionary:
	return {"id": id, "category_id": category_id,
		"monthly_cap_cents": monthly_cap_cents, "active_from": active_from}

static func from_dict(d: Dictionary) -> Limit:
	var l := Limit.new()
	l.id = d.get("id", "")
	l.category_id = d.get("category_id", "")
	l.monthly_cap_cents = int(d.get("monthly_cap_cents", 0))
	l.active_from = d.get("active_from", "")
	return l
