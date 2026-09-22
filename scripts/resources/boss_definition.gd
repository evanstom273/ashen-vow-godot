@tool
class_name BossDefinition
extends EnemyDefinition
## Enemy-compatible base stats. Phase orchestration and fog gates are data-only.
@export_group("Boss encounter (data only)")
@export var title: String = ""
@export var phases: Array[BossPhase] = []
@export var music: AudioStream
@export var respawn_on_rest: bool = false
@export var show_boss_health_bar: bool = true
