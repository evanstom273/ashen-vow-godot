class_name PhysicalVFX
extends Node2D
## Cosmetic particles and geometry only. No gameplay callbacks.
var profile: VFXDefinition
var mode: StringName = &"dust"
var direction: Vector2 = Vector2.UP
var intensity: float = 1.0
var elapsed: float = 0.0
var extent: float = 22.0
var persistent: bool = false
var blood: bool = false
var emitter: GPUParticles2D
var lamp: PointLight2D
var seeds: Array[Vector2] = []
var spatial_scale: float = 1.0

func _ready() -> void:
	spatial_scale = WorldScale.actor_scale(self)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("physical_fx")
	z_as_relative = false
	z_index = -8 if mode in [&"dust", &"stain", &"rest", &"ambient"] else 3
	if mode == &"hit" and profile != null and profile.style in [VFXDefinition.Style.WOOD, VFXDefinition.Style.STONE]: z_index = -8
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if profile != null and profile.additive else CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	if blood: add_to_group("blood_fx")
	var random := RandomNumberGenerator.new()
	random.randomize()
	for _i in 7: seeds.append(Vector2(random.randf_range(-1, 1), random.randf_range(0.3, 1)))
	if mode in [&"stain", &"confirmation", &"glint"]: return
	if profile == null: return
	if not persistent and get_tree().get_nodes_in_group("transient_fx").size() >= 40: return
	if not persistent: add_to_group("transient_fx")
	_make_emitter()
	if not persistent: lamp = Feedback.effect_light(self, profile)

func _make_emitter() -> void:
	if profile.emission_amount <= 0: return
	emitter = GPUParticles2D.new()
	emitter.amount = maxi(1, roundi(profile.emission_amount * intensity))
	if not Feedback.budget_emitter(emitter, persistent):
		emitter.free()
		emitter = null
		return
	emitter.lifetime = maxf(0.05, profile.particle_lifetime)
	emitter.local_coords = false
	emitter.top_level = true
	emitter.one_shot = not persistent
	emitter.explosiveness = 0.0 if persistent else 1.0
	emitter.texture = profile.particle_texture if profile.particle_texture != null else (Feedback.fragment_texture if mode == &"hit" else Feedback.particle_texture)
	var bounds: Rect2 = Rect2(-1100, -700, 2200, 1400) if mode == &"ambient" else Rect2(-180, -220, 360, 400)
	emitter.visibility_rect = Rect2(bounds.position * spatial_scale, bounds.size * spatial_scale)
	var process: ParticleProcessMaterial = profile.particle_material.duplicate(true) as ParticleProcessMaterial if profile.particle_material != null else ParticleProcessMaterial.new()
	process.particle_flag_disable_z = true
	process.direction = Vector3(direction.x, direction.y, 0)
	process.spread = 35.0 if mode == &"hit" else 70.0
	process.initial_velocity_min = profile.emission_speed * 0.35
	process.initial_velocity_max = profile.emission_speed * intensity
	process.gravity = Vector3(0, profile.gravity if mode == &"hit" else -8.0, 0)
	process.damping_min = 20.0 if not persistent else 0.0
	process.damping_max = 40.0 if not persistent else 2.0
	process.scale_min = profile.particle_scale * 0.3
	process.scale_max = profile.particle_scale * 0.65
	process.angular_velocity_min = -180
	process.angular_velocity_max = 180
	process.color = profile.color
	if profile.smoke: process.color = Color(profile.color, 0.12)
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	if persistent:
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(820, 520, 0) if mode == &"ambient" else Vector3(10, 3, 0)
		process.gravity = Vector3(4, -3, 0)
	if mode == &"rest":
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		process.emission_ring_axis = Vector3(0, 0, 1)
		process.emission_ring_radius = 40
		process.emission_ring_inner_radius = 15
		process.emission_ring_height = 0
		process.direction = Vector3(0, -1, 0)
		process.spread = 25
	WorldScale.scale_particles(process, spatial_scale)
	emitter.process_material = process
	emitter.material = material
	emitter.set_meta("smoke", profile.smoke)
	add_child(emitter)
	emitter.global_position = global_position
	emitter.emitting = true

func _process(delta: float) -> void:
	if blood and not Feedback.blood_enabled:
		queue_free()
		return
	elapsed += delta
	if is_instance_valid(emitter): emitter.global_position = global_position
	var owner_id: int = int(get_meta("fx_owner", 0))
	if owner_id != 0 and not is_instance_valid(instance_from_id(owner_id)):
		queue_free()
		return
	if persistent:
		var rect: Rect2 = get_viewport_rect().grow(180)
		var screen_at: Vector2 = get_global_transform_with_canvas().origin
		var on_screen: bool = rect.has_point(screen_at)
		if mode == &"ambient":
			var corners: Transform2D = get_global_transform_with_canvas()
			var a: Vector2 = corners * Vector2(-820, -520)
			var b: Vector2 = corners * Vector2(820, 520)
			on_screen = Rect2(a, b - a).abs().intersects(rect)
		if is_instance_valid(emitter):
			emitter.emitting = on_screen and not (profile.smoke and Feedback.reduced_effects)
		visible = on_screen and not (profile.smoke and Feedback.reduced_effects)
	else:
		var lifetime: float = 12.0 if mode == &"stain" else (0.12 if mode == &"confirmation" else profile.lifetime)
		if elapsed >= lifetime:
			queue_free()
			return
	if is_instance_valid(lamp): lamp.visible = not Feedback.reduced_effects
	queue_redraw()

func _draw() -> void:
	if mode == &"confirmation":
		var alpha: float = maxf(0, 1.0 - elapsed / 0.12)
		draw_line(Vector2(-4, 0), Vector2(4, 0), Color(0.92, 0.88, 0.76, alpha), 1.3, true)
		draw_line(Vector2(0, -4), Vector2(0, 4), Color(0.92, 0.88, 0.76, alpha), 1.3, true)
		return
	if profile == null: return
	if mode == &"glint":
		var strength: float = 0.5 + 0.3 * sin(elapsed * 5)
		draw_line(Vector2(-4, 0), Vector2(4, 0), Color(profile.color, strength), 1.2, true)
		draw_line(Vector2(0, -5), Vector2(0, 5), Color(profile.core_color, strength), 1.2, true)
	elif mode == &"stain":
		var alpha: float = 0.7 * (1.0 - smoothstep(8, 12, elapsed))
		for i in seeds.size():
			var at: Vector2 = Vector2(seeds[i].x * extent, seeds[i].y * extent * 0.4)
			draw_set_transform(at, seeds[i].x, Vector2(1, 0.5) * (0.6 + seeds[i].y))
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -3), Vector2(2, -5), Vector2(7, 0), Vector2(2, 5), Vector2(-6, 2)]), Color(profile.color, alpha))
		draw_set_transform(Vector2.ZERO)
	elif mode == &"hit":
		var fade: float = maxf(0, 1.0 - elapsed / profile.lifetime)
		for i in 5:
			var velocity: Vector2 = direction.rotated(seeds[i].x * 0.6) * profile.emission_speed * seeds[i].y * intensity
			var at: Vector2 = velocity * elapsed + Vector2(0, profile.gravity * elapsed * elapsed * 0.5)
			var size: float = profile.fragment_size * (0.6 + seeds[i].y)
			if profile.style == VFXDefinition.Style.METAL:
				draw_line(at - velocity.normalized() * size * 3, at, Color(profile.core_color, fade), 1.2, true)
			else:
				draw_set_transform(at, seeds[i].x + elapsed * 4)
				draw_colored_polygon(PackedVector2Array([Vector2(-size, -size * 0.3), Vector2(size, 0), Vector2(-size * 0.4, size * 0.6)]), Color(profile.color, fade))
		draw_set_transform(Vector2.ZERO)
	elif mode == &"rest":
		var progress: float = clampf(elapsed / profile.lifetime, 0, 1)
		var radius: float = 15 + 100 * progress
		for i in 3:
			draw_arc(Vector2(0, 8), radius * (1 - i * 0.13), 0, TAU, 64, Color(profile.color, (1 - progress) * 0.5), 2, true)
	elif mode == &"idle":
		draw_arc(Vector2(0, 15), 30 + sin(elapsed * 1.5), 0, TAU, 48, Color(profile.color, 0.2), 1.2, true)
	elif mode == &"flame":
		for i in 5:
			var x: float = -12 + i * 6
			var height: float = 18 + sin(elapsed * 4 + i * 1.8) * 5 + sin(elapsed * 6 + i) * 3
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 0), Vector2(x + sin(elapsed * 3 + i) * 4, -height), Vector2(x + 5, 0)]), Color(profile.color, 0.85))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 2, 0), Vector2(x, -height * 0.6), Vector2(x + 2, 0)]), Color(profile.core_color, 0.9))
