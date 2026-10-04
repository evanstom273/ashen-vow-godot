class_name SceneContract
extends RefCounted
static func has_node(scene: PackedScene, path: String) -> bool:
	if scene == null: return false
	var state: SceneState = scene.get_state()
	for _depth in 16:
		if state == null: return false
		for index in state.get_node_count():
			if String(state.get_node_path(index)).trim_prefix("./") == path.trim_prefix("./"): return true
		state = state.get_base_scene_state()
	return false
## Inspect scene metadata without instantiation, _init(), AI, audio or particles.

static func root_script(scene: PackedScene) -> Script:
	if scene == null: return null
	var state: SceneState = scene.get_state()
	for _depth in 16:
		if state == null or state.get_node_count() == 0: return null
		for index in state.get_node_property_count(0):
			if state.get_node_property_name(0, index) == &"script":
				return state.get_node_property_value(0, index) as Script
		state = state.get_base_scene_state()
	return null

static func inherits_script(scene: PackedScene, global_class: StringName) -> bool:
	var script: Script = root_script(scene)
	for _depth in 32:
		if script == null: return false
		if script.get_global_name() == global_class: return true
		script = script.get_base_script()
	return false

static func root_is(scene: PackedScene, native_class: StringName) -> bool:
	if scene == null: return false
	var state: SceneState = scene.get_state()
	for _depth in 16:
		if state == null or state.get_node_count() == 0: return false
		var type: StringName = state.get_node_type(0)
		if not type.is_empty(): return type == native_class or ClassDB.is_parent_class(type, native_class)
		state = state.get_base_scene_state()
	return false
