@tool
extends Node2D
## An opt-in, disposable play space. Merely opening it in the editor runs no tests.
func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint(): return
	var hud := CanvasLayer.new()
	hud.set_script(preload("res://scripts/court_hud.gd"))
	hud.set("area_title", "THE PROVING GROUND")
	hud.set("area_subtitle", "Disposable character • 128 units per metre")
	add_child(hud)
	var player := $Actors/Player as PlayerController
	player.camera.limit_left = -4096
	player.camera.limit_right = 4096
	player.camera.limit_top = -3072
	player.camera.limit_bottom = 3072

func _draw() -> void:
	draw_rect(Rect2(-4096,-3072,8192,6144), Color("1b2927"))
	for x in range(-4096,4097,128): draw_line(Vector2(x,-3072),Vector2(x,3072),Color(0.46,0.53,0.47,0.16),2)
	for y in range(-3072,3073,128): draw_line(Vector2(-4096,y),Vector2(4096,y),Color(0.46,0.53,0.47,0.16),2)
	for distance in [2,4,8,12]:
		draw_arc(Vector2.ZERO, distance*128.0, 0, TAU, 64, Color(0.75,0.65,0.42,0.35),3,true)
		draw_string(ThemeDB.fallback_font, Vector2(distance*128,0), str(distance)+" m", HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("c2b58b"))

func _exit_tree() -> void:
	if not Engine.is_editor_hint() and GameSession.development_session: GameSession.leave_development_session()
