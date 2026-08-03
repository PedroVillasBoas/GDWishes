class_name FinanceProject
extends RefCounted
## Finance project root | everything saved in .gdwish

const SCHEMA_VERSION := 1

var name: String = "Meu Projeto"
var created_at: String = ""
var last_saved: String = ""

# settings
var base_currency: String = "BRL"
var rate_usd_brl: int = 5_000_000 # micro-units
var base_salary_usd_cents: int = 0
var base_salary_brl_cents: int = 0
var hours_per_day: int = 8
var start_month: String = ""

# coleções
var categories: Array[Category] = []
var limits: Array[Limit] = []
var limit_adjustments: Array[LimitAdjustment] = []
var transactions: Array[Transaction] = []
var recurring_incomes: Array[RecurringIncome] = []
var recurring_costs: Array[RecurringCost] = []
var wishes: Array[Wish] = []
var wish_deposits: Array[WishDeposit] = []

static func new_id() -> String:
	return "%08x%08x" % [randi(), randi()]

# --- Lookups

func category_by_id(cid: String) -> Category:
	for c in categories:
		if c.id == cid:
			return c
	return null

func limit_for_category(cid: String) -> Limit:
	for l in limits:
		if l.category_id == cid:
			return l
	return null

func wish_by_id(wid: String) -> Wish:
	for w in wishes:
		if w.id == wid:
			return w
	return null

func children_of(wish_id: String) -> Array[Wish]:
	var result: Array[Wish] = []
	for w in wishes:
		if w.parent_id == wish_id:
			result.append(w)
	return result

# --- Serialization

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"meta": {"name": name, "created_at": created_at, "last_saved": last_saved},
		"settings": {
			"base_currency": base_currency,
			"rates": {"USD_BRL": rate_usd_brl},
			"base_salary": {"usd_cents": base_salary_usd_cents, "brl_cents": base_salary_brl_cents},
			"hours_per_day": hours_per_day,
			"start_month": start_month,
		},
		"categories": categories.map(func(x): return x.to_dict()),
		"limits": limits.map(func(x): return x.to_dict()),
		"limit_adjustments": limit_adjustments.map(func(x): return x.to_dict()),
		"transactions": transactions.map(func(x): return x.to_dict()),
		"recurring_incomes": recurring_incomes.map(func(x): return x.to_dict()),
		"recurring_costs": recurring_costs.map(func(x): return x.to_dict()),
		"wishes": wishes.map(func(x): return x.to_dict()),
		"wish_deposits": wish_deposits.map(func(x): return x.to_dict()),
	}

static func from_dict(d: Dictionary) -> FinanceProject:
	var p := FinanceProject.new()
	var meta: Dictionary = d.get("meta", {})
	p.name = meta.get("name", "Meu Projeto")
	p.created_at = meta.get("created_at", "")
	p.last_saved = meta.get("last_saved", "")
	var s: Dictionary = d.get("settings", {})
	p.base_currency = s.get("base_currency", "BRL")
	p.rate_usd_brl = int(s.get("rates", {}).get("USD_BRL", 5_000_000))
	p.base_salary_usd_cents = int(s.get("base_salary", {}).get("usd_cents", 0))
	p.base_salary_brl_cents = int(s.get("base_salary", {}).get("brl_cents", 0))
	p.hours_per_day = int(s.get("hours_per_day", 8))
	p.start_month = s.get("start_month", "")
	for x in d.get("categories", []): p.categories.append(Category.from_dict(x))
	for x in d.get("limits", []): p.limits.append(Limit.from_dict(x))
	for x in d.get("limit_adjustments", []): p.limit_adjustments.append(LimitAdjustment.from_dict(x))
	for x in d.get("transactions", []): p.transactions.append(Transaction.from_dict(x))
	for x in d.get("recurring_incomes", []): p.recurring_incomes.append(RecurringIncome.from_dict(x))
	for x in d.get("recurring_costs", []): p.recurring_costs.append(RecurringCost.from_dict(x))
	for x in d.get("wishes", []): p.wishes.append(Wish.from_dict(x))
	for x in d.get("wish_deposits", []): p.wish_deposits.append(WishDeposit.from_dict(x))
	return p
