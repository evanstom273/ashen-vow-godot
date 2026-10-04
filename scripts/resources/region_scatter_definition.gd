@tool
class_name RegionScatterDefinition
extends Resource
@export var seed_value: int = 7319
@export_range(2, 12, 0.25) var tree_spacing_metres: float = 4.5
@export_range(0, 5, 0.1) var route_clearance_metres: float = 1.5
@export_range(1, 64, 1) var details_per_chunk: int = 48
@export_range(4, 64, 1) var chunk_metres: int = 16
## Cosmetic meshes only. Collision, landmarks and map geometry never unload.
@export_range(16, 512, 8) var detail_cache_chunks: int = 128
@export_group("Batched ground cover")
@export_range(2.0, 8.0, 0.5) var cover_cell_metres: float = 4.0
@export_range(4, 32, 1) var cover_items_per_cluster: int = 18
@export_range(32, 512, 16) var cover_max_items_per_chunk: int = 256
