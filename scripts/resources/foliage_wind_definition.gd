@tool
class_name FoliageWindDefinition
extends Resource
## Cosmetic displacement only. No physics shape, root or trunk is animated.
@export_range(0.0, 0.3, 0.005) var amplitude_metres: float = 0.06
@export_range(0.1, 5.0, 0.05) var frequency: float = 1.0
@export_range(0.0, 1.0, 0.05) var flutter: float = 0.15

func make_material(height_local: float, phase: float, reveal: bool = false) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/foreground_reveal.gdshader") if reveal else preload("res://shaders/foliage_wind.gdshader")
	result.set_shader_parameter("wind_amplitude", amplitude_metres * 128.0)
	result.set_shader_parameter("wind_frequency", frequency)
	result.set_shader_parameter("wind_flutter", flutter)
	result.set_shader_parameter("wind_height", maxf(height_local, 0.01))
	result.set_shader_parameter("wind_phase", phase)
	return result
