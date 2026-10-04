extends Node
## Presentation only: no combat, movement or spawn adjustments. No offline time.
var definition: ClimateDefinition = preload("res://data/environment/climate.tres")
var hour: float = 9.0
var weather_index: int = 0
var remaining: float = 240.0
var weather_clock: float = 0.0
var wind_multiplier: float = 1.0
var rain_amount: float = 0.0
var tint := Color.WHITE
var sheltered: bool = false
var _rain: GPUParticles2D
var _scene_id: int = 0
var _light: CanvasModulate
var _shelter_clock: float = 0.0
var _sequence: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hour = definition.starting_hour
	GameSession.character_changed.connect(_restore)

func _restore() -> void:
	if GameSession.character == null: return
	var state: Dictionary = GameSession.character.climate
	hour = fposmod(float(state.get("hour", definition.starting_hour)), 24.0)
	weather_index = clampi(int(state.get("weather", 0)), 0, definition.weather.size()-1)
	remaining = maxf(1.0, float(state.get("remaining", 240.0)))
	_sequence = maxi(0, int(state.get("sequence", 0)))

func snapshot() -> Dictionary:
	return {"hour": hour, "weather": weather_index, "remaining": remaining, "sequence": _sequence}

func _process(delta: float) -> void:
	var actor: PlayerController = GameSession.actor
	if not is_instance_valid(actor) or not actor._session_ready or definition.weather.is_empty(): return
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene): return
	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_light = null
		for node: Node in scene.find_children("*", "CanvasModulate", true, false):
			_light = node as CanvasModulate
			break
		_create_rain(scene)
	hour = fposmod(hour + delta * 24.0 / maxf(60.0, definition.day_seconds), 24.0)
	remaining -= delta
	if remaining <= 0.0:
		_sequence += 1
		var random := RandomNumberGenerator.new()
		random.seed = 9173 + _sequence * 7919
		weather_index = random.randi_range(0, definition.weather.size()-1)
		var chosen: WeatherDefinition = definition.weather[weather_index]
		remaining = random.randf_range(chosen.minimum_seconds, maxf(chosen.minimum_seconds, chosen.maximum_seconds))
	var weather: WeatherDefinition = definition.weather[weather_index]
	var blend: float = 1.0 - exp(-delta * 3.0 / maxf(1.0, definition.weather_blend_seconds))
	tint = tint.lerp(weather.tint, blend)
	rain_amount = lerpf(rain_amount, weather.rain, blend)
	wind_multiplier = lerpf(wind_multiplier, weather.wind_multiplier, blend)
	var daylight: float = smoothstep(-0.15, 0.45, sin((hour-6.0) / 24.0 * TAU))
	if is_instance_valid(_light): _light.color = definition.nightlight.lerp(definition.daylight, daylight) * tint
	_shelter_clock -= delta
	if _shelter_clock <= 0.0:
		_shelter_clock = 0.25
		sheltered = false
		for floor_layer: BuildingFloor in Elevation.of(actor).floors:
			if is_instance_valid(floor_layer) and floor_layer.definition != null and floor_layer.definition.enclosed and floor_layer.storey() == Elevation.level(actor) and floor_layer.contains_world(actor.global_position):
				sheltered = true
				break
	if is_instance_valid(_rain):
		var camera: Camera2D = actor.get_viewport().get_camera_2d()
		var extent: Vector2 = actor.get_viewport_rect().size / (camera.zoom if camera != null else Vector2.ONE)
		_rain.global_position = camera.get_screen_center_position() if camera != null else actor.global_position
		var material := _rain.process_material as ParticleProcessMaterial
		material.emission_box_extents = Vector3(extent.x * 0.55, extent.y * 0.55, 0)
		_rain.visibility_rect = Rect2(-extent, extent * 2)
		_rain.emitting = rain_amount > 0.05 and not sheltered
		_rain.modulate.a = rain_amount * (0.0 if sheltered else 1.0)
	weather_clock -= delta
	if weather_clock <= 0.0:
		weather_clock = 1.0
		if rain_amount > 0.1 and not sheltered: Feedback.play("rain", actor.global_position, -14.0 + linear_to_db(rain_amount))

func _create_rain(scene: Node) -> void:
	if is_instance_valid(_rain): _rain.queue_free()
	_rain = GPUParticles2D.new()
	_rain.amount = 64
	_rain.lifetime = 0.8
	_rain.local_coords = false
	_rain.texture = preload("res://assets/illustrated/rain_drop.svg")
	_rain.z_index = 300
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.direction = Vector3(0.2, 1, 0)
	material.spread = 4.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 700.0
	material.initial_velocity_max = 950.0
	material.color = Color(0.68, 0.77, 0.84, 0.28)
	_rain.process_material = material
	if not Feedback.budget_emitter(_rain, true):
		_rain.free()
		_rain = null
		return
	scene.add_child(_rain)
