extends Node
var court: Node2D
var player: PlayerController
var failures: int = 0
var captures: bool = false

func _ready() -> void:
    captures = "--capture" in OS.get_cmdline_user_args()
    call_deferred("_run")

func check(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error("ACCEPTANCE FAIL: " + label)
    else: print("PASS: " + label)

func frames(count: int) -> void:
    for i in count: await get_tree().physics_frame

func snap(label: String) -> void:
    if not captures: return
    await RenderingServer.frame_post_draw
    var path: String = "res://.godot/qa/" + label + ".png"
    get_viewport().get_texture().get_image().save_png(path)
    print("CAPTURE: " + path)

func _run() -> void:
    DirAccess.make_dir_recursive_absolute("res://.godot/qa")
    court = load("res://scenes/main.tscn").instantiate()
    add_child(court)
    player = court.player
    player.set_process_unhandled_input(false)
    await frames(8)
    var enemy: Node2D = get_tree().get_first_node_in_group("sentinel")
    enemy.set_physics_process(false)
    await frames(285 if captures else 2)
    check(player.health == 5 and player.stamina == 100,"Spawn health and stamina")
    await snap("01-courtyard-idle")
    Input.action_press("move_right")
    player._right_held = true
    player._hold_time = 0.3
    await frames(12)
    check(player.sprinting and player.velocity.length() > 350,"Hold sprint and stamina expenditure")
    await snap("02-sprint")
    Input.action_release("move_right")
    player._right_held = false
    await frames(2)
    player.global_position = Vector2(-180,120)
    player.set_target(get_tree().get_first_node_in_group("interactable"))
    player._cooldown = 0
    player.stamina = 100
    player.request_action("dodge")
    check(player.dodge_direction.y > 0.8,"Stationary dodge uses locked aim")
    await frames(10)
    var prior_health: int = player.health
    player.take_damage(1,enemy)
    check(player.health == prior_health,"Roll invulnerability during active interval")
    await snap("03-roll")
    await frames(30)
    check(player.state == PlayerController.PlayerState.NORMAL and absf(player.visuals.roll_pivot.rotation) < 0.01,"Roll returns upright")
    player.stamina = 0
    player.request_action("attack")
    check(player.state == PlayerController.PlayerState.NORMAL,"Insufficient stamina prevents attack")
    player._regen_delay = 0
    await frames(15)
    check(player.stamina > 0,"Stamina regenerates")
    var dummy: Node2D = get_tree().get_first_node_in_group("resettable")
    player.global_position = dummy.global_position + Vector2(33,0)
    player.set_target(dummy)
    player.stamina = 100
    player.request_action("attack")
    await frames(9)
    await snap("04-attack-impact")
    await frames(28)
    check(dummy.health == 2,"One damage per active attack window")
    player.global_position = Vector2(700,400)
    await frames(2)
    check(player.locked_target == null and not dummy.locked,"Out-of-range lock clears indicator")
    var shrine: Node2D = get_tree().get_first_node_in_group("interactable")
    player.set_target(shrine)
    check(player.nearby_interactable() == null,"Distant shrine interaction rejected")
    player.global_position = shrine.global_position + Vector2(0,40)
    player.health = 2
    player.stamina = 20
    enemy.state = enemy.State.APPROACH
    check(not shrine.can_interact(player),"Rest blocked during combat")
    enemy.state = enemy.State.IDLE
    player.interact_nearby()
    check(player.health == 5 and player.stamina == 100 and dummy.health == 3,"Shrine restores and resets encounter")
    await frames(12)
    await snap("06-shrine")
    await _directions(dummy, enemy)
    player.global_position = Vector2(230,-20)
    enemy.reset_encounter()
    enemy.state = enemy.State.WINDUP
    enemy.clock = 0.35
    enemy.direction = Vector2.DOWN
    enemy.queue_redraw()
    player.set_target(enemy)
    await frames(15)
    await snap("05-sentinel-telegraph")
    enemy.set_physics_process(true)
    await frames(75)
    check(player.health < 5,"Sentinel strike damages player")
    enemy.set_physics_process(false)
    player._protection = 0
    player.take_damage(20,enemy)
    await frames(90)
    check(player.state == PlayerController.PlayerState.DEAD,"Player death disables actions")
    await snap("07-death")
    get_tree().paused = false
    print("ACCEPTANCE COMPLETE: ", failures, " failures")
    print("PERFORMANCE: FPS=", Engine.get_frames_per_second(), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000, " physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
    get_tree().quit(failures)

func _directions(dummy: Node2D, enemy: Node2D) -> void:
    var dummy_home: Vector2 = dummy.global_position
    var directions_ok: bool = true
    for i in 8:
        var direction: Vector2 = Vector2.RIGHT.rotated(i * TAU / 8)
        player.global_position = Vector2(-120,-140)
        dummy.global_position = player.global_position + direction * 36
        dummy.reset_encounter()
        player.set_target(dummy)
        player.stamina = 100
        player.request_action("attack")
        directions_ok = directions_ok and player.aim.dot(direction) > 0.99
        await frames(30)
        directions_ok = directions_ok and dummy.health == 2
    check(directions_ok,"Eight-direction attacks hit once and aim correctly")
    var rolls_ok: bool = true
    for face in [-1.0, 1.0]:
        for i in 8:
            var direction: Vector2 = Vector2.RIGHT.rotated(i * TAU / 8)
            player.global_position = Vector2(-120,-140)
            dummy.global_position = player.global_position + Vector2(face*100,0)
            dummy.reset_encounter()
            player.set_target(dummy)
            player._cooldown = 0
            player.stamina = 100
            _move(direction)
            player.request_action("dodge")
            _move(Vector2.ZERO)
            await frames(9)
            player.visuals._process(0.001)
            var screen_rotation: float = player.visuals.roll_pivot.rotation * player.facing
            var expected: float = signf(direction.x) if absf(direction.x) > 0.1 else signf(direction.y)
            rolls_ok = rolls_ok and signf(screen_rotation) == expected
            await frames(24)
            player.visuals._process(0.001)
            rolls_ok = rolls_ok and absf(player.visuals.roll_pivot.rotation) < 0.01
    check(rolls_ok,"All 16 direction/facing roll combinations spin and restore correctly")
    dummy.global_position = dummy_home
    dummy.reset_encounter()
    player.set_target(null)
    player.global_position = Vector2(0,260)
    player.health = 5
    player._protection = 0
    player._cooldown = 0
    player.stamina = 100
    player.request_action("dodge")
    player.take_damage(1,enemy)
    check(player.health == 4,"Roll startup remains vulnerable")
    player.take_damage(1,enemy)
    check(player.health == 4,"Damage protection prevents repeat hits")
    await frames(25)
    player.restore()
    player.request_action("attack")
    await frames(18)
    player._cooldown = 0
    player.request_action("dodge")
    await frames(8)
    check(player.state == PlayerController.PlayerState.DODGING,"Recovery input buffer starts dodge after attack")
    await frames(33)
    player._right_held = true
    player._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(not player._right_held,"Focus loss releases held sprint")

func _move(direction: Vector2) -> void:
    for action: String in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
    if direction.x < -0.1: Input.action_press("move_left")
    if direction.x > 0.1: Input.action_press("move_right")
    if direction.y < -0.1: Input.action_press("move_up")
    if direction.y > 0.1: Input.action_press("move_down")
