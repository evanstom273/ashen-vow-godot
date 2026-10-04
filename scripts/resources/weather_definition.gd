class_name WeatherDefinition
extends Resource
@export var id: StringName = &"clear"
@export var display_name: String = "Clear"
@export var tint: Color = Color.WHITE
@export_range(0, 1, 0.01) var rain: float = 0.0
@export_range(0, 3, 0.05) var wind_multiplier: float = 1.0
@export_range(30, 1200, 1) var minimum_seconds: float = 180.0
@export_range(30, 1200, 1) var maximum_seconds: float = 420.0
