@tool
extends StaticBody2D
@export_enum("pillar", "brazier", "grass", "banner", "rubble") var kind: String = "pillar"
var clock: float = 0.0
var light: PointLight2D
var actor: Node2D
var art: Node2D
var faded: float = 1.0
@export var flame_vfx: VFXDefinition = preload("res://data/vfx/brazier_flame.tres")
@export var ember_vfx: VFXDefinition = preload("res://data/vfx/brazier_embers.tres")
@export var smoke_vfx: VFXDefinition = preload("res://data/vfx/brazier_smoke.tres")

func _ready() -> void:
	clock = absf(position.x * 0.013 + position.y * 0.021)
	if Engine.is_editor_hint():
		queue_redraw()
		return
	actor = get_tree().get_first_node_in_group("player")
	collision_layer = 1 if kind in ["pillar", "brazier"] else 0
	collision_mask = 0
	if collision_layer != 0:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 21 if kind == "pillar" else 13
		shape.shape = circle
		add_child(shape)
	if kind == "pillar":
		var occluder := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-12,-8),Vector2(12,-8),Vector2(12,8),Vector2(-12,8)])
		occluder.occluder = poly
		occluder.occluder_light_mask = 2
		add_child(occluder)
	if kind == "brazier":
		light = PointLight2D.new()
		light.texture = Feedback.light_texture
		light.texture_scale = 5.0
		light.color = Color("ffc489")
		light.energy = 1.4
		light.position.y = -30
		light.shadow_enabled = true
		light.shadow_item_cull_mask = 2
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		add_child(light)
		var glow := Sprite2D.new()
		glow.texture = Feedback.light_texture
		glow.position.y = -34
		glow.scale = Vector2.ONE * 1.4
		glow.modulate = Color(1.0,0.48,0.16,0.2)
		var glow_material := CanvasItemMaterial.new()
		glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		glow.material = glow_material
		add_child(glow)
		Feedback.physical_effect(to_global(Vector2(0, -34)), flame_vfx, &"flame", Vector2.UP, 1, self, true)
		Feedback.physical_effect(to_global(Vector2(0, -35)), ember_vfx, &"embers", Vector2.UP, 1, self, true)
		Feedback.physical_effect(to_global(Vector2(0, -44)), smoke_vfx, &"smoke", Vector2.UP, 1, self, true)
		var sound := AudioStreamPlayer2D.new()
		sound.stream = Feedback.sounds.get("fire")
		sound.bus = "Ambience"
		sound.volume_db = -15
		sound.max_distance = 380 * WorldScale.actor_scale(self)
		add_child(sound)
		if DisplayServer.get_name() != "headless": sound.play()

func _process(delta: float) -> void:
	clock += delta
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if not is_instance_valid(actor): actor = get_tree().get_first_node_in_group("player")
	var relative: Vector2 = to_local(actor.global_position) if is_instance_valid(actor) else Vector2.INF
	var behind: bool = relative.y < 0 and relative.y > -85 and absf(relative.x) < 36
	faded = move_toward(faded, 0.35 if behind and kind in ["pillar", "banner"] else 1.0, delta * 4)
	modulate.a = faded
	if light != null:
		light.energy = 1.25 + sin(clock * 1.7) * 0.1 + sin(clock * 2.3) * 0.05
	queue_redraw()

func _draw() -> void:
	match kind:
		"pillar":
			draw_set_transform(Vector2(8,8),0,Vector2(1,0.45))
			draw_circle(Vector2.ZERO,32,Color(0,0,0,0.35))
			draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(-28,-5,56,18),Color("282f33"))
			draw_rect(Rect2(-25,-14,50,20),Color("576062"))
			draw_rect(Rect2(-18,-72,36,63),Color("475256"))
			draw_rect(Rect2(-17,-71,8,60),Color("606b6a"))
			draw_rect(Rect2(11,-71,7,60),Color("323d43"))
			draw_rect(Rect2(-25,-77,50,12),Color("737b72"))
			draw_line(Vector2(-15,-43),Vector2(15,-43),Color("2f3c41"),2)
			draw_polyline(PackedVector2Array([Vector2(6,-73),Vector2(1,-61),Vector2(7,-52),Vector2(2,-43)]),Color("2a373b"),2,true)
		"brazier":
			draw_set_transform(Vector2(4,7),0,Vector2(1,0.4))
			draw_circle(Vector2.ZERO,23,Color(0,0,0,0.4))
			draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(-12,-5,24,11),Color("414247"))
			draw_rect(Rect2(-5,-26,10,24),Color("555653"))
			draw_polygon(PackedVector2Array([Vector2(-18,-34),Vector2(18,-34),Vector2(10,-21),Vector2(-10,-21)]),PackedColorArray([Color("6b6556")]))
			if Engine.is_editor_hint():
				for i in 4:
					var x: float = -10 + i * 7
					var height: float = 15 + sin(clock*8+i*1.8)*6
					draw_colored_polygon(PackedVector2Array([Vector2(x-5,-33),Vector2(x+sin(clock*5+i)*3,-33-height),Vector2(x+5,-33)]),Color("e5a15c"))
					draw_colored_polygon(PackedVector2Array([Vector2(x-3,-33),Vector2(x+sin(clock*4+i)*2,-33-height*0.7),Vector2(x+3,-33)]),Color("ffd887"))
					draw_line(Vector2(x,-34),Vector2(x,-39-height*0.35),Color("ffe1a0"),3,true)
		"grass":
			for i in 7:
				var x: float = i * 3 - 9
				draw_line(Vector2(x,0),Vector2(x-5+sin(clock*1.5+i)*3,-9-fmod(i*7.0,13)),Color("626453"),1,true)
		"banner":
			draw_line(Vector2(0,6),Vector2(0,-85),Color("777568"),3,true)
			draw_line(Vector2(-3,-82),Vector2(36,-82),Color("777568"),3,true)
			var wave: float = sin(clock*2)*3
			draw_colored_polygon(PackedVector2Array([Vector2(3,-80),Vector2(32,-80),Vector2(30+wave,-32),Vector2(18+wave,-39),Vector2(4+wave,-30)]),Color("68444b"))
			draw_line(Vector2(17,-74),Vector2(17+wave,-47),Color("b4996c"),2,true)
		"rubble":
			draw_colored_polygon(PackedVector2Array([Vector2(-15,3),Vector2(-12,-8),Vector2(2,-11),Vector2(12,1),Vector2(5,8)]),Color("414b4e"))
			draw_line(Vector2(-12,-8),Vector2(2,-11),Color("67706a"),2,true)
