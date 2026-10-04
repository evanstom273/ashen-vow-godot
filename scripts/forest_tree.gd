@tool
extends StaticBody2D
@export var variation: int = 0
@export_enum("Broadleaf", "Conifer", "Dead") var tree_family: int = 0
@export var tree_scale: float = 1.0
## Optional world-unit trunk footprint, independent of the overhanging crown.
@export var trunk_collision_radius: float = -1.0
@export var wind_profile: FoliageWindDefinition = preload("res://data/environment/wind_canopy.tres")
@export_group("Player reveal")
@export var reveal_enabled: bool = true
@export_range(1, 800, 1) var reveal_radius: float = 190.0
@export_range(0.1, 400, 0.5) var reveal_edge_softness: float = 64.0
@export_range(0, 1, 0.01) var reveal_minimum_opacity: float = 0.08
@export_range(0, 0.5, 0.01) var reveal_transition_time: float = 0.18
var reveal: ForegroundReveal
var canopy_art: Node2D
var art_signature: String = ""
var trunk_shape: CircleShape2D
var _art_built: bool = false

func _ready() -> void:
	_art_built = Engine.is_editor_hint()
	collision_layer = 1
	collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	trunk_shape = shape
	shape.radius = trunk_collision_radius if trunk_collision_radius > 0 else 17.0 * tree_scale
	collider.shape = shape
	add_child(collider)
	# Separate drawing item: the mask never touches the trunk, roots or shadow.
	# Keep its origin at the tree base so it retains the tree's Y-sort position.
	canopy_art = Node2D.new()
	canopy_art.name = "Canopy"
	_update_canopy_material()
	canopy_art.draw.connect(_draw_canopy)
	add_child(canopy_art)
	canopy_art.queue_redraw()
	queue_redraw()
	if not Engine.is_editor_hint():
		reveal = ForegroundReveal.new()
		reveal.name = "PlayerReveal"
		_configure_reveal()
		canopy_art.add_child(reveal)
		reveal.set_process(false)
		var screen := VisibleOnScreenNotifier2D.new()
		screen.rect = Rect2(Vector2(-95,-180)*tree_scale,Vector2(210,205)*tree_scale)
		screen.screen_entered.connect(_on_screen.bind(true))
		screen.screen_exited.connect(_on_screen.bind(false))
		add_child(screen)
		set_process(false)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		var wind_values: Array = [wind_profile.amplitude_metres,wind_profile.frequency,wind_profile.flutter] if wind_profile != null else []
		var signature: String = str([tree_scale,tree_family,variation,trunk_collision_radius,wind_values])
		if signature != art_signature:
			art_signature = signature
			trunk_shape.radius = trunk_collision_radius if trunk_collision_radius>0 else 17.0*tree_scale
			_update_canopy_material()
			queue_redraw()
			canopy_art.queue_redraw()

func _on_screen(value: bool) -> void:
	if value and not _art_built:
		_art_built = true
		queue_redraw()
		canopy_art.queue_redraw()
	if is_instance_valid(reveal):
		_configure_reveal()
		reveal.set_process(value)

func _configure_reveal() -> void:
	reveal.enabled = reveal_enabled
	reveal.radius = reveal_radius
	reveal.edge_softness = reveal_edge_softness
	reveal.minimum_opacity = reveal_minimum_opacity
	reveal.transition_time = reveal_transition_time
	reveal.visual_bounds = Rect2(-90, -165, 185, 140)

func _update_canopy_material() -> void:
	canopy_art.scale = Vector2.ONE * tree_scale
	canopy_art.material = wind_profile.make_material(165.0, float(variation) * 0.17, true) if wind_profile != null else null

func _draw() -> void:
	if not _art_built: return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * tree_scale)
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 7), Vector2(4, 17), Vector2(93, -35), Vector2(72, -56), Vector2(17, -19)]), Color(0.015, 0.027, 0.025, 0.32))
	draw_colored_polygon(PackedVector2Array([Vector2(-29, 10), Vector2(-17, -2), Vector2(-12, -86), Vector2(8, -98), Vector2(17, -6), Vector2(32, 10), Vector2(11, 4), Vector2(0, 11), Vector2(-8, 3)]), Color("302e27"))
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -82), Vector2(-2, -91), Vector2(1, 5), Vector2(-9, -5)]), Color("64604a"))
	draw_line(Vector2(10, -60), Vector2(32, -84), Color("393d2e"), 7)
	for i in 6:
		var side: float = -1 if i%2==0 else 1
		var root := Vector2(side*(6+i),-4)
		draw_line(root,Vector2(side*(24+i*3),8+i*0.6),Color("4b4d38"),maxf(1,5-i*0.5))
	if tree_family == 2:
		for i in 5:
			var side: float = -1 if i%2==0 else 1
			var branch := Vector2(side*(25+i*4),-60-i*13)
			draw_line(Vector2(0,-35-i*14),branch,Color("535944"),6-i*0.6)
			draw_line(branch,branch+Vector2(side*12,-20),Color("73745a"),2.5)
	draw_set_transform(Vector2.ZERO)

func _draw_canopy() -> void:
	if not _art_built: return
	var random := RandomNumberGenerator.new()
	random.seed = variation + 991
	canopy_art.draw_set_transform(Vector2.ZERO)
	if tree_family == 2:
		canopy_art.draw_set_transform(Vector2.ZERO)
		return
	if tree_family == 1:
		for layer in 5:
			var width: float = 58-layer*8
			var y: float = -35-layer*23
			var crown := PackedVector2Array([Vector2(-width,y+12),Vector2(-width*0.65,y-10),Vector2(-8,y-55),Vector2(8,y-52),Vector2(width*0.8,y-5),Vector2(width,y+14),Vector2(3,y+23)])
			canopy_art.draw_colored_polygon(crown,Color("254535").lightened(layer*0.028))
			canopy_art.draw_line(Vector2(-width*0.6,y+3),Vector2(-9,y-31),Color("536e46"),2)
		canopy_art.draw_set_transform(Vector2.ZERO)
		return
	for layer in 4:
		var center := Vector2(random.randf_range(-15, 15), -68 - layer * 17)
		var radius: float = 66 - layer * 10
		var canopy := PackedVector2Array()
		for i in 11:
			var angle: float = i * TAU / 11.0
			canopy.append(center + Vector2(cos(angle), sin(angle) * 0.55) * radius * random.randf_range(0.8, 1.13))
		var colors: Array[Color] = [Color("172d29"), Color("254136"), Color("344e3b"), Color("466044")]
		canopy_art.draw_colored_polygon(canopy, colors[layer])
		for i in 4:
			var at: Vector2 = center + Vector2(random.randf_range(-radius * 0.6, radius * 0.6), random.randf_range(-12, 9))
			canopy_art.draw_line(at, at + Vector2(8, -3), Color("63714c"), 2)
		# Offset lobes give broadleaf crowns an asymmetric, branching silhouette.
		for lobe in 3:
			var at: Vector2 = center+Vector2((lobe-1)*radius*0.55,sin(variation+lobe)*12)
			var leaves := PackedVector2Array()
			for vertex in 7:
				leaves.append(at+Vector2.from_angle(vertex*TAU/7)*Vector2(radius*0.4,radius*0.22)*random.randf_range(0.8,1.1))
			canopy_art.draw_colored_polygon(leaves,colors[layer].lightened(0.025))
	canopy_art.draw_set_transform(Vector2.ZERO)
