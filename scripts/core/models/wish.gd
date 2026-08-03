class_name Wish
extends RefCounted

var id: String = ""
var parent_id: String = ""     # "" = root
var name: String = ""
var goal_cents: int = -1       # -1 = composite (meta = sum of children)
var target_month: String = ""  # "YYYY-MM" or ""
var icon: String = "wish"
var status: String = "active"  # "active" | "completed" | "archived"

func is_composite() -> bool:
	return goal_cents < 0

func to_dict() -> Dictionary:
	return {"id": id, "parent_id": parent_id, "name": name, "goal_cents": goal_cents,
		"target_month": target_month, "icon": icon, "status": status}

static func from_dict(d: Dictionary) -> Wish:
	var w := Wish.new()
	w.id = d.get("id", "")
	w.parent_id = d.get("parent_id", "")
	w.name = d.get("name", "")
	w.goal_cents = int(d.get("goal_cents", -1))
	w.target_month = d.get("target_month", "")
	w.icon = d.get("icon", "wish")
	w.status = d.get("status", "active")
	return w
