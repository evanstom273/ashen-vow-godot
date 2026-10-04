class_name SpellProjectile
extends Node2D

var direction := Vector2.RIGHT
var speed: float = 1400.0 # World units/second; independent of the drawing scale.
var lifetime: float = 3.0
var attack: AttackDefinition
var attacker_stats: AttributeStats
var source: Node
var tint: Color = Color("9fc8ff")
var radius: float = 40.0 # World-space collision radius.
var profile: VFXDefinition
var age: float = 0.0
var ended: bool = false

func _ready() -> void:
    if not has_meta(&"elevation_level"): set_meta(&"elevation_level", Elevation.level(source))
    attack = Elevation.stamp_attack(attack, Elevation.level(self))
    Elevation.register_visual(self)
    z_index = 35
    z_as_relative = false
    direction = direction.normalized()
    global_scale = Vector2.ONE * (profile.art_scale if profile != null else WorldScale.ART_SCALE)
    add_to_group("spell_projectiles")
    var mat := CanvasItemMaterial.new()
    mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    material = mat
    # Defer until the caster has assigned the world spawn position.
    call_deferred("_start_trail")
    queue_redraw()

func _start_trail() -> void:
    if ended or not is_inside_tree(): return
    Feedback.spell_effect(global_position, profile, &"trail", self)

func _finish(impact: bool) -> void:
    if ended: return
    ended = true
    Feedback.spell_effect(global_position, profile, &"burst", null, WorldScale.art_distance(36.0 if impact else 12.0), -1.0 if impact else 0.25, 0, Elevation.level(self))
    queue_free()

func _physics_process(delta: float) -> void:
    if ended: return
    if not is_instance_valid(source) or not source.is_inside_tree():
        _finish(false)
        return
    age += delta
    lifetime -= delta
    if lifetime <= 0.0:
        _finish(false)
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
    for result: Dictionary in Elevation.shapes(self, query, Elevation.level(self), 32, attack != null and attack.cross_elevations):
        var target: Node = result.collider
        if target == source: continue
        if target.has_method("is_targetable") and not target.is_targetable(): continue
        var previous_health: Variant = target.get("health")
        if target.has_method("receive_hit"):
            target.receive_hit(attack, attacker_stats, source)
        else:
            if target.has_method("take_damage"):
                target.take_damage(attack.health_damage(attacker_stats), source)
        var damaged: bool = previous_health != null and target.get("health") < previous_health
        if previous_health == null:
            Feedback.hit_effect(global_position, source, EnemyDefinition.HitSurface.STONE, attack)
        _finish(damaged or previous_health == null)
        return true
    return false

func _draw() -> void:
    if profile != null:
        var size: float = profile.visual_size
        draw_set_transform(Vector2.ZERO, direction.angle())
        draw_circle(Vector2.ZERO, size * 1.8, Color(profile.color, 0.12))
        match profile.style:
            VFXDefinition.Style.CRYSTAL:
                draw_colored_polygon(PackedVector2Array([Vector2(size * 1.4, 0), Vector2(-size * 0.6, -size * 0.45), Vector2(-size, 0), Vector2(-size * 0.6, size * 0.45)]), profile.color)
                for i in 3:
                    var orbit := Vector2(cos(age * 10 + i * TAU / 3), sin(age * 10 + i * TAU / 3)) * size
                    draw_circle(orbit, 2, profile.core_color)
            VFXDefinition.Style.FIRE:
                draw_colored_polygon(PackedVector2Array([Vector2(size * 1.5, 0), Vector2(-size, -size * 0.65), Vector2(-size * 0.4, 0), Vector2(-size, size * 0.65)]), profile.color)
                draw_circle(Vector2(-size * 0.4, sin(age * 30) * 2), size * 0.4, profile.core_color)
            VFXDefinition.Style.RADIANT:
                draw_line(Vector2(-size * 1.5, 0), Vector2(size, 0), profile.color, 4, true)
                draw_colored_polygon(PackedVector2Array([Vector2(size * 1.7, 0), Vector2(size * 0.5, -size * 0.4), Vector2(size * 0.8, 0), Vector2(size * 0.5, size * 0.4)]), profile.core_color)
            _:
                draw_circle(Vector2.ZERO, size, profile.color)
        draw_line(Vector2(-size * 0.6, 0), Vector2(size * 0.8, 0), profile.core_color, 1.5, true)
        draw_set_transform(Vector2.ZERO)
        return
    var local_radius: float = radius / WorldScale.ART_SCALE
    draw_circle(Vector2.ZERO, local_radius * 1.9, Color(tint, 0.16))
    draw_circle(Vector2.ZERO, local_radius, tint)
    draw_circle(Vector2.ZERO, local_radius * 0.38, Color("f2fbff"))
    draw_line(-direction * local_radius * 2.5, Vector2.ZERO, Color(tint, 0.55), 2.0, true)
