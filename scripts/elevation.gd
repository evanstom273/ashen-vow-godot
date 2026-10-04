class_name Elevation
extends Node
## Scene-owned logical elevation. One parallel category bank serves ALL nonzero
## storeys. Existing level-zero world bodies retain their original collision bits.
const CATEGORY_BITS: int = 255
const RAISED_SHIFT: int = 8
var members: Dictionary = {}
var exceptions: Dictionary = {}
var floors: Array[BuildingFloor] = []
var stairs: Array[ElevationTransition] = []
var visuals: Dictionary = {}
var revision: int = 0
var viewer: Node2D
const CELL: float = 2048.0
var raised_buckets: Dictionary = {}
var raised_cells: Dictionary = {}
var raised_movers: Dictionary = {}
var _body_clock: float = 0.0

static func of(node: Node) -> Elevation:
	var scene: Node = node
	while scene.get_parent() != null and scene.get_parent() != node.get_tree().root:
		scene = scene.get_parent()
	if scene.has_meta(&"elevation_runtime_ref"):
		var cached: Variant = (scene.get_meta(&"elevation_runtime_ref") as WeakRef).get_ref()
		if is_instance_valid(cached): return cached as Elevation
	var existing := scene.get_node_or_null("ElevationRuntime") as Elevation
	if existing != null: return existing
	var result := Elevation.new()
	result.name = "ElevationRuntime"
	scene.set_meta(&"elevation_runtime_ref", weakref(result))
	scene.call_deferred("add_child", result)
	return result

static func register_visual(item: Node2D, anchor: Node2D = null) -> void:
	if Engine.is_editor_hint(): return
	var registry: Elevation = of(item)
	var id: int = item.get_instance_id()
	if registry.visuals.has(id):
		registry.visuals[id].anchor = weakref(anchor) if is_instance_valid(anchor) else null
		return
	registry.visuals[id] = {"item": weakref(item), "anchor": weakref(anchor) if is_instance_valid(anchor) else null, "alpha": 1.0, "base_alpha": item.modulate.a, "applied_alpha": item.modulate.a}
	item.tree_exiting.connect(registry._forget_visual.bind(id), CONNECT_ONE_SHOT)

func _forget_visual(id: int) -> void:
	if not visuals.has(id): return
	var entry: Dictionary = visuals[id]
	var item: Variant = entry.item.get_ref()
	if is_instance_valid(item):
		var tint: Color = item.modulate
		tint.a = float(entry.base_alpha)
		item.modulate = tint
		if item is Light2D and entry.has("base_energy"): item.energy = float(entry.base_energy)
		if item.has_meta(&"elevation_visibility"): item.remove_meta(&"elevation_visibility")
	visuals.erase(id)

func _process(delta: float) -> void:
	_body_clock += delta
	if _body_clock >= 0.1:
		_body_clock = 0.0
		for identity: int in raised_movers.keys():
			var object: Object = instance_from_id(identity)
			if is_instance_valid(object) and object is CollisionObject2D: _refresh_exceptions(object)
	if not is_instance_valid(viewer): viewer = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(viewer): return
	for entry: Dictionary in visuals.values():
		var candidate: Variant = entry.item.get_ref()
		if not is_instance_valid(candidate): continue
		var item := candidate as Node2D
		var anchor: Variant = entry.anchor.get_ref() if entry.anchor != null else null
		var at: Vector2 = anchor.global_position if is_instance_valid(anchor) else item.global_position
		var value: int = level(anchor) if is_instance_valid(anchor) else level(item)
		if is_instance_valid(anchor): item.set_meta(&"elevation_level", value)
		var desired: float = visibility_at(at, value)
		if item == viewer: desired = 1.0
		entry.alpha = move_toward(float(entry.alpha), desired, delta / 0.22)
		# Modulate the whole subtree without changing .visible (targetability),
		# damage-flash colours or the node's own animated alpha.
		item.set_meta(&"elevation_visibility", float(entry.alpha))
		var tint: Color = item.modulate
		if not is_equal_approx(tint.a, float(entry.applied_alpha)): entry.base_alpha = tint.a
		tint.a = float(entry.base_alpha) * float(entry.alpha)
		item.modulate = tint
		entry.applied_alpha = tint.a
		if item is Light2D:
			# Point lights do not use canvas alpha for their emitted illumination.
			var lamp := item as Light2D
			if not entry.has("applied_energy") or not is_equal_approx(lamp.energy, float(entry.applied_energy)): entry.base_energy = lamp.energy
			lamp.energy = float(entry.base_energy) * float(entry.alpha)
			entry.applied_energy = lamp.energy

func visibility_at(at: Vector2, value: int) -> float:
	if not is_instance_valid(viewer): return 1.0
	var result: float = 1.0 if value == level(viewer) else 0.0
	for floor_layer: BuildingFloor in floors:
		if not is_instance_valid(floor_layer) or floor_layer.storey() != value or not floor_layer.contains_world(at): continue
		result = floor_layer.content_opacity()
		break
	return result

func register_floor(floor_layer: BuildingFloor) -> void:
	if floors.has(floor_layer): return
	floors.append(floor_layer)
	revision += 1
	floor_layer.tree_exiting.connect(_remove_floor.bind(floor_layer), CONNECT_ONE_SHOT)

func _remove_floor(floor_layer: BuildingFloor) -> void:
	floors.erase(floor_layer)
	revision += 1

func register_stairs(transition: ElevationTransition) -> void:
	if stairs.has(transition): return
	stairs.append(transition)
	revision += 1
	transition.tree_exiting.connect(_remove_stairs.bind(transition), CONNECT_ONE_SHOT)

func _remove_stairs(transition: ElevationTransition) -> void:
	stairs.erase(transition)
	revision += 1

func support_at(point: Vector2, value: int, radius: float = 0.0) -> bool:
	# Ground geography already supplies collision/landing volumes. All other
	# storeys need authored support, including negative underground levels.
	if value == 0: return true
	var samples: Array[Vector2] = [point]
	if radius > 0:
		for index in 8: samples.append(point + Vector2.RIGHT.rotated(TAU * float(index) / 8.0) * radius)
	for sample: Vector2 in samples:
		var supported: bool = false
		for floor_layer: BuildingFloor in floors:
			if floor_layer.definition != null and floor_layer.definition.supplies_support and floor_layer.storey() == value and floor_layer.contains_world(sample):
				supported = true
				break
		if not supported:
			for transition: ElevationTransition in stairs:
				if transition.supports(value, sample):
					supported = true
					break
		if not supported: return false
	return true

static func body_radius(actor: CollisionObject2D) -> float:
	var radius: float = 0.0
	for child: Node in actor.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			var bounds: Rect2 = child.shape.get_rect()
			var extent: float = maxf(bounds.size.x, bounds.size.y) * 0.5
			if child.shape is RectangleShape2D: extent = bounds.size.length() * 0.5
			radius = maxf(radius, actor.global_position.distance_to(child.to_global(bounds.get_center())) + extent * WorldScale.actor_scale(child))
	return radius

static func can_occupy(actor: CharacterBody2D, at: Vector2, value: int, mask: int = -1) -> bool:
	if not of(actor).support_at(at, value, body_radius(actor)): return false
	for child: Node in actor.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null: continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = child.shape
		query.transform = child.global_transform
		query.transform.origin += at - actor.global_position
		query.collision_mask = base_mask(actor) if mask < 0 else mask
		query.exclude = [actor.get_rid()]
		query.collide_with_areas = true
		if not shapes(actor, query, value, 1).is_empty(): return false
	return true

func preview(actor: Node2D) -> Dictionary:
	for transition: ElevationTransition in stairs:
		if transition.allows_actor(actor) and transition.contains_world(actor.global_position):
			return {"from": transition.definition.from_level, "to": transition.definition.to_level, "blend": transition.progress(actor.global_position)}
	return {}

static func slide(actor: CharacterBody2D, delta: float) -> void:
	var desired: Vector2 = actor.velocity * delta
	if desired.is_zero_approx():
		actor.move_and_slide()
		return
	var registry: Elevation = of(actor)
	var crossing: Dictionary = registry._crossing(actor, desired)
	if crossing.is_empty() and level(actor) == 0 and registry.preview(actor).is_empty():
		actor.move_and_slide()
	else:
		# Sweep each sliding remainder too; an obstacle must not push the actor
		# sideways off authored upper-floor support after the initial clearance check.
		var remainder: Vector2 = desired
		for _slide in 4:
			var collision: KinematicCollision2D = move(actor, remainder)
			if collision == null: break
			remainder = collision.get_remainder().slide(collision.get_normal())
			actor.velocity = actor.velocity.slide(collision.get_normal())
			if remainder.is_zero_approx(): break

static func move(actor: CharacterBody2D, desired: Vector2) -> KinematicCollision2D:
	var registry: Elevation = of(actor)
	var crossing: Dictionary = registry._crossing(actor, desired)
	if crossing.is_empty():
		if actor.has_meta(&"stairs_denied") and registry.preview(actor).is_empty(): actor.remove_meta(&"stairs_denied")
		return actor.move_and_collide(registry._supported_motion(actor, desired))
	var fraction: float = crossing.fraction
	var seam: Vector2 = actor.global_position + desired * fraction
	var destination: int = crossing.destination
	if not can_occupy(actor, seam, destination):
		if actor.has_method("show_message") and not actor.has_meta(&"stairs_denied"):
			actor.call("show_message", "The stairs are obstructed")
			actor.set_meta(&"stairs_denied", true)
		return actor.move_and_collide(desired * maxf(0, fraction - 0.001))
	if actor.has_meta(&"stairs_denied"): actor.remove_meta(&"stairs_denied")
	var first: KinematicCollision2D = actor.move_and_collide(desired * fraction)
	if first != null: return first
	set_level(actor, destination)
	return actor.move_and_collide(registry._supported_motion(actor, desired * (1.0 - fraction)))

func _crossing(actor: CharacterBody2D, motion: Vector2) -> Dictionary:
	var best: Dictionary = {}
	for transition: ElevationTransition in stairs:
		var crossing: Dictionary = transition.crossing(actor, motion)
		if not crossing.is_empty() and (best.is_empty() or float(crossing.fraction) < float(best.fraction)): best = crossing
	return best

func _supported_motion(actor: CharacterBody2D, desired: Vector2) -> Vector2:
	if level(actor) == 0: return desired
	var steps: int = maxi(1, ceili(desired.length() / 32.0))
	var radius: float = body_radius(actor)
	for index in range(1, steps + 1):
		if not support_at(actor.global_position + desired * float(index) / steps, level(actor), radius):
			return desired * float(index - 1) / steps
	return desired

static func definition_of(node: Node) -> ElevationDefinition:
	var current: Node = node
	while is_instance_valid(current):
		if current.has_meta(&"elevation_level"): return null
		if current.has_meta(&"elevation_definition"):
			var definition := current.get_meta(&"elevation_definition") as ElevationDefinition
			if definition != null: return definition
		current = current.get_parent()
	return null

static func level(node: Node) -> int:
	var current: Node = node
	while is_instance_valid(current):
		if current.has_meta(&"elevation_level"): return int(current.get_meta(&"elevation_level"))
		if current.has_meta(&"elevation_definition"):
			var definition := current.get_meta(&"elevation_definition") as ElevationDefinition
			if definition != null: return definition.level
		current = current.get_parent()
	return 0

static func occupies(node: Node, value: int) -> bool:
	var definition: ElevationDefinition = definition_of(node)
	return definition.occupies(value) if definition != null else level(node) == value

static func compatible(a: Node, b: Node) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b): return false
	if occupies(a, level(b)) or occupies(b, level(a)): return true
	var definition: ElevationDefinition = definition_of(a)
	if definition != null:
		for extra: int in definition.additional_levels:
			if occupies(b, extra): return true
	return false

static func accepts_hit(receiver: Node, source: Node, attack: AttackDefinition = null) -> bool:
	if attack != null:
		if attack.cross_elevations: return true
		if attack.has_hit_elevation: return occupies(receiver, attack.hit_elevation)
	return not is_instance_valid(source) or compatible(receiver, source)

static func stamp_attack(attack: AttackDefinition, value: int, cross: bool = false) -> AttackDefinition:
	if attack == null: return null
	var result := attack.duplicate() as AttackDefinition
	result.hit_elevation = value
	result.has_hit_elevation = true
	result.cross_elevations = attack.cross_elevations or cross
	return result

static func mask_for(mask: int, value: int, cross: bool = false) -> int:
	var categories: int = mask & CATEGORY_BITS
	if cross: return categories | (categories << RAISED_SHIFT)
	return categories if value == 0 else categories << RAISED_SHIFT

static func register_tree(root: Node) -> void:
	if Engine.is_editor_hint(): return
	if root is CollisionObject2D: register_body(root)
	for child: Node in root.get_children(): register_tree(child)

static func register_body(body: CollisionObject2D) -> void:
	if Engine.is_editor_hint(): return
	var registry: Elevation = of(body)
	var id: int = body.get_instance_id()
	if registry.members.has(id): return
	registry.members[id] = weakref(body)
	if not body is CharacterBody2D: registry.revision += 1
	body.set_meta(&"elevation_base_layer", body.collision_layer)
	body.set_meta(&"elevation_base_mask", body.collision_mask)
	if body is CharacterBody2D:
		body.set_meta(&"elevation_level", level(body))
		register_visual(body)
	registry._apply_masks(body)
	registry._refresh_exceptions(body)
	body.tree_exiting.connect(registry._forget_member.bind(id), CONNECT_ONE_SHOT)

static func base_layer(body: CollisionObject2D) -> int:
	return int(body.get_meta(&"elevation_base_layer", body.collision_layer))

static func base_mask(body: CollisionObject2D) -> int:
	return int(body.get_meta(&"elevation_base_mask", body.collision_mask))

static func set_masks(body: CollisionObject2D, layers: int, mask: int) -> void:
	if not body.is_inside_tree():
		body.collision_layer = layers
		body.collision_mask = mask
		return
	register_body(body)
	body.set_meta(&"elevation_base_layer", layers)
	body.set_meta(&"elevation_base_mask", mask)
	var registry: Elevation = of(body)
	registry._apply_masks(body)
	registry._refresh_exceptions(body)

static func set_level(body: CollisionObject2D, value: int) -> void:
	register_body(body)
	var previous: int = level(body)
	body.set_meta(&"elevation_level", value)
	var registry: Elevation = of(body)
	registry._apply_masks(body)
	registry._refresh_exceptions(body)
	if previous != value and body.has_method("on_elevation_changed"):
		body.call_deferred("on_elevation_changed", previous, value)
	if previous != value and not body is CharacterBody2D: registry.revision += 1

func _apply_masks(body: CollisionObject2D) -> void:
	var layers: int = mask_for(base_layer(body), level(body))
	var mask: int = mask_for(base_mask(body), level(body))
	var definition: ElevationDefinition = definition_of(body)
	if definition != null:
		for extra: int in definition.additional_levels:
			layers |= mask_for(base_layer(body), extra)
			mask |= mask_for(base_mask(body), extra)
	body.collision_layer = layers
	body.collision_mask = mask
	_index_body(body)

func _refresh_exceptions(member: CollisionObject2D) -> void:
	if not member is PhysicsBody2D: return
	var body := member as PhysicsBody2D
	_index_body(body)
	# Ground bodies have a separate physics bank and need no pairwise scan.
	var candidates: Array[CollisionObject2D] = []
	if raised_cells.has(body.get_instance_id()): candidates = nearby_raised(_body_bounds(body).grow(1024.0))
	# Reconcile existing pairs even when a body changes floor or leaves this window.
	for key: String in exceptions.keys():
		var pair: Dictionary = exceptions[key]
		var a: Variant = pair.a.get_ref()
		var b: Variant = pair.b.get_ref()
		if not is_instance_valid(a) or not is_instance_valid(b): _remove_exception(key); continue
		if a == body and not candidates.has(b): candidates.append(b)
		elif b == body and not candidates.has(a): candidates.append(a)
	for candidate: CollisionObject2D in candidates:
		if not is_instance_valid(candidate) or not candidate is PhysicsBody2D or candidate == body: continue
		var other := candidate as PhysicsBody2D
		var key: String = str(mini(body.get_instance_id(), other.get_instance_id())) + ":" + str(maxi(body.get_instance_id(), other.get_instance_id()))
		var shares_bank: bool = (body.collision_mask & other.collision_layer) != 0 or (other.collision_mask & body.collision_layer) != 0
		if shares_bank and not compatible(body, other):
			if not exceptions.has(key):
				var added_a: bool = not body.get_collision_exceptions().has(other)
				var added_b: bool = not other.get_collision_exceptions().has(body)
				if added_a: body.add_collision_exception_with(other)
				if added_b: other.add_collision_exception_with(body)
				exceptions[key] = {"a": weakref(body), "b": weakref(other), "added_a": added_a, "added_b": added_b}
		elif exceptions.has(key): _remove_exception(key)

func _remove_exception(key: String) -> void:
	var entry: Dictionary = exceptions[key]
	var a: Variant = entry.a.get_ref()
	var b: Variant = entry.b.get_ref()
	if is_instance_valid(a) and is_instance_valid(b):
		if entry.added_a: a.remove_collision_exception_with(b)
		if entry.added_b: b.remove_collision_exception_with(a)
	exceptions.erase(key)

func _forget_member(id: int) -> void:
	_unindex_body(id)
	# Reparenting leaves/re-enters the tree too. Restore semantic bits before a
	# new registration so raised masks cannot be shifted a second time.
	var departing: Variant = members[id].get_ref() if members.has(id) else null
	if is_instance_valid(departing):
		departing.collision_layer = base_layer(departing)
		departing.collision_mask = base_mask(departing)
		departing.tree_entered.connect(Elevation.register_body.bind(departing), CONNECT_ONE_SHOT)
	members.erase(id)
	# Dynamic actors never contributed static navigation occupancy on registration.
	# Their removal must not invalidate all local windows (e.g. expiring summons).
	if is_instance_valid(departing) and not departing is CharacterBody2D: revision += 1
	for key: String in exceptions.keys():
		var entry: Dictionary = exceptions[key]
		var a: Variant = entry.a.get_ref()
		var b: Variant = entry.b.get_ref()
		if not is_instance_valid(a) or not is_instance_valid(b) or a.get_instance_id() == id or b.get_instance_id() == id:
			_remove_exception(key)

func _body_bounds(body: CollisionObject2D) -> Rect2:
	var result := Rect2(body.global_position - Vector2.ONE, Vector2.ONE * 2)
	for child: Node in body.get_children():
		if child is CollisionShape2D and child.shape != null: result = result.merge(child.global_transform * child.shape.get_rect())
		elif child is CollisionPolygon2D:
			for point: Vector2 in child.polygon: result = result.expand(child.to_global(point))
	return result

func _unindex_body(identity: int) -> void:
	for cell: Vector2i in raised_cells.get(identity, []):
		if raised_buckets.has(cell):
			raised_buckets[cell].erase(identity)
			if raised_buckets[cell].is_empty(): raised_buckets.erase(cell)
	raised_cells.erase(identity)
	raised_movers.erase(identity)

func _index_body(body: CollisionObject2D) -> void:
	var identity: int = body.get_instance_id()
	_unindex_body(identity)
	if ((body.collision_layer | body.collision_mask) & (CATEGORY_BITS << RAISED_SHIFT)) == 0: return
	var rect: Rect2 = _body_bounds(body).grow(64.0)
	var lo := Vector2i((rect.position / CELL).floor())
	var hi := Vector2i((rect.end / CELL).floor())
	var cells: Array[Vector2i] = []
	for y in range(lo.y, hi.y+1):
		for x in range(lo.x, hi.x+1):
			var cell := Vector2i(x,y)
			if not raised_buckets.has(cell): raised_buckets[cell] = []
			raised_buckets[cell].append(identity)
			cells.append(cell)
	raised_cells[identity] = cells
	if body is CharacterBody2D: raised_movers[identity] = true

func nearby_raised(rect: Rect2) -> Array[CollisionObject2D]:
	var result: Array[CollisionObject2D] = []
	var seen: Dictionary = {}
	var lo := Vector2i((rect.position / CELL).floor())
	var hi := Vector2i((rect.end / CELL).floor())
	for y in range(lo.y, hi.y+1):
		for x in range(lo.x, hi.x+1):
			for identity: int in raised_buckets.get(Vector2i(x,y), []):
				if seen.has(identity): continue
				seen[identity] = true
				var object: Object = instance_from_id(identity)
				if is_instance_valid(object) and object is CollisionObject2D: result.append(object)
	return result

## Queries copy their parameters. Cached navigation jobs never get a twice-mapped
## mask or exclusions left behind by another cell's incompatible-floor results.
static func ray(actor: Node2D, original: PhysicsRayQueryParameters2D, value: int, cross: bool = false) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(original.from, original.to, mask_for(original.collision_mask, value, cross), original.exclude)
	query.collide_with_areas = original.collide_with_areas
	query.collide_with_bodies = original.collide_with_bodies
	query.hit_from_inside = original.hit_from_inside
	var hit: Dictionary = actor.get_world_2d().direct_space_state.intersect_ray(query)
	while not hit.is_empty() and not cross and not occupies(hit.collider, value):
		var excluded: Array[RID] = query.exclude
		excluded.append(hit.rid)
		query.exclude = excluded
		hit = actor.get_world_2d().direct_space_state.intersect_ray(query)
	return hit

static func shapes(actor: Node2D, original: PhysicsShapeQueryParameters2D, value: int, maximum: int = 32, cross: bool = false) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = original.shape
	query.transform = original.transform
	query.motion = original.motion
	query.margin = original.margin
	query.exclude = original.exclude
	query.collide_with_areas = original.collide_with_areas
	query.collide_with_bodies = original.collide_with_bodies
	query.collision_mask = mask_for(original.collision_mask, value, cross)
	var result: Array[Dictionary] = []
	while result.size() < maximum:
		var hits: Array[Dictionary] = actor.get_world_2d().direct_space_state.intersect_shape(query, 32)
		if hits.is_empty(): break
		var excluded: Array[RID] = query.exclude
		for hit: Dictionary in hits:
			excluded.append(hit.rid)
			if cross or occupies(hit.collider, value):
				result.append(hit)
				if result.size() >= maximum: break
		query.exclude = excluded
		if hits.size() < 32: break
	return result
