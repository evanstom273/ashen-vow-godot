class_name TrainingDummy
extends TargetableEntity
@export var definition: EnemyDefinition = preload("res://data/enemies/training_effigy.tres")
var attributes: AttributeStats
var vitals: VitalStats
var timer: float = 0.0
var wobble: float = 0.0
var locked: bool = false
var reset_timer: float = 0.0
var visual: Node2D
var flash_material: ShaderMaterial
func _ready() -> void:
	if definition == null: definition = load("res://data/enemies/training_effigy.tres")
	attributes = definition.attributes.duplicate(true) as AttributeStats if definition.attributes != null else AttributeStats.new()
	vitals = definition.vitals if definition.vitals != null else VitalStats.new()
	max_health = vitals.max_health(attributes)
	super._ready()
	z_index = 0
	add_to_group("resettable")
	visual = Node2D.new()
	add_child(visual)
	flash_material = ShaderMaterial.new()
	flash_material.shader = load("res://shaders/flash.gdshader")
	visual.material = flash_material
	for path: String in ["Body", "Head", "Eye"]:
		var part: Polygon2D = get_node(path)
		part.reparent(visual)
		part.use_parent_material = true
	$LockRing.z_index = -1
func _process(delta: float) -> void:
	timer += delta
	wobble = move_toward(wobble, 0, delta * 2)
	visual.rotation = sin(timer * 25) * wobble * 0.3
	flash_material.set_shader_parameter("flash", minf(1, wobble * 1.5))
	$LockRing.visible = locked and health > 0
	$LockRing.scale = Vector2.ONE * (1 + sin(timer * 3) * 0.035)
	if health == 0:
		reset_timer -= delta
		visual.rotation = 1.3
		visual.modulate.a = 0.45
		if reset_timer <= 0 and definition.auto_restore_delay > 0: reset_encounter()
func get_display_name() -> String: return definition.display_name
func receive_hit(incoming: AttackDefinition, attacker_stats: AttributeStats, source: Node) -> void:
	_apply_hit(incoming.health_damage(attacker_stats, SpellEffects.defence(self, vitals.defence)), source, incoming, attacker_stats)
func take_damage(amount: int, source: Node) -> void:
	_apply_hit(amount, source)
func _apply_hit(amount: int, source: Node, incoming: AttackDefinition = null, attacker_stats: AttributeStats = null) -> void:
	if not Elevation.accepts_hit(self, source, incoming): return
	if health <= 0: return
	if health > amount: SpellEffects.apply_attack(self, incoming, attacker_stats, source)
	if amount == 0 and incoming != null and incoming.max_health_drain != null: return
	Feedback.damage_number(self, mini(amount, health))
	if amount > 0: Feedback.hit_effect(global_position, source, definition.hit_surface, incoming, amount, self)
	health = maxi(0, health - amount)
	if incoming == null or not incoming.periodic_damage:
		wobble = 0.7
		timer = 0
		Feedback.play(String(definition.hit_sound), global_position)
	if health == 0:
		reset_timer = definition.auto_restore_delay
		locked = false
		Feedback.burst(global_position, "death", Vector2.UP, null, get_instance_id())
func set_lock_on(value: bool) -> void: locked = value
func reset_encounter() -> void:
	SpellEffects.of(self).clear()
	health = max_health
	visual.rotation = 0
	visual.modulate = Color.WHITE
	wobble = 0
	locked = false
