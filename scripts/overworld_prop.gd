@tool
class_name OverworldProp
extends StaticBody2D
## Polygon art in metres; separate upper art allows reveal without changing collision.
enum DrawLayer { AUTO, GROUND, Y_SORTED }
## Above landmark floors (-15), below actors/solid props (0).
const GROUND_ART_Z: int = -10
@export_enum("grave", "rock", "wall", "tower", "pool", "waystone", "slab", "rubble", "buttress", "arch", "stairs", "bridge", "fallen_tree", "camp", "bush", "grass", "reeds") var kind: String = "rock"
@export var footprint := Vector2(1.2, 0.8)
@export var height_metres: float = 1.0
@export var flight_blocker: bool = false
@export var solid: bool = true
@export var variation: int = 0
@export_group("Presentation")
## Auto keeps walkable steps, bridges, water and non-solid slabs below actors.
## Solid furniture and architecture retain depth sorting. Collision is independent.
@export var draw_layer: DrawLayer = DrawLayer.AUTO
@export var wind_profile: FoliageWindDefinition = preload("res://data/environment/wind_undergrowth.tres")
var ground_art: Node2D
var upper: Node2D
var shore_art: Node2D
var collider: CollisionPolygon2D
var reveal: ForegroundReveal
var outline := PackedVector2Array()
var elapsed: float = 0
var configuration: String = ""
var _art_built: bool = false

func _ready() -> void:
	_art_built = Engine.is_editor_hint()
	collision_mask = 0
	ground_art = Node2D.new()
	ground_art.name = "GroundArtwork"
	ground_art.z_index = GROUND_ART_Z
	ground_art.draw.connect(_draw_ground)
	add_child(ground_art)
	upper = Node2D.new()
	upper.name = "UpperArtwork"
	# Keep shader vertices in metres; the child transform carries art scale only.
	upper.scale = Vector2.ONE * 128.0
	upper.draw.connect(_draw_upper)
	add_child(upper)
	collider = CollisionPolygon2D.new()
	add_child(collider)
	_refresh()
	if not Engine.is_editor_hint():
		if height_metres >= 2.5 and not _uses_ground_layer():
			reveal = ForegroundReveal.new()
			reveal.radius = 190
			reveal.edge_softness = 64
			reveal.player_offset = Vector2(0,-18)
			reveal.visual_bounds = Rect2(Vector2(-footprint.x*0.6,-footprint.y*0.5-height_metres-0.5),Vector2(footprint.x*1.2,footprint.y+height_metres+1))
			upper.add_child(reveal)
			reveal.set_process(false)
		var visible_area := VisibleOnScreenNotifier2D.new()
		visible_area.rect = Rect2(Vector2(-footprint.x,-footprint.y-height_metres)*128,Vector2(footprint.x*2,footprint.y*2+height_metres)*128)
		visible_area.screen_entered.connect(_visible_on_screen.bind(true))
		visible_area.screen_exited.connect(_visible_on_screen.bind(false))
		add_child(visible_area)
		set_process(false)

func _visible_on_screen(value: bool) -> void:
	if value and not _art_built:
		_art_built = true
		ground_art.queue_redraw()
		upper.queue_redraw()
		if is_instance_valid(shore_art): shore_art.queue_redraw()
	set_process(value and kind == "pool")
	if is_instance_valid(reveal): reveal.set_process(value)

func _uses_ground_layer() -> bool:
	if draw_layer != DrawLayer.AUTO: return draw_layer == DrawLayer.GROUND
	return kind in ["stairs", "bridge", "pool"] or (kind == "slab" and not solid)

func _refresh() -> void:
	collision_layer = (17 if flight_blocker else 1) if solid else 0
	remove_from_group("flight_blocker")
	remove_from_group("flyover_obstacle")
	add_to_group("flight_blocker" if flight_blocker else "flyover_obstacle")
	outline.clear()
	var half: Vector2 = footprint*0.5
	if kind in ["rock","rubble","pool"]:
		for i in 10:
			var angle: float = float(i)*TAU/10.0
			outline.append(Vector2.from_angle(angle)*half*(0.91+sin(i*2.7+variation)*0.09))
	else:
		outline = PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)])
	collider.polygon = Transform2D(0,Vector2.ONE*128,0,Vector2.ZERO)*outline
	collider.disabled = not solid
	# Keep the body/footprint and world transform intact; only artwork changes layers.
	upper.z_index = GROUND_ART_Z if _uses_ground_layer() else 0
	if kind in ["bush", "grass", "reeds"] and wind_profile != null:
		upper.material = wind_profile.make_material(maxf(0.1,height_metres),float(variation)*0.3,height_metres>=2.5 and not _uses_ground_layer())
	else:
		upper.material = null
	if kind == "pool":
		if not is_instance_valid(shore_art):
			shore_art = Node2D.new()
			shore_art.name = "BankReeds"
			shore_art.scale = Vector2.ONE * 128.0
			shore_art.z_index = GROUND_ART_Z + 1
			shore_art.draw.connect(_draw_shore)
			add_child(shore_art)
		if wind_profile != null:
			shore_art.material = wind_profile.make_material(maxf(0.1,footprint.y*0.5),float(variation)*0.3)
			(shore_art.material as ShaderMaterial).set_shader_parameter("wind_vertex_weights",true)
		else:
			shore_art.material = null
	ground_art.queue_redraw()
	upper.queue_redraw()
	if is_instance_valid(shore_art): shore_art.queue_redraw()
	configuration = _configuration_signature()

func _configuration_signature() -> String:
	var wind_values: Array = [wind_profile.amplitude_metres,wind_profile.frequency,wind_profile.flutter] if wind_profile != null else []
	return str([kind,footprint,height_metres,solid,flight_blocker,variation,draw_layer,wind_values])

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if configuration != _configuration_signature(): _refresh()
		return
	elapsed += delta
	upper.queue_redraw()

func map_shape() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in outline: result.append(to_global(point*128))
	return result

func _draw_ground() -> void:
	if not _art_built or outline.is_empty(): return
	ground_art.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*128)
	var shadow := PackedVector2Array()
	for point: Vector2 in outline: shadow.append(point+Vector2(height_metres*0.28,0.14))
	ground_art.draw_colored_polygon(shadow,Color(0.035,0.06,0.045,0.32))
	if kind == "pool":
		ground_art.draw_colored_polygon(outline,Color("435643"))
	ground_art.draw_set_transform(Vector2.ZERO)

func _draw_upper() -> void:
	if not _art_built or outline.is_empty(): return
	upper.draw_set_transform(Vector2.ZERO)
	var half: Vector2 = footprint*0.5
	var random := RandomNumberGenerator.new()
	random.seed = variation+271
	match kind:
		"bush":
			for layer in 3:
				var leaves := PackedVector2Array()
				var centre := Vector2(0, -height_metres * (0.22 + layer * 0.22))
				for i in 12:
					var angle: float = float(i) * TAU / 12.0
					leaves.append(centre + Vector2.from_angle(angle) * half * (1.0 - layer * 0.18) * random.randf_range(0.85, 1.15))
				upper.draw_colored_polygon(leaves, Color("263d2d").lightened(layer * 0.055))
			for i in 9:
				var at := Vector2(random.randf_range(-half.x, half.x) * 0.7, -height_metres * random.randf_range(0.2, 0.8))
				upper.draw_line(at, at + Vector2(0.1, -0.05), Color("586b3c"), 0.045)
		"grass", "reeds":
			for i in 14:
				var root := Vector2(random.randf_range(-half.x, half.x), random.randf_range(-half.y, half.y))
				var tip: Vector2 = root + Vector2(random.randf_range(-0.18, 0.18), -height_metres * random.randf_range(0.5, 1.0))
				upper.draw_line(root, tip, Color("657048") if i % 3 == 0 else Color("43563b"), 0.025)
				if kind == "reeds" and i % 3 == 0:
					upper.draw_line(tip, tip + Vector2(0, -0.15), Color("806a46"), 0.07)
		"pool":
			# Irregular shallow bank and deeper centre share the unchanged water footprint.
			upper.draw_colored_polygon(outline,Color("455c46"))
			var water := PackedVector2Array()
			for point: Vector2 in outline: water.append(point*0.91)
			upper.draw_colored_polygon(water,Color("203c3b"))
			var depth := PackedVector2Array()
			for point: Vector2 in outline: depth.append(point*0.73+Vector2(-0.15,0.08))
			upper.draw_colored_polygon(depth,Color("1b3436"))
			for i in 9:
				var at := Vector2(sin(i*3.7)*half.x*0.6,cos(i*1.9)*half.y*0.6)
				var phase: float = elapsed*0.4+float(i)
				upper.draw_arc(at,0.2+fposmod(phase,1.2),0.1,2.1,12,Color(0.5,0.65,0.55,0.13),0.025)
		"grave","waystone":
			var lean: float = sin(variation*2.1)*0.13
			var top := Vector2(lean,-height_metres)
			var stone := PackedVector2Array([Vector2(-half.x,half.y),top+Vector2(-half.x,0.2),top+Vector2(-half.x*0.65,0),top+Vector2(half.x*0.65,0),top+Vector2(half.x,0.2),Vector2(half.x,half.y)])
			upper.draw_colored_polygon(stone,Color("626c60"))
			upper.draw_line(stone[1],stone[2],Color("9a9d81"),0.05)
			upper.draw_line(top+Vector2(0,0.25),Vector2(lean,0),Color("323f38"),0.07)
			upper.draw_line(top+Vector2(-half.x*0.45,0.45),top+Vector2(half.x*0.45,0.45),Color("333f38"),0.06)
			for i in 4:
				var root := Vector2(-half.x+i*footprint.x/4.0,half.y)
				upper.draw_line(root,root+Vector2(0.18,-0.35),Color("3f563c"),0.075)
		"rock","rubble":
			var crown := Vector2(-half.x*0.12,-height_metres)
			for i in outline.size():
				var face := PackedVector2Array([outline[i],outline[(i+1)%outline.size()],crown])
				upper.draw_colored_polygon(face,Color("596453").lightened(float(i%3)*0.08).darkened(float((i+variation)%2)*0.14))
			upper.draw_line(crown,outline[2],Color("879077"),0.04)
		"fallen_tree":
			upper.draw_line(Vector2(-half.x,0),Vector2(half.x,-0.2),Color("2d3027"),footprint.y)
			upper.draw_line(Vector2(-half.x,-0.12),Vector2(half.x,-0.32),Color("675f43"),footprint.y*0.3)
			for i in 4:
				var at := Vector2(-half.x+i*footprint.x/4.0,-0.1)
				upper.draw_line(at,at+Vector2(0.4,-0.8),Color("454934"),0.12)
		"camp":
			upper.draw_colored_polygon(PackedVector2Array([Vector2(-half.x,half.y),Vector2(0,-height_metres),Vector2(half.x,half.y)]),Color("625c41"))
			upper.draw_colored_polygon(PackedVector2Array([Vector2(-0.35,half.y),Vector2(0,-height_metres*0.7),Vector2(0.4,half.y)]),Color("232e26"))
			upper.draw_line(Vector2(0,-height_metres),Vector2(0,half.y),Color("81775c"),0.05)
		"bridge","stairs","slab":
			upper.draw_colored_polygon(outline,Color("646754") if kind != "bridge" else Color("61513c"))
			for i in maxi(1,int(footprint.x/0.4)):
				var x: float = -half.x+i*0.4
				upper.draw_line(Vector2(x,-half.y),Vector2(x,half.y),Color("303b30"),0.025)
			if kind=="slab":
				upper.draw_line(Vector2(-half.x*0.6,-half.y*0.5),Vector2(half.x*0.5,half.y*0.5),Color("354638"),0.09)
		"arch":
			_draw_arch(half)
		_:
			_draw_masonry(half,random)
	upper.draw_set_transform(Vector2.ZERO)

func _draw_arch(half: Vector2) -> void:
	# Only the overhead lintel/spandrel is painted. The passage is genuinely open.
	if footprint.y>footprint.x:
		# Side-facing ruined gate: broken spring stones, not an opaque slab across
		# the approach. This is artwork only; existing gate towers own collision.
		for side: float in [-1.0,1.0]:
			var y: float = side*half.y
			var spring := PackedVector2Array([Vector2(-half.x,y),Vector2(half.x,y),Vector2(half.x*0.85,y-side*0.65-height_metres*0.16),Vector2(-half.x*0.7,y-side*0.8-height_metres*0.16)])
			upper.draw_colored_polygon(spring,Color("7d826f"))
			upper.draw_line(spring[2],spring[3],Color("aaa78a"),0.08)
		return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var center := Vector2(0,half.y-height_metres*0.48)
	for i in 19:
		var angle: float = PI+float(i)*PI/18.0
		outer.append(center+Vector2(cos(angle)*half.x,sin(angle)*height_metres*0.5))
		inner.append(center+Vector2(cos(angle)*half.x*0.82,sin(angle)*height_metres*0.34))
	for i in 18:
		upper.draw_colored_polygon(PackedVector2Array([outer[i],outer[i+1],inner[i+1],inner[i]]),Color("92937a").darkened(float(i%3)*0.08))
		upper.draw_line(outer[i],inner[i],Color("465344"),0.04)

func _draw_masonry(half: Vector2, random: RandomNumberGenerator) -> void:
	var top_y: float = -half.y-height_metres
	var top := PackedVector2Array([Vector2(-half.x,top_y+0.18),Vector2(-half.x*0.42,top_y),Vector2(half.x*0.1,top_y+0.12),Vector2(half.x,top_y+0.02),Vector2(half.x,half.y-height_metres),Vector2(-half.x,half.y-height_metres)])
	upper.draw_colored_polygon(PackedVector2Array([Vector2(-half.x,half.y),Vector2(half.x,half.y),Vector2(half.x,half.y-height_metres),Vector2(-half.x,half.y-height_metres)]),Color("485249"))
	upper.draw_colored_polygon(top,Color("747b68"))
	for row in maxi(1,ceili(height_metres/0.45)):
		var y: float = half.y-row*0.45
		upper.draw_line(Vector2(-half.x,y),Vector2(half.x,y),Color("313e35"),0.025)
		for column in range(ceili(footprint.x/0.8)):
			var x: float = -half.x+column*0.8+float(row%2)*0.4
			if x>half.x: continue
			upper.draw_line(Vector2(x,y),Vector2(x,maxf(half.y-height_metres,y-0.45)),Color("334238"),0.025)
	if kind=="tower":
		for i in 5:
			upper.draw_rect(Rect2(Vector2(-half.x+i*footprint.x/5.0,top_y-0.45),Vector2(footprint.x/8,0.6)),Color("8b8e75"))
		upper.draw_rect(Rect2(Vector2(-0.18,half.y-height_metres*0.72),Vector2(0.36,1.1)),Color("192f29"))
	for i in 5:
		var x: float = random.randf_range(-half.x,half.x)
		upper.draw_line(Vector2(x,half.y),Vector2(x+0.2,half.y-random.randf_range(0.1,0.5)),Color("4f6442"),0.08)

func _draw_shore() -> void:
	if not _art_built or kind != "pool" or outline.size()<3: return
	var random := RandomNumberGenerator.new()
	random.seed = variation+1927
	# Group reeds along alternate banks, leaving recognisable open water.
	for cluster in 9:
		if cluster%3 == 0: continue
		var root: Vector2 = outline[cluster%outline.size()]*0.97
		for blade in 5:
			var base: Vector2 = root+Vector2(random.randf_range(-0.24,0.24),random.randf_range(-0.1,0.1))
			var tip: Vector2 = base+Vector2(random.randf_range(-0.18,0.12),-random.randf_range(0.4,0.85))
			var phase: float = float(cluster)*1.37+float(variation)*0.31
			shore_art.draw_polygon(PackedVector2Array([base-Vector2(0.015,0),tip,base+Vector2(0.015,0)]),PackedColorArray([Color("64724b"),Color("78845c"),Color("64724b")]),PackedVector2Array([Vector2(0,phase),Vector2(1,phase),Vector2(0,phase)]))
			if blade%2==0:
				shore_art.draw_polygon(PackedVector2Array([tip+Vector2(-0.03,0),tip+Vector2(0,-0.14),tip+Vector2(0.03,0)]),PackedColorArray([Color("897851"),Color("897851"),Color("897851")]),PackedVector2Array([Vector2(1,phase),Vector2(1,phase),Vector2(1,phase)]))
