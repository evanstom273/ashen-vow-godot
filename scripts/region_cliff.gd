@tool
extends StaticBody2D
var from_metres := Vector2.ZERO
var to_metres := Vector2.ZERO
var variant: int = 0

func _ready() -> void:
	collision_layer = 17
	collision_mask = 0
	add_to_group("flight_blocker")
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(from_metres.distance_to(to_metres)*128+128,256)
	collider.position = (from_metres+to_metres)*64
	collider.rotation = (to_metres-from_metres).angle()
	collider.shape = shape
	add_child(collider)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*128)
	var normal: Vector2 = (to_metres-from_metres).normalized().orthogonal()
	var count: int = maxi(2,ceili(from_metres.distance_to(to_metres)/3.5))
	for i in count:
		var a: Vector2 = from_metres.lerp(to_metres,float(i)/count)
		var b: Vector2 = from_metres.lerp(to_metres,float(i+1)/count)
		var height_a: float = 3.2+sin(a.x*0.11+a.y*0.2)*0.75
		var height_b: float = 3.2+sin(b.x*0.11+b.y*0.2)*0.75
		var top_a: Vector2 = a+Vector2(0,-height_a)
		var top_b: Vector2 = b+Vector2(0,-height_b)
		draw_colored_polygon(PackedVector2Array([a,b,top_b,top_a]),Color("3a4539").lightened(float((i+variant)%3)*0.025))
		draw_colored_polygon(PackedVector2Array([top_a,top_b,top_b+normal*2,top_a+normal*2]),Color("616951"))
		draw_line(top_a,top_b,Color("7d8265"),0.07)
		draw_line(a.lerp(b,0.35),top_a.lerp(top_b,0.55),Color("263a30"),0.08)
	draw_set_transform(Vector2.ZERO)
