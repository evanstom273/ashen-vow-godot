class_name MusicDefinition
extends Resource
@export var instrument: ProceduralSoundDefinition
@export_range(30, 180, 1) var exploration_bpm: float = 48.0
@export_range(30, 180, 1) var combat_bpm: float = 84.0
## Semitones from the instrument root; -100 is a rest. Authored in project.
@export var exploration: PackedInt32Array = PackedInt32Array([0, -100, 7, -100, 3, -100, -2, -100])
@export var combat: PackedInt32Array = PackedInt32Array([0, 7, 0, 3, -2, 5, -2, 7])
