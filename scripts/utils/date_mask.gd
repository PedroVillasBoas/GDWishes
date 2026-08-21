class_name DateMask
extends RefCounted
## Auto-formatting for date LineEdits.
##
## The user types digits only ("15042026") and the separators appear on their own
## in the order chosen in Settings ("15-04-2026"). Attach once per LineEdit:
##     DateMask.attach(my_line_edit)
## and read the value back with DateMask.to_iso(my_line_edit.text).

const SEPARATOR := "-"

## Digit-group widths per format, in display order.
const _GROUPS := {
	"DD-MM-YYYY": [2, 2, 4],
	"MM-DD-YYYY": [2, 2, 4],
	"YYYY-MM-DD": [4, 2, 2],
}

## Which group holds day / month / year, per format.
const _ROLES := {
	"DD-MM-YYYY": ["d", "m", "y"],
	"MM-DD-YYYY": ["m", "d", "y"],
	"YYYY-MM-DD": ["y", "m", "d"],
}

static func available_formats() -> Array[String]:
	return ["DD-MM-YYYY", "MM-DD-YYYY", "YYYY-MM-DD"]

static func current_format() -> String:
	var fmt: String = App.app_settings.get("date_format", "MM-DD-YYYY")
	return fmt if _GROUPS.has(fmt) else "MM-DD-YYYY"

## Connects the auto-mask to a LineEdit. Safe to call more than once.
static func attach(le: LineEdit) -> void:
	if le == null or le.has_meta("date_mask_attached"):
		return
	le.set_meta("date_mask_attached", true)
	le.placeholder_text = current_format()
	le.max_length = current_format().length()
	le.text_changed.connect(_on_text_changed.bind(le))

static func _on_text_changed(new_text: String, le: LineEdit) -> void:
	var masked := mask(new_text)
	if masked == new_text:
		return
	# Setting `text` from inside text_changed does not re-emit the signal, so this
	# cannot loop. The caret goes to the end because typing is always append-style.
	le.text = masked
	le.caret_column = masked.length()

## "15042026" -> "15-04-2026" (for DD-MM-YYYY). Ignores anything that is not a digit.
static func mask(raw: String) -> String:
	var digits := ""
	for ch in raw:
		if ch >= "0" and ch <= "9":
			digits += ch
	var groups: Array = _GROUPS[current_format()]
	var total: int = groups[0] + groups[1] + groups[2]
	digits = digits.substr(0, total)
	var out := ""
	var pos := 0
	for i in groups.size():
		var take: int = mini(groups[i], digits.length() - pos)
		if take <= 0:
			break
		if out != "":
			out += SEPARATOR
		out += digits.substr(pos, take)
		pos += take
	return out

## Display string -> "YYYY-MM-DD". Returns "" when the date is incomplete.
static func to_iso(display: String) -> String:
	var digits := ""
	for ch in display:
		if ch >= "0" and ch <= "9":
			digits += ch
	var fmt := current_format()
	var groups: Array = _GROUPS[fmt]
	if digits.length() < groups[0] + groups[1] + groups[2]:
		return ""
	var roles: Array = _ROLES[fmt]
	var parts := {}
	var pos := 0
	for i in groups.size():
		parts[roles[i]] = digits.substr(pos, groups[i])
		pos += groups[i]
	return "%s-%s-%s" % [parts["y"], parts["m"], parts["d"]]

## "YYYY-MM-DD" -> display string in the current format. Passes through anything
## that is not a full ISO date (e.g. an empty field or a "YYYY-MM" month key).
static func from_iso(iso: String) -> String:
	var p := iso.split("-")
	if p.size() != 3:
		return iso
	var fmt := current_format()
	var roles: Array = _ROLES[fmt]
	var values := {"y": p[0], "m": p[1], "d": p[2]}
	var out: Array[String] = []
	for role in roles:
		out.append(values[role])
	return SEPARATOR.join(out)

## Today, already formatted for display.
static func today_display() -> String:
	var d := Time.get_date_dict_from_system()
	return from_iso("%04d-%02d-%02d" % [d.year, d.month, d.day])
