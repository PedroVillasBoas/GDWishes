extends Node
## Autoload "Fmt" | money, rate, percent, month and date formatting.
## Month names follow the language chosen in Settings; dates follow the format
## chosen in Settings (see DateMask).

## 123456 -> "R$ 1.234,56" | -50 -> "-R$ 0,50"
func money(cents: int, symbol := "R$ ") -> String:
	var negative := cents < 0
	var v := absi(cents)
	@warning_ignore("integer_division")
	var int_part := str(int(v / 100))
	var dec_part := "%02d" % (v % 100)

	# Groups thousands with "."
	var grouped := ""
	var count := 0
	for i in range(int_part.length() - 1, -1, -1):
		grouped = int_part[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "." + grouped
	return ("-" if negative else "") + symbol + grouped + "," + dec_part

## 5186000 -> "5,186000"
func rate(rate_micro: int) -> String:
	@warning_ignore("integer_division")
	return "%d,%06d" % [int(rate_micro / 1_000_000), rate_micro % 1_000_000]

## 0.734 -> "73%"
func pct(ratio: float) -> String:
	return "%d%%" % int(round(clampf(ratio, 0.0, 9.99) * 100.0))

# --- Months ("YYYY-MM")

func current_month() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d" % [d.year, d.month]

## "2026-04" -> "April 2026" (or the current language's month name)
func month_label(key: String, short := false) -> String:
	var parts := key.split("-")
	if parts.size() != 2:
		return key
	var m := int(parts[1]) - 1
	if m < 0 or m > 11:
		return key
	var names: Array = Lang.month_short() if short else Lang.month_names()
	return "%s %s" % [names[m], parts[0]]

func add_months(key: String, delta: int) -> String:
	var parts := key.split("-")
	var total := int(parts[0]) * 12 + (int(parts[1]) - 1) + delta
	@warning_ignore("integer_division")
	return "%04d-%02d" % [int(total / 12), (total % 12) + 1]

## Inclusive List: months_between("2026-04", "2026-06") -> ["2026-04","2026-05","2026-06"]
func months_between(from_key: String, to_key: String) -> Array[String]:
	var result: Array[String] = []
	var k := from_key
	while k <= to_key:
		result.append(k)
		k = add_months(k, 1)
		if result.size() > 1200:  # safety stop (100 years)
			break
	return result

# --- Dates

## "2026-04-15" -> "04-15-2026" (or whatever the Settings date format is).
## A "YYYY-MM" month key is rendered as month + year, since it has no day.
func date_display(iso: String) -> String:
	var p := iso.split("-")
	if p.size() == 3:
		return DateMask.from_iso(iso)
	if p.size() == 2:
		return month_label(iso, true)
	return iso

## Kept as an explicit name for places that always want day/month/year digits.
func date_br(iso: String) -> String:
	return date_display(iso)
