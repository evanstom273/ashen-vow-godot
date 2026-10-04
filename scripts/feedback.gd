extends Node
## Bounded, reusable world feedback. Audio is synthesized once, never per frame.
var reduced_effects: bool = false
var blood_enabled: bool = true
var shake_strength: float = 1.0
var sounds: Dictionary = {}
var sound_definitions: Dictionary = {}
var light_texture: Texture2D
var particle_texture: Texture2D
var voices: Array[AudioStreamPlayer2D] = []
var rng := RandomNumberGenerator.new()
var fragment_texture: Texture2D
var effect_clock: float = 0.0
var presentation: CombatPresentation
var movement_profiles: MovementVFXDefinition = preload("res://data/vfx/player_movement.tres")

func present(profile: CombatFeedbackDefinition, at: Vector2, direction: Vector2 = Vector2.ZERO, source: Node = null, receiver: Node = null, recurring: bool = false, elevation: Variant = null) -> void:
	if is_instance_valid(presentation): presentation.request(profile, at, direction, source, receiver, recurring, elevation)

func _bind_elevation(effect: Node2D, owner_id: int = 0, parent: Node = null, value: Variant = null, follow: Node2D = null) -> void:
	var effect_owner: Variant = instance_from_id(owner_id) if owner_id != 0 else null
	var origin: Node = parent if is_instance_valid(parent) else (effect_owner as Node if is_instance_valid(effect_owner) else null)
	effect.set_meta(&"elevation_level", int(value) if value != null else Elevation.level(origin))
	Elevation.register_visual(effect, follow)
	# Top-level particle emitters have independent CanvasItem modulation chains.
	for child: Node in effect.find_children("*", "Node2D", true, false):
		if child is Node2D and (child.top_level or child is Light2D): Elevation.register_visual(child, effect)

func effect_light(parent: Node2D, profile: VFXDefinition) -> PointLight2D:
	if reduced_effects or profile.light_energy <= 0 or get_tree().get_nodes_in_group("vfx_lights").size() >= 8: return null
	var lamp := PointLight2D.new()
	lamp.add_to_group("vfx_lights")
	lamp.texture = light_texture
	lamp.texture_scale = profile.light_radius / 64.0
	lamp.color = profile.color
	lamp.energy = profile.light_energy
	lamp.shadow_enabled = false
	parent.add_child(lamp)
	Elevation.register_visual(lamp, parent)
	return lamp

func available_particles(ambient: bool = false) -> int:
	var allocated: int = 0
	var seen: Dictionary = {}
	for group: String in ["budget_particles", "spell_particles"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if not node is GPUParticles2D or seen.has(node.get_instance_id()): continue
			seen[node.get_instance_id()] = true
			if bool(node.get_meta("ambient_budget", false)) == ambient: allocated += node.amount
	return maxi(0, (256 if ambient else 1792) - allocated)

func available_spell_particles() -> int:
	return available_particles(false)

func budget_emitter(emitter: GPUParticles2D, ambient: bool = false) -> bool:
	var available: int = available_particles(ambient)
	if available <= 0: return false
	emitter.amount = mini(emitter.amount, available)
	emitter.set_meta("ambient_budget", ambient)
	emitter.add_to_group("budget_particles")
	emitter.process_mode = Node.PROCESS_MODE_PAUSABLE
	emitter.amount_ratio = 0.5 if reduced_effects else 1.0
	return true

func _process(delta: float) -> void:
	effect_clock += delta
	for node: Node in get_tree().get_nodes_in_group("budget_particles"):
		if node is GPUParticles2D:
			node.amount_ratio = 0.5 if reduced_effects else 1.0
			if bool(node.get_meta("smoke", false)) and reduced_effects: node.emitting = false

func _budget_scene_particles(root: Node) -> bool:
	var candidates: Array[Node] = root.find_children("*", "GPUParticles2D", true, false)
	if root is GPUParticles2D: candidates.push_front(root)
	var remaining: int = available_particles(false)
	for node: Node in candidates:
		var emitter := node as GPUParticles2D
		if remaining <= 0:
			if node == root: return false
			node.get_parent().remove_child(node)
			node.free()
			continue
		emitter.amount = mini(emitter.amount, remaining)
		remaining -= emitter.amount
		emitter.add_to_group("budget_particles")
		emitter.set_meta("ambient_budget", false)
		emitter.amount_ratio = 0.5 if reduced_effects else 1.0
	return true

func physical_effect(at: Vector2, profile: VFXDefinition, mode: StringName = &"dust", direction: Vector2 = Vector2.UP, intensity: float = 1.0, parent: Node = null, persistent: bool = false, blood: bool = false, owner_id: int = 0) -> PhysicalVFX:
	if get_tree().current_scene == null or profile == null: return null
	if not persistent and mode not in [&"confirmation", &"stain", &"glint"] and get_tree().get_nodes_in_group("transient_fx").size() >= 40: return null
	var effect := PhysicalVFX.new()
	effect.profile = profile
	effect.mode = mode
	effect.direction = direction
	effect.intensity = clampf(intensity, 0.65, 1.4)
	effect.persistent = persistent
	effect.blood = blood
	effect.set_meta("fx_owner", owner_id)
	effect.set_meta("persistent_vfx", persistent)
	var destination: Node = parent if parent != null else get_tree().current_scene
	var spatial_scale: float = WorldScale.actor_scale(parent) if parent is Node2D else profile.art_scale
	WorldScale.attach_art(effect, destination, at, spatial_scale)
	_bind_elevation(effect, owner_id, parent)
	return effect

func clear_physical_effects(owner_id: int = 0) -> void:
	for node: Node in get_tree().get_nodes_in_group("physical_fx"):
		if not bool(node.get_meta("persistent_vfx", false)) and (owner_id == 0 or int(node.get_meta("fx_owner", 0)) == owner_id): node.queue_free()
	for node: Node in get_tree().get_nodes_in_group("physical_trails"):
		if owner_id == 0 or int(node.get_meta("fx_owner", 0)) == owner_id: node.call("clear")

func clear_spell_visuals(owner_id: int = 0) -> void:
	for visual: Node in get_tree().get_nodes_in_group("spell_visuals"):
		if owner_id == 0 or int(visual.get_meta("spell_owner", 0)) == owner_id:
			visual.queue_free()

func spell_visual(profile: VFXDefinition, snapshot: Dictionary, parent: Node = null) -> Node2D:
	if profile == null or get_tree().current_scene == null: return null
	var kind: StringName = snapshot.get("kind", &"")
	var scene: PackedScene = profile.delivery_scene
	if kind == &"cast": scene = profile.cast_scene
	elif kind in [&"burst", &"expiry", &"completion", &"link"]: scene = profile.impact_scene
	if scene == null: scene = preload("res://scenes/fx_spell_visual.tscn")
	var instance: Node = scene.instantiate()
	if not _budget_scene_particles(instance):
		instance.free()
		return null
	if not instance is Node2D:
		instance.free()
		return null
	var visual := instance as Node2D
	visual.set_meta("spell_owner", int(snapshot.get("owner_id", 0)))
	visual.add_to_group("spell_visuals")
	visual.process_mode = Node.PROCESS_MODE_PAUSABLE
	if visual.has_method("setup"): visual.call("setup", profile, snapshot)
	var destination: Node = parent if parent != null else get_tree().current_scene
	WorldScale.attach_art(visual, destination, snapshot.get("origin", Vector2.ZERO), profile.art_scale)
	_bind_elevation(visual, int(snapshot.get("owner_id", 0)), parent, snapshot.get("elevation", null), parent as Node2D if parent is CharacterBody2D else null)
	if visual.has_method("update_visual"): visual.call("update_visual", snapshot)
	if kind in [&"cast", &"burst", &"expiry", &"completion", &"link"] and not visual is SpellVisual:
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = maxf(0.01, float(snapshot.get("duration", profile.lifetime)))
		visual.add_child(timer)
		timer.timeout.connect(visual.queue_free)
		timer.start()
	return visual

func spell_effect(at: Vector2, profile: VFXDefinition, mode: StringName = &"burst", follow: Node2D = null, extent: float = 160.0, duration: float = -1.0, owner_id: int = 0, elevation: Variant = null) -> Node2D:
	if profile == null or get_tree().current_scene == null: return null
	if get_tree().get_nodes_in_group("transient_fx").size() >= 40: return null
	if profile.spell_visuals:
		var source_object: Variant = instance_from_id(owner_id) if owner_id != 0 else null
		var origin: Node = follow if is_instance_valid(follow) else (source_object as Node if is_instance_valid(source_object) else null)
		var origin_level: int = int(elevation) if elevation != null else Elevation.level(origin)
		var visual: Node2D = spell_visual(profile, {"kind": mode, "origin": at, "radius": extent, "duration": duration if duration > 0 else profile.lifetime, "owner_id": owner_id, "elevation": origin_level})
		if visual is SpellVisual: visual.follow = follow
		elif visual != null and is_instance_valid(follow): visual.reparent(follow, true)
		if is_instance_valid(visual) and is_instance_valid(follow): _bind_elevation(visual, owner_id, follow, origin_level, follow)
		return visual
	var override_scene: PackedScene = profile.cast_scene if mode == &"cast" else (profile.impact_scene if mode == &"burst" else null)
	if override_scene != null:
		var custom: Node2D = custom_effect(override_scene, at, duration if duration > 0 else profile.lifetime, profile.art_scale)
		if custom != null:
			if is_instance_valid(follow):
				custom.reparent(follow, true)
			_bind_elevation(custom, owner_id, follow, elevation, follow)
			return custom
	var effect := Node2D.new()
	effect.set_script(preload("res://scripts/world_vfx.gd"))
	effect.set("profile", profile)
	effect.set("mode", mode)
	effect.set("follow", follow)
	effect.set("extent", extent / profile.art_scale)
	effect.set("duration", duration if duration > 0 else profile.lifetime)
	effect.add_to_group("transient_fx")
	WorldScale.attach_art(effect, get_tree().current_scene, at, profile.art_scale)
	_bind_elevation(effect, owner_id, follow, elevation, follow)
	return effect

func custom_effect(scene: PackedScene, at: Vector2, duration: float = 1.5, art_scale: float = WorldScale.ART_SCALE) -> Node2D:
	if scene == null or get_tree().get_nodes_in_group("transient_fx").size() >= 40: return null
	var instance: Node = scene.instantiate()
	if not _budget_scene_particles(instance):
		instance.free()
		return null
	if not instance is Node2D:
		instance.free()
		return null
	var effect := instance as Node2D
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	effect.add_to_group("transient_fx")
	WorldScale.attach_art(effect, get_tree().current_scene, at, art_scale)
	_bind_elevation(effect)
	var timer := Timer.new()
	timer.wait_time = maxf(0.01, duration)
	timer.one_shot = true
	effect.add_child(timer)
	timer.timeout.connect(effect.queue_free)
	timer.start()
	return effect

func clear_blood() -> void:
	for group: String in ["blood_fx", "blood_stains"]:
		for effect: Node in get_tree().get_nodes_in_group(group):
			if not effect.is_queued_for_deletion(): effect.queue_free()

func damage_number(receiver: Node2D, amount: int) -> void:
	if amount <= 0 or not is_instance_valid(receiver) or get_tree().current_scene == null: return
	var existing_id: int = int(receiver.get_meta("damage_number_id", 0))
	var candidate: Variant = instance_from_id(existing_id) if existing_id != 0 else null
	var number: DamageNumber
	if is_instance_valid(candidate) and candidate is DamageNumber and not candidate.is_queued_for_deletion():
		number = candidate as DamageNumber
	else:
		number = DamageNumber.new()
		get_tree().current_scene.add_child(number)
		receiver.set_meta("damage_number_id", number.get_instance_id())
	number.add_damage(amount, receiver)
	Elevation.register_visual(number, receiver)

func clear_damage_numbers() -> void:
	for number: Node in get_tree().get_nodes_in_group("damage_numbers"): number.queue_free()

func hit_effect(at: Vector2, source: Node, surface: int, incoming: AttackDefinition = null, accepted_damage: float = -1.0, receiver: Node = null) -> void:
	# Sustained effects already own their presentation; ticks are not new impacts.
	if incoming != null and incoming.periodic_damage: return
	if accepted_damage == 0.0: return
	var heading := Vector2.RIGHT
	if is_instance_valid(source) and source is Node2D:
		heading = (at - (source as Node2D).global_position).normalized()
	var owner_id: int = receiver.get_instance_id() if is_instance_valid(receiver) else 0
	if incoming != null:
		var selected_feedback: CombatFeedbackDefinition = incoming.feedback
		if is_instance_valid(source):
			var enemy: Variant = source.get("definition")
			if enemy is EnemyDefinition and enemy.attack_feedback != null: selected_feedback = enemy.attack_feedback
		if selected_feedback != null: present(selected_feedback, at, heading, source, receiver, incoming.recurring_feedback)
	# A cheap reusable confirmation remains even when particles or blood are disabled.
	if is_instance_valid(receiver):
		var confirmation: Node = receiver.get_node_or_null("HitConfirmation")
		if not is_instance_valid(confirmation) or confirmation.is_queued_for_deletion():
			confirmation = physical_effect(at, preload("res://data/vfx/stone.tres"), &"confirmation", heading, 1, receiver, false, false, owner_id)
			if confirmation != null: confirmation.name = "HitConfirmation"
		if is_instance_valid(confirmation):
			confirmation.set("elapsed", 0.0)
			(confirmation as Node2D).global_position = at
		var last: float = float(receiver.get_meta("last_hit_vfx", -100.0))
		if effect_clock - last < 0.12: return
		receiver.set_meta("last_hit_vfx", effect_clock)
	var intensity: float = 1.0 if accepted_damage < 0 else clampf(sqrt(accepted_damage / 100.0), 0.75, 1.35)
	var overridden: bool = incoming != null and incoming.vfx != null
	if overridden:
		var custom: Node2D = custom_effect(incoming.vfx, at)
		if is_instance_valid(custom): _bind_elevation(custom, owner_id, receiver)
		if is_instance_valid(custom):
			custom.add_to_group("physical_fx")
			custom.set_meta("fx_owner", owner_id)
			if is_instance_valid(receiver): receiver.tree_exiting.connect(custom.queue_free, CONNECT_ONE_SHOT)
	elif surface not in [0, 2]:
		var paths: Array[String] = ["flesh", "metal", "metal", "wood", "stone"]
		var profile: VFXDefinition = load("res://data/vfx/" + paths[clampi(surface, 0, 4)] + ".tres")
		physical_effect(at, profile, &"hit", heading, intensity, null, false, false, owner_id)
		if surface in [3, 4]:
			physical_effect(at + WorldScale.art_offset(Vector2(0, 8)), movement_profiles.footstep, &"dust", heading, intensity, null, false, false, owner_id)
	elif surface == 2:
		physical_effect(at, preload("res://data/vfx/metal.tres"), &"hit", heading, intensity, null, false, false, owner_id)
	if not blood_enabled or surface not in [0, 2]: return
	var blood_profile: VFXDefinition = preload("res://data/vfx/armored_blood.tres") if surface == 2 else preload("res://data/vfx/flesh.tres")
	physical_effect(at, blood_profile, &"hit", heading, intensity, null, false, true, owner_id)
	var stains: Array[Node] = get_tree().get_nodes_in_group("blood_stains")
	if stains.size() >= 64:
		var oldest: Node = stains[0]
		oldest.get_parent().remove_child(oldest)
		oldest.queue_free()
	var stain: PhysicalVFX = physical_effect(at + WorldScale.art_offset(heading * 10 + Vector2(0, 8)), blood_profile, &"stain", heading, intensity, null, false, true, owner_id)
	if stain != null:
		stain.extent = clampf(16.0 * intensity, 12, 18) if surface == 2 else clampf(22.0 * intensity, 18, 26)
		stain.add_to_group("blood_stains")

func _ready() -> void:
	presentation = CombatPresentation.new()
	add_child(presentation)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.seed = 817
	_inputs()
	for bus in ["Effects", "Ambience", "Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -15.0)
	light_texture = _radial(128)
	particle_texture = _radial(16)
	var fragment := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 8:
			if x >= y and x < 8 - y: fragment.set_pixel(x, y, Color.WHITE)
	fragment_texture = ImageTexture.create_from_image(fragment)
	for kind in ["step", "roll", "swing", "wood", "metal", "hurt", "death", "shrine", "tell", "wind", "fire", "rumble"]:
		sounds[kind] = _sound(kind)
	var library: ProceduralAudioLibrary = preload("res://data/environment/audio_library.tres")
	for definition: ProceduralSoundDefinition in library.events:
		if definition == null: continue
		sounds[String(definition.id)] = definition.synthesize()
		sound_definitions[String(definition.id)] = definition

func _inputs() -> void:
	var keys: Dictionary = {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "pause": [KEY_ESCAPE], "help": [KEY_TAB]}
	for action: String in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	for action: String in {"target_previous": MOUSE_BUTTON_WHEEL_UP, "target_next": MOUSE_BUTTON_WHEEL_DOWN}:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP if action == "target_previous" else MOUSE_BUTTON_WHEEL_DOWN
		if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _radial(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d: float = Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0.0, 1.0 - d), 2.0)))
	return ImageTexture.create_from_image(img)

func burst(at: Vector2, kind: String = "dust", direction: Vector2 = Vector2.UP, override_profile: VFXDefinition = null, owner_id: int = 0) -> void:
	var profile: VFXDefinition = override_profile
	if profile == null:
		match kind:
			"footstep": profile = movement_profiles.footstep
			"sprint": profile = movement_profiles.sprint
			"dodge": profile = movement_profiles.dodge_takeoff
			"wake": profile = movement_profiles.dodge_wake
			"death": profile = movement_profiles.death
			"shrine": profile = preload("res://data/vfx/shrine_rest.tres")
			_: profile = movement_profiles.settle
	physical_effect(at, profile, &"rest" if kind == "shrine" else &"dust", direction, 1.0, null, false, false, owner_id)

func ambient_emitter(smoke: bool = false) -> GPUParticles2D:
	# Compatibility factory for external callers; courtyard uses profile-owned effects.
	var effect := GPUParticles2D.new()
	effect.amount = 8
	effect.lifetime = 2.0
	effect.texture = light_texture if smoke else particle_texture
	var process := ParticleProcessMaterial.new()
	process.particle_flag_disable_z = true
	process.direction = Vector3(0, -1, 0)
	process.gravity = Vector3(2, -3, 0)
	process.initial_velocity_min = 8
	process.initial_velocity_max = 18
	process.color = Color(0.2, 0.2, 0.2, 0.1) if smoke else Color(0.6, 0.8, 0.7, 0.5)
	WorldScale.scale_particles(process, WorldScale.ART_SCALE)
	effect.top_level = true
	effect.local_coords = false
	effect.process_material = process
	effect.set_meta("smoke", smoke)
	if not budget_emitter(effect, true):
		effect.free()
		return null
	return effect

func play(kind: String, at: Vector2, volume: float = 0.0, emitter: Node = null, floor_level: Variant = null) -> void:
	if DisplayServer.get_name() == "headless": return
	if not is_instance_valid(get_tree().current_scene): return
	if kind == "step" and is_instance_valid(GameSession.actor):
		kind = "step_stone" if Elevation.level(GameSession.actor) != 0 or WorldClimate.sheltered else "step_grass"
	var definition: ProceduralSoundDefinition = sound_definitions.get(kind)
	var priority: int = definition.priority if definition != null else 2
	for index in range(voices.size() - 1, -1, -1):
		if not is_instance_valid(voices[index]): voices.remove_at(index)
	if not sounds.has(kind): return
	if voices.size() >= 18:
		var victim: int = -1
		var lowest: int = priority
		for index in voices.size():
			var value: int = int(voices[index].get_meta("priority", 0))
			if value < lowest: lowest = value; victim = index
		if victim < 0: return
		voices[victim].stop()
		voices[victim].queue_free()
		voices.remove_at(victim)
	var voice := AudioStreamPlayer2D.new()
	voice.set_meta("priority", priority)
	voice.stream = sounds[kind]
	# Ambient emitters use the looping fire stream directly; one-shot spell
	# playback must finish so it releases its voice slot.
	if kind == "fire":
		var one_shot: AudioStreamWAV = sounds[kind].duplicate() as AudioStreamWAV
		one_shot.loop_mode = AudioStreamWAV.LOOP_DISABLED
		voice.stream = one_shot
	voice.bus = definition.bus if definition != null else "Effects"
	voice.volume_db = volume - 10.0
	var variation: float = definition.pitch_variation if definition != null else 0.07
	voice.pitch_scale = rng.randf_range(1.0-variation, 1.0+variation)
	voice.max_distance = definition.audible_metres * 128.0 if definition != null else WorldScale.art_distance(1200.0)
	# Optional context keeps legacy event callers compatible while giving spells,
	# actors and impacts the same floor-aware attenuation as their presentation.
	if is_instance_valid(GameSession.actor):
		var origin_level: int = int(floor_level) if floor_level != null else Elevation.level(emitter)
		if (floor_level != null or is_instance_valid(emitter)) and not Elevation.occupies(GameSession.actor, origin_level): voice.volume_db -= 18.0
	if WorldClimate.sheltered and is_instance_valid(GameSession.actor) and at.distance_to(GameSession.actor.global_position) > 640.0: voice.volume_db -= 7.0
	get_tree().current_scene.add_child(voice)
	voice.global_position = at
	voices.append(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func _sound(kind: String) -> AudioStreamWAV:
	var duration: float = 0.15
	if kind in ["roll", "swing", "hurt", "tell"]: duration = 0.35
	if kind in ["shrine", "death"]: duration = 1.2
	if kind in ["wind", "fire"]: duration = 3.0
	if kind == "rumble": duration = 0.3
	var count: int = int(duration * 22050.0)
	var data := PackedByteArray()
	data.resize(count * 2)
	var smooth: float = 0.0
	for i in count:
		var t: float = float(i) / 22050.0
		var p: float = t / duration
		smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), 0.15)
		var value: float = smooth * exp(-p * 7.0)
		match kind:
			"rumble": value = (sin(t * TAU * 48.0) * 0.65 + smooth * 0.15) * sin(PI * minf(1.0, p * 5.0)) * exp(-p * 6.0)
			"shrine": value = (sin(t * TAU * 440.0) + sin(t * TAU * 660.0) * 0.5) * sin(PI * p) * exp(-p * 3.0) * 0.2
			"metal": value += sin(t * TAU * 930.0) * exp(-p * 18.0) * 0.25
			"wood", "step": value += sin(t * TAU * 130.0) * exp(-p * 15.0) * 0.4
			"tell": value = sin(t * TAU * (160.0 + 160.0 * p)) * sin(PI * p) * 0.2
			"wind": value = smooth * 0.16 + sin(t * TAU * 55.0) * 0.018
			"fire": value = smooth * 0.25
			"swing", "roll": value = smooth * sin(PI * p) * 0.8
			"death", "hurt": value += sin(t * TAU * (90.0 - p * 35.0)) * exp(-p * 7.0) * 0.3
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	if kind in ["wind", "fire"]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
