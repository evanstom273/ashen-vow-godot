class_name ActorStatusDisplay
extends Control
var actor: PlayerController
var _clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 0.1: _clock = 0.0; queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor) or actor.health <= 0: return
	var y: float = 0.0
	var buildup := actor.get_node_or_null("ActorStatuses") as ActorStatuses
	if buildup != null:
		for entry: Dictionary in buildup.meters.values():
			if float(entry.value) <= 0: continue
			var definition: StatusDefinition = entry.definition
			draw_rect(Rect2(0,y,150,5), Color("182223"))
			draw_rect(Rect2(0,y,150 * float(entry.value) / float(entry.threshold),5), definition.color)
			if definition.icon != null: draw_texture_rect(definition.icon, Rect2(-22,y-8,18,18), false)
			draw_string(ThemeDB.fallback_font, Vector2(158,y+6), definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, definition.color)
			y += 23
	var effects := actor.get_node_or_null("SpellEffects") as SpellEffects
	if effects == null: return
	for entry: Dictionary in effects.entries.values():
		var definition: SpellEffectDefinition = entry.definition
		var label: String = definition.display_name if not definition.display_name.is_empty() else String(definition.id).replace("_", " ").capitalize()
		if definition.icon != null: draw_texture_rect(definition.icon, Rect2(-22,y,18,18), false)
		draw_string(ThemeDB.fallback_font, Vector2(0,y+12), "%s  %.1fs" % [label, float(entry.remaining)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d4c798"))
		y += 19
	for entry: Dictionary in effects.burns.values():
		draw_string(ThemeDB.fallback_font, Vector2(0,y+12), "Blackflame  %.1fs" % maxf(0.0, float(entry.duration)-float(entry.elapsed)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e5b7aa"))
		y += 19
