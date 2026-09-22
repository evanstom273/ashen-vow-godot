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
    take_damage(incoming.health_damage(attacker_stats, vitals.defence), source)
func take_damage(amount: int, _source: Node) -> void:
    if health <= 0: return
    health = maxi(0, health - amount)
    wobble = 0.7
    timer = 0
    Feedback.play(String(definition.hit_sound), global_position)
    if health == 0:
        reset_timer = definition.auto_restore_delay
        locked = false
        Feedback.burst(global_position, "dust")
func set_lock_on(value: bool) -> void: locked = value
func reset_encounter() -> void:
    health = max_health
    visual.rotation = 0
    visual.modulate = Color.WHITE
    wobble = 0
    locked = false
