class_name EnemyMind
extends RefCounted
enum Mode { IDLE, PATROL, PURSUE, SEARCH, RETURN }
var mode: Mode = Mode.IDLE
var actor: CharacterBody2D
var definition: EnemyPerception
var target_id: int = 0
var last_known := Vector2.ZERO
var goal := Vector2.ZERO
var goal_level: int = 0
var last_known_level: int = 0
var lost_time: float = 0.0
var search_time: float = 0.0
var scan_time: float = 0.0
var sees_target: bool = false
var patrol_index: int = 0
var patrol_clock: float = 0.0
var cooldowns: Dictionary = {}

func setup(owner_actor: CharacterBody2D, settings: EnemyPerception) -> void:
	actor = owner_actor
	definition = settings if settings != null else EnemyPerception.new()
	goal = actor.global_position
	goal_level = Elevation.level(actor)

func target() -> Node2D:
	var object: Object = instance_from_id(target_id) if target_id != 0 else null
	return object as Node2D if is_instance_valid(object) and object is Node2D and SpellDeliveryService.alive(object) else null

func sight(candidate: Node2D) -> bool:
	if not SpellDeliveryService.alive(candidate) or not Elevation.compatible(actor, candidate): return false
	var query := PhysicsRayQueryParameters2D.create(actor.global_position, candidate.global_position, 1)
	var excluded: Array[RID] = [actor.get_rid()]
	if candidate is CollisionObject2D: excluded.append(candidate.get_rid())
	query.exclude = excluded
	return Elevation.ray(actor, query, Elevation.level(actor)).is_empty()

func provoke(source: Node2D, propagate: bool = true) -> void:
	if not SpellDeliveryService.alive(source): return
	var newly_alerted: bool = target_id != source.get_instance_id() or not engaged()
	target_id = source.get_instance_id()
	last_known = source.global_position
	last_known_level = Elevation.level(source)
	goal = last_known
	goal_level = last_known_level
	lost_time = 0.0
	search_time = 0.0
	mode = Mode.PURSUE
	sees_target = sight(source)
	if not propagate or not newly_alerted: return
	for neighbor: Node2D in ActorRegistry.nearby(actor.global_position, definition.alert_metres * 128.0, [&"enemy"]):
		if neighbor != actor and neighbor.has_method("receive_local_alert") and Elevation.compatible(actor, neighbor):
			neighbor.call("receive_local_alert", source, last_known)

func update(delta: float, home: Vector2, patrol: PackedVector2Array, home_level: int = 0) -> void:
	for key: Variant in cooldowns: cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
	scan_time -= delta
	var candidate: Node2D = target()
	if candidate == null and target_id != 0:
		target_id = 0
		mode = Mode.RETURN
		sees_target = false
	if scan_time <= 0:
		scan_time = maxf(0.1, definition.acquisition_interval)
		if candidate == null and mode in [Mode.IDLE, Mode.PATROL, Mode.RETURN]:
			var nearest: float = definition.sight_metres * 128.0
			for possible: Node2D in ActorRegistry.nearby(actor.global_position, nearest, [&"player", &"spell_ally"]):
				var distance: float = actor.global_position.distance_to(possible.global_position)
				if distance < nearest and sight(possible): candidate = possible; nearest = distance
			if candidate != null: provoke(candidate)
		sees_target = candidate != null and actor.global_position.distance_to(candidate.global_position) <= definition.sight_metres * 128.0 * 1.35 and sight(candidate)
	if candidate != null:
		if sees_target:
			last_known = candidate.global_position
			last_known_level = Elevation.level(candidate)
			lost_time = 0.0
			search_time = 0.0
			mode = Mode.PURSUE
		else:
			lost_time += delta
			if lost_time >= definition.memory_seconds or actor.global_position.distance_to(last_known) <= definition.arrival_metres * 128.0:
				mode = Mode.SEARCH
				search_time += delta
				if search_time >= definition.search_seconds:
					target_id = 0
					mode = Mode.RETURN
		goal = last_known
		goal_level = last_known_level
	if mode == Mode.RETURN:
		goal = home
		goal_level = home_level
		if Elevation.level(actor) == home_level and actor.global_position.distance_to(home) < definition.arrival_metres * 128.0: mode = Mode.IDLE
	if mode in [Mode.IDLE, Mode.PATROL]:
		goal = home
		goal_level = home_level
		if not patrol.is_empty():
			mode = Mode.PATROL
			goal = actor.get_parent().to_global(patrol[patrol_index % patrol.size()])
			if actor.global_position.distance_to(goal) < definition.arrival_metres * 128.0:
				patrol_clock += delta
				if patrol_clock >= definition.patrol_pause: patrol_index += 1; patrol_clock = 0.0

func choose(moves: Array[EnemyMove], distance: float) -> EnemyMove:
	if not sees_target: return null
	var best: EnemyMove
	for move: EnemyMove in moves:
		if move == null or move.attack == null or float(cooldowns.get(move.id, 0.0)) > 0: continue
		if distance < move.minimum_metres * 128.0 or distance > move.maximum_metres * 128.0: continue
		if best == null or move.priority > best.priority: best = move
	return best

func engaged() -> bool:
	return mode in [Mode.PURSUE, Mode.SEARCH] and target_id != 0

func clear() -> void:
	target_id = 0
	sees_target = false
	mode = Mode.IDLE
	lost_time = 0.0
	search_time = 0.0
	cooldowns.clear()
