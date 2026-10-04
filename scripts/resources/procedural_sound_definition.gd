class_name ProceduralSoundDefinition
extends Resource
## Synthesis is cached at startup, never in a damage/cast callback.
@export var id: StringName
@export_range(0.03, 4, 0.01) var duration: float = 0.3
@export_range(20, 8000, 1) var frequency: float = 220.0
@export_range(-3000, 3000, 1) var frequency_sweep: float = -80.0
@export_range(0, 1, 0.01) var noise_mix: float = 0.25
@export_range(0.001, 1, 0.001) var attack_seconds: float = 0.008
@export_range(0.1, 8, 0.1) var decay_power: float = 2.0
@export_range(0, 1, 0.01) var brightness: float = 0.6
@export_range(0, 1, 0.01) var overtone: float = 0.25
@export_range(0, 1, 0.01) var gain: float = 0.65
@export_range(0, 10, 1) var priority: int = 3
@export_range(0, 0.2, 0.01) var pitch_variation: float = 0.06
@export_range(1, 100, 1) var audible_metres: float = 35.0
@export_enum("Effects", "Ambience", "Music") var bus: String = "Effects"

func synthesize(pitch: float = 1.0) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = ceili(clampf(duration, 0.03, 4.0) * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = hash(id)
	var phase: float = 0.0
	var filtered: float = 0.0
	for index in count:
		var seconds: float = float(index) / rate
		var progress: float = float(index) / count
		phase += TAU * maxf(20.0, frequency + frequency_sweep * progress) * pitch / rate
		var tone: float = (sin(phase) + sin(phase * 2.007) * overtone) / (1.0 + overtone)
		var sample: float = lerpf(tone, random.randf_range(-1, 1), noise_mix)
		filtered = lerpf(filtered, sample, clampf(brightness, 0.015, 1.0))
		var envelope: float = minf(1.0, seconds / maxf(0.001, attack_seconds)) * pow(1.0-progress, decay_power)
		bytes.encode_s16(index * 2, roundi(clampf(filtered * envelope * gain, -0.98, 0.98) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
