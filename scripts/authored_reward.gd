@tool
extends InteractableEntity
@export var reward_id: StringName
@export var definition: RewardDefinition
@export var interaction_distance: float = 224.0

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	super._ready()
	GameSession.character_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	visible = not GameSession.reward_claimed(reward_id)

func can_interact(actor: Node) -> bool:
	return not Engine.is_editor_hint() and super.can_interact(actor) and not reward_id.is_empty() and definition != null and global_position.distance_to(actor.global_position) <= interaction_distance

func get_interaction_prompt() -> String:
	return "Examine " + (definition.display_name if definition != null else "remains")

func interact(actor: Node) -> void:
	if not can_interact(actor): return
	if GameSession.grant_reward(reward_id, definition):
		actor.show_message("Discovered: " + definition.display_name, 4.0)
		Feedback.play("shrine", global_position, 0.0, self)
		_refresh()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([-30, 12, -20, -12, 12, -18, 34, 10, 8, 23]), Color("303532"))
	draw_line(Vector2(-12, 2), Vector2(12, -7), Color("c9b685"), 4, true)
	draw_circle(Vector2(0, -28), 5, Color("f0dbae"))
	draw_arc(Vector2(0, -28), 14, 0, TAU, 24, Color(0.9, 0.8, 0.5, 0.3), 2, true)
