extends Node2D
## AnimationPlayer owns pose channels; this compositor alone owns rig transforms.
var tuck: float = 0.0
var swing: float = 0.0
var fall: float = 0.0
var recoil: float = 0.0
var flash: float = 0.0
var actor: PlayerController
var roll_pivot: Node2D
var animator: AnimationPlayer
var weapon: Node2D
var blade: Polygon2D
var trail: Polygon2D
var timer: float = 0.0
var lean: float = 0.0
var scarf_motion: float = 0.0
var scarf_velocity: float = 0.0
var previous_velocity := Vector2.ZERO
var materials: Array[ShaderMaterial] = []
var walk_blend: float = 0.0
var walk_phase: float = 0.0
var last_travel: float = 0.0

func _ready() -> void:
    actor = get_parent() as PlayerController
    roll_pivot = Node2D.new()
    roll_pivot.name = "RollPivot"
    actor.rig.add_child(roll_pivot)
    roll_pivot.position = Vector2(0, -9)
    var root: Node2D = actor.rig.get_node("Root")
    root.reparent(roll_pivot)
    root.position = Vector2(0, 9)
    for node: Node in root.find_children("*", "Polygon2D", true, false):
        var mat := ShaderMaterial.new()
        mat.shader = load("res://shaders/flash.gdshader")
        (node as Polygon2D).material = mat
        materials.append(mat)
    animator = AnimationPlayer.new()
    animator.root_node = NodePath("..")
    add_child(animator)
    var library := AnimationLibrary.new()
    library.add_animation("RESET", _animation(0.01, {"tuck": [[0, 0]], "swing": [[0, 0]], "fall": [[0, 0]], "recoil": [[0, 0]]}))
    var roll_time: float = actor.dodge_duration
    var strike: AttackDefinition = actor.attack
    var hurt_time: float = actor.vitals.stagger_duration
    library.add_animation("roll", _animation(roll_time, {"tuck": [[0, 0], [roll_time*0.133, 1], [roll_time*0.689, 1], [roll_time*0.889, 0.3], [roll_time, 0]]}))
    library.add_animation("attack", _animation(strike.duration(), {"swing": [[0, 0], [strike.windup*0.9, -0.9], [strike.windup+strike.active*0.4, 0.25], [strike.active_end(), 1.1], [strike.active_end()+strike.recovery*0.45, 0.8], [strike.duration(), 0]]}))
    library.add_animation("hurt", _animation(hurt_time, {"recoil": [[0, 0.4], [hurt_time*0.36, -0.2], [hurt_time, 0]], "tuck": [[0, 0], [hurt_time, 0]], "swing": [[0, 0], [hurt_time, 0]]}))
    library.add_animation("death", _animation(0.85, {"fall": [[0, 0], [0.18, 0.25], [0.6, 1], [0.85, 1]], "tuck": [[0, 0], [0.85, 0]], "swing": [[0, 0], [0.85, 0]]}))
    animator.add_animation_library("", library)
    weapon = Node2D.new()
    actor.add_child(weapon)
    blade = Polygon2D.new()
    blade.polygon = PackedVector2Array([Vector2(8,-2), Vector2(30,-3), Vector2(36,0), Vector2(30,3), Vector2(8,2)])
    blade.color = actor.equipped_weapon.blade_color
    root.get_node("RightArm/Weapon").color = actor.equipped_weapon.blade_color
    weapon.add_child(blade)
    trail = Polygon2D.new()
    trail.color = actor.attack.slash_color
    var effect_material := ShaderMaterial.new()
    effect_material.shader = load("res://shaders/slash.gdshader")
    trail.material = effect_material
    weapon.add_child(trail)
    weapon.visible = false

func _animation(length_seconds: float, tracks: Dictionary) -> Animation:
    var anim := Animation.new()
    anim.length = length_seconds
    for property: String in tracks:
        var track: int = anim.add_track(Animation.TYPE_VALUE)
        anim.track_set_path(track, NodePath(".:" + property))
        for key: Array in tracks[property]: anim.track_insert_key(track, float(key[0]), float(key[1]))
    return anim

func begin(action: String) -> void:
    animator.play(action)
    animator.advance(0)

func _process(delta: float) -> void:
    animator.speed_scale = 0.0 if actor.hit_stop > 0 else 1.0
    if actor.hit_stop > 0: return
    timer += delta
    flash = move_toward(flash, 0, delta * 7)
    for mat: ShaderMaterial in materials: mat.set_shader_parameter("flash", flash)
    var root: Node2D = roll_pivot.get_node("Root")
    var walking: bool = actor.state == PlayerController.PlayerState.NORMAL and actor.get_real_velocity().length() > 1
    walk_phase += maxf(0.0, actor.travel - last_travel) * PI / (31.0 if actor.sprinting else 25.0)
    last_travel = actor.travel
    walk_blend = move_toward(walk_blend, 1.0 if walking else 0.0, delta * 12.0)
    var stride: float = sin(walk_phase) * walk_blend
    var response: float = 1.0 - exp(-delta * 18)
    lean = lerpf(lean, actor.velocity.x / 365.0 * 0.13, response)
    var acceleration: Vector2 = (actor.velocity - previous_velocity).limit_length(450)
    previous_velocity = actor.velocity
    scarf_velocity += (-scarf_motion * 95 - scarf_velocity * 15 + acceleration.x * 0.08) * delta
    scarf_motion = clampf(scarf_motion + scarf_velocity * delta, -0.28, 0.28)
    actor.rig.scale = Vector2(actor.facing, 1.0)
    actor.rig.rotation = 0
    actor.rig.position = Vector2(0, -absf(stride) * (2.7 if actor.sprinting else 1.4) + sin(timer * 2.1) * 0.35 * (1.0 - fall))
    roll_pivot.rotation = 0
    roll_pivot.scale = Vector2(1.0 + tuck * 0.08, 1.0 - tuck * 0.24)
    if actor.state == PlayerController.PlayerState.DODGING:
        var p: float = clampf(actor.action_time / actor.dodge_duration, 0, 1)
        var screen_sign: float = signf(actor.dodge_direction.x) if absf(actor.dodge_direction.x) > 0.1 else signf(actor.dodge_direction.y)
        # Parent is mirrored: compensate once to preserve screen-space spin.
        roll_pivot.rotation = TAU * smoothstep(0.04, 0.94, p) * screen_sign * actor.facing
        actor.rig.position.y -= sin(p * PI) * 3
    roll_pivot.rotation += fall * 1.45 + recoil
    actor.rig.position.y += fall * 12
    actor.rig.modulate.a = 1.0 - fall * 0.28
    if actor._protection > 0 and actor.state != PlayerController.PlayerState.DEAD:
        actor.rig.modulate.a = 0.8 + sin(timer * 35) * 0.2
    var joints: Dictionary = {"LeftLeg": stride * 0.48 - tuck * 0.9, "RightLeg": -stride * 0.48 + tuck * 0.9, "LeftArm": -stride * 0.3 + tuck * 1.25, "RightArm": stride * 0.3 - tuck * 1.25 + swing, "Body": lean * actor.facing - stride * 0.025 + swing * 0.12, "Head": -lean * actor.facing * 0.6 + stride * 0.025}
    for joint: String in joints:
        var part: Node2D = root.get_node(joint)
        part.rotation = lerp_angle(part.rotation, float(joints[joint]), response)
    root.get_node("Body/Scarf").rotation = scarf_motion * actor.facing
    root.get_node("Body/CloakHighlight").position.x = scarf_motion * 2
    var attacking: bool = actor.state == PlayerController.PlayerState.ATTACKING
    root.get_node("RightArm/Weapon").visible = not attacking
    weapon.visible = attacking
    if attacking:
        weapon.scale = Vector2.ONE * actor.attack.reach / (42.0 * actor.scale.x / 1.25)
        weapon.z_index = -1 if actor.aim.y < -0.3 else 2
        weapon.rotation = actor.aim.angle() + swing
        var points := PackedVector2Array()
        for i in 13:
            var angle: float = -1.0 + float(i) / 12.0 * 1.2
            points.append(Vector2.RIGHT.rotated(angle) * 34)
        for i in range(12, -1, -1):
            var angle: float = -1.0 + float(i) / 12.0 * 1.2
            points.append(Vector2.RIGHT.rotated(angle) * 24)
        trail.polygon = points
        var fade_end: float = actor.attack.active_end() + actor.attack.recovery * 0.4
        trail.visible = actor.action_time >= actor.attack.windup and actor.action_time < fade_end
        (trail.material as ShaderMaterial).set_shader_parameter("fade", 1.0 - smoothstep(actor.attack.active_end(), fade_end, actor.action_time))
    var shadow: Node2D = actor.get_node("Shadow")
    shadow.scale = Vector2(1 + tuck * 0.15, 1 - tuck * 0.2)
    shadow.modulate.a = 1 - tuck * 0.25
