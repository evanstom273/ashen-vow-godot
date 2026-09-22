class_name SpellProjectile
extends Node2D

var direction := Vector2.RIGHT
var speed: float = 350.0
var lifetime: float = 3.0
var attack: AttackDefinition
var attacker_stats: AttributeStats
var source: Node
var tint: Color = Color("9fc8ff")
var radius: float = 10.0

func _ready() -> void:
    z_index = 35
    z_as_relative = false
    direction = direction.normalized()
    add_to_group("spell_projectiles")
    queue_redraw()

func _physics_process(delta: float) -> void:
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()
        return
    # Sample the entire travel segment so fast bolts cannot jump over targets.
    var distance: float = speed * delta
    var steps: int = maxi(1, ceili(distance / maxf(1.0, radius)))
    for _step in steps:
        if _collide(): return
        global_position += direction * distance / steps
    if _collide(): return
    queue_redraw()

func _collide() -> bool:
    var shape := CircleShape2D.new()
    shape.radius = radius
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape
    query.transform = Transform2D(0, global_position)
    query.collision_mask = 3
    if is_instance_valid(source) and source is CollisionObject2D:
        query.exclude = [(source as CollisionObject2D).get_rid()]
    for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
        var target: Node = result.collider
        if target == source: continue
        if target.has_method("is_targetable") and not target.is_targetable(): continue
        if target.has_method("receive_hit"):
            target.receive_hit(attack, attacker_stats, source)
        else:
            if target.has_method("take_damage"):
                target.take_damage(attack.health_damage(attacker_stats), source)
        Feedback.burst(global_position, "impact", direction)
        queue_free()
        return true
    return false

func _draw() -> void:
    draw_circle(Vector2.ZERO, radius * 1.9, Color(tint, 0.16))
    draw_circle(Vector2.ZERO, radius, tint)
    draw_circle(Vector2.ZERO, radius * 0.38, Color("f2fbff"))
    draw_line(-direction * radius * 2.5, Vector2.ZERO, Color(tint, 0.55), 2.0, true)
