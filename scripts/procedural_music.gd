extends Node
var definition: MusicDefinition = preload("res://data/environment/stillwood_music.tres")
var samples: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var clock: float = 2.0
var beat: int = 0
var combat_blend: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if definition.instrument == null: return
	for pattern: PackedInt32Array in [definition.exploration, definition.combat]:
		for note: int in pattern:
			if note > -100 and not samples.has(note): samples[note] = definition.instrument.synthesize(pow(2.0, float(note) / 12.0))

func _process(delta: float) -> void:
	var actor: PlayerController = GameSession.actor
	if not is_instance_valid(actor) or not actor._session_ready or actor.health <= 0: return
	combat_blend = move_toward(combat_blend, 1.0 if actor.in_combat() else 0.0, delta * 0.3)
	clock -= delta
	if clock > 0.0: return
	clock = 60.0 / lerpf(definition.exploration_bpm, definition.combat_bpm, combat_blend)
	var pattern: PackedInt32Array = definition.combat if combat_blend > 0.5 else definition.exploration
	if pattern.is_empty(): return
	var note: int = pattern[beat % pattern.size()]
	beat += 1
	if not samples.has(note): return
	for index in range(voices.size()-1, -1, -1):
		if not is_instance_valid(voices[index]): voices.remove_at(index)
	if voices.size() >= 6: voices.pop_front().queue_free()
	var voice := AudioStreamPlayer.new()
	voice.stream = samples[note]
	voice.bus = "Music"
	voice.volume_db = lerpf(-19.0, -14.0, combat_blend) - (3.0 if WorldClimate.sheltered else 0.0)
	add_child(voice)
	voices.append(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
