extends Node
## Autoload "Lang" — application language.
##
## Screens call Lang.t("some.key") for every user-facing string and rebuild
## themselves when `language_changed` fires. Scene-authored text is overwritten
## in each screen's _ready(), so nothing needs to be translated in the editor.

signal language_changed

const DEFAULT_LANGUAGE := "en"

## Add a language by adding an entry here and a dictionary in _STRINGS.
const LANGUAGES := [
	{"id": "en", "name": "English"},
	{"id": "pt", "name": "Português (Brasil)"},
]

var current: String = DEFAULT_LANGUAGE

const _STRINGS := {
	"en": {
		# --- generic
		"generic.save": "Save",
		"generic.cancel": "Cancel",
		"generic.edit": "Edit",
		"generic.delete": "Delete",
		"generic.confirm": "Confirm",
		"generic.close": "Close",
		"generic.apply": "Apply",
		"generic.add": "Add",
		"generic.details": "Details",
		"generic.name": "Name",
		"generic.amount": "Amount",
		"generic.value": "Value",
		"generic.type": "Type",
		"generic.category": "Category",
		"generic.method": "Method",
		"generic.date": "Date",
		"generic.notes": "Notes",
		"generic.month": "Month",
		"generic.total": "Total",
		"generic.none": "None",
		"generic.all": "All",
		"generic.undo": "Undo",
		"generic.required": "This field is required.",
		"generic.expand": "Expand",
		"generic.collapse": "Collapse",

		# --- money types
		"type.income": "Income",
		"type.expense": "Expense",
		"method.credit": "Credit",
		"method.debit": "Debit",
		"method.pix": "Pix",
		"method.cash": "Cash",

		# --- navigation
		"nav.dashboard": "Dashboard",
		"nav.transactions": "Transactions",
		"nav.wishes": "Wishes",
		"nav.categories": "Categories & Limits",
		"nav.recurring": "Recurring",
		"nav.settings": "Settings",
		"nav.save_project": "Save   Ctrl+S",
		"nav.close_project": "Close project",
		"nav.collapse": "Collapse sidebar",
		"nav.expand": "Expand sidebar",
		"nav.saved": "saved",
		"nav.unsaved": "unsaved changes",
		"nav.autosave_off": "(autosave off)",

		# --- main menu
		"menu.new_project": "New Project",
		"menu.open": "Open…",
		"menu.recent": "RECENT",
		"menu.name_required": "Give the project a name.",
		"menu.month_invalid": "Initial month must be YYYY-MM (e.g. 2026-04).",

		# --- dashboard
		"dash.balance": "TOTAL BALANCE",
		"dash.free": "FREE BALANCE",
		"dash.income": "INCOME",
		"dash.expense": "EXPENSES",
		"dash.balance_evolution": "Balance evolution",
		"dash.by_category": "Expenses by category",
		"dash.in_out": "Income x Expenses",
		"dash.top_wishes": "Top Wishes",
		"dash.month_limits": "Limits this month",
		"dash.cashflow": "Cash Flow (with projection)",
		"dash.cf_month": "Month",
		"dash.cf_opening": "Opening Balance",
		"dash.cf_income": "Income",
		"dash.cf_expense": "Expenses",
		"dash.cf_closing": "Result",
		"dash.welcome": "Welcome to %s!\nAdd your first transaction — the charts show up on their own.",
		"dash.first_transaction": "First transaction",
		"dash.no_wishes": "No wishes yet.",
		"dash.create_wish": "Create wish",
		"dash.no_limits": "No limits defined.",
		"dash.set_limits": "Set limits",
		"dash.filter_hint": "Filter: %s — open Transactions and pick the category.",

		# --- transactions
		"tx.title": "Transaction",
		"tx.new": "New transaction",
		"tx.edit": "Edit transaction",
		"tx.search": "Search…  Ctrl+F",
		"tx.all_categories": "All categories",
		"tx.col_date": "Date",
		"tx.col_name": "Name",
		"tx.col_category": "Category",
		"tx.col_type": "Type",
		"tx.col_orig": "Original Value",
		"tx.col_method": "Method",
		"tx.col_value": "Value",
		"tx.col_notes": "Notes",
		"tx.col_actions": "Actions",
		"tx.installments": "Installments",
		"tx.empty": "No transactions in this period.",
		"tx.name_required": "Name is required.",
		"tx.amount_required": "Amount must be greater than zero.",
		"tx.category_required": "Pick a category.",
		"tx.no_category_for_type": "Create a category of this type first.",
		"tx.deleted": "Transaction deleted.",
		"tx.installment_deleted": "Installment deleted.",
		"tx.installments_deleted": "%d installments deleted.",
		"tx.delete_group": "This transaction is installment %d/%d.\nDelete ALL installments?",
		"tx.delete_all": "All",
		"tx.delete_one": "Only this one",
		"tx.confirm_delete": "Delete \"%s\"?",
		"tx.limit_left": "%s: %s left this month",

		# --- categories & limits
		"cat.title": "Category",
		"cat.new": "New category",
		"cat.empty": "No categories — create the first one.",
		"cat.in_use": "Category in use by transactions — edit them before deleting.",
		"cat.limits_title": "Limits this month",
		"cat.limit": "Limit",
		"cat.limit_dialog": "Monthly limit — %s",
		"cat.cap": "Cap",
		"cat.rollover": "Rollover",
		"cat.spent": "Spent",
		"cat.available": "Available",
		"cat.no_limit": "no limit set",
		"cat.transfer": "Transfer between limits",
		"cat.transfer_need_two": "Create at least two limits to transfer.",
		"cat.transfer_done": "Transfer registered.",

		# --- wishes
		"wish.new": "New Wish",
		"wish.new_sub": "New sub-wish",
		"wish.add_sub": "Add sub-wish",
		"wish.empty": "No wishes yet — create your first dream.",
		"wish.show_archived": "Show archived",
		"wish.deposit": "Deposit",
		"wish.withdraw": "Withdraw",
		"wish.bought": "Bought it!",
		"wish.of": "%s of %s",
		"wish.missing": "missing %s",
		"wish.target": "target: %s",
		"wish.composite": "Composite wish (goal = sum of children)",
		"wish.goal_required": "Set the goal (or mark it as composite).",
		"wish.no_deposits": "No deposits yet.",
		"wish.free_balance": "Free balance: %s",
		"wish.over_free": "Careful: deposit is larger than the free balance (%s).",
		"wish.complete_title": "Bought it!",
		"wish.complete_body": "Generate an expense of %s and archive \"%s\"?",
		"wish.complete_ok": "Generate and archive",
		"wish.complete_archive": "Archive only",
		"wish.completed": "%s complete! Goal reached!",
		"wish.simulator": "Simulator",
		"wish.monthly_deposit": "Monthly deposit:",
		"wish.sim_result": "Depositing %s/month, you finish in %s",
		"wish.priority": "Priority",
		"wish.priority_low": "Low",
		"wish.priority_normal": "Normal",
		"wish.priority_high": "High",
		"wish.priority_critical": "Critical",
		"wish.icon_color": "Icon color",
		"wish.archive": "Archive",
		"wish.unarchive": "Restore",
		"wish.delete": "Delete",
		"wish.archive_title": "Archive wish",
		"wish.delete_title": "Delete wish",
		"wish.archive_confirm": "Archive \"%s\"?\nIt leaves the list but its history is kept.",
		"wish.delete_confirm": "Permanently delete \"%s\"?\nThis cannot be undone.",
		"wish.release_note": "\n%s goes back to your Free Balance.",
		"wish.release_note_sub": "\n%s from its sub-wishes goes back to your Free Balance.",
		"wish.archived_toast": "\"%s\" archived.",
		"wish.deleted_toast": "\"%s\" deleted.",
		"wish.released_toast": " %s released.",
		"wish.deposit_into": "Deposit into",
		"wish.pick_target": "Pick which wish receives the deposit",

		# --- recurring
		"rec.incomes": "Incomes",
		"rec.costs": "Fixed Costs",
		"rec.income": "Income",
		"rec.cost": "Cost",
		"rec.pending": "Pending confirmation this month",
		"rec.no_incomes": "No income registered — start with your salary.",
		"rec.no_costs": "No fixed costs — add rent, subscriptions, tuition…",
		"rec.kind_fixed": "Fixed",
		"rec.kind_variable": "Variable",
		"rec.kind_fixed_variable": "Fixed-variable",
		"rec.active_from": "Active from",
		"rec.fill_fields": "Fill in name and amount.",

		# --- settings
		"set.app": "Application",
		"set.project": "Project",
		"set.theme": "Theme",
		"set.font": "Font",
		"set.language": "Language",
		"set.date_format": "Date format",
		"set.autosave": "Autosave",
		"set.autosave_interval": "Autosave interval",
		"set.project_name": "Project name",
		"set.rate": "USD -> BRL rate",
		"set.salary_usd": "Base salary (USD)",
		"set.salary_brl": "Base salary (BRL)",
		"set.hours": "Hours per day",
		"set.applied": "Settings applied.",
		"set.theme_applied": "Theme applied.",
		"set.font_applied": "Font applied.",
		"set.language_applied": "Language applied.",
		"set.date_applied": "Date format applied.",
		"set.name_required": "The project needs a name.",
		"set.theme_default_font": "Theme default",
		"set.tab_appearance": "Appearance",
		"set.tab_preferences": "Preferences",
		"set.tab_project": "Project",
	},

	"pt": {
		# --- generic
		"generic.save": "Salvar",
		"generic.cancel": "Cancelar",
		"generic.edit": "Editar",
		"generic.delete": "Excluir",
		"generic.confirm": "Confirmar",
		"generic.close": "Fechar",
		"generic.apply": "Aplicar",
		"generic.add": "Adicionar",
		"generic.details": "Detalhes",
		"generic.name": "Nome",
		"generic.amount": "Valor",
		"generic.value": "Valor",
		"generic.type": "Tipo",
		"generic.category": "Categoria",
		"generic.method": "Método",
		"generic.date": "Data",
		"generic.notes": "Observações",
		"generic.month": "Mês",
		"generic.total": "Total",
		"generic.none": "Nenhum",
		"generic.all": "Todos",
		"generic.undo": "Desfazer",
		"generic.required": "Este campo é obrigatório.",
		"generic.expand": "Expandir",
		"generic.collapse": "Recolher",

		"type.income": "Entrada",
		"type.expense": "Saída",
		"method.credit": "Crédito",
		"method.debit": "Débito",
		"method.pix": "Pix",
		"method.cash": "Dinheiro",

		"nav.dashboard": "Dashboard",
		"nav.transactions": "Lançamentos",
		"nav.wishes": "Wishes",
		"nav.categories": "Categorias & Limites",
		"nav.recurring": "Recorrentes",
		"nav.settings": "Configurações",
		"nav.save_project": "Salvar   Ctrl+S",
		"nav.close_project": "Fechar projeto",
		"nav.collapse": "Recolher menu",
		"nav.expand": "Expandir menu",
		"nav.saved": "salvo",
		"nav.unsaved": "alterações não salvas",
		"nav.autosave_off": "(autosave desligado)",

		"menu.new_project": "Novo Projeto",
		"menu.open": "Abrir…",
		"menu.recent": "RECENTES",
		"menu.name_required": "Dê um nome ao projeto.",
		"menu.month_invalid": "Mês inicial deve ser AAAA-MM (ex.: 2026-04).",

		"dash.balance": "SALDO TOTAL",
		"dash.free": "SALDO LIVRE",
		"dash.income": "ENTRADAS",
		"dash.expense": "SAÍDAS",
		"dash.balance_evolution": "Evolução do saldo",
		"dash.by_category": "Gastos por categoria",
		"dash.in_out": "Entradas x Saídas",
		"dash.top_wishes": "Top Wishes",
		"dash.month_limits": "Limites do mês",
		"dash.cashflow": "Fluxo de Caixa (com projeção)",
		"dash.cf_month": "Mês",
		"dash.cf_opening": "Saldo Anterior",
		"dash.cf_income": "Entradas",
		"dash.cf_expense": "Saídas",
		"dash.cf_closing": "Resultado",
		"dash.welcome": "Bem-vindo ao %s!\nComece lançando sua primeira movimentação — os gráficos aparecem sozinhos.",
		"dash.first_transaction": "Primeiro lançamento",
		"dash.no_wishes": "Nenhum wish ainda.",
		"dash.create_wish": "Criar wish",
		"dash.no_limits": "Nenhum limite definido.",
		"dash.set_limits": "Definir limites",
		"dash.filter_hint": "Filtro: %s — abra Lançamentos e selecione a categoria.",

		"tx.title": "Lançamento",
		"tx.new": "Novo lançamento",
		"tx.edit": "Editar lançamento",
		"tx.search": "Buscar…  Ctrl+F",
		"tx.all_categories": "Todas as categorias",
		"tx.col_date": "Data",
		"tx.col_name": "Nome",
		"tx.col_category": "Categoria",
		"tx.col_type": "Tipo",
		"tx.col_orig": "Valor Original",
		"tx.col_method": "Método",
		"tx.col_value": "Valor",
		"tx.col_notes": "Observações",
		"tx.col_actions": "Ações",
		"tx.installments": "Parcelas",
		"tx.empty": "Nenhum lançamento neste período.",
		"tx.name_required": "Nome é obrigatório.",
		"tx.amount_required": "Valor deve ser maior que zero.",
		"tx.category_required": "Escolha uma categoria.",
		"tx.no_category_for_type": "Crie uma categoria desse tipo primeiro.",
		"tx.deleted": "Lançamento excluído.",
		"tx.installment_deleted": "Parcela excluída.",
		"tx.installments_deleted": "%d parcelas excluídas.",
		"tx.delete_group": "Este lançamento é a parcela %d/%d.\nExcluir TODAS as parcelas?",
		"tx.delete_all": "Todas",
		"tx.delete_one": "Só esta",
		"tx.confirm_delete": "Excluir \"%s\"?",
		"tx.limit_left": "%s: %s restantes este mês",

		"cat.title": "Categoria",
		"cat.new": "Nova categoria",
		"cat.empty": "Sem categorias — crie a primeira.",
		"cat.in_use": "Categoria em uso por lançamentos — edite-os antes de excluir.",
		"cat.limits_title": "Limites do mês",
		"cat.limit": "Limite",
		"cat.limit_dialog": "Limite mensal — %s",
		"cat.cap": "Teto",
		"cat.rollover": "Sobras",
		"cat.spent": "Gasto",
		"cat.available": "Disponível",
		"cat.no_limit": "sem limite definido",
		"cat.transfer": "Transferir entre limites",
		"cat.transfer_need_two": "Crie pelo menos dois limites para transferir.",
		"cat.transfer_done": "Transferência registrada.",

		"wish.new": "Novo Wish",
		"wish.new_sub": "Novo sub-wish",
		"wish.add_sub": "Adicionar sub-wish",
		"wish.empty": "Nenhum wish ainda — crie seu primeiro sonho.",
		"wish.show_archived": "Mostrar arquivados",
		"wish.deposit": "Aportar",
		"wish.withdraw": "Retirar",
		"wish.bought": "Comprei!",
		"wish.of": "%s de %s",
		"wish.missing": "falta %s",
		"wish.target": "alvo: %s",
		"wish.composite": "Wish composto (meta = soma dos filhos)",
		"wish.goal_required": "Defina a meta (ou marque como composto).",
		"wish.no_deposits": "Nenhum aporte ainda.",
		"wish.free_balance": "Saldo livre: %s",
		"wish.over_free": "Atenção: aporte maior que o saldo livre (%s).",
		"wish.complete_title": "Comprei!",
		"wish.complete_body": "Gerar um lançamento de saída de %s e arquivar \"%s\"?",
		"wish.complete_ok": "Gerar e arquivar",
		"wish.complete_archive": "Só arquivar",
		"wish.completed": "%s completo! Meta atingida!",
		"wish.simulator": "Simulador",
		"wish.monthly_deposit": "Aporte mensal:",
		"wish.sim_result": "Aportando %s/mês, você conclui em %s",
		"wish.priority": "Prioridade",
		"wish.priority_low": "Baixa",
		"wish.priority_normal": "Normal",
		"wish.priority_high": "Alta",
		"wish.priority_critical": "Crítica",
		"wish.icon_color": "Cor do ícone",
		"wish.archive": "Arquivar",
		"wish.unarchive": "Restaurar",
		"wish.delete": "Excluir",
		"wish.archive_title": "Arquivar wish",
		"wish.delete_title": "Excluir wish",
		"wish.archive_confirm": "Arquivar \"%s\"?\nEle sai da lista, mas o histórico é mantido.",
		"wish.delete_confirm": "Excluir \"%s\" definitivamente?\nEsta ação não pode ser desfeita.",
		"wish.release_note": "\n%s volta para o seu Saldo Livre.",
		"wish.release_note_sub": "\n%s dos sub-wishes volta para o seu Saldo Livre.",
		"wish.archived_toast": "\"%s\" arquivado.",
		"wish.deleted_toast": "\"%s\" excluído.",
		"wish.released_toast": " %s liberado.",
		"wish.deposit_into": "Aportar em",
		"wish.pick_target": "Escolha qual wish recebe o aporte",

		"rec.incomes": "Rendas",
		"rec.costs": "Custos Fixos",
		"rec.income": "Renda",
		"rec.cost": "Custo",
		"rec.pending": "Pendentes de confirmação neste mês",
		"rec.no_incomes": "Nenhuma renda cadastrada — comece pelo seu salário.",
		"rec.no_costs": "Nenhum custo fixo — cadastre aluguel, assinaturas, faculdade…",
		"rec.kind_fixed": "Fixo",
		"rec.kind_variable": "Variável",
		"rec.kind_fixed_variable": "Fixo-variável",
		"rec.active_from": "Ativo desde",
		"rec.fill_fields": "Preencha nome e valor.",

		"set.app": "Aplicação",
		"set.project": "Projeto",
		"set.theme": "Tema",
		"set.font": "Fonte",
		"set.language": "Idioma",
		"set.date_format": "Formato de data",
		"set.autosave": "Autosave",
		"set.autosave_interval": "Intervalo do autosave",
		"set.project_name": "Nome do projeto",
		"set.rate": "Cotação USD -> BRL",
		"set.salary_usd": "Salário base (USD)",
		"set.salary_brl": "Salário base (BRL)",
		"set.hours": "Horas por dia",
		"set.applied": "Configurações aplicadas.",
		"set.theme_applied": "Tema aplicado.",
		"set.font_applied": "Fonte aplicada.",
		"set.language_applied": "Idioma aplicado.",
		"set.date_applied": "Formato de data aplicado.",
		"set.name_required": "O projeto precisa de um nome.",
		"set.theme_default_font": "Padrão do tema",
		"set.tab_appearance": "Aparência",
		"set.tab_preferences": "Preferências",
		"set.tab_project": "Projeto",
	},
}

const MONTH_NAMES := {
	"en": ["January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"],
	"pt": ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
		"Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"],
}

const MONTH_SHORT := {
	"en": ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
	"pt": ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
		"Jul", "Ago", "Set", "Out", "Nov", "Dez"],
}

func _ready() -> void:
	# App loads after this autoload, so the stored language is read from disk here
	# rather than through App.app_settings, which does not exist yet.
	var stored := _read_stored_language()
	current = stored if _STRINGS.has(stored) else DEFAULT_LANGUAGE

## Translates a key. Unknown keys fall back to English, then to the key itself so
## a missing string is visible in the UI instead of silently rendering empty.
func t(key: String) -> String:
	var table: Dictionary = _STRINGS.get(current, {})
	if table.has(key):
		return table[key]
	var fallback: Dictionary = _STRINGS.get(DEFAULT_LANGUAGE, {})
	if fallback.has(key):
		return fallback[key]
	push_warning("Lang: missing key '%s'" % key)
	return key

## Convenience for keys that carry a %s placeholder.
func tf(key: String, args) -> String:
	return t(key) % args

func set_language(id: String) -> void:
	if not _STRINGS.has(id) or id == current:
		return
	current = id
	App.set_app_setting("language", id)
	language_changed.emit()

func month_names() -> Array:
	return MONTH_NAMES.get(current, MONTH_NAMES[DEFAULT_LANGUAGE])

func month_short() -> Array:
	return MONTH_SHORT.get(current, MONTH_SHORT[DEFAULT_LANGUAGE])

func _read_stored_language() -> String:
	if not FileAccess.file_exists("user://app_settings.json"):
		return DEFAULT_LANGUAGE
	var f := FileAccess.open("user://app_settings.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary and data.has("language"):
		return String(data["language"])
	return DEFAULT_LANGUAGE
