class_name AshenShrine
extends InteractableEntity
@export var definition: ShrineDefinition = preload("res://data/interactables/ashen_shrine.tres")
## Unique per authored shrine instance, independent of its shared definition.
@export var checkpoint_id: StringName = &""
var pulse: float = 0.0
var clock: float = 0.0
var light: PointLight2D
var rune_material: ShaderMaterial
func _ready() -> void:
	if definition == null: definition = load("res://data/interactables/ashen_shrine.tres")
	super._ready()
	add_to_group("shrine")
	z_index = 0
	$Stone.color = Color("596769")
	$Core.color = Color("bcece0")
	$Glow.visible = true
	rune_material = ShaderMaterial.new()
	rune_material.shader = load("res://shaders/runes.gdshader")
	$Core.material = rune_material
	light = PointLight2D.new()
	light.texture = Feedback.light_texture
	light.texture_scale = 3.5
	light.color = definition.light_color
	light.energy = definition.light_energy
	light.position.y = -15
	add_child(light)
	Elevation.register_visual(light, self)
	Feedback.physical_effect(to_global(Vector2(0, -12)), definition.idle_vfx, &"idle", Vector2.UP, 1, self, true)
func can_interact(player: Node) -> bool:
	if not super.can_interact(player): return false
	if pulse > 0.3: return false
	if global_position.distance_to(player.global_position) > definition.interaction_radius: return false
	if definition.block_during_combat and player.has_method("in_combat") and player.in_combat(): return false
	return true
func get_display_name() -> String: return definition.display_name
func get_interaction_prompt() -> String: return definition.interaction_prompt
func interact(player: Node) -> void:
	if not can_interact(player): return
	player.restore(definition.restore_health, definition.restore_stamina)
	if definition.reset_enemies: GameSession.reset_encounter_flags()
	if not checkpoint_id.is_empty(): GameSession.attune(self)
	Feedback.clear_blood()
	if is_instance_valid(Feedback.presentation): Feedback.presentation.clear()
	Feedback.clear_damage_numbers()
	Feedback.clear_physical_effects()
	Feedback.clear_spell_visuals()
	player.show_message(definition.rest_message)
	for group: String in ["sentinel", "resettable"]:
		if group == "sentinel" and not definition.reset_enemies: continue
		if group == "resettable" and not definition.reset_dummies: continue
		for target: Node in get_tree().get_nodes_in_group(group): target.reset_encounter()
	pulse = definition.pulse_duration
	Feedback.physical_effect(global_position, definition.rest_vfx, &"rest", Vector2.UP, 1, null, false, false, get_instance_id())
	Feedback.play("shrine", global_position, 3, self)
	if player.has_method("request_shrine_menu"): player.request_shrine_menu()
func _process(delta: float) -> void:
	clock += delta
	pulse = maxf(0, pulse - delta)
	light.energy = definition.light_energy + sin(clock * 1.7) * 0.1 + pulse
	rune_material.set_shader_parameter("strength", 0.7 + pulse * 0.3)
	rune_material.set_shader_parameter("elapsed", clock)
	$Glow.scale = Vector2.ONE * (1.0 + sin(clock * 2) * 0.08)
	queue_redraw()
func _draw() -> void:
	draw_arc(Vector2(0,8), 38, 0, TAU, 64, Color(0.5,0.75,0.7,0.22), 1, true)
	for i in 8:
		var p := Vector2.RIGHT.rotated(i * TAU / 8) * 31
		draw_line(p, p * 1.13, Color(0.6,0.8,0.7,0.4), 2, true)
