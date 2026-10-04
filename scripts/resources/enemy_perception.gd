@tool
class_name EnemyPerception
extends Resource
## All distances here are world metres, unlike legacy actor-local attack reach.
@export var sight_metres: float = 12.0
@export var alert_metres: float = 10.0
@export var memory_seconds: float = 4.0
@export var search_seconds: float = 6.0
@export var acquisition_interval: float = 0.25
@export var arrival_metres: float = 0.8
@export var patrol_pause: float = 2.0
