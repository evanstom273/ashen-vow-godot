class_name ClimateDefinition
extends Resource
@export_range(60, 7200, 1) var day_seconds: float = 1440.0
@export_range(0, 24, 0.1) var starting_hour: float = 9.0
@export var daylight: Color = Color(0.83, 0.88, 0.82)
@export var nightlight: Color = Color(0.47, 0.56, 0.67)
@export_range(1, 120, 1) var weather_blend_seconds: float = 18.0
@export var weather: Array[WeatherDefinition] = []
