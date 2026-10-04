@tool
class_name EnvironmentArtDefinition
extends Resource
## Shared imported SVG textures. Scene geometry and collider footprints stay separate.
@export var textures: Dictionary[StringName, Texture2D] = {}

func texture(kind: StringName) -> Texture2D:
	return textures.get(kind) as Texture2D
