@tool
class_name OverworldDefinition
extends Resource
const UNITS_PER_METRE: float = 128.0
@export var boundary := PackedVector2Array()
@export var routes: Array[RegionRouteDefinition] = []
@export var biomes: Array[RegionBiomeDefinition] = []
@export var scatter: RegionScatterDefinition
@export var wind: EnvironmentWindDefinition = preload("res://data/environment/stillwood_wind.tres")

func blended_biome(at: Vector2, roll: float) -> RegionBiomeDefinition:
	# Weighted choice at patch scale gives interleaved ecotones, not a family border.
	var total: float = 0.0
	for biome: RegionBiomeDefinition in biomes: total += biome.influence(at)
	var cursor: float = clampf(roll, 0.0, 0.99999) * total
	for biome: RegionBiomeDefinition in biomes:
		cursor -= biome.influence(at)
		if cursor <= 0.0: return biome
	return dominant_biome(at)

func soil_at(at: Vector2) -> Color:
	var color := Color(0,0,0,0)
	var total: float = 0
	for biome: RegionBiomeDefinition in biomes:
		var weight: float = biome.influence(at)
		color += biome.soil*weight
		total += weight
	return color/total if total > 0.00001 else Color("293c2b")

func dominant_biome(at: Vector2) -> RegionBiomeDefinition:
	var best: RegionBiomeDefinition
	var greatest: float = -1
	for biome: RegionBiomeDefinition in biomes:
		var weight: float = biome.influence(at)
		if weight > greatest:
			greatest = weight
			best = biome
	return best

func tree_density_at(at: Vector2) -> float:
	var density: float = 0
	var total: float = 0
	for biome: RegionBiomeDefinition in biomes:
		var weight: float = biome.influence(at)
		density += biome.tree_density*weight
		total += weight
	return density/total if total>0.00001 else 0.0

func vegetation_at(at: Vector2) -> Color:
	var color := Color(0,0,0,0)
	var total: float = 0
	for biome: RegionBiomeDefinition in biomes:
		var weight: float = biome.influence(at)
		color += biome.vegetation*weight
		total += weight
	return color/total if total>0.00001 else Color("566345")
