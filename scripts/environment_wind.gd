extends Node
## One pausable clock for the entire region; no per-plant CPU animation.
var definition: EnvironmentWindDefinition = preload("res://data/environment/stillwood_wind.tres")
var elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(value: EnvironmentWindDefinition) -> void:
	if value != null: definition = value

func _process(delta: float) -> void:
	if definition == null: return
	elapsed += delta * definition.time_scale
	var strength: float = definition.strength
	strength *= WorldClimate.wind_multiplier
	if Feedback.reduced_effects: strength *= definition.reduced_effects_multiplier
	RenderingServer.global_shader_parameter_set("environment_time", elapsed)
	RenderingServer.global_shader_parameter_set("environment_wind", definition.direction.normalized() * strength)
