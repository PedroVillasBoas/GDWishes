class_name Category
extends RefCounted

var id: String = ""
var name: String = ""
var type: String = "expense"   # "income" | "expense"
var icon: String = "categories"
var color: String = "#7C6FF0"

func to_dict() -> Dictionary:
	return {"id": id, "name": name, "type": type, "icon": icon, "color": color}

static func from_dict(d: Dictionary) -> Category:
	var c := Category.new()
	c.id = d.get("id", "")
	c.name = d.get("name", "")
	c.type = d.get("type", "expense")
	c.icon = d.get("icon", "categories")
	c.color = d.get("color", "#7C6FF0")
	return c
