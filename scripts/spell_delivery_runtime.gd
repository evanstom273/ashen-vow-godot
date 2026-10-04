extends Node2D
var definition: SpellDeliveryDefinition
var context: SpellCastContext
var elapsed: float = 0.0
var clock: float = 0.0
var travelled: float = 0.0
var hits: Dictionary = {}
var remaining: int = 0
var commanded: bool = false
var cancelled: bool = false
var broken_time: float = 0.0
var points: Array[Vector2] = []
var summons: Array[Node] = []
var beam_end := Vector2.ZERO
var random := RandomNumberGenerator.new()
var visual_scene: Node2D
var visual_owner_id: int = 0
var runtime_duration: float = 0.0
var drain_applied: bool = false

func _ready() -> void:
	add_to_group("spell_delivery")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 32
	z_as_relative = false
	random.randomize()
	global_position = context.origin
	set_meta(&"elevation_level", context.elevation)
	Elevation.register_visual(self)
	runtime_duration = definition.duration
	visual_owner_id = context.attribution.get_instance_id()
	if definition.vfx != null:
		context.profile = definition.vfx
	beam_end = global_position
	var d: Variant = definition
	match definition.kind():
		&"area":
			if not d.at_caster: global_position = context.point
			_area(d.radius, d.wall_occlusion)
			cancel()
		&"self":
			SpellDeliveryService.hit(definition, context, context.caster)
			_impact(global_position)
			cancel()
		&"target":
			if SpellDeliveryService.alive(context.target) and SpellDeliveryService.on_plane(context, context.target) and (not d.require_line_of_sight or SpellDeliveryService.visible(context, global_position, context.target.global_position)):
				SpellDeliveryService.hit(definition, context, context.target)
				_impact(context.target.global_position)
			cancel()
		&"imbue":
			SpellEffects.of(context.caster).imbues[context.weapon_token] = {"damage": d.bonus_damage, "remaining": definition.duration, "color": d.weapon_color, "profile": context.profile}
			_impact(global_position)
			cancel()
		&"zone", &"trap", &"barrage", &"summon":
			global_position = context.point
		&"orbiting": remaining = d.count
		&"chain": remaining = d.target_count
	if definition is TrapDelivery:
		remaining = definition.trigger_count
		clock = definition.rearm_interval
	if definition is BarrageDelivery:
		for _i in definition.count:
			var sample: Vector2 = context.point + Vector2.RIGHT.rotated(random.randf_range(0, TAU)) * sqrt(random.randf()) * definition.scatter_radius
			var placement: Vector2 = SpellDeliveryService.wall_end(context, context.caster.global_position, sample)
			placement -= (sample - context.caster.global_position).normalized() * WorldScale.art_distance(14)
			points.append(placement if SpellDeliveryService.placement_clear(context, placement) else context.point)
	if definition is SummonDelivery:
		for i in definition.count:
			var ally: Node
			if definition.summon.scene != null: ally = definition.summon.scene.instantiate()
			else:
				ally = CharacterBody2D.new()
				ally.set_script(load("res://scripts/spell_summon.gd"))
			ally.call("configure", definition.summon, context.branch(), definition.duration)
			var spawn: Vector2 = global_position + Vector2.RIGHT.rotated(i * TAU / definition.count) * WorldScale.art_distance(12)
			WorldScale.attach_art(ally as Node2D, context.caster.get_tree().current_scene, spawn if SpellDeliveryService.placement_clear(context, spawn) else global_position)
			summons.append(ally)
	if not cancelled and not definition is SummonDelivery:
		visual_scene = Feedback.spell_visual(context.profile, _visual_snapshot(), self)

func cancel() -> void:
	if cancelled: return
	cancelled = true
	_stop_visual()
	for ally: Node in summons:
		if is_instance_valid(ally):
			SpellDeliveryService.clear_owned(ally)
			ally.queue_free()
	queue_free()

func command() -> void:
	if definition is OrbitingDelivery and not commanded:
		commanded = true
		# Waiting for a command must not accumulate an instant full volley.
		clock = definition.fire_interval

func _physics_process(delta: float) -> void:
	if cancelled: return
	if not SpellDeliveryService.alive(context.caster) or not SpellDeliveryService.alive(context.attribution):
		cancel()
		return
	# Independent shots/fields remain on their cast floor. Attached deliveries end
	# when their caster changes plane; neither a channel nor a tether follows through a ceiling.
	if Elevation.level(context.caster) != context.elevation and definition.kind() in [&"beam", &"cone", &"aura", &"orbiting", &"dash", &"tether"]:
		cancel()
		return
	var d: Variant = definition
	var step: float = minf(delta, maxf(0, runtime_duration - elapsed))
	elapsed += step
	clock += step
	if definition.is_channel():
		if not context.caster.has_method("delivery_channel_active") or not context.caster.delivery_channel_active(self):
			cancel()
			return
		var desired: Vector2 = context.caster.aim_direction()
		if definition.kind() != &"tether":
			context.direction = Vector2.RIGHT.rotated(rotate_toward(context.direction.angle(), desired.angle(), d.turn_rate * step))
	match definition.kind():
		&"projectile":
			if d.homing and SpellDeliveryService.alive(context.target) and SpellDeliveryService.on_plane(context, context.target):
				context.direction = Vector2.RIGHT.rotated(rotate_toward(context.direction.angle(), (context.target.global_position - global_position).angle(), d.turn_rate * step))
			_travel(d.speed * step, d.radius, false)
		&"wave":
			context.direction = context.direction.rotated(d.curvature * step)
			_travel(minf(d.speed * step, d.distance - travelled), d.thickness, true)
			if travelled >= d.distance: cancel()
		&"beam":
			global_position = context.caster.global_position
			beam_end = SpellDeliveryService.wall_end(context, global_position, global_position + context.direction * d.length)
			while clock >= definition.tick_interval:
				clock -= definition.tick_interval
				var victims: Array[Node2D] = SpellDeliveryService.targets(context, definition.target_filter, global_position, d.length)
				victims.sort_custom(func(a: Node2D, b: Node2D) -> bool: return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
				for actor: Node2D in victims:
					if _segment_distance(actor.global_position, global_position, beam_end) <= d.width * 0.5 + SpellDeliveryService.target_radius(actor):
						SpellDeliveryService.hit(definition, context, actor)
						if not d.piercing: break
		&"cone":
			global_position = context.caster.global_position
			while not cancelled and (not d.held or clock >= definition.tick_interval):
				if d.held: clock -= definition.tick_interval
				for actor: Node2D in SpellDeliveryService.targets(context, definition.target_filter, global_position, d.radius):
					var offset: Vector2 = actor.global_position - global_position
					if offset.length() <= d.radius and context.direction.dot(offset.normalized()) >= cos(deg_to_rad(d.angle_degrees * 0.5)) and SpellDeliveryService.visible(context, global_position, actor.global_position):
						SpellDeliveryService.hit(definition, context, actor)
				if not d.held: cancel()
		&"zone", &"aura":
			if definition is AuraDelivery: global_position = context.caster.global_position
			var delay: float = d.initial_delay if definition is ZoneDelivery else 0.0
			while clock >= definition.tick_interval:
				clock -= definition.tick_interval
				if elapsed >= delay: _area(d.radius, true, false)
		&"chain":
			while not cancelled and clock >= d.jump_delay:
				clock -= d.jump_delay
				if not SpellDeliveryService.alive(context.target) or not SpellDeliveryService.on_plane(context, context.target): cancel()
				else:
					var impact_at: Vector2 = context.target.global_position
					if d.require_line_of_sight and not SpellDeliveryService.visible(context, global_position, impact_at):
						cancel()
						return
					var target_id: int = context.target.get_instance_id()
					SpellDeliveryService.hit(definition, context, context.target, pow(d.damage_falloff, d.target_count - remaining))
					_link(global_position, impact_at)
					_impact(impact_at)
					hits[target_id] = true
					points.append(global_position)
					points.append(impact_at)
					global_position = impact_at
					remaining -= 1
					context.target = _nearest(global_position, d.jump_radius, d.require_line_of_sight)
					if remaining <= 0 or context.target == null: cancel()
		&"orbiting":
			global_position = context.caster.global_position
			if d.automatic or commanded:
				while clock >= d.fire_interval and remaining > 0:
					var target: Node2D = _nearest(global_position, definition.cast_range)
					if target != null or not d.automatic:
						clock -= d.fire_interval
						var origin: Vector2 = global_position + Vector2.RIGHT.rotated(elapsed * d.orbit_speed + remaining * TAU / d.count) * d.orbit_radius
						_child(d.child, origin, target)
						remaining -= 1
					else:
						clock = minf(clock, d.fire_interval)
						break
				if remaining <= 0: cancel()
		&"trap":
			if elapsed >= d.arming_delay and clock >= d.rearm_interval:
				var target: Node2D = _nearest(global_position, d.trigger_radius)
				if target != null:
					_child(d.child, global_position, target)
					remaining -= 1
					clock = 0
					if remaining <= 0: cancel()
		&"barrage":
			while remaining < points.size() and elapsed >= d.telegraph_duration + remaining * d.impact_interval:
				global_position = points[remaining]
				_area(d.impact_radius, true)
				remaining += 1
			if remaining >= points.size(): cancel()
		&"dash":
			if not context.caster.has_method("delivery_movement_active") or not context.caster.delivery_movement_active(self):
				cancel()
				return
			var body := context.caster as CharacterBody2D
			if body == null:
				cancel()
				return
			var start: Vector2 = body.global_position
			points.append(start)
			if d.steering > 0: context.direction = Vector2.RIGHT.rotated(rotate_toward(context.direction.angle(), body.aim_direction().angle(), d.steering * step))
			var requested: Vector2 = context.direction * d.distance * step / definition.duration
			var collision: KinematicCollision2D = Elevation.move(body, requested)
			global_position = body.global_position
			if Elevation.level(body) != context.elevation:
				cancel()
				return
			for actor: Node2D in SpellDeliveryService.targets(context, "Hostile", start, requested.length() + d.hit_width):
				if not hits.has(actor.get_instance_id()) and _segment_distance(actor.global_position, start, global_position) <= d.hit_width * 0.5 + SpellDeliveryService.target_radius(actor):
					hits[actor.get_instance_id()] = true
					SpellDeliveryService.hit(definition, context, actor)
			if collision != null or global_position.distance_to(start) + 0.1 < requested.length(): cancel()
		&"tether":
			global_position = context.caster.global_position
			if not SpellDeliveryService.alive(context.target) or not SpellDeliveryService.on_plane(context, context.target) or global_position.distance_to(context.target.global_position) > d.break_range:
				cancel()
				return
			beam_end = context.target.global_position
			broken_time = 0.0 if SpellDeliveryService.visible(context, global_position, beam_end) else broken_time + step
			if broken_time > d.line_of_sight_grace:
				cancel()
				return
			while clock >= definition.tick_interval:
				clock -= definition.tick_interval
				if d.drain_definition() != null:
					if not drain_applied and broken_time == 0:
						var result: HitResult = SpellDeliveryService.hit(definition, context, context.target)
						drain_applied = result.accepted
				elif broken_time == 0: SpellDeliveryService.hit(definition, context, context.target)
	if elapsed >= runtime_duration and not cancelled:
		if definition.is_channel() and context.profile != null and broken_time == 0:
			Feedback.present(context.profile.completion_feedback, global_position, context.direction, context.attribution, null, false, context.elevation)
		if definition is TetherDelivery and definition.drain_definition() == null and broken_time == 0 and SpellDeliveryService.alive(context.target):
			var completion := SelfDelivery.new()
			completion.target_filter = definition.target_filter
			completion.attack = definition.completion_attack
			completion.effects = definition.completion_effects
			var completion_context: SpellCastContext = context.branch()
			completion_context.attack = null
			var completion_at: Vector2 = context.target.global_position
			SpellDeliveryService.hit(completion, completion_context, context.target)
			_impact(completion_at, WorldScale.art_distance(65.0), &"completion")
		if definition is ProjectileDelivery: _impact(global_position, WorldScale.art_distance(12.0), &"expiry")
		if definition is DashDelivery: _impact(global_position, WorldScale.art_distance(38.0))
		cancel()
	if not cancelled: _update_visual()
	queue_redraw()

func _area(radius: float, occlusion: bool, emit_impact: bool = true) -> void:
	for actor: Node2D in SpellDeliveryService.targets(context, definition.target_filter, global_position, radius):
		if actor.global_position.distance_to(global_position) <= radius and (not occlusion or SpellDeliveryService.visible(context, global_position, actor.global_position)):
			var before: int = int(actor.get("health")) if actor.get("health") != null else 0
			var at: Vector2 = actor.global_position
			SpellDeliveryService.hit(definition, context, actor)
			if definition.target_filter != "Hostile" and is_instance_valid(actor) and actor.get("health") != null and int(actor.get("health")) > before:
				Feedback.spell_effect(at, context.profile, &"restore", null, WorldScale.art_distance(12.0), 0.4, visual_owner_id, context.elevation)
	if emit_impact:
		_impact(global_position, radius)
		if context.profile != null and definition.target_filter == "Hostile":
			Feedback.present(context.profile.impact_feedback, global_position, context.direction, context.attribution, null, definition.kind() in [&"zone", &"aura"] or context.from_summon, context.elevation)

func _nearest(origin: Vector2, radius: float, require_sight: bool = true) -> Node2D:
	var nearest: Node2D
	var distance: float = radius
	for actor: Node2D in SpellDeliveryService.targets(context, "Hostile", origin, radius):
		var candidate: float = origin.distance_to(actor.global_position)
		if not hits.has(actor.get_instance_id()) and candidate <= distance and (not require_sight or SpellDeliveryService.visible(context, origin, actor.global_position)):
			nearest = actor
			distance = candidate
	return nearest

func _child(child: SpellDeliveryDefinition, origin: Vector2, target: Node2D) -> void:
	var child_context: SpellCastContext = context.branch()
	child_context.target = target
	child_context.point = origin
	child_context.origin = origin
	child_context.direction = (target.global_position - origin).normalized() if SpellDeliveryService.alive(target) else context.direction
	var instance: Node2D = SpellDeliveryService.launch(child, child_context)
	if is_instance_valid(instance): instance.global_position = origin

func _travel(distance: float, radius: float, wave: bool) -> void:
	var d: Variant = definition
	var steps: int = maxi(1, ceili(distance / maxf(1, radius * 0.5)))
	for _i in steps:
		var start: Vector2 = global_position
		var end: Vector2 = start + context.direction * distance / steps
		var wall: Vector2 = SpellDeliveryService.wall_end(context, start, end)
		global_position = wall
		travelled += start.distance_to(wall)
		for actor: Node2D in SpellDeliveryService.targets(context, definition.target_filter, start, start.distance_to(wall) + (d.width if wave else radius)):
			var padding: float = SpellDeliveryService.target_radius(actor)
			var near: bool = _segment_distance(actor.global_position, start, wall) <= radius + padding
			if wave:
				var offset: Vector2 = actor.global_position - wall
				near = absf(offset.dot(context.direction)) <= radius + padding and absf(offset.dot(context.direction.orthogonal())) <= d.width * 0.5
			if near and not hits.has(actor.get_instance_id()) and SpellDeliveryService.visible(context, wall, actor.global_position):
				hits[actor.get_instance_id()] = true
				var impact_position: Vector2 = actor.global_position
				SpellDeliveryService.hit(definition, context, actor)
				_impact(impact_position)
				if not wave and hits.size() > d.pierce_count:
					cancel()
					return
		if wall.distance_to(end) > 0.1:
			if context.profile != null: Feedback.present(context.profile.impact_feedback, wall, context.direction, context.attribution, null, false, context.elevation)
			_impact(wall)
			cancel()
			return

func _segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))

func _draw() -> void:
	if cancelled: return
	if is_instance_valid(visual_scene): return
	var profile: VFXDefinition = definition.vfx if definition.vfx != null else context.profile
	var color: Color = profile.color if profile != null else Color("94ceff")
	var d: Variant = definition
	match definition.kind():
		&"beam", &"tether":
			draw_line(Vector2.ZERO, to_local(beam_end), Color(color, 0.2), d.width if definition is BeamDelivery else WorldScale.art_distance(8), true)
			draw_line(Vector2.ZERO, to_local(beam_end), color, WorldScale.art_distance(2), true)
		&"projectile": draw_circle(Vector2.ZERO, d.radius, color)
		&"wave":
			draw_arc(Vector2.ZERO, d.width * 0.5, context.direction.angle() - PI * 0.5, context.direction.angle() + PI * 0.5, 32, color, d.thickness, true)
		&"cone":
			draw_arc(Vector2.ZERO, d.radius, context.direction.angle() - deg_to_rad(d.angle_degrees / 2), context.direction.angle() + deg_to_rad(d.angle_degrees / 2), 32, color, WorldScale.art_distance(3), true)
		&"zone", &"aura":
			draw_circle(Vector2.ZERO, d.radius, Color(color, 0.1))
			draw_arc(Vector2.ZERO, d.radius, 0, TAU, 48, color, WorldScale.art_distance(2), true)
		&"trap": draw_arc(Vector2.ZERO, d.trigger_radius, 0, TAU, 32, Color(color, 0.8 if elapsed >= d.arming_delay else 0.3), WorldScale.art_distance(2), true)
		&"orbiting":
			for i in remaining:
				draw_circle(Vector2.RIGHT.rotated(elapsed * d.orbit_speed + i * TAU / d.count) * d.orbit_radius, WorldScale.art_distance(6), color)
		&"barrage":
			for i in range(remaining, points.size()):
				draw_arc(to_local(points[i]), d.impact_radius, 0, TAU, 24, Color(color, 0.4), WorldScale.art_distance(1), true)
		&"chain":
			for i in range(0, points.size(), 2): draw_line(to_local(points[i]), to_local(points[i + 1]), color, WorldScale.art_distance(2), true)
		&"dash":
			for i in range(1, points.size()): draw_line(to_local(points[i - 1]), to_local(points[i]), Color(color, 0.4), d.hit_width, true)

func _link(start: Vector2, end: Vector2) -> void:
	if get_tree().get_nodes_in_group("transient_fx").size() >= 40: return
	Feedback.spell_visual(context.profile, {"kind": &"link", "origin": start, "end": end, "duration": 0.3, "owner_id": visual_owner_id, "elevation": context.elevation})

func _impact(at: Vector2, extent: float = 160.0, mode: StringName = &"burst") -> void:
	Feedback.spell_effect(at, context.profile, mode, null, extent, -1.0, visual_owner_id, context.elevation)

func _visual_snapshot() -> Dictionary:
	var d: Variant = definition
	var snapshot: Dictionary = {
		"kind": definition.kind(), "origin": global_position, "direction": context.direction,
		"elapsed": elapsed, "duration": runtime_duration, "end": beam_end,
		"owner_id": visual_owner_id, "elevation": context.elevation
	}
	if context.depth == 0 and context.caster.has_method("spell_visual_origin"):
		var catalyst_at: Vector2 = context.caster.call("spell_visual_origin", context.hand)
		if definition.is_channel():
			snapshot.origin = catalyst_at
		elif definition is ProjectileDelivery:
			snapshot.origin = global_position + (catalyst_at - context.caster.global_position) * maxf(0, 1.0 - elapsed / 0.12)
	for key: String in ["radius", "width", "thickness", "angle_degrees"]:
		var value: Variant = d.get(key)
		if value != null: snapshot["angle" if key == "angle_degrees" else key] = value
	if definition is BeamDelivery:
		# Keep contact decoration at the first receiver without changing damage geometry.
		if not definition.piercing:
			var distance: float = global_position.distance_to(beam_end)
			for actor: Node2D in SpellDeliveryService.targets(context, definition.target_filter, global_position, definition.length):
				if _segment_distance(actor.global_position, global_position, beam_end) <= definition.width * 0.5 + SpellDeliveryService.target_radius(actor):
					var projected: float = (actor.global_position - global_position).dot(context.direction)
					if projected >= 0 and projected < distance:
						distance = projected
						snapshot.end = global_position + context.direction * distance
	if definition is ConeDelivery:
		var boundary := PackedVector2Array()
		for i in 25:
			var heading: Vector2 = context.direction.rotated(deg_to_rad(definition.angle_degrees) * (float(i) / 24 - 0.5))
			boundary.append(SpellDeliveryService.wall_end(context, global_position, global_position + heading * definition.radius))
		snapshot.boundary = boundary
	if definition is TrapDelivery:
		snapshot.radius = definition.trigger_radius
		snapshot.armed = elapsed >= definition.arming_delay
	if definition is OrbitingDelivery:
		var orbits := PackedVector2Array()
		for i in range(1, remaining + 1):
			orbits.append(global_position + Vector2.RIGHT.rotated(elapsed * definition.orbit_speed + i * TAU / definition.count) * definition.orbit_radius)
		snapshot.orbits = orbits
	if definition is BarrageDelivery:
		snapshot.targets = PackedVector2Array(points)
		snapshot.next = remaining
		snapshot.radius = definition.impact_radius
		snapshot.telegraph = definition.telegraph_duration
		snapshot.interval = definition.impact_interval
	return snapshot

func _update_visual() -> void:
	if not is_instance_valid(visual_scene): return
	if visual_scene.has_method("update_visual"):
		visual_scene.call("update_visual", _visual_snapshot())
	elif visual_scene.has_method("update_delivery"):
		visual_scene.call("update_delivery", self)
	else:
		visual_scene.rotation = context.direction.angle()

func _stop_visual() -> void:
	if not is_instance_valid(visual_scene): return
	if SpellDeliveryService.alive(context.caster): _update_visual()
	if visual_scene.has_method("stop"): visual_scene.call("stop")
	else: visual_scene.queue_free()
	visual_scene = null

func _exit_tree() -> void:
	# Scene teardown must not reparent into a tree that is already exiting.
	if is_instance_valid(visual_scene): visual_scene.queue_free()
	visual_scene = null
