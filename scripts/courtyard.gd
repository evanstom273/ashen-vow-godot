@tool
extends Node2D
@export var game_data: GameDataCatalog = preload("res://data/game_catalog.tres")
var rng := RandomNumberGenerator.new()
var actors: Node2D
var player: PlayerController
var ambient_particles: GPUParticles2D
var elapsed: float = 0.0

func _ready() -> void:
    rng.seed = 4318
    if Engine.is_editor_hint():
        _floor()
        queue_redraw()
        return
    RenderingServer.set_default_clear_color(Color("101b24"))
    _floor()
    var ambient := CanvasModulate.new()
    ambient.color = Color("a6b5c5")
    add_child(ambient)
    actors = $Actors
    player = $Actors/Player
    for i in 75:
        var at := Vector2(rng.randf_range(-735,735),rng.randf_range(-435,435))
        if absf(at.x) < 535 and absf(at.y) < 305: continue
        _prop("grass" if i % 3 != 0 else "rubble",at)
    for wall: Rect2 in [Rect2(-820,-520,1640,45),Rect2(-820,475,1640,45),Rect2(-820,-520,45,1040),Rect2(775,-520,45,1040)]:
        var body := StaticBody2D.new()
        var collider := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = wall.size
        collider.shape = shape
        body.position = wall.get_center()
        body.add_child(collider)
        add_child(body)
    _atmosphere()
    var hud := CanvasLayer.new()
    hud.set_script(load("res://scripts/court_hud.gd"))
    add_child(hud)
    var sound := AudioStreamPlayer.new()
    sound.stream = Feedback.sounds.get("wind")
    sound.bus = "Ambience"
    add_child(sound)
    if DisplayServer.get_name() != "headless": sound.play()

func _entity(path: String, at: Vector2, label: String) -> void:
    var entity: Node2D = load(path).instantiate()
    entity.name = label
    entity.position = at
    actors.add_child(entity)

func _prop(kind: String, at: Vector2) -> void:
    var prop: Node2D = load("res://scenes/court_prop.tscn").instantiate()
    prop.kind = kind
    prop.position = at
    actors.add_child(prop)

func _floor() -> void:
    var texture: Texture2D = load("res://assets/paving.svg")
    var source := TileSetAtlasSource.new()
    source.texture = texture
    source.texture_region_size = Vector2i(64,64)
    for i in 4: source.create_tile(Vector2i(i,0))
    var tile_set := TileSet.new()
    tile_set.tile_size = Vector2i(64,64)
    tile_set.add_source(source,0)
    var floor_layer := TileMapLayer.new()
    floor_layer.name = "WeatheredPaving"
    floor_layer.tile_set = tile_set
    floor_layer.z_index = -20
    var stone := ShaderMaterial.new()
    stone.shader = load("res://shaders/stone.gdshader")
    floor_layer.material = stone
    add_child(floor_layer)
    for y in range(-8,8):
        for x in range(-13,13): floor_layer.set_cell(Vector2i(x,y),0,Vector2i(rng.randi_range(0,3),0))

func _atmosphere() -> void:
    ambient_particles = GPUParticles2D.new()
    ambient_particles.amount = 65
    ambient_particles.lifetime = 10
    ambient_particles.preprocess = 5
    ambient_particles.texture = Feedback.particle_texture
    ambient_particles.z_index = 40
    ambient_particles.visibility_rect = Rect2(-1000,-700,2000,1400)
    var process := ParticleProcessMaterial.new()
    process.particle_flag_disable_z = true
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(820,520,0)
    process.direction = Vector3(0.6,1,0)
    process.spread = 15
    process.gravity = Vector3(0,0,0)
    process.initial_velocity_min = 8
    process.initial_velocity_max = 16
    process.scale_min = 0.10
    process.scale_max = 0.22
    process.color = Color(0.8,0.85,0.8,0.28)
    ambient_particles.process_material = process
    add_child(ambient_particles)
    for side in [-1,1]:
        var mist := GPUParticles2D.new()
        mist.amount = 8
        mist.lifetime = 12
        mist.preprocess = 8
        mist.texture = Feedback.light_texture
        mist.position = Vector2(side*720,0)
        mist.z_index = 5
        var effect_material := ParticleProcessMaterial.new()
        effect_material.particle_flag_disable_z = true
        effect_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        effect_material.emission_box_extents = Vector3(45,470,0)
        effect_material.direction = Vector3(0,-1,0)
        effect_material.initial_velocity_min = 4
        effect_material.initial_velocity_max = 9
        effect_material.gravity = Vector3.ZERO
        effect_material.scale_min = 2
        effect_material.scale_max = 4
        effect_material.color = Color(0.3,0.4,0.45,0.08)
        mist.process_material = effect_material
        mist.add_to_group("ambient_fx")
        add_child(mist)

func _process(delta: float) -> void:
    if Engine.is_editor_hint(): return
    elapsed += delta
    ambient_particles.amount_ratio = 0.3 if Feedback.reduced_effects else 1.0
    for effect: Node in get_tree().get_nodes_in_group("ambient_fx"):
        (effect as GPUParticles2D).amount_ratio = 0.3 if Feedback.reduced_effects else 1.0

func _draw() -> void:
    # Fixed handcrafted architectural details, above tiles but below actors.
    draw_rect(Rect2(-830,-530,1660,1060),Color("17232b"),false,20)
    for y in [-468,442]:
        for i in 26:
            var x: float = -810+i*64
            draw_rect(Rect2(x,y,61,30),Color("465154"))
            draw_line(Vector2(x,y),Vector2(x+61,y),Color("6d756e"),2)
            draw_rect(Rect2(x,y+30,61,12),Color("26353c"))
    for x in [-794,766]:
        for i in 14:
            var y: float = -430+i*64
            draw_rect(Rect2(x,y,27,61),Color("465154"))
    for inset in [0,10]:
        draw_rect(Rect2(-568-inset,-324-inset,1136+inset*2,648+inset*2),Color(0.45,0.46,0.38,0.26),false,1)
    for radius in [115,121,157]:
        draw_arc(Vector2(170,-60),radius,0.16,TAU-0.16,96,Color(0.6,0.55,0.4,0.20),2,true)
    for i in 12:
        var dir := Vector2.RIGHT.rotated(i*TAU/12)
        draw_line(Vector2(170,-60)+dir*127,Vector2(170,-60)+dir*143,Color(0.6,0.55,0.4,0.25),2,true)
    draw_colored_polygon(PackedVector2Array([Vector2(170,-105),Vector2(187,-60),Vector2(170,-15),Vector2(153,-60)]),Color(0.6,0.55,0.4,0.17))
    for step in 3:
        var rect := Rect2(-310-step*9,215+step*15,220+step*18,70)
        draw_rect(rect,Color("3f4d51").darkened(step*0.06))
        draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color("69736c"),1)
    draw_rect(Rect2(-286,224,172,74),Color("2b3b43"))
    var decoration_rng := RandomNumberGenerator.new()
    decoration_rng.seed = 730
    for i in 95:
        var p := Vector2(decoration_rng.randf_range(-740,740),decoration_rng.randf_range(-430,430))
        if i % 3 == 0:
            draw_polyline(PackedVector2Array([p,p+Vector2(9,5),p+Vector2(14,3),p+Vector2(22,11)]),Color(0.07,0.12,0.14,0.35),1,true)
        else:
            draw_circle(p,decoration_rng.randf_range(1,2),Color(0.48,0.48,0.41,0.16))
