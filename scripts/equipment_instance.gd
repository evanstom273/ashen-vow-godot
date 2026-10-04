class_name EquipmentInstance
extends RefCounted
## Character-owned identity. Never use Resource identity as an owned-item ID.
var id: String = ""
var definition_id: StringName
var upgrade_level: int = 0

func to_record() -> Dictionary:
	return {"id": id, "definition": String(definition_id), "upgrade": upgrade_level}

static func from_record(record: Dictionary) -> EquipmentInstance:
	var item := EquipmentInstance.new()
	item.id = String(record.get("id", ""))
	item.definition_id = StringName(record.get("definition", ""))
	item.upgrade_level = clampi(int(record.get("upgrade", 0)), 0, 25)
	return item
