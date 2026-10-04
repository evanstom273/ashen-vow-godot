class_name TargetableEntity
extends Node2D

var max_health: int = 1

var health: int = 1


func _ready() -> void:
	health = max_health
	add_to_group("targetable")
	if not Engine.is_editor_hint(): ActorRegistry.register(self)
	Elevation.register_tree(self)
	Elevation.register_visual(self)


func is_targetable() -> bool:
	return health > 0 and visible


func get_target_point() -> Vector2:
	return global_position


func take_damage(amount: int, source: Node) -> void:
	if not Elevation.accepts_hit(self, source): return
	if health <= 0 or amount <= 0: return
	health = maxi(0, health - amount)
	if health == 0:
		visible = false

func receive_hit(attack: AttackDefinition, stats: AttributeStats, source: Node) -> HitResult:
	if attack == null: return HitResult.reject(&"missing_attack")
	var rejected: StringName = hit_rejection(source, attack)
	if not rejected.is_empty(): return HitResult.reject(rejected)
	var amount: int = attack.health_damage(stats)
	if amount <= 0: return HitResult.reject(&"no_damage")
	var result := HitResult.accept(mini(amount, health))
	health = maxi(0, health - amount)
	result.killed = health == 0
	if result.killed: visible = false
	return result

func hit_rejection(source: Node, incoming: AttackDefinition = null) -> StringName:
	if not Elevation.accepts_hit(self, source, incoming): return &"elevation"
	if health <= 0: return &"dead"
	return &""


func set_lock_on(locked: bool) -> void:
	if has_node("LockRing"):
		$LockRing.visible = locked and is_targetable()
