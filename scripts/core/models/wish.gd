class_name Wish
extends RefCounted

## Priority levels, low to high. The index is what gets stored.
const PRIORITIES := ["low", "normal", "high", "critical"]

var id: String = ""
var parent_id: String = ""     # "" = root
var name: String = ""
var goal_cents: int = -1       # -1 = composite (meta = sum of children)
var target_month: String = ""  # "YYYY-MM" or ""
var icon: String = "wishes"
var icon_color: String = ""    # "" = follow the theme accent
var status: String = "active"  # "active" | "completed" | "archived"
var priority: int = 1          # index into PRIORITIES; 1 = normal
var collapsed: bool = false    # card folded in the Wishes grid

func is_composite() -> bool:
	return goal_cents < 0

func priority_id() -> String:
	return PRIORITIES[clampi(priority, 0, PRIORITIES.size() - 1)]

func to_dict() -> Dictionary:
	return {"id": id, "parent_id": parent_id, "name": name, "goal_cents": goal_cents,
		"target_month": target_month, "icon": icon, "icon_color": icon_color,
		"status": status, "priority": priority, "collapsed": collapsed}

static func from_dict(d: Dictionary) -> Wish:
	var w := Wish.new()
	w.id = d.get("id", "")
	w.parent_id = d.get("parent_id", "")
	w.name = d.get("name", "")
	w.goal_cents = int(d.get("goal_cents", -1))
	w.target_month = d.get("target_month", "")
	w.icon = d.get("icon", "wishes")
	w.icon_color = d.get("icon_color", "")
	w.status = d.get("status", "active")
	w.priority = int(d.get("priority", 1))
	w.collapsed = bool(d.get("collapsed", false))
	return w
