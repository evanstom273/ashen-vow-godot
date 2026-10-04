class_name SaveStore
extends RefCounted
## JSON only. Resource paths and objects are never deserialized from save data.
const SCHEMA: int = 1
const MAX_BYTES: int = 4194304
static var last_error: String = ""
static var _newer_schema: bool = false

static func read_document(path: String, validator: Callable = Callable()) -> Dictionary:
	last_error = ""
	_newer_schema = false
	var primary: Dictionary = _read_one(path)
	if _newer_schema:
		last_error = "This save belongs to a newer version; original files were preserved"
		return {}
	if not primary.is_empty() and (not validator.is_valid() or validator.call(primary)): return primary
	var backup: Dictionary = _read_one(path + ".bak")
	if _newer_schema:
		last_error = "This backup belongs to a newer version; original files were preserved"
		return {}
	if not backup.is_empty() and (not validator.is_valid() or validator.call(backup)):
		last_error = "Recovered the previous save backup"
		return backup
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		last_error = "Save could not be read; original files were not overwritten"
	return {}

static func _read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return {}
	var version: Variant = parsed.get("schema")
	if not (version is int or version is float) or not is_finite(float(version)): return {}
	if float(version) > SCHEMA: _newer_schema = true
	if float(version) != SCHEMA: return {}
	if not parsed.get("payload") is String or not parsed.get("checksum") is String: return {}
	var payload: String = parsed.payload
	if payload.sha256_text() != parsed.checksum: return {}
	var record: Variant = JSON.parse_string(payload)
	return record if record is Dictionary else {}

static func write_document(path: String, data: Dictionary, validator: Callable = Callable()) -> bool:
	last_error = ""
	if validator.is_valid() and not validator.call(data): return _failed("Invalid save state; previous save retained", ERR_INVALID_DATA)
	_newer_schema = false
	var primary: Dictionary = _read_one(path)
	_read_one(path + ".bak")
	if _newer_schema: return _failed("Cannot overwrite a newer save format", ERR_UNAVAILABLE)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK: return _failed("Cannot create save directory", directory_error)
	var payload: String = JSON.stringify(data)
	var envelope: String = JSON.stringify({"schema": SCHEMA, "payload": payload, "checksum": payload.sha256_text()})
	if envelope.to_utf8_buffer().size() > MAX_BYTES: return _failed("Save exceeds its size limit", ERR_OUT_OF_MEMORY)
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _failed("Cannot write save", FileAccess.get_open_error())
	file.store_string(envelope)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK: return _failed("Save write failed", write_error)
	# Only a verified primary may replace the recoverable backup. In particular,
	# loading a backup after primary corruption must not destroy that good backup.
	if not primary.is_empty() and (not validator.is_valid() or validator.call(primary)):
		var copy_error: Error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if copy_error != OK: return _failed("Cannot preserve save backup", copy_error)
		var backup_error: Error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if backup_error != OK: return _failed("Cannot replace save backup", backup_error)
	var replace_error: Error = DirAccess.rename_absolute(temporary, path)
	if replace_error != OK: return _failed("Cannot replace save; previous save retained", replace_error)
	return true

static func _failed(message: String, code: Error) -> bool:
	last_error = "%s (%s)" % [message, error_string(code)]
	push_warning(last_error)
	return false
