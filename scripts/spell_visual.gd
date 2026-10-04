class_name SpellVisual
extends Node2D
## Cosmetic-only snapshot consumer. Never queries targets or applies damage.
var profile: VFXDefinition
var frame: Dictionary = {}
var follow: Node2D
var age: float = 0.0
var stopped: bool = false
var tail_age: float = 0.0
var owner_id: int = 0
var particles: GPUParticles2D
var smoke_particles: GPUParticles2D
var lamp: PointLight2D
var samples: Array[Vector2] = []
var sample_ages: Array[float] = []
var ground: Node2D

func setup(value: VFXDefinition, snapshot: Dictionary) -> void:
	profile = value
	frame = snapshot.duplicate()
	owner_id = int(frame.get("owner_id", 0))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("spell_visuals")
	z_as_relative = false
	z_index = 34
	var additive := CanvasItemMaterial.new()
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Additive black is invisible; use opaque flame silhouettes with pale edges.
	if profile != null and profile.style == VFXDefinition.Style.DARK_FLAME:
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = additive
	ground = Node2D.new()
	ground.z_as_relative = false
	ground.z_index = -8
	ground.material = additive
	add_child(ground)
	ground.draw.connect(_draw_ground)
	if profile == null: return
	if get_tree().get_nodes_in_group("transient_fx").size() < 40:
		add_to_group("transient_fx")
		particles = _emitter(false)
		if profile.smoke and not Feedback.reduced_effects:
			smoke_particles = _emitter(true)
	lamp = Feedback.effect_light(self, profile)

func _emitter(smoke: bool) -> GPUParticles2D:
	if profile.emission_amount <= 0: return null
	var requested: int = maxi(1, ceili(float(profile.emission_amount) / (3.0 if smoke else 1.0)))
	if frame.get("kind", &"") == &"burn": requested = maxi(1, requested >> 2)
	var available: int = Feedback.available_spell_particles()
	if available <= 0: return null
	var emitter := GPUParticles2D.new()
	emitter.amount = mini(requested, available)
	emitter.amount_ratio = 0.5 if Feedback.reduced_effects else 1.0
	emitter.add_to_group("spell_particles")
	emitter.local_coords = false
	emitter.top_level = true
	emitter.lifetime = profile.particle_lifetime * (1.5 if smoke else 1.0)
	emitter.texture = profile.particle_texture if profile.particle_texture != null else Feedback.particle_texture
	emitter.visibility_rect = Rect2(-2200, -2200, 4400, 4400)
	var source: ParticleProcessMaterial = profile.particle_material
	var mat: ParticleProcessMaterial = source.duplicate(true) as ParticleProcessMaterial if source != null else ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.gravity = Vector3(0, -28 if smoke else -12, 0)
	mat.direction = Vector3(1, 0, 0)
	mat.spread = profile.emission_spread
	mat.initial_velocity_min = profile.emission_speed * 0.25
	mat.initial_velocity_max = profile.emission_speed
	mat.scale_min = profile.particle_scale * (2.0 if smoke else 0.35)
	mat.scale_max = profile.particle_scale * (4.0 if smoke else 1.0)
	mat.color = Color(0.16, 0.12, 0.18, 0.16) if smoke else (profile.accent_color if profile.style == VFXDefinition.Style.DARK_FLAME else profile.color)
	WorldScale.scale_particles(mat, profile.art_scale)
	emitter.process_material = mat
	var canvas := CanvasItemMaterial.new()
	canvas.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	canvas.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX if smoke else CanvasItemMaterial.BLEND_MODE_ADD
	emitter.material = canvas
	add_child(emitter)
	emitter.global_position = global_position
	if StringName(frame.get("kind", &"")) in [&"burst", &"completion", &"expiry", &"restore"]:
		emitter.one_shot = true
		emitter.explosiveness = 1.0
	emitter.emitting = true
	return emitter

func update_visual(snapshot: Dictionary) -> void:
	if stopped: return
	frame = snapshot.duplicate()
	global_position = snapshot.get("origin", global_position)
	_configure_emission()
	queue_redraw()
	if is_instance_valid(ground): ground.queue_redraw()

func _configure_emission() -> void:
	var kind: StringName = frame.get("kind", &"")
	var heading: Vector2 = frame.get("direction", Vector2.RIGHT)
	var radius: float = float(frame.get("radius", profile.visual_size * profile.art_scale))
	for emitter: GPUParticles2D in [particles, smoke_particles]:
		if not is_instance_valid(emitter): continue
		emitter.global_position = global_position
		emitter.global_rotation = 0.0
		var mat := emitter.process_material as ParticleProcessMaterial
		mat.direction = Vector3(heading.x, heading.y, 0)
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		if kind in [&"projectile", &"dash", &"wave"]:
			mat.direction = Vector3(-heading.x, -heading.y, 0)
			mat.spread = 25.0
		elif kind == &"burn":
			emitter.global_position = to_global(Vector2(0, -8))
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 20.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(8, 8, 0) * profile.art_scale
		elif kind == &"imbue":
			emitter.global_position = frame.get("tip", global_position)
		elif kind == &"cone":
			mat.spread = float(frame.get("angle", 70.0)) * 0.5
			mat.initial_velocity_min = radius / emitter.lifetime * 0.5
			mat.initial_velocity_max = radius / emitter.lifetime
		elif kind in [&"zone", &"aura", &"trap"]:
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_axis = Vector3(0, 0, 1)
			mat.emission_ring_radius = radius
			mat.emission_ring_inner_radius = radius * 0.2
			mat.emission_ring_height = 0.0
		elif kind in [&"beam", &"tether"]:
			var end: Vector2 = frame.get("end", global_position)
			emitter.global_position = global_position.lerp(end, 0.5)
			emitter.global_rotation = (end - global_position).angle()
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(global_position.distance_to(end) * 0.5, float(frame.get("width", 8.0 * profile.art_scale)) * 0.3, 0)

func _local_extent(key: String, authored_default: float) -> float:
	# Snapshot lengths are world-space. Polygon art is drawn under art_scale.
	return float(frame.get(key, authored_default * profile.art_scale)) / profile.art_scale

func stop() -> void:
	if stopped: return
	stopped = true
	for emitter: GPUParticles2D in [particles, smoke_particles]:
		if is_instance_valid(emitter): emitter.emitting = false
	if is_instance_valid(lamp): lamp.visible = false
	# Preserve world-space particles and ribbons after the gameplay owner disappears.
	if is_inside_tree() and get_tree().current_scene != null and get_parent() != get_tree().current_scene:
		var final_level: int = Elevation.level(self)
		reparent(get_tree().current_scene, true)
		# Tree-exit cleanup releases old bindings during reparenting. The fading
		# tail stays on its final floor instead of following the caster upstairs.
		Feedback._bind_elevation(self, 0, null, final_level)

func _process(delta: float) -> void:
	if profile == null:
		queue_free()
		return
	age += delta
	if is_instance_valid(follow) and not stopped:
		global_position = follow.global_position
	elif frame.get("kind", &"") == &"cast":
		queue_free()
		return
	if not stopped: _configure_emission()
	if is_instance_valid(smoke_particles) and Feedback.reduced_effects:
		smoke_particles.emitting = false
	for emitter: GPUParticles2D in [particles, smoke_particles]:
		if is_instance_valid(emitter):
			emitter.amount_ratio = 0.5 if Feedback.reduced_effects else 1.0
	if is_instance_valid(lamp):
		lamp.visible = not stopped and not Feedback.reduced_effects
		lamp.energy = profile.light_energy * (0.88 + 0.12 * sin(age * 7.0))
	var kind: StringName = frame.get("kind", &"")
	if kind in [&"burst", &"completion", &"expiry", &"cast", &"link", &"restore"]:
		if age >= float(frame.get("duration", profile.lifetime)):
			if kind == &"cast":
				queue_free()
				return
			stop()
	if stopped:
		tail_age += delta
		if tail_age >= maxf(profile.particle_lifetime * 1.5, profile.ribbon_fade):
			queue_free()
			return
	queue_redraw()
	if is_instance_valid(ground): ground.queue_redraw()

func _draw_blackflame_burn() -> void:
	# Grounded flames on the victim, not a second projectile or a short tether.
	var count: int = 3 if Feedback.reduced_effects else 5
	for i in count:
		var x: float = (float(i) / maxf(1.0, count - 1.0) - 0.5) * 19.0
		var height: float = 15.0 + 7.0 * sin(age * 9.0 + i * 1.9)
		var at := Vector2(x, 4)
		var flame := PackedVector2Array([at + Vector2(-3, 0), at + Vector2(-2, -height * 0.45), at + Vector2(sin(age * 11 + i) * 3, -height), at + Vector2(3, 0), at + Vector2(-3, 0)])
		draw_colored_polygon(flame, profile.color)
		draw_polyline(flame, Color(profile.core_color, 0.7), 1.0, true)

func _draw_dark_shard(heading: Vector2, size: float) -> void:
	draw_set_transform(Vector2.ZERO, heading.angle())
	var outline := PackedVector2Array([Vector2(size * 1.9, 0), Vector2(-size * 0.5, -size * 0.6), Vector2(-size * 1.5, 0), Vector2(-size * 0.5, size * 0.6), Vector2(size * 1.9, 0)])
	draw_colored_polygon(outline, profile.color)
	draw_polyline(outline, profile.core_color, 1.8, true)
	draw_line(Vector2(-size, 0), Vector2(size * 1.5, 0), profile.accent_color, 2.0, true)
	for i in 4:
		var at := Vector2(-size * (1 + i * 0.55), sin(age * 24 + i * 1.7) * size * 0.3)
		draw_line(at, at + Vector2(-size * 0.7, sin(age * 18 + i) * 4), Color(profile.core_color, 0.7 - i * 0.12), maxf(1, 4 - i), true)
	draw_set_transform(Vector2.ZERO)

func _draw_dark_flame_link(end: Vector2) -> void:
	var normal: Vector2 = end.normalized().orthogonal()
	var line := PackedVector2Array()
	for i in 49:
		var fraction: float = float(i) / 48.0
		line.append(end * fraction + normal * sin(fraction * 36.0 - age * 18.0) * 5.0 * sin(fraction * PI))
	draw_polyline(line, Color(profile.accent_color, 0.4), 16.0, true)
	draw_polyline(line, profile.core_color, 9.0, true)
	draw_polyline(line, profile.color, 6.5, true)
	var count: int = 5 if Feedback.reduced_effects else 10
	for i in count:
		var fraction: float = fposmod(float(i) / count + age * 0.9, 1.0)
		var at: Vector2 = end * fraction
		var height: float = 10.0 + 9.0 * sin(age * 13.0 + i) * sin(age * 13.0 + i)
		var flame := PackedVector2Array([at + Vector2(-5, 3), at + Vector2(-3, -height * 0.4), at + Vector2(3 + sin(age * 17 + i) * 4, -height), at + Vector2(5, 3), at + Vector2(-5, 3)])
		draw_colored_polygon(flame, profile.color)
		draw_polyline(flame, Color(profile.core_color, 0.8), 1.2, true)
	draw_arc(end, 14.0 + sin(age * 18.0) * 2.0, 0, TAU, 32, profile.accent_color, 2.0, true)

func _ribbon() -> void:
	for i in range(1, samples.size()):
		var fade: float = maxf(0, 1.0 - sample_ages[i] / profile.ribbon_fade)
		var a: Vector2 = to_local(samples[i - 1])
		var b: Vector2 = to_local(samples[i])
		draw_line(a, b, Color(profile.color, fade * 0.16), profile.ribbon_width * 2.5 * fade, true)
		draw_line(a, b, Color(profile.color, fade * 0.7), maxf(0.5, profile.ribbon_width * fade), true)
		draw_line(a, b, Color(profile.core_color, fade), maxf(0.5, profile.ribbon_width * fade * 0.2), true)

func _crystal(at: Vector2, size: float, heading: float) -> void:
	draw_set_transform(at, heading)
	draw_colored_polygon(PackedVector2Array([Vector2(size * 1.8, 0), Vector2(-size, -size * 0.5), Vector2(-size * 0.5, 0), Vector2(-size, size * 0.5)]), profile.color)
	draw_line(Vector2(-size * 0.5, 0), Vector2(size * 1.6, 0), profile.core_color, 2, true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if profile == null: return
	var kind: StringName = frame.get("kind", &"burst")
	var heading: Vector2 = frame.get("direction", Vector2.RIGHT)
	var size: float = profile.visual_size
	var color: Color = profile.color
	if stopped: return
	match kind:
		&"burn":
			if profile.style == VFXDefinition.Style.DARK_FLAME:
				_draw_blackflame_burn()
		&"projectile":
			if profile.style == VFXDefinition.Style.DARK_FLAME:
				_draw_dark_shard(heading, size)
				return
			draw_circle(Vector2.ZERO, size * 2, Color(color, 0.12 * profile.glow_strength))
			if profile.style == VFXDefinition.Style.FIRE:
				for i in 5:
					_crystal(-heading * i * size * 0.45 + heading.orthogonal() * sin(age * 28 + i) * 3, size * (1.0 - i * 0.12), heading.angle())
			elif profile.style == VFXDefinition.Style.RADIANT:
				draw_line(-heading * size * 2.5, heading * size * 1.8, profile.core_color, 4, true)
				_crystal(heading * size, size, heading.angle())
			else:
				_crystal(Vector2.ZERO, size, heading.angle())
				for i in 3:
					var orbit: Vector2 = Vector2.RIGHT.rotated(age * 5 + i * TAU / 3) * size * 1.5
					_crystal(orbit, size * 0.22, heading.angle())
		&"beam", &"tether":
			var end: Vector2 = to_local(frame.get("end", global_position))
			var width: float = _local_extent("width", 10.0)
			if profile.style == VFXDefinition.Style.DARK_FLAME:
				_draw_dark_flame_link(end)
				return
			draw_line(Vector2.ZERO, end, Color(color, 0.12 * profile.glow_strength), width * 2.8, true)
			for strand in 3:
				var line := PackedVector2Array()
				for i in 33:
					var t: float = float(i) / 32
					var wave: float = sin(t * 30 - age * 14 + strand * TAU / 3) * width * 0.4 * sin(t * PI)
					line.append(end * t + end.normalized().orthogonal() * wave)
				draw_polyline(line, profile.accent_color if strand == 1 else color, width * 0.22, true)
			draw_line(Vector2.ZERO, end, profile.core_color, maxf(1, width * 0.22), true)
			draw_circle(Vector2.ZERO, size * 0.8, Color(profile.core_color, 0.85))
			draw_circle(end, size * (0.7 + sin(age * 12) * 0.1), Color(color, 0.5))
			for i in 10:
				var t: float = fposmod(float(i) / 10 - age * 0.7, 1.0)
				draw_circle(end * t, 2.0, profile.core_color)
		&"cone":
			var boundary: PackedVector2Array = frame.get("boundary", PackedVector2Array())
			if boundary.size() >= 2:
				for layer in range(4, 0, -1):
					var poly := PackedVector2Array([Vector2.ZERO])
					var fraction: float = float(layer) / 4
					for i in boundary.size():
						var flicker: float = 0.92 + 0.08 * sin(age * 14 + i * 1.7)
						poly.append(to_local(boundary[i]) * fraction * flicker)
					draw_colored_polygon(poly, Color(profile.core_color if layer == 1 else color, 0.16 + 0.04 * (4 - layer)))
				for i in range(1, boundary.size(), 3):
					draw_line(Vector2.ZERO, to_local(boundary[i]) * (0.6 + 0.15 * sin(age * 9 + i)), Color(profile.core_color, 0.45), 3, true)
		&"wave":
			var radius: float = _local_extent("width", 120.0) * 0.5
			for layer in 4:
				draw_arc(-heading * layer * 4, radius, heading.angle() - PI * 0.5, heading.angle() + PI * 0.5, 48, Color(color, 0.4 / (layer + 1)), _local_extent("thickness", 16.0) * (1.0 + layer * 0.6), true)
			draw_arc(Vector2.ZERO, radius, heading.angle() - PI * 0.5, heading.angle() + PI * 0.5, 48, profile.core_color, 2.5, true)
		&"orbiting":
			var orbits: PackedVector2Array = frame.get("orbits", PackedVector2Array())
			for point: Vector2 in orbits:
				_crystal(to_local(point), size * 0.7, age * 0.8)
				draw_circle(to_local(point), size, Color(color, 0.13))
		&"barrage":
			var targets: PackedVector2Array = frame.get("targets", PackedVector2Array())
			var next: int = int(frame.get("next", 0))
			for i in range(next, targets.size()):
				var until: float = float(frame.get("telegraph", 0.65)) + i * float(frame.get("interval", 0.3)) - float(frame.get("elapsed", 0.0))
				if until < 0.45:
					var tip: Vector2 = to_local(targets[i]) + Vector2(30, -260) * clampf(until / 0.45, 0, 1)
					draw_line(tip + Vector2(25, -100), tip, Color(color, 0.55), 9, true)
					_crystal(tip, size, Vector2(-30, 260).angle())
		&"summon":
			for i in 5:
				var offset := Vector2(cos(age * 2 + i * TAU / 5) * 15, sin(age * 2 + i * TAU / 5) * 8 - 12)
				_crystal(offset, size * 0.22, -PI * 0.5)
			draw_circle(Vector2(0, -12), size * 0.65, Color(profile.core_color, 0.9))
			draw_circle(Vector2(0, -12), size * 1.5, Color(color, 0.14))
		&"imbue":
			var tip: Vector2 = to_local(frame.get("tip", to_global(Vector2(24, 0))))
			draw_line(Vector2.ZERO, tip, Color(color, 0.25), 8, true)
			draw_line(Vector2.ZERO, tip, profile.core_color, 1.5, true)
			_crystal(tip * (0.5 + 0.5 * sin(age * 3)), 2.5, tip.angle())
		&"dash":
			_crystal(Vector2.ZERO, size * 1.3, heading.angle())
		&"restore":
			for i in 6:
				var mote := Vector2(sin(i * 2.1 + age) * 13, -age * 35 - i * 3)
				draw_circle(mote, 1.5, Color(profile.core_color, maxf(0, 1.0 - age / 0.4)))
		&"cast", &"burst", &"completion", &"expiry":
			var progress: float = clampf(age / maxf(0.01, float(frame.get("duration", profile.lifetime))), 0, 1)
			var extent: float = _local_extent("radius", 40.0)
			var radius: float = size * (1.8 - progress) if kind == &"cast" else extent * (0.15 + progress * 0.85)
			var alpha: float = 0.4 + progress * 0.6 if kind == &"cast" else 1.0 - progress
			if profile.style == VFXDefinition.Style.DARK_FLAME:
				for i in 8:
					var ray: Vector2 = Vector2.RIGHT.rotated(i * TAU / 8.0 + age * 1.8)
					var at: Vector2 = ray * radius * 0.6
					var tongue := PackedVector2Array([at - ray.orthogonal() * 4, at + ray * size * alpha, at + ray.orthogonal() * 4, at - ray.orthogonal() * 4])
					draw_colored_polygon(tongue, Color(color, alpha))
					draw_polyline(tongue, Color(profile.core_color, alpha), 1.2, true)
				draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(profile.accent_color, alpha), 2, true)
				return
			draw_circle(Vector2.ZERO, radius, Color(color, alpha * 0.14 * profile.glow_strength))
			for ring in 3:
				draw_arc(Vector2.ZERO, radius * (1.0 - ring * 0.18), age * (ring + 1), TAU + age * (ring + 1), 48, Color(color, alpha * 0.6), 2 + ring, true)
			for i in 12:
				var ray: Vector2 = Vector2.RIGHT.rotated(i * TAU / 12 + age * 0.4)
				draw_line(ray * radius * 0.55, ray * radius, Color(profile.core_color, alpha), 2, true)
				if profile.style == VFXDefinition.Style.CRYSTAL: _crystal(ray * radius, size * alpha * 0.3, ray.angle())
				elif profile.style in [VFXDefinition.Style.FIRE, VFXDefinition.Style.WAVE]:
					var base: Vector2 = ray * radius
					draw_colored_polygon(PackedVector2Array([base - ray.orthogonal() * 5, base + ray * size * alpha, base + ray.orthogonal() * 5]), Color(color, alpha * 0.6))
				elif profile.style == VFXDefinition.Style.HEAL:
					var mote: Vector2 = ray * radius * 0.6 + Vector2(0, -progress * 30)
					draw_line(mote - Vector2(0, 3), mote + Vector2(0, 3), Color(profile.core_color, alpha), 2, true)
		&"link":
			var end: Vector2 = to_local(frame.get("end", global_position))
			for strand in 3:
				var line := PackedVector2Array()
				for i in 17:
					var t: float = float(i) / 16
					line.append(end * t + end.normalized().orthogonal() * sin(i * 6.7 + strand * 2 + floor(age * 20)) * sin(t * PI) * 13)
				draw_polyline(line, profile.core_color if strand == 0 else Color(color, 0.55), 2.0 if strand == 0 else 5.0, true)

func _draw_ground() -> void:
	if profile == null or stopped: return
	var kind: StringName = frame.get("kind", &"")
	if kind == &"burst" and profile.style == VFXDefinition.Style.WAVE:
		var burst_progress: float = clampf(age / profile.lifetime, 0, 1)
		var ring_radius: float = _local_extent("radius", 105.0) * burst_progress
		ground.draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 64, Color(profile.color, (1.0 - burst_progress) * 0.6), 15, true)
		ground.draw_circle(Vector2.ZERO, ring_radius, Color(profile.accent_color, (1.0 - burst_progress) * 0.12))
		return
	if kind not in [&"zone", &"aura", &"trap", &"barrage"]: return
	var centers := PackedVector2Array([Vector2.ZERO])
	if kind == &"barrage":
		centers.clear()
		var targets: PackedVector2Array = frame.get("targets", PackedVector2Array())
		for i in range(int(frame.get("next", 0)), targets.size()): centers.append(to_local(targets[i]))
	var radius: float = _local_extent("radius", 80.0)
	var armed: bool = bool(frame.get("armed", true))
	var opacity: float = 0.9 if armed else 0.35
	for center: Vector2 in centers:
		ground.draw_circle(center, radius, Color(profile.color, 0.09))
		for ring in 2:
			ground.draw_arc(center, radius * (1.0 - ring * 0.18), 0, TAU, 64, Color(profile.color, opacity * (0.65 + sin(age * 3) * 0.15)), 2, true)
		for i in 12:
			var ray: Vector2 = Vector2.RIGHT.rotated(i * TAU / 12)
			var at: Vector2 = center + ray * radius * 0.82
			ground.draw_line(at, at + ray.rotated(0.7) * 9, Color(profile.core_color, opacity * 0.7), 2, true)
			if profile.style == VFXDefinition.Style.FIRE:
				ground.draw_polyline(PackedVector2Array([center + ray * radius * 0.15, center + ray.rotated(0.2) * radius * 0.4, center + ray * radius * 0.7]), Color(profile.color, 0.45), 2, true)
