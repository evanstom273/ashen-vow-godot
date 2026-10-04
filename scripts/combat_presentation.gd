class_name CombatPresentation
extends Node
var events: Array[Dictionary] = []
var cooldowns: Dictionary = {}
var offset := Vector2.ZERO
var zoom_factor: float = 1.0
var hud_strength: float = 0.0
var elapsed: float = 0.0
var global_cooldown: float = 0.0
var overlay: ColorRect
var screen_material: ShaderMaterial
var scene_id: int = 0

func _ready() -> void:
	# Runs during pause only to clear camera/rumble, never to advance effects.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas := CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_material = ShaderMaterial.new()
	screen_material.shader = preload("res://shaders/combat_screen.gdshader")
	overlay.material = screen_material
	canvas.add_child(overlay)
	overlay.hide()

func clear() -> void:
	events.clear()
	cooldowns.clear()
	offset = Vector2.ZERO
	zoom_factor = 1.0
	hud_strength = 0.0
	global_cooldown = 0.0
	if is_instance_valid(overlay): overlay.hide()
	var player: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("clear_camera_feedback"): player.call("clear_camera_feedback")
	for device: int in Input.get_connected_joypads(): Input.stop_joy_vibration(device)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree(): clear()

func request(profile: CombatFeedbackDefinition, at: Vector2, direction: Vector2, source: Node, receiver: Node, recurring: bool, elevation: Variant = null) -> void:
	if profile == null or get_tree().paused: return
	var player: Node = get_tree().get_first_node_in_group("player")
	var origin: Node = receiver if is_instance_valid(receiver) else source
	if is_instance_valid(player):
		if elevation != null:
			if not Elevation.occupies(player, int(elevation)): return
		elif is_instance_valid(origin) and not Elevation.compatible(player, origin): return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null: return
	var distance: float = camera.get_screen_center_position().distance_to(at)
	if distance > WorldScale.art_distance(650): return
	# Resource copies made for hits must retain a stable cooldown identity.
	var key: String = str(source.get_instance_id() if is_instance_valid(source) else 0) + ":" + profile.resource_name + ":" + str(recurring)
	if float(cooldowns.get(key, 0.0)) > 0 or global_cooldown > 0: return
	cooldowns[key] = profile.recurring_interval if recurring else profile.minimum_interval
	global_cooldown = 0.35 if recurring else 0.075
	var scale: float = (profile.recurring_scale if recurring else 1.0) * clampf(1.0 - distance / WorldScale.art_distance(900.0), 0.25, 1.0)
	if events.size() >= 8: events.pop_front()
	events.append({"profile": profile, "age": 0.0, "scale": scale, "direction": direction.normalized(), "recurring": recurring})
	if not recurring:
		if not profile.sound_key.is_empty(): Feedback.play(String(profile.sound_key), at, profile.sound_volume_db)
		if not profile.rumble_key.is_empty(): Feedback.play(String(profile.rumble_key), at, profile.sound_volume_db)
		if is_instance_valid(source) and source.get("hit_stop") != null:
			source.set("hit_stop", maxf(float(source.get("hit_stop")), profile.hit_stop))
		if is_instance_valid(receiver) and receiver.is_in_group("player"):
			hud_strength = maxf(hud_strength, profile.hud_response * (0.3 if Feedback.reduced_effects else 1.0))
		var reduction: float = 0.3 if Feedback.reduced_effects else 1.0
		for device: int in Input.get_connected_joypads():
			Input.start_joy_vibration(device, profile.vibration_low * reduction, profile.vibration_high * reduction, profile.vibration_duration)

func _process(delta: float) -> void:
	var current: Node = get_tree().current_scene
	var current_id: int = current.get_instance_id() if is_instance_valid(current) else 0
	if current_id != scene_id or get_tree().paused:
		clear()
		scene_id = current_id
		return
	elapsed += delta
	global_cooldown = maxf(0.0, global_cooldown - delta)
	for key: Variant in cooldowns.keys():
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
		if cooldowns[key] <= 0: cooldowns.erase(key)
	offset = Vector2.ZERO
	zoom_factor = 1.0
	hud_strength = move_toward(hud_strength, 0.0, delta * 5.0)
	var wash := Color(0, 0, 0, 0)
	var brightness: float = 0.0
	var contrast: float = 0.0
	var distortion: float = 0.0
	var chromatic: float = 0.0
	for i in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[i]
		var p: CombatFeedbackDefinition = event.profile
		event.age += delta
		if event.age >= p.duration:
			events.remove_at(i)
			continue
		var envelope: float = pow(1.0 - float(event.age) / maxf(0.01, p.duration), p.falloff) * float(event.scale)
		var motion: float = envelope * Feedback.shake_strength * (0.2 if Feedback.reduced_effects else 1.0)
		var phase: float = float(event.age) * p.frequency * TAU
		offset += Vector2(sin(phase), sin(phase * 1.37)) * p.shake_strength * motion
		offset += (event.direction as Vector2) * p.directional_kick * motion
		zoom_factor += p.zoom_punch * motion
		if not Feedback.reduced_effects and not bool(event.recurring):
			if p.flash_color.a * envelope > wash.a: wash = Color(p.flash_color, minf(0.08, p.flash_color.a) * envelope)
			brightness += p.brightness_pulse * envelope
			contrast += p.contrast_pulse * envelope
			distortion = maxf(distortion, p.distortion * envelope)
			chromatic = maxf(chromatic, p.chromatic * envelope)
	offset = offset.limit_length(12.0 * Feedback.shake_strength)
	zoom_factor = minf(zoom_factor, 1.035)
	overlay.visible = not Feedback.reduced_effects and (wash.a > 0.001 or absf(brightness) > 0.001 or contrast > 0.001 or distortion > 0.00001 or chromatic > 0.00001)
	screen_material.set_shader_parameter("elapsed", elapsed)
	screen_material.set_shader_parameter("wash", wash)
	screen_material.set_shader_parameter("brightness", clampf(brightness, -0.08, 0.08))
	screen_material.set_shader_parameter("contrast", minf(contrast, 0.12))
	screen_material.set_shader_parameter("distortion", minf(distortion, 0.003))
	screen_material.set_shader_parameter("chromatic", minf(chromatic, 0.002))
