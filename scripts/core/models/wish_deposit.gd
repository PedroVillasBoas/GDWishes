class_name WishDeposit
extends RefCounted
## Contribution to a wish (negative = withdrawal)

var id: String = ""
var wish_id: String = ""
var month: String = ""
var amount_cents: int = 0
var note: String = ""

func to_dict() -> Dictionary:
	return {"id": id, "wish_id": wish_id, "month": month,
		"amount_cents": amount_cents, "note": note}

static func from_dict(d: Dictionary) -> WishDeposit:
	var w := WishDeposit.new()
	w.id = d.get("id", "")
	w.wish_id = d.get("wish_id", "")
	w.month = d.get("month", "")
	w.amount_cents = int(d.get("amount_cents", 0))
	w.note = d.get("note", "")
	return w
