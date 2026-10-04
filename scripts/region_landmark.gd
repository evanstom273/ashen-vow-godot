@tool
class_name RegionLandmark
extends Node2D
## Root of an editable landmark scene. Scene transforms are the placement authority.
@export var landmark_id: StringName
@export var display_name: String
@export var map_kind: String = "ruin"
@export var discovery_metres: float = 12
@export var known_initially: bool = false
@export_group("Environmental dressing")
@export var ground_cover: GroundCoverProfile
@export var cover_bounds_metres := Rect2(-10, -10, 20, 20)
@export var floor_texture: Texture2D = preload("res://assets/illustrated/masonry_floor.svg")
@export_group("Footprints")
@export var reservations_metres: Array[Rect2] = []
@export var floors_metres: Array[Rect2] = []:
	set(value):
		floors_metres = value
		if is_instance_valid(floor_art): floor_art.queue_redraw()
## Optional ordered terrain terraces/organic floors; colours correspond by index.
@export var ground_polygons_metres: Array[PackedVector2Array] = []:
	set(value):
		ground_polygons_metres = value
		if is_instance_valid(floor_art): floor_art.queue_redraw()
@export var ground_colors: Array[Color] = []:
	set(value):
		ground_colors = value
		if is_instance_valid(floor_art): floor_art.queue_redraw()
var floor_art: Node2D

func cover_record() -> Dictionary:
	if ground_cover == null: return {}
	var transform_metres := Transform2D(global_transform.x, global_transform.y, global_position/128.0)
	var rect := Rect2(transform_metres * cover_bounds_metres.position, Vector2.ZERO)
	for point: Vector2 in RegionGeometry.rect_polygon(cover_bounds_metres): rect = rect.expand(transform_metres * point)
	return {"kind":"profile", "profile":ground_cover, "rect":cover_bounds_metres, "inverse":transform_metres.affine_inverse(), "bounds":rect.grow(3.0)}

func _ready() -> void:
	y_sort_enabled = true
	floor_art = Node2D.new()
	floor_art.name = "GeneratedFloorArt"
	floor_art.z_index = -15
	floor_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_art.draw.connect(_draw_floor)
	add_child(floor_art)

func _draw_floor() -> void:
	floor_art.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*128)
	for i in ground_polygons_metres.size():
		var tint: Color = ground_colors[i] if i<ground_colors.size() else Color("515548")
		floor_art.draw_colored_polygon(ground_polygons_metres[i],tint)
	for floor_rect: Rect2 in floors_metres:
		floor_art.draw_rect(floor_rect.grow(0.3),Color("29352e"))
		floor_art.draw_rect(floor_rect,Color("515548"))
		if floor_texture != null:
			var polygon: PackedVector2Array = RegionGeometry.rect_polygon(floor_rect)
			var coordinates := PackedVector2Array()
			for point: Vector2 in polygon: coordinates.append(point / 2.0)
			floor_art.draw_polygon(polygon, PackedColorArray([Color.WHITE]), coordinates, floor_texture)
			continue
		for y in range(ceili(floor_rect.position.y),floori(floor_rect.end.y)):
			for x in range(ceili(floor_rect.position.x),floori(floor_rect.end.x)):
				var tint := Color("5e6353") if posmod(x*7+y*13,5) == 0 else Color("444d41")
				floor_art.draw_rect(Rect2(Vector2(x+0.06,y+0.06),Vector2(0.9,0.9)),tint)
				if posmod(x*13+y*3,17)==0:
					floor_art.draw_line(Vector2(x+0.2,y),Vector2(x+0.6,y+0.7),Color("29382d"),0.035)
	floor_art.draw_set_transform(Vector2.ZERO)

func map_record() -> Dictionary:
	return {"id":landmark_id,"name":display_name,"position":global_position,"kind":map_kind,"known":known_initially,"discovery_radius":discovery_metres*128}

func map_floors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in ground_polygons_metres.size():
		var polygon := PackedVector2Array()
		for point: Vector2 in ground_polygons_metres[i]: polygon.append(to_global(point*128))
		var tint: Color = ground_colors[i] if i<ground_colors.size() else Color("515548")
		result.append({"kind":"floor","polygon":polygon,"color":tint})
	for rect: Rect2 in floors_metres:
		var polygon := PackedVector2Array()
		for point: Vector2 in RegionGeometry.rect_polygon(rect): polygon.append(to_global(point*128))
		result.append({"kind":"floor","polygon":polygon,"color":Color("686c55")})
	return result

func reserved_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for local_rect: Rect2 in reservations_metres:
		var points := PackedVector2Array([local_rect.position,Vector2(local_rect.end.x,local_rect.position.y),local_rect.end,Vector2(local_rect.position.x,local_rect.end.y)])
		var world := Rect2(to_global(points[0]*128)/128,Vector2.ZERO)
		for point: Vector2 in points: world = world.expand(to_global(point*128)/128)
		result.append(world)
	return result
