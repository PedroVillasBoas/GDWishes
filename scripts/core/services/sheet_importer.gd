class_name SheetImporter
extends RefCounted
## Imports the CSVs exported from Google Sheets (Money folder) into the current project

## Returns {"ok": true, "report": String} or {"ok": false, "error": String}
static func import_folder(p: FinanceProject, folder: String) -> Dictionary:
	var report := ""
	
	# 1. Categories (Categorias/Categorias-Data.csv)
	var cat_path := folder.path_join("Categorias").path_join("Categorias-Data.csv")
	if FileAccess.file_exists(cat_path):
		var count := _import_categories(p, cat_path)
		report += "%d categorias importadas.\n" % count
	
	# 2. Transactions (Lancamentos/Lançamentos-Data.csv)
	var tx_path := _find_transactions_csv(folder)
	if tx_path == "":
		return {"ok": false, "error": "Não encontrei o CSV de lançamentos na pasta."}
	var tx_count := _import_transactions(p, tx_path)
	report += "%d lançamentos importados.\n" % tx_count
	
	# 3. Global Variables
	var vg_path := folder.path_join("Variaveis Globais").path_join("Variaveis-Globais-Data.csv")
	if FileAccess.file_exists(vg_path):
		_import_globals(p, vg_path)
		report += "Cotações e salário base importados.\n"
	return {"ok": true, "report": report}

static func _find_transactions_csv(folder: String) -> String:
	var dir_path := folder.path_join("Lancamentos")
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	for f in dir.get_files():   # the name contains a "ç" | find any .csv file in the folder
		if f.ends_with(".csv"):
			return dir_path.path_join(f)
	return ""

static func _read_csv(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var rows := []
	while not f.eof_reached():
		var row := f.get_csv_line()   # handles internal quotes/commas
		if row.size() > 1 or (row.size() == 1 and row[0].strip_edges() != ""):
			rows.append(row)
	f.close()
	return rows

static func _import_categories(p: FinanceProject, path: String) -> int:
	var rows := _read_csv(path)
	var count := 0
	var palette := ["#E8A33D", "#2EA8E8", "#7C6FF0", "#D65CC0", "#3FB950",
		"#F85149", "#E8B33D", "#8B949E"]
	for i in range(1, rows.size()): # Skips header
		var row: PackedStringArray = rows[i]
		if row.size() < 3: continue
		var cname := row[0].strip_edges()
		if cname == "" or cname == "Total": continue
		if _category_by_name(p, cname) != null: continue # does not duplicate
		var c := Category.new()
		c.id = FinanceProject.new_id()
		c.name = cname
		c.type = "income" if row[1].strip_edges() == "Entrada" else "expense"
		c.color = palette[count % palette.size()]
		p.categories.append(c)
	
		# A completed "budget" becomes a limit
		var cap := Money.parse_brl(row[2])
		if c.type == "expense" and cap > 0:
			var lim := Limit.new()
			lim.id = FinanceProject.new_id()
			lim.category_id = c.id
			lim.monthly_cap_cents = cap
			lim.active_from = p.start_month
			p.limits.append(lim)
		count += 1
	return count

static func _import_transactions(p: FinanceProject, path: String) -> int:
	var rows := _read_csv(path)
	var count := 0
	# Header: Date,Description,Category,Type,Original Amount,Currency,Exchange Rate,Amount,Method,Installments,Month/Year,Notes
	for i in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 12 or row[1].strip_edges() == "":
			continue
		var t := Transaction.new()
		t.id = FinanceProject.new_id()
		t.description = row[1].strip_edges()
		var cat := _category_by_name(p, row[2].strip_edges())
		if cat == null:   # Unknown Category -> create on the fly
			cat = Category.new()
			cat.id = FinanceProject.new_id()
			cat.name = row[2].strip_edges()
			cat.type = "income" if row[3].strip_edges() == "Entrada" else "expense"
			p.categories.append(cat)
		t.category_id = cat.id
		t.type = "income" if row[3].strip_edges() == "Entrada" else "expense"
		t.orig_amount_cents = Money.parse_brl(row[4])
		t.currency = row[5].strip_edges() if row[5].strip_edges() in ["BRL", "USD"] else "BRL"
		t.rate = Money.parse_rate(row[6])
		t.amount_cents = Money.parse_brl(row[7])
		if t.amount_cents == 0:
			t.amount_cents = Money.convert_cents(t.orig_amount_cents, t.rate)
		t.method = {"Crédito": "credit", "Débito": "debit", "Pix": "pix"}.get(row[8].strip_edges(), "cash")
	
		# "Month/Year" comes as "04/2026" -> "2026-04"
		var my := row[10].strip_edges().split("/")
		t.month = "%s-%s" % [my[1], my[0]] if my.size() == 2 else Fmt.current_month()
		t.date = t.month + "-01"
		t.notes = row[11].strip_edges()
		p.transactions.append(t)
		count += 1
	return count

static func _import_globals(p: FinanceProject, path: String) -> void:
	var rows := _read_csv(path)
	for row in rows:
		if row.size() < 2: continue
		match row[0].strip_edges():
			"USD -> BRL": p.rate_usd_brl = Money.parse_rate(row[1])
			"USD": p.base_salary_usd_cents = Money.parse_brl(row[1])
			"BRL": p.base_salary_brl_cents = Money.parse_brl(row[1])
			"DIA": p.hours_per_day = int(row[1]) if row[1].is_valid_int() else 8

static func _category_by_name(p: FinanceProject, cname: String) -> Category:
	for c in p.categories:
		if c.name == cname:
			return c
	return null
