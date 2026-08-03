class_name LimitAdjustment
extends RefCounted
## Value transfer between limits within a month

var id: String = ""
var month: String = ""       # "YYYY-MM"
var from_limit: String = ""  # Origin limit ID
var to_limit: String = ""    # Destination limit ID
var amount_cents: int = 0
var note: String = ""

func to_dict() -> Dictionary:
	return {"id": id, "month": month, "from_limit": from_limit,
		"to_limit": to_limit, "amount_cents": amount_cents, "note": note}

static func from_dict(d: Dictionary) -> LimitAdjustment:
	var a := LimitAdjustment.new()
	a.id = d.get("id", "")
	a.month = d.get("month", "")
	a.from_limit = d.get("from_limit", "")
	a.to_limit = d.get("to_limit", "")
	a.amount_cents = int(d.get("amount_cents", 0))
	a.note = d.get("note", "")
	return a
