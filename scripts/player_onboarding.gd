class_name PlayerOnboarding
extends Node
var actor: PlayerController
var clock: float = 2.0

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not actor._session_ready or GameSession.character == null: return
	clock -= delta
	if clock > 0.0 or actor.message_time > 0.0: return
	clock = 8.0
	if not _seen("magic"):
		_show("magic", "Your wand grants unlimited Glimmer. Cycle spells with %s; cast with %s or the catalyst hand." % [GameSettings.prompt("cycle_spell", actor.gamepad_active), GameSettings.prompt("cast_spell", actor.gamepad_active)])
	elif actor.health > 0 and actor.health < actor.max_health * 0.6 and not _seen("healing"):
		_show("healing", "Flasks take time to use. Find an opening; rest at a shrine to restore health and finite spell uses.")
	elif not GameSession.character.recovery.is_empty() and not _seen("recovery"):
		_show("recovery", "Your lost Embers wait at your recovery flame. A second death replaces it, even if you carry no Embers.")
	elif actor.in_combat() and not _seen("raven"):
		_show("raven", "Raven is a traversal form: enter outside combat. You can revert only above safe ground.")

func _seen(key: String) -> bool:
	return bool(GameSession.character.world_flags.get("tutorial:" + key, false))

func _show(key: String, text: String) -> void:
	GameSession.character.world_flags["tutorial:" + key] = true
	actor.show_message(text, 7.0)
	GameSession.queue_save()
	clock = 20.0
