extends Node
## Bounded, reusable world feedback. Audio is synthesized once, never per frame.
var reduced_effects: bool = false
var shake_strength: float = 1.0
var sounds: Dictionary = {}
var light_texture: Texture2D
var particle_texture: Texture2D
var voices: Array[AudioStreamPlayer2D] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 817
    _inputs()
    for bus in ["Effects", "Ambience"]:
        if AudioServer.get_bus_index(bus) < 0:
            AudioServer.add_bus()
            AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -15.0)
    light_texture = _radial(128)
    particle_texture = _radial(16)
    for kind in ["step", "roll", "swing", "wood", "metal", "hurt", "death", "shrine", "tell", "wind", "fire"]:
        sounds[kind] = _sound(kind)

func _inputs() -> void:
    var keys: Dictionary = {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "pause": [KEY_ESCAPE], "help": [KEY_TAB]}
    for action: String in keys:
        if not InputMap.has_action(action): InputMap.add_action(action)
        for key: int in keys[action]:
            var event := InputEventKey.new()
            event.physical_keycode = key as Key
            if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
    for action: String in {"target_previous": MOUSE_BUTTON_WHEEL_UP, "target_next": MOUSE_BUTTON_WHEEL_DOWN}:
        if not InputMap.has_action(action): InputMap.add_action(action)
        var event := InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_WHEEL_UP if action == "target_previous" else MOUSE_BUTTON_WHEEL_DOWN
        if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _radial(size: int) -> Texture2D:
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            var d: float = Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
            img.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0.0, 1.0 - d), 2.0)))
    return ImageTexture.create_from_image(img)

func burst(at: Vector2, kind: String = "dust", direction: Vector2 = Vector2.UP) -> void:
    if get_tree().get_nodes_in_group("transient_fx").size() >= 40: return
    var effect: GPUParticles2D = preload("res://scenes/fx_burst.tscn").instantiate()
    effect.add_to_group("transient_fx")
    effect.amount = 7 if reduced_effects else (24 if kind == "shrine" else 14)
    if kind == "footstep": effect.amount = 3 if reduced_effects else 5
    effect.lifetime = 0.65 if kind != "shrine" else 1.4
    effect.one_shot = true
    effect.explosiveness = 1.0
    effect.texture = particle_texture
    effect.z_index = 30
    effect.visibility_rect = Rect2(-180, -180, 360, 360)
    var mat := ParticleProcessMaterial.new()
    mat.particle_flag_disable_z = true
    mat.direction = Vector3(direction.x, direction.y, 0)
    mat.spread = 70.0
    mat.initial_velocity_min = 18.0
    mat.initial_velocity_max = 75.0 if kind != "shrine" else 110.0
    mat.gravity = Vector3(0, -10, 0)
    mat.damping_min = 25.0
    mat.damping_max = 45.0
    mat.scale_min = 0.3
    mat.scale_max = 0.85
    mat.color = Color("b1a894") if kind in ["dust", "footstep"] else Color("ffd299")
    if kind == "footstep":
        mat.initial_velocity_max = 28.0
        mat.scale_max = 0.4
    if kind == "shrine": mat.color = Color("a5eee4")
    var gradient := Gradient.new()
    gradient.set_color(0, Color.WHITE)
    gradient.set_color(1, Color(1, 1, 1, 0))
    var ramp := GradientTexture1D.new()
    ramp.gradient = gradient
    mat.color_ramp = ramp
    effect.process_material = mat
    get_tree().current_scene.add_child(effect)
    effect.global_position = at
    effect.emitting = true
    get_tree().create_timer(effect.lifetime + 0.2, false).timeout.connect(effect.queue_free)

func ambient_emitter(smoke: bool = false) -> GPUParticles2D:
    var effect := GPUParticles2D.new()
    effect.add_to_group("ambient_fx")
    effect.amount = 8
    effect.lifetime = 3.0
    effect.preprocess = 1.5
    effect.texture = light_texture if smoke else particle_texture
    effect.visibility_rect = Rect2(-120, -200, 240, 260)
    var mat := ParticleProcessMaterial.new()
    mat.particle_flag_disable_z = true
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(12, 4, 0)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 18
    mat.gravity = Vector3(3, -2, 0)
    mat.initial_velocity_min = 8
    mat.initial_velocity_max = 18
    mat.scale_min = 0.35 if smoke else 0.10
    mat.scale_max = 0.7 if smoke else 0.24
    mat.color = Color(0.28, 0.32, 0.34, 0.18) if smoke else Color(0.63, 0.93, 0.84, 0.65)
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 0))
    gradient.set_color(1, Color(1, 1, 1, 0))
    gradient.add_point(0.2, Color.WHITE)
    var ramp := GradientTexture1D.new()
    ramp.gradient = gradient
    mat.color_ramp = ramp
    effect.process_material = mat
    return effect

func play(kind: String, at: Vector2, volume: float = 0.0) -> void:
    if DisplayServer.get_name() == "headless": return
    for index in range(voices.size() - 1, -1, -1):
        if not is_instance_valid(voices[index]): voices.remove_at(index)
    if voices.size() >= 18 or not sounds.has(kind): return
    var voice := AudioStreamPlayer2D.new()
    voice.stream = sounds[kind]
    voice.bus = "Effects"
    voice.volume_db = volume - 10.0
    voice.pitch_scale = rng.randf_range(0.93, 1.07)
    voice.max_distance = 1200.0
    get_tree().current_scene.add_child(voice)
    voice.global_position = at
    voices.append(voice)
    voice.finished.connect(voice.queue_free)
    voice.play()

func _sound(kind: String) -> AudioStreamWAV:
    var duration: float = 0.15
    if kind in ["roll", "swing", "hurt", "tell"]: duration = 0.35
    if kind in ["shrine", "death"]: duration = 1.2
    if kind in ["wind", "fire"]: duration = 3.0
    var count: int = int(duration * 22050.0)
    var data := PackedByteArray()
    data.resize(count * 2)
    var smooth: float = 0.0
    for i in count:
        var t: float = float(i) / 22050.0
        var p: float = t / duration
        smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), 0.15)
        var value: float = smooth * exp(-p * 7.0)
        match kind:
            "shrine": value = (sin(t * TAU * 440.0) + sin(t * TAU * 660.0) * 0.5) * sin(PI * p) * exp(-p * 3.0) * 0.2
            "metal": value += sin(t * TAU * 930.0) * exp(-p * 18.0) * 0.25
            "wood", "step": value += sin(t * TAU * 130.0) * exp(-p * 15.0) * 0.4
            "tell": value = sin(t * TAU * (160.0 + 160.0 * p)) * sin(PI * p) * 0.2
            "wind": value = smooth * 0.16 + sin(t * TAU * 55.0) * 0.018
            "fire": value = smooth * 0.25
            "swing", "roll": value = smooth * sin(PI * p) * 0.8
            "death", "hurt": value += sin(t * TAU * (90.0 - p * 35.0)) * exp(-p * 7.0) * 0.3
        data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 24000.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = data
    if kind in ["wind", "fire"]:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_end = count
    return stream
