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
var _overlay_mode: OptionButton
var _shelf: OptionButton
var _diagnostics: AcceptDialog
const OVERLAYS: Script = preload("res://addons/world_authoring/overlays.gd")
const SHELF: Array[String] = ["props/campfire", "props/shrine", "props/authored_reward", "vegetation/broadleaf", "vegetation/conifer", "vegetation/dead_tree", "vegetation/fern_bed", "props/lake", "props/low_wall", "props/stairs", "enemies/court_sentinel", "enemies/grave_warden", "enemies/greywatch_warden", "enemies/thorn_stalker", "enemies/ash_cantor", "landmarks/chapel", "landmarks/fort", "landmarks/watchtower", "landmarks/quarry"]

func _enter_tree() -> void:
	_ensure_editor_controls()
	if not scene_changed.is_connected(_scene_changed):
		scene_changed.connect(_scene_changed)
	set_process(true)

func _ensure_editor_controls() -> void:
	# Live script reloads can add fields without rerunning _enter_tree().
	# Rebuild an incomplete toolbar once, rather than leaving callbacks with nil UI.
	if _editor_controls_ready(): return
	var cutaway_enabled: bool = true
	var overlay_index: int = 0
	var shelf_index: int = 0
	if is_instance_valid(_cutaway): cutaway_enabled = _cutaway.button_pressed
	if is_instance_valid(_overlay_mode): overlay_index = _overlay_mode.selected
	if is_instance_valid(_shelf): shelf_index = _shelf.selected
	_release_editor_controls()
	_toolbar = HBoxContainer.new()
	var rebuild := Button.new()
	rebuild.text = "Rebuild terrain"
	rebuild.tooltip_text = "Rebuild generated terrain/dressing only; preserve authored props and enemies."
	rebuild.pressed.connect(_rebuild)
	_toolbar.add_child(rebuild)
	_cutaway = CheckButton.new()
	_cutaway.text = "Roof cutaway"
	_cutaway.button_pressed = cutaway_enabled
	_cutaway.tooltip_text = "Editor-only roof visibility. Does not change roofs in the running game."
	_cutaway.toggled.connect(_cutaway_changed)
	_toolbar.add_child(_cutaway)
	_overlay_mode = OptionButton.new()
	for label: String in ["Overlays off", "Collision / landing", "Encounters", "Effect geometry", "Navigation / floors"]: _overlay_mode.add_item(label)
	_overlay_mode.select(clampi(overlay_index, 0, _overlay_mode.item_count - 1))
	_overlay_mode.item_selected.connect(func(_index: int) -> void: update_overlays())
	_toolbar.add_child(_overlay_mode)
	_shelf = OptionButton.new()
	for path: String in SHELF: _shelf.add_item(path.get_file().capitalize())
	_shelf.select(clampi(shelf_index, 0, SHELF.size() - 1))
	_toolbar.add_child(_shelf)
	var insert := Button.new()
	insert.text = "Place asset"
	insert.tooltip_text = "Insert at the 2D view centre, under Actors when available. Undo/Redo supported. Assign unique persistent IDs in the Inspector."
	insert.pressed.connect(_insert_asset)
	_toolbar.add_child(insert)
	var audit := Button.new()
	audit.text = "Audit content"
	audit.pressed.connect(_audit)
	_toolbar.add_child(audit)
	_diagnostics = AcceptDialog.new()
	_diagnostics.title = "Authoring diagnostics — not runtime validation"
	EditorInterface.get_base_control().add_child(_diagnostics)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	set_force_draw_over_forwarding_enabled()
	_roof_time = 0.0
	update_overlays()

func _editor_controls_ready() -> bool:
	return is_instance_valid(_toolbar) and not _toolbar.is_queued_for_deletion() \
		and is_instance_valid(_cutaway) and not _cutaway.is_queued_for_deletion() \
		and is_instance_valid(_overlay_mode) and not _overlay_mode.is_queued_for_deletion() \
		and is_instance_valid(_shelf) and not _shelf.is_queued_for_deletion() \
		and is_instance_valid(_diagnostics) and not _diagnostics.is_queued_for_deletion()

func _release_editor_controls() -> void:
	if is_instance_valid(_toolbar):
		if _toolbar.get_parent() != null:
			remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
	if is_instance_valid(_diagnostics):
		_diagnostics.hide()
		_diagnostics.queue_free()
	_toolbar = null
	_cutaway = null
	_overlay_mode = null
	_shelf = null
	_diagnostics = null

func _exit_tree() -> void:
	set_process(false)
	if scene_changed.is_connected(_scene_changed):
		scene_changed.disconnect(_scene_changed)
	if is_instance_valid(_root): _restore_roofs(_root)
	_root = null
	_release_editor_controls()
	update_overlays()

func _scene_changed(root: Node) -> void:
	if is_instance_valid(_root) and _root != root: _restore_roofs(_root)
	_root = root
	_last_view = Rect2()
	_stable_time = 0.0
	_view_applied = false
	_roof_time = 0.0

func _process(delta: float) -> void:
	if not is_inside_tree(): return
	_ensure_editor_controls()
	var edited: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited): return
	if not is_instance_valid(_root) or _root != edited: _scene_changed(edited)
	_roof_time -= delta
	if _roof_time <= 0.0:
		_roof_time = 1.0
		_apply_roofs(_root, _cutaway.button_pressed)
		if _overlay_mode.selected > 0: update_overlays()
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

func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	if not is_inside_tree() or not _editor_controls_ready(): return
	if _overlay_mode.selected <= 0 or not is_instance_valid(_root): return
	var viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null: return
	OVERLAYS.draw(overlay, viewport.global_canvas_transform, EditorInterface.get_selection().get_selected_nodes(), _overlay_mode.selected)
	if _overlay_mode.selected == 3:
		var inspected: Object = EditorInterface.get_inspector().get_edited_object()
		var centre: Vector2 = viewport.global_canvas_transform.affine_inverse() * (Vector2(viewport.size) * 0.5)
		for node: Node in EditorInterface.get_selection().get_selected_nodes():
			if node is Node2D: centre = node.global_position; break
		OVERLAYS.draw_payload(overlay, viewport.global_canvas_transform, inspected, centre)

func _insert_asset() -> void:
	if not is_inside_tree() or not _editor_controls_ready() or not is_instance_valid(_root): return
	if _shelf.selected < 0 or _shelf.selected >= SHELF.size(): return
	var viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null: return
	var packed: PackedScene = load("res://scenes/" + SHELF[_shelf.selected] + ".tscn") as PackedScene
	if packed == null: return
	var node := packed.instantiate() as Node2D
	if node == null: return
	var parent: Node = _root.get_node_or_null("Actors")
	if parent == null: parent = _root
	var centre: Vector2 = viewport.global_canvas_transform.affine_inverse() * (Vector2(viewport.size) * 0.5)
	node.position = (parent as Node2D).to_local(centre) if parent is Node2D else centre
	# Inserting a scene is intentional editor work, never preview regeneration.
	var history: EditorUndoRedoManager = get_undo_redo()
	history.create_action("Place " + String(node.name), UndoRedo.MERGE_DISABLE, _root)
	history.add_do_method(parent, "add_child", node, true)
	history.add_do_property(node, "owner", _root)
	history.add_do_reference(node)
	history.add_undo_method(parent, "remove_child", node)
	history.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	EditorInterface.edit_node(node)

func _audit() -> void:
	if not is_inside_tree() or not _editor_controls_ready(): return
	var issues: Array[String] = ContentAudit.inspect(load("res://data/game_catalog.tres") as GameDataCatalog)
	if is_instance_valid(_root): OVERLAYS.audit_ids(_root, {}, issues)
	for child: Node in _diagnostics.get_children():
		if child is ScrollContainer: child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(690, 420)
	_diagnostics.add_child(scroll)
	var report := Label.new()
	report.text = "No authored configuration issues found. Parsing and runtime remain unverified." if issues.is_empty() else "\n".join(PackedStringArray(issues))
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(report)
	_diagnostics.popup_centered()
