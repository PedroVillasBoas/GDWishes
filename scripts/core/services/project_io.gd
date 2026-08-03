class_name ProjectIO
extends RefCounted
## Saves/loads .gdwish (JSON) files with rotating backups

const BACKUP_COUNT := 3

## Returns "" on success, or an error message
static func save(project: FinanceProject, path: String) -> String:
	project.last_saved = Time.get_datetime_string_from_system()
	_rotate_backups(path)
	var json := JSON.stringify(project.to_dict(), "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Não foi possível escrever em:\n%s\n(%s)" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(json)
	f.close()
	return ""

## Returs {"project": FinanceProject} if success or {"error": String}
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "Arquivo não encontrado:\n%s" % path}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "Não foi possível abrir:\n%s" % path}
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if data == null or not (data is Dictionary):
		return {"error": "Arquivo corrompido ou inválido.\nTente abrir um backup (%s.bak1)" % path}
	var version := int(data.get("schema_version", 0))
	if version > FinanceProject.SCHEMA_VERSION:
		return {"error": "Este arquivo foi criado por uma versão mais nova do GDWishes."}
	
	# (future schema migrations go here: if version == 1: ...)
	return {"project": FinanceProject.from_dict(data)}

static func _rotate_backups(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	for i in range(BACKUP_COUNT - 1, 0, -1):  # .bak2 -> .bak3, .bak1 -> .bak2
		var older := "%s.bak%d" % [path, i]
		if FileAccess.file_exists(older):
			dir.copy(older, "%s.bak%d" % [path, i + 1])
	dir.copy(path, path + ".bak1")
