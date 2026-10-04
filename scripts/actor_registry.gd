extends Node
## Bounded, scene-lifetime actor index. IDs are resolved before any object access.
const CELL: float = 2048.0
var actors: Dictionary = {}
var buckets: Dictionary = {}
var cursor: int = 0
var clock: float = 0.0

func register(actor: Node2D) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(actor): return
	var identity: int = actor.get_instance_id()
	if actors.has(identity): return
	actors[identity] = Vector2i(2147483647, 2147483647)
	actor.tree_exiting.connect(unregister.bind(identity), CONNECT_ONE_SHOT)
	_update(identity)

func unregister(identity: int) -> void:
	if not actors.has(identity): return
	var key: Vector2i = actors[identity]
	if buckets.has(key):
		buckets[key].erase(identity)
		if buckets[key].is_empty(): buckets.erase(key)
	actors.erase(identity)

func _update(identity: int) -> void:
	var object: Object = instance_from_id(identity)
	if not is_instance_valid(object) or not object is Node2D:
		unregister(identity)
		return
	var cell := Vector2i(floori(object.global_position.x / CELL), floori(object.global_position.y / CELL))
	var previous: Vector2i = actors[identity]
	if previous == cell: return
	if buckets.has(previous):
		buckets[previous].erase(identity)
		if buckets[previous].is_empty(): buckets.erase(previous)
	if not buckets.has(cell): buckets[cell] = []
	buckets[cell].append(identity)
	actors[identity] = cell

func nearby(at: Vector2, radius: float, groups: Array[StringName] = []) -> Array[Node2D]:
	var result: Array[Node2D] = []
	# One extra cell tolerates bounded index-update latency without dropping contacts.
	var lo := Vector2i(floori((at.x - radius) / CELL) - 1, floori((at.y - radius) / CELL) - 1)
	var hi := Vector2i(floori((at.x + radius) / CELL) + 1, floori((at.y + radius) / CELL) + 1)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			for identity: int in buckets.get(Vector2i(x, y), []):
				var object: Object = instance_from_id(identity)
				if not is_instance_valid(object) or not object is Node2D: continue
				var actor := object as Node2D
				if actor.is_queued_for_deletion() or not actor.is_inside_tree() or actor.global_position.distance_squared_to(at) > radius * radius: continue
				var matches: bool = groups.is_empty()
				for group: StringName in groups:
					if actor.is_in_group(group): matches = true; break
				if matches: result.append(actor)
	return result

func registered() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for identity: int in actors:
		var object: Object = instance_from_id(identity)
		if is_instance_valid(object) and object is Node2D: result.append(object)
	return result

func _physics_process(delta: float) -> void:
	clock += delta
	if clock < 0.1 or actors.is_empty(): return
	clock = 0.0
	var identities: Array = actors.keys()
	for _index in mini(64, identities.size()):
		cursor %= identities.size()
		_update(int(identities[cursor]))
		cursor += 1
