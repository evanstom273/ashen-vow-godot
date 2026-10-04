class_name PlayerTransformation
extends Node
## Orthogonal to combat state: future combat-capable forms can use existing actions.
enum Phase { HUMAN, ENTERING, ACTIVE, REVERTING }
var phase: Phase = Phase.HUMAN
var definition: TransformationDefinition
var actor: PlayerController
var visual: Node2D
var elapsed: float = 0.0
var emission_time: float = 0.0
var saved_layer: int
var saved_mask: int
var saved_rig_visible: bool
var saved_shadow_visible: bool
var zoom_factor: float = 1.0
var requested_zoom: float = 1.0
var camera_blend_duration: float = 0.7
var zoom_start: float = 1.0
var zoom_target: float = 1.0
var zoom_elapsed: float = 0.0
var transition_burst_played: bool = false
var dissolve_items: Array[Dictionary] = []

func _begin_dissolve() -> void:
	_end_dissolve()
	var items: Array[Node] = actor.rig.find_children("*", "Polygon2D", true, false)
	items.append(visual)
	for node: Node in items:
		var item := node as CanvasItem
		var effect := ShaderMaterial.new()
		effect.shader = preload("res://shaders/transformation_dissolve.gdshader")
		dissolve_items.append({"item": item, "original": item.material, "effect": effect, "form": item == visual})
		item.material = effect
	_update_dissolve(0.0)

func _update_dissolve(fraction: float) -> void:
	for entry: Dictionary in dissolve_items:
		var form_amount: float = 1.0 - fraction if phase == Phase.ENTERING else fraction
		var amount: float = form_amount if entry.form else 1.0 - form_amount
		(entry.effect as ShaderMaterial).set_shader_parameter("dissolve", amount)

func _end_dissolve() -> void:
	for entry: Dictionary in dissolve_items:
		if is_instance_valid(entry.item): entry.item.material = entry.original
	dissolve_items.clear()

func _ready() -> void:
	actor = get_parent() as PlayerController
	process_mode = Node.PROCESS_MODE_PAUSABLE

func allows(permission: String) -> bool:
	if phase == Phase.HUMAN: return true
	return phase == Phase.ACTIVE and bool(definition.get("allow_" + permission))

func toggle(selected: TransformationDefinition) -> void:
	if get_tree().paused or actor.state != PlayerController.PlayerState.NORMAL: return
	if phase == Phase.ACTIVE:
		if not can_land():
			actor.show_message("Cannot revert here — find clear, solid ground")
			return
		phase = Phase.REVERTING
	elif phase == Phase.HUMAN:
		if selected == null or selected.visual_scene == null or selected.movement == null:
			actor.show_message("Transformation is not configured")
			return
		if selected.collision_mask == 0:
			actor.show_message("Transformation needs a blocking collision mask")
			return
		var instance: Node = selected.visual_scene.instantiate()
		if not instance is Node2D:
			instance.free()
			actor.show_message("Transformation requires a Node2D visual")
			return
		definition = selected
		camera_blend_duration = definition.camera_blend_duration
		requested_zoom = definition.camera_zoom
		if definition.wheel_zoom_enabled:
			requested_zoom = clampf(requested_zoom, minf(definition.camera_zoom_min, definition.camera_zoom_max), maxf(definition.camera_zoom_min, definition.camera_zoom_max))
		saved_layer = Elevation.base_layer(actor)
		saved_mask = Elevation.base_mask(actor)
		saved_rig_visible = actor.rig.visible
		saved_shadow_visible = actor.get_node("Shadow").visible
		visual = instance as Node2D
		visual.z_as_relative = true
		visual.z_index = definition.visual_z_index
		actor.add_child(visual)
		if visual.has_method("setup"): visual.call("setup", definition)
		visual.visible = false
		phase = Phase.ENTERING
	else: return
	# Clear combat intent without discarding held sprint or touch-stick movement.
	actor._buffer = ""
	actor._buffer_time = 0.0
	actor._left_held = false
	actor._cancel_attack_candidate()
	actor.cancel_spell_channel()
	if not definition.preserve_transition_movement: actor.velocity = Vector2.ZERO
	elapsed = 0.0
	transition_burst_played = false
	actor.rig.visible = saved_rig_visible
	visual.visible = true
	_begin_dissolve()
	_emit(definition.revert_vfx if phase == Phase.REVERTING else definition.transform_vfx)

func can_land() -> bool:
	if definition == null: return false
	if not Elevation.of(actor).support_at(actor.global_position, Elevation.level(actor), Elevation.body_radius(actor)): return false
	var checked_shape: bool = false
	# Check every enabled humanoid body shape, including scale and local offset.
	for child: Node in actor.get_children():
		if not child is CollisionShape2D: continue
		var shape := child as CollisionShape2D
		if shape.disabled or shape.shape == null: continue
		checked_shape = true
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.collision_mask = saved_mask | definition.landing_mask
		query.exclude = [actor.get_rid()]
		query.collide_with_areas = true
		query.margin = 1.0
		if not Elevation.shapes(actor, query, Elevation.level(actor), 1).is_empty(): return false
	return checked_shape

func handle_zoom_input(event: InputEvent) -> bool:
	if definition == null or not definition.wheel_zoom_enabled or get_tree().paused: return false
	if not event is InputEventMouseButton: return false
	var mouse := event as InputEventMouseButton
	if mouse.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return false
	if mouse.pressed:
		var direction: float = 1.0 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
		requested_zoom = clampf(requested_zoom + direction * definition.camera_zoom_step * maxf(0.01, mouse.factor), minf(definition.camera_zoom_min, definition.camera_zoom_max), maxf(definition.camera_zoom_min, definition.camera_zoom_max))
	return true

func update_camera_zoom(delta: float) -> void:
	var desired: float = requested_zoom if phase in [Phase.ENTERING, Phase.ACTIVE] else 1.0
	if phase in [Phase.ENTERING, Phase.ACTIVE] and definition.camera_zoom_absolute:
		desired /= maxf(0.001, actor._base_camera_zoom.x)
	if not is_equal_approx(desired, zoom_target):
		zoom_start = zoom_factor
		zoom_target = desired
		zoom_elapsed = 0.0
	zoom_elapsed += delta
	zoom_factor = lerpf(zoom_start, zoom_target, smoothstep(0.0, maxf(0.1, camera_blend_duration), zoom_elapsed))

func tick(delta: float) -> void:
	if phase == Phase.HUMAN: return
	if actor.state == PlayerController.PlayerState.HURT:
		if phase == Phase.ENTERING:
			clear()
			return
		if phase == Phase.REVERTING:
			_end_dissolve()
			phase = Phase.ACTIVE
			visual.visible = true
			actor.rig.hide()
			actor.get_node("Shadow").hide()
	elapsed += delta
	if phase in [Phase.ENTERING, Phase.REVERTING]:
		if not definition.preserve_transition_movement: actor.velocity = Vector2.ZERO
		var fraction: float = smoothstep(0.0, definition.transition_duration, elapsed)
		_update_dissolve(fraction)
		if fraction >= 0.5 and not transition_burst_played:
			transition_burst_played = true
			_emit(definition.revert_vfx if phase == Phase.REVERTING else definition.transform_vfx)
		visual.visible = true
		actor.rig.visible = saved_rig_visible
		actor.get_node("Shadow").visible = actor.rig.visible and saved_shadow_visible
		if elapsed >= definition.transition_duration:
			if phase == Phase.ENTERING:
				_end_dissolve()
				actor.rig.hide()
				actor.get_node("Shadow").hide()
				Elevation.set_masks(actor, definition.collision_layer, definition.collision_mask)
				phase = Phase.ACTIVE
				actor.show_message(definition.display_name + " — Transform again to revert")
			elif can_land(): clear(definition.preserve_transition_movement)
			else:
				_end_dissolve()
				phase = Phase.ACTIVE
				visual.visible = true
				actor.rig.hide()
				actor.get_node("Shadow").hide()
				actor.show_message("Landing became obstructed")
	if phase == Phase.ACTIVE:
		emission_time += delta
		var interval: float = definition.sprint_vfx_interval if actor.sprinting else definition.movement_vfx_interval
		if actor.velocity.length() > definition.movement.walk_speed * 0.65 and emission_time >= interval:
			emission_time = 0.0
			_emit(definition.sprint_vfx if actor.sprinting and definition.sprint_vfx != null else definition.movement_vfx)

func _emit(profile: VFXDefinition) -> void:
	if profile != null:
		Feedback.physical_effect(actor.to_global(definition.visual_offset), profile, &"hit", -actor.velocity.normalized(), 1.0, null, false, false, actor.get_instance_id())

func clear(preserve_momentum: bool = false) -> void:
	if phase == Phase.HUMAN: return
	_end_dissolve()
	Elevation.set_masks(actor, saved_layer, saved_mask)
	if is_instance_valid(actor.rig): actor.rig.visible = saved_rig_visible
	var shadow := actor.get_node_or_null("Shadow") as CanvasItem
	if is_instance_valid(shadow): shadow.visible = saved_shadow_visible
	if is_instance_valid(visual): visual.queue_free()
	visual = null
	phase = Phase.HUMAN
	definition = null
	emission_time = 0.0
	if not preserve_momentum: actor.velocity = Vector2.ZERO

func _exit_tree() -> void:
	if is_instance_valid(actor): clear()
