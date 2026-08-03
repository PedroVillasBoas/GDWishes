extends SceneTree
## Core tests | Runs without a UI | Each assertion prints ✔/✘.

var _failures := 0

func _init() -> void:
	_test_money()
	_test_installments()
	_test_limits_rollover()
	_test_wishes()
	_test_cashflow()
	_test_roundtrip()
	print("\n%s" % ("TODOS OS TESTES PASSARAM ✔" if _failures == 0 else "%d FALHAS ✘" % _failures))
	quit(1 if _failures > 0 else 0)

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ✔ " + label)
	else:
		_failures += 1
		printerr("  ✘ " + label)

func _test_money() -> void:
	print("Money:")
	check(Money.parse_brl("R$ 1.234,56") == 123456, "parse_brl 1.234,56")
	check(Money.parse_brl("-R$ 0,50") == -50, "parse_brl negativo")
	check(Money.parse_rate("4,95060") == 4950600, "parse_rate")
	check(Money.convert_cents(230370, 4950600) == 1140470, "conversão USD da planilha")

func _test_installments() -> void:
	print("Parcelas:")
	var parts := Money.split_installments(712601, 3)   # Pichau 2
	var total := 0
	for x in parts: total += x
	check(total == 712601, "parcelas somam o total")
	check(parts[0] >= parts[1], "1ª parcela absorve a sobra")

func _test_limits_rollover() -> void:
	print("Limites (rollover):")
	var p := _project()
	var cat := p.categories[0]
	var lim := Limit.new()
	lim.id = "l1"; lim.category_id = cat.id
	lim.monthly_cap_cents = 15000; lim.active_from = "2026-04"
	p.limits.append(lim)
	_spend(p, cat.id, "2026-04", 14670)
	var april := LimitEngine.state_for(p, lim, "2026-04")
	check(april.leftover == 330, "abril sobra 3,30")
	var may := LimitEngine.state_for(p, lim, "2026-05")
	check(may.available == 15330, "maio disponível 153,30")
	_spend(p, cat.id, "2026-05", 20000)
	var june := LimitEngine.state_for(p, lim, "2026-06")
	check(june.available == 15000 - 4670, "junho desconta estouro de maio")

func _test_wishes() -> void:
	print("Wishes:")
	var p := _project()
	var pc := Wish.new(); pc.id = "w1"; pc.name = "PC"; pc.goal_cents = -1
	var mon := Wish.new(); mon.id = "w2"; mon.parent_id = "w1"; mon.goal_cents = 250000
	var gpu := Wish.new(); gpu.id = "w3"; gpu.parent_id = "w1"; gpu.goal_cents = 400000
	p.wishes.append_array([pc, mon, gpu])
	check(WishEngine.goal_of(p, pc) == 650000, "meta composta = soma dos filhos")
	WishEngine.deposit(p, mon, "2026-07", 100000)
	WishEngine.deposit(p, gpu, "2026-07", 225000)
	check(WishEngine.saved_of(p, pc) == 325000, "acumulado agrega filhos")
	check(absf(WishEngine.progress_of(p, pc) - 0.5) < 0.001, "progresso 50%")
	check(WishEngine.completion_month(p, mon, 50000, "2026-08") == "2026-10", "simulador (3 meses)")

func _test_cashflow() -> void:
	print("Fluxo de caixa (números reais da planilha):")
	var p := _project()
	var cat := p.categories[0]
	_income(p, cat.id, "2026-03", 1140400)   # income 11.404,00
	_income(p, cat.id, "2026-03", 200000)    # extra 2.000,00
	_spend(p, cat.id, "2026-03", 218760)     # school
	_spend(p, cat.id, "2026-03", 5000)       # car maintence
	var rows := Cashflow.rows(p, "2026-03", "2026-03")
	check(rows[0].income == 1340400, "total disponível mar-26 = 13.404,00")
	check(rows[0].closing == 1116640, "resultado mar-26 = 11.166,40")

func _test_roundtrip() -> void:
	print("Persistência (round-trip):")
	var p := _project()
	_spend(p, p.categories[0].id, "2026-04", 5980)
	var json1 := JSON.stringify(p.to_dict(), "\t")
	var p2 := FinanceProject.from_dict(JSON.parse_string(json1))
	var json2 := JSON.stringify(p2.to_dict(), "\t")
	check(json1 == json2, "save -> load -> save produz JSON idêntico")

# --- Helpers

func _project() -> FinanceProject:
	var p := FinanceProject.new()
	p.start_month = "2026-03"
	var c := Category.new()
	c.id = "c1"; c.name = "Teste"; c.type = "expense"
	p.categories.append(c)
	return p

func _spend(p: FinanceProject, cid: String, month: String, cents: int) -> void:
	Ledger.add_transaction(p, {"description": "gasto", "type": "expense",
		"orig_amount_cents": cents, "currency": "BRL", "rate": Money.RATE_ONE,
		"amount_cents": cents, "category_id": cid, "method": "pix",
		"date": month + "-15", "month": month, "notes": ""})

func _income(p: FinanceProject, cid: String, month: String, cents: int) -> void:
	Ledger.add_transaction(p, {"description": "renda", "type": "income",
		"orig_amount_cents": cents, "currency": "BRL", "rate": Money.RATE_ONE,
		"amount_cents": cents, "category_id": cid, "method": "pix",
		"date": month + "-01", "month": month, "notes": ""})
