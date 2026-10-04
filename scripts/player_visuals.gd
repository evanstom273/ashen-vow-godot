extends Node2D
## AnimationPlayer owns pose channels; this compositor alone owns rig transforms.
var tuck: float = 0.0
var swing: float = 0.0
var fall: float = 0.0
var recoil: float = 0.0
var flash: float = 0.0
var actor: PlayerController
var roll_pivot: Node2D
var animator: AnimationPlayer
var weapon: Node2D
var blade: Polygon2D
var trail: Polygon2D
var timer: float = 0.0
var lean: float = 0.0
var scarf_motion: float = 0.0
var scarf_velocity: float = 0.0
var previous_velocity := Vector2.ZERO
var materials: Array[ShaderMaterial] = []
var walk_blend: float = 0.0
var walk_phase: float = 0.0
## Distance per footfall at the metre-scale movement speeds (128 units/m).
@export_range(10, 512, 1) var walk_step_distance: float = 192.0
@export_range(10, 512, 1) var sprint_step_distance: float = 256.0
var last_travel: float = 0.0
var hand_models: Dictionary = {}
@export var movement_vfx: MovementVFXDefinition = preload("res://data/vfx/player_movement.tres")
var melee_trails: Dictionary = {}
var melee_active: Dictionary = {}
var charge_glints: Dictionary = {}
var imbue_visuals: Dictionary = {}
const EQUIPPED_MODEL_SCALE: float = 0.65

func _ready() -> void:
	actor = get_parent() as PlayerController
	roll_pivot = Node2D.new()
	roll_pivot.name = "RollPivot"
	actor.rig.add_child(roll_pivot)
	roll_pivot.position = Vector2(0, -9)
	var root: Node2D = actor.rig.get_node("Root")
	root.reparent(roll_pivot)
	root.position = Vector2(0, 9)
	# Local sibling order keeps arms above the body without escaping world Y-sort.
	for arm_name: String in ["LeftArm", "RightArm"]:
		root.move_child(root.get_node(arm_name), -1)
	for node: Node in root.find_children("*", "Polygon2D", true, false):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/flash.gdshader")
		(node as Polygon2D).material = mat
		materials.append(mat)
	animator = AnimationPlayer.new()
	animator.root_node = NodePath("..")
	add_child(animator)
	var library := AnimationLibrary.new()
	library.add_animation("RESET", _animation(0.01, {"tuck": [[0, 0]], "swing": [[0, 0]], "fall": [[0, 0]], "recoil": [[0, 0]]}))
	var roll_time: float = actor.dodge_duration
	var strike: AttackDefinition = actor.attack
	var hurt_time: float = actor.vitals.stagger_duration
	library.add_animation("roll", _animation(roll_time, {"tuck": [[0, 0], [roll_time*0.133, 1], [roll_time*0.689, 1], [roll_time*0.889, 0.3], [roll_time, 0]]}))
	library.add_animation("attack", _animation(strike.duration(), {"swing": [[0, 0], [strike.windup*0.9, -0.9], [strike.windup+strike.active*0.4, 0.25], [strike.active_end(), 1.1], [strike.active_end()+strike.recovery*0.45, 0.8], [strike.duration(), 0]]}))
	library.add_animation("hurt", _animation(hurt_time, {"recoil": [[0, 0.4], [hurt_time*0.36, -0.2], [hurt_time, 0]], "tuck": [[0, 0], [hurt_time, 0]], "swing": [[0, 0], [hurt_time, 0]]}))
	library.add_animation("death", _animation(0.85, {"fall": [[0, 0], [0.18, 0.25], [0.6, 1], [0.85, 1]], "tuck": [[0, 0], [0.85, 0]], "swing": [[0, 0], [0.85, 0]]}))
	animator.add_animation_library("", library)
	weapon = Node2D.new()
	actor.add_child(weapon)
	blade = Polygon2D.new()
	blade.polygon = PackedVector2Array([Vector2(8,-2), Vector2(30,-3), Vector2(36,0), Vector2(30,3), Vector2(8,2)])
	blade.color = actor.equipped_weapon.blade_color
	root.get_node("RightArm/Weapon").color = actor.equipped_weapon.blade_color
	weapon.add_child(blade)
	blade.visible = false
	trail = Polygon2D.new()
	trail.color = actor.attack.slash_color
	var effect_material := ShaderMaterial.new()
	effect_material.shader = load("res://shaders/slash.gdshader")
	trail.material = effect_material
	weapon.add_child(trail)
	weapon.visible = false
	actor.loadout_changed.connect(_refresh_equipment)
	_refresh_equipment(&"right", 0)
	_refresh_equipment(&"left", 0)

func _make_model(definition: WeaponDefinition) -> Node2D:
	if definition == null: return null
	if definition.equipped_scene != null:
		var instance: Node = definition.equipped_scene.instantiate()
		if instance is Node2D: return instance as Node2D
		instance.free()
	var fallback := Polygon2D.new()
	fallback.polygon = blade.polygon
	fallback.color = definition.blade_color
	return fallback

func get_hand_model(hand: StringName) -> Node2D:
	var stored: Variant = hand_models.get(hand)
	return stored as Node2D if is_instance_valid(stored) else null

func _refresh_equipment(hand: StringName, _index: int) -> void:
	if hand != &"right" and hand != &"left": return
	_clear_melee(hand)
	_stop_imbue_visual(hand)
	var old: Node2D = get_hand_model(hand)
	if is_instance_valid(old):
		old.get_parent().remove_child(old)
		old.queue_free()
	var model: Node2D = _make_model(actor.get_selected_weapon(hand))
	hand_models[hand] = model
	if model == null: return
	var arm: Node2D = roll_pivot.get_node("Root/RightArm" if hand == &"right" else "Root/LeftArm")
	arm.add_child(model)
	# Added after the hand: above its grip, but on the actor's world sorting layer.
	model.z_index = 0
	model.z_as_relative = true
	model.position = Vector2(0, 10)
	model.rotation = -0.8 if hand == &"right" else 0.8
	model.scale = Vector2.ONE * EQUIPPED_MODEL_SCALE

func _stop_imbue_visual(hand: StringName) -> void:
	var stored: Variant = imbue_visuals.get(hand)
	# Shrine/death cleanup can free the node before this hand is refreshed.
	imbue_visuals.erase(hand)
	if is_instance_valid(stored):
		var effect := stored as Node2D
		if effect.has_method("stop"): effect.call("stop")
		else: effect.queue_free()

func _update_imbue_visual(hand: StringName, model: Node2D, effects: SpellEffects, token: int, attacking: bool) -> void:
	if effects == null or not effects.imbues.has(token):
		_stop_imbue_visual(hand)
		return
	var entry: Dictionary = effects.imbues[token]
	var profile: VFXDefinition = entry.get("profile") as VFXDefinition
	if profile == null: return
	var tip: Vector2 = model.to_global(Vector2(32, 0))
	var longest: float = 0.0
	for node: Node in model.find_children("*", "Polygon2D", true, false):
		var polygon := node as Polygon2D
		for point: Vector2 in polygon.polygon:
			var world: Vector2 = polygon.to_global(point)
			var local: Vector2 = model.to_local(world)
			if local.x > longest:
				longest = local.x
				tip = world
	var snapshot: Dictionary = {"kind": &"imbue", "origin": model.global_position, "tip": tip, "direction": (tip - model.global_position).normalized(), "owner_id": actor.get_instance_id()}
	var stored: Variant = imbue_visuals.get(hand)
	var effect: Node2D = stored as Node2D if is_instance_valid(stored) else null
	if not is_instance_valid(effect):
		effect = Feedback.spell_visual(profile, snapshot, actor)
		imbue_visuals[hand] = effect
	if is_instance_valid(effect):
		effect.global_position = model.global_position
		effect.global_rotation = 0
		effect.global_scale = Vector2.ONE * profile.art_scale
		if effect.has_method("update_visual"): effect.call("update_visual", snapshot)
	if attacking and actor._active_hand == hand:
		trail.color = profile.color

func movement_effect(event: String, at: Vector2, direction: Vector2) -> void:
	var key: String = {"dodge": "dodge_takeoff", "wake": "dodge_wake", "dust": "settle"}.get(event, event)
	var selected: VFXDefinition = movement_vfx.get(key) as VFXDefinition if movement_vfx != null else null
	Feedback.burst(at, event, direction, selected, actor.get_instance_id())

func _clear_melee(hand: StringName) -> void:
	var stored: Variant = melee_trails.get(hand)
	if is_instance_valid(stored): stored.clear()
	var glint: Variant = charge_glints.get(hand)
	if is_instance_valid(glint): glint.queue_free()
	charge_glints.erase(hand)
	melee_active[hand] = false

func _update_melee(hand: StringName, model: Node2D) -> void:
	var grip: Vector2 = model.global_position
	var tip: Vector2 = model.to_global(Vector2(30, 0))
	var longest: float = 0.0
	for node: Node in model.find_children("*", "Polygon2D", true, false):
		var polygon := node as Polygon2D
		for point: Vector2 in polygon.polygon:
			var at: Vector2 = polygon.to_global(point)
			if model.to_local(at).x > longest:
				longest = model.to_local(at).x
				tip = at
	var selected: VFXDefinition = actor.attack.melee_vfx
	var active: bool = actor.state == PlayerController.PlayerState.ATTACKING and actor._active_hand == hand and actor.action_time >= actor.attack.windup and actor.action_time < actor.attack.active_end()
	if actor.state == PlayerController.PlayerState.DEAD:
		_clear_melee(hand)
		return
	if active and selected != null:
		var stored: Variant = melee_trails.get(hand)
		var ribbon: MeleeTrail = stored as MeleeTrail if is_instance_valid(stored) else null
		if ribbon == null:
			ribbon = MeleeTrail.new()
			ribbon.set_meta("fx_owner", actor.get_instance_id())
			actor.add_child(ribbon)
			melee_trails[hand] = ribbon
		var tint: Color = Color.WHITE
		var effects := actor.get_node_or_null("SpellEffects") as SpellEffects
		var token: int = actor.weapon_token(hand)
		if effects != null and effects.imbues.has(token): tint = effects.imbues[token].color
		ribbon.sample(grip, tip, selected, tint)
		if not bool(melee_active.get(hand, false)) and selected.release_dust > 0:
			Feedback.burst(actor.to_global(Vector2(0, 10)), "dust", -actor.aim, movement_vfx.settle, actor.get_instance_id())
	melee_active[hand] = active
	var charging: bool = actor._active_hand == hand and actor.state in [PlayerController.PlayerState.ATTACK_HOLD, PlayerController.PlayerState.CHARGING]
	var stored_glint: Variant = charge_glints.get(hand)
	if charging:
		if not is_instance_valid(stored_glint):
			stored_glint = Feedback.physical_effect(tip, preload("res://data/vfx/windup_glint.tres"), &"glint", Vector2.UP, 1, actor, true)
			charge_glints[hand] = stored_glint
		if is_instance_valid(stored_glint): stored_glint.global_position = tip
	elif is_instance_valid(stored_glint):
		stored_glint.queue_free()
		charge_glints.erase(hand)

func _animation(length_seconds: float, tracks: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = length_seconds
	for property: String in tracks:
		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath(".:" + property))
		for key: Array in tracks[property]: anim.track_insert_key(track, float(key[0]), float(key[1]))
	return anim

func begin(action: String) -> void:
	if action == "attack":
		trail.color = actor.attack.slash_color
	animator.play(action)
	animator.advance(0)

func locomotion_sprint_blend() -> float:
	# Actual speed, not the input flag: both acceleration and braking blend poses.
	var extra_speed: float = actor.speed * (actor.sprint_multiplier - 1.0)
	if extra_speed <= 0.001: return 0.0
	return clampf((actor.get_real_velocity().length() - actor.speed) / extra_speed, 0.0, 1.0)

func current_step_distance() -> float:
	return lerpf(walk_step_distance, sprint_step_distance, locomotion_sprint_blend())

func _process(delta: float) -> void:
	if is_instance_valid(actor.transformation) and actor.transformation.phase != PlayerTransformation.Phase.HUMAN:
		weapon.hide()
		for hand: StringName in hand_models:
			_clear_melee(hand)
			_stop_imbue_visual(hand)
		last_travel = actor.travel
		return
	animator.speed_scale = 0.0 if actor.hit_stop > 0 else 1.0
	if actor.hit_stop > 0: return
	timer += delta
	flash = move_toward(flash, 0, delta * 7)
	for mat: ShaderMaterial in materials: mat.set_shader_parameter("flash", flash)
	var root: Node2D = roll_pivot.get_node("Root")
	var walking: bool = actor.uses_ground_locomotion() and actor.get_real_velocity().length() > 1
	walk_phase += maxf(0.0, actor.travel - last_travel) * PI / current_step_distance()
	last_travel = actor.travel
	walk_blend = move_toward(walk_blend, 1.0 if walking else 0.0, delta * 12.0)
	var stride: float = sin(walk_phase) * walk_blend
	var response: float = 1.0 - exp(-delta * 18)
	lean = lerpf(lean, clampf(actor.velocity.x / maxf(1.0, actor.speed * actor.sprint_multiplier), -1.0, 1.0) * 0.13, response)
	var acceleration: Vector2 = (actor.velocity - previous_velocity).limit_length(450)
	previous_velocity = actor.velocity
	scarf_velocity += (-scarf_motion * 95 - scarf_velocity * 15 + acceleration.x * 0.08) * delta
	scarf_motion = clampf(scarf_motion + scarf_velocity * delta, -0.28, 0.28)
	actor.rig.scale = Vector2(actor.facing, 1.0)
	actor.rig.rotation = 0
	actor.rig.position = Vector2(0, -absf(stride) * lerpf(1.4, 2.7, locomotion_sprint_blend()) + sin(timer * 2.1) * 0.35 * (1.0 - fall))
	roll_pivot.rotation = 0
	roll_pivot.scale = Vector2(1.0 + tuck * 0.08, 1.0 - tuck * 0.24)
	if actor.state == PlayerController.PlayerState.DODGING:
		var p: float = clampf(actor.action_time / actor.dodge_duration, 0, 1)
		var screen_sign: float = signf(actor.dodge_direction.x) if absf(actor.dodge_direction.x) > 0.1 else signf(actor.dodge_direction.y)
		# Parent is mirrored: compensate once to preserve screen-space spin.
		roll_pivot.rotation = TAU * smoothstep(0.04, 0.94, p) * screen_sign * actor.facing
		actor.rig.position.y -= sin(p * PI) * 3
	roll_pivot.rotation += fall * 1.45 + recoil
	actor.rig.position.y += fall * 12
	actor.rig.modulate.a = 1.0 - fall * 0.28
	if actor._protection > 0 and actor.state != PlayerController.PlayerState.DEAD:
		actor.rig.modulate.a = 0.8 + sin(timer * 35) * 0.2
	# Keep walking legs under combat poses without adding arm swing to the weapon.
	var arm_stride: float = stride if actor.state == PlayerController.PlayerState.NORMAL else 0.0
	var joints: Dictionary = {"LeftLeg": stride * 0.48 - tuck * 0.9, "RightLeg": -stride * 0.48 + tuck * 0.9, "LeftArm": -arm_stride * 0.3 + tuck * 1.25, "RightArm": arm_stride * 0.3 - tuck * 1.25 + swing, "Body": lean * actor.facing - stride * 0.025 + swing * 0.12, "Head": -lean * actor.facing * 0.6 + stride * 0.025}
	for joint: String in joints:
		var part: Node2D = root.get_node(joint)
		part.rotation = lerp_angle(part.rotation, float(joints[joint]), response)
	root.get_node("Body/Scarf").rotation = scarf_motion * actor.facing
	root.get_node("Body/CloakHighlight").position.x = scarf_motion * 2
	var attacking: bool = actor.state == PlayerController.PlayerState.ATTACKING
	root.get_node("RightArm/Weapon").visible = false
	for hand: StringName in hand_models:
		var model: Node2D = get_hand_model(hand)
		var arm: Node2D = root.get_node("RightArm" if hand == &"right" else "LeftArm")
		var hand_shape: Polygon2D = arm.get_node("Shape")
		# Sibling order, not global Z offsets, keeps equipment above hands.
		hand_shape.z_index = 0
		if is_instance_valid(model):
			model.visible = true
			model.z_index = 0
			var effects := actor.get_node_or_null("SpellEffects") as SpellEffects
			var token: int = actor.weapon_token(hand)
			model.modulate = effects.imbues[token].color if effects != null and effects.imbues.has(token) else Color.WHITE
			if attacking and actor._active_hand == hand:
				# Convert the swing direction into the mirrored arm's space.
				var swing_direction: Vector2 = actor.aim.rotated(swing)
				model.rotation = (arm.to_local(model.global_position + swing_direction) - model.position).angle()
			else:
				model.rotation = -0.8 if hand == &"right" else 0.8
			_update_imbue_visual(hand, model, effects, token, attacking)
			_update_melee(hand, model)
	weapon.visible = attacking
	if attacking:
		# Model size is presentation, not melee reach. Only the slash grows.
		weapon.scale = Vector2.ONE * EQUIPPED_MODEL_SCALE
		trail.scale = Vector2.ONE * actor.attack.reach / (42.0 * actor.scale.x / 1.25 * EQUIPPED_MODEL_SCALE)
		# The legacy slash must also remain within the actor's world layer.
		weapon.z_index = 0
		var active_arm: Node2D = root.get_node("RightArm" if actor._active_hand == &"right" else "LeftArm")
		weapon.global_position = active_arm.to_global(Vector2(0, 10))
		weapon.rotation = actor.aim.angle() + swing
		var points := PackedVector2Array()
		for i in 13:
			var angle: float = -1.0 + float(i) / 12.0 * 1.2
			points.append(Vector2.RIGHT.rotated(angle) * 34)
		for i in range(12, -1, -1):
			var angle: float = -1.0 + float(i) / 12.0 * 1.2
			var taper: float = maxf(0.03, sin(float(i) / 12.0 * PI))
			points.append(Vector2.RIGHT.rotated(angle) * (34.0 - 10.0 * taper))
		trail.polygon = points
		var fade_end: float = actor.attack.active_end() + actor.attack.recovery * 0.4
		trail.visible = false # No legacy motion-smear overlay.
		if actor.attack.melee_vfx != null: trail.visible = false
		(trail.material as ShaderMaterial).set_shader_parameter("fade", 1.0 - smoothstep(actor.attack.active_end(), fade_end, actor.action_time))
	var shadow: Node2D = actor.get_node("Shadow")
	shadow.scale = Vector2(1 + tuck * 0.15, 1 - tuck * 0.2)
	shadow.modulate.a = 1 - tuck * 0.25
