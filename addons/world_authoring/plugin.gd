@tool
extends EditorPlugin
## Editor-only helper. Does not enter play mode, run AI, or save generated nodes.
var _toolbar: HBoxContainer
var _cutaway: CheckButton
var _root: Node
var _last_view := Rect2()
var _stable_time: float = 0.0
var _sample_time: float = 0.0
var _view_applied: bool = false
var _roof_time: float = 0.0

func _enter_tree() -> void:
	_toolbar = HBoxContainer.new()
	var rebuild := Button.new()
	rebuild.text = "Rebuild terrain"
	rebuild.tooltip_text = "Rebuild generated terrain/dressing only; preserve authored props and enemies."
	rebuild.pressed.connect(_rebuild)
	_toolbar.add_child(rebuild)
	_cutaway = CheckButton.new()
	_cutaway.text = "Roof cutaway"
	_cutaway.button_pressed = true
	_cutaway.tooltip_text = "Editor-only roof visibility. Does not change roofs in the running game."
	_cutaway.toggled.connect(_cutaway_changed)
	_toolbar.add_child(_cutaway)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	scene_changed.connect(_scene_changed)
	set_process(true)

func _exit_tree() -> void:
	if is_instance_valid(_root): _restore_roofs(_root)
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	_toolbar.queue_free()

func _scene_changed(root: Node) -> void:
	if is_instance_valid(_root) and _root != root: _restore_roofs(_root)
	_root = root
	_last_view = Rect2()
	_stable_time = 0.0
	_view_applied = false
	_roof_time = 0.0

func _process(delta: float) -> void:
	var edited: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited): return
	if not is_instance_valid(_root) or _root != edited: _scene_changed(edited)
	_roof_time -= delta
	if _roof_time <= 0.0:
		_roof_time = 1.0
		_apply_roofs(_root, _cutaway.button_pressed)
	if not _root.has_method("preview_editor_view"): return
	_sample_time += delta
	if _sample_time < 0.2: return
	var elapsed: float = _sample_time
	_sample_time = 0.0
	var viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null or viewport.size.x <= 0 or viewport.size.y <= 0: return
	var inverse: Transform2D = viewport.global_canvas_transform.affine_inverse()
	var view: Rect2 = inverse * Rect2(Vector2.ZERO, Vector2(viewport.size))
	if view.position.distance_to(_last_view.position) > 16.0 or view.size.distance_to(_last_view.size) > 16.0:
		_last_view = view
		_stable_time = 0.0
		_view_applied = false
		return
	_stable_time += elapsed
	if not _view_applied and _stable_time >= 0.5:
		_root.call("preview_editor_view", view)
		_view_applied = true

func _rebuild() -> void:
	if not is_instance_valid(_root) or not _root.has_method("preview_editor_view"): return
	_root.set("rebuild_region_preview", true)
	_view_applied = false

func _cutaway_changed(value: bool) -> void:
	if is_instance_valid(_root): _apply_roofs(_root, value)

func _apply_roofs(node: Node, hidden: bool) -> void:
	if node is BuildingRoof and node.preview_hidden != hidden:
		node.preview_hidden = hidden
		node.queue_redraw()
	for child: Node in node.get_children():
		# Generated scatter never contains roofs. Skip thousands of cosmetic children.
		if child.has_meta("region_generator") or child is StillwoodOverworld: continue
		_apply_roofs(child, hidden)

func _restore_roofs(node: Node) -> void:
	# Restore each building's own saved editor-preview choice on scene/plugin exit.
	if node is BuildingRoof:
		node.preview_hidden = false
		node.queue_redraw()
	for child: Node in node.get_children():
		if child.has_meta("region_generator") or child is StillwoodOverworld: continue
		_restore_roofs(child)
	if node is BuildingInterior: node._refresh_preview()
