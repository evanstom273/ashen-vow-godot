extends Node2D
## Cosmetic only: no collision, damage, or gameplay callbacks.
var profile: VFXDefinition
var mode: StringName = &"burst"
var follow: Node2D
var direction: Vector2 = Vector2.RIGHT
var extent: float = 40.0
var duration: float = 0.7
var elapsed: float = 0.0
var seeds: Array[Vector2] = []
var samples: Array[Vector2] = []
var ages: Array[float] = []
var light: PointLight2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = -10 if mode == &"stain" else 34
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var solid: bool = profile.style >= VFXDefinition.Style.FLESH or mode == &"stain"
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX if solid else CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	var random := RandomNumberGenerator.new()
	random.randomize()
	for _i in profile.particle_count:
		seeds.append(Vector2(random.randf_range(-PI, PI), random.randf_range(0.25, 1.0)))
	if mode != &"stain" and profile.light_energy > 0:
		light = Feedback.effect_light(self, profile)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if (mode == &"stain" or profile.style == VFXDefinition.Style.FLESH) and not Feedback.blood_enabled:
		queue_free()
		return
	if mode == &"cast":
		if not is_instance_valid(follow):
			queue_free()
			return
		global_position = follow.global_position
	if mode == &"trail":
		for i in ages.size(): ages[i] += delta
		if is_instance_valid(follow):
			samples.push_front(follow.global_position)
			ages.push_front(0.0)
		var limit: int = maxi(2, profile.trail_points >> (1 if Feedback.reduced_effects else 0))
		while not ages.is_empty() and (ages.back() > profile.trail_lifetime or samples.size() > limit):
			ages.pop_back()
			samples.pop_back()
		if not is_instance_valid(follow) and samples.is_empty():
			queue_free()
			return
	elif elapsed >= duration:
		queue_free()
		return
	if is_instance_valid(light):
		light.visible = not Feedback.reduced_effects
		light.energy = profile.light_energy * (1.0 if mode in [&"cast", &"trail"] else maxf(0, 1.0 - elapsed / duration))
		if mode == &"trail":
			light.visible = light.visible and is_instance_valid(follow)
			if is_instance_valid(follow): light.global_position = follow.global_position
	queue_redraw()

func _draw() -> void:
	if profile == null: return
	var count: int = maxi(1, seeds.size() >> (1 if Feedback.reduced_effects else 0))
	if mode == &"trail": return # No historical-position smear.
	if mode == &"stain":
		var alpha: float = 0.65 * (1.0 - smoothstep(8.0, 12.0, elapsed))
		for i in mini(count, 9):
			var point: Vector2 = Vector2.RIGHT.rotated(seeds[i].x) * seeds[i].y * extent
			draw_set_transform(point, seeds[i].x, Vector2(1, 0.45))
			draw_circle(Vector2.ZERO, 2 + seeds[i].y * 4, Color("651a24") * Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO)
		return
	var progress: float = clampf(elapsed / duration, 0, 1)
	var fade: float = 1.0 - progress
	var size: float = extent * (0.15 + 0.85 * progress)
	if mode == &"cast":
		size = profile.visual_size * (1.6 - progress)
		fade = 0.4 + progress * 0.6
	var colored := Color(profile.color, fade * 0.7)
	if profile.style < VFXDefinition.Style.FLESH:
		draw_circle(Vector2.ZERO, size, Color(profile.color, fade * 0.09))
		draw_arc(Vector2.ZERO, size, elapsed * 2, TAU + elapsed * 2, 48, colored, 1.5, true)
		if profile.style == VFXDefinition.Style.HEAL:
			for i in 8:
				var rune: Vector2 = Vector2.RIGHT.rotated(i * TAU / 8 + elapsed * 0.4) * size
				draw_line(rune * 0.85, rune * 1.12, colored, 2, true)
		if profile.style == VFXDefinition.Style.WAVE:
			draw_arc(Vector2.ZERO, size * 0.9, 0, TAU, 64, Color(profile.core_color, fade * 0.65), 3, true)
	for i in count:
		var particle_seed: Vector2 = seeds[i]
		var axis: Vector2 = Vector2.RIGHT.rotated(particle_seed.x)
		var point: Vector2 = axis * size * particle_seed.y
		if profile.style >= VFXDefinition.Style.FLESH:
			axis = direction.rotated(particle_seed.x * 0.25)
			point = axis * size * particle_seed.y + Vector2(0, progress * progress * 15)
		if profile.style == VFXDefinition.Style.HEAL:
			point.y -= progress * extent
		match profile.style:
			VFXDefinition.Style.CRYSTAL:
				draw_colored_polygon(PackedVector2Array([point + axis * 5 * fade, point + axis.orthogonal() * 2 * fade, point - axis * 3 * fade, point - axis.orthogonal() * 2 * fade]), colored)
			VFXDefinition.Style.RADIANT:
				draw_line(point, point + axis * 15 * fade, Color(profile.core_color, fade), 1.5, true)
			VFXDefinition.Style.FIRE, VFXDefinition.Style.WAVE:
				draw_circle(point, (2 + particle_seed.y * 5) * fade, colored)
				if profile.smoke and not Feedback.reduced_effects:
					draw_circle(point + Vector2(0, -progress * 20), 4 + progress * 6, Color(0.12, 0.1, 0.08, fade * 0.18))
			VFXDefinition.Style.HEAL:
				draw_line(point - Vector2(0, 3), point + Vector2(0, 3), colored, 1.5, true)
				draw_line(point - Vector2(2, 0), point + Vector2(2, 0), colored, 1.5, true)
			_:
				draw_line(point, point - axis * (3 + particle_seed.y * 5) * fade, colored, 2.0 if profile.style == VFXDefinition.Style.FLESH else 1.2, true)
