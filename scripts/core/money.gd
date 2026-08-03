class_name Money
## Amount in CENTS (int) | Rate in micro-units (int, 6 decimal places)

const RATE_ONE := 1_000_000  # Exchange rate 1.000000 (BRL -> BRL)

## Converts a value into cents using a rate in micro-units
## Ex.: convert_cents(230370, 4950600) -> 1.140.470 (R$ 2.303,70 * 4,9506)
static func convert_cents(orig_cents: int, rate_micro: int) -> int:
	# Half-up rounding with integer arithmetic
	var num := orig_cents * rate_micro
	@warning_ignore("integer_division")
	return int((num + RATE_ONE / 2) / RATE_ONE) if num >= 0 else -int((-num + RATE_ONE / 2) / RATE_ONE)

## "1.234,56", "R$ 1.234,56", "-R$ 0,50" -> cents (int) | Returns 0 if invalid
static func parse_brl(text: String) -> int:
	var s := text.strip_edges().replace("R$", "").replace("$", "").replace(" ", "").replace(" ", "")
	if s.is_empty():
		return 0
	var negative := s.begins_with("-") or (s.begins_with("(") and s.ends_with(")"))
	s = s.trim_prefix("-").trim_prefix("(").trim_suffix(")")
	s = s.replace(".", "") # Million separator
	var parts := s.split(",")
	var int_part := parts[0] if parts[0].is_valid_int() else "0"
	var dec_part := "00"
	if parts.size() > 1:
		dec_part = (parts[1] + "00").substr(0, 2)
	if not dec_part.is_valid_int():
		dec_part = "00"
	var cents := int(int_part) * 100 + int(dec_part)
	return -cents if negative else cents

## "4,95060" ou "4.9506" -> micro-units (int) | Returns RATE_ONE if invalid
static func parse_rate(text: String) -> int:
	var s := text.strip_edges().replace("R$", "").replace("$", "").replace(" ", "").replace(",", ".")
	if not s.is_valid_float():
		return RATE_ONE
	return int(round(s.to_float() * RATE_ONE))

## Divides a total into N installments; the first absorbs the remaining cents.
## Ex.: split_installments(10000, 3) -> [3334, 3333, 3333]
static func split_installments(total_cents: int, n: int) -> Array[int]:
	var result: Array[int] = []
	if n <= 0:
		return result
	@warning_ignore("integer_division")
	var base := int(total_cents / n)
	var remainder := total_cents - base * n
	for i in n:
		result.append(base + (remainder if i == 0 else 0))
	return result
