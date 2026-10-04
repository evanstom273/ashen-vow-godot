@tool
class_name WorldScale
extends RefCounted
## Gameplay distances are world units: 128 units = 1 metre.
## Polygon art/profiles were authored at unit scale and are displayed at 4x.
## Never apply ART_SCALE to already-migrated delivery or movement resources.
const UNITS_PER_METRE: float = 128.0
const ART_SCALE: float = 4.0

static func metres(value: float) -> float:
	return value * UNITS_PER_METRE

static func actor_scale(actor: Node2D) -> float:
	return maxf(actor.global_transform.x.length(), actor.global_transform.y.length())

static func art_distance(value: float) -> float:
	return value * ART_SCALE

static func art_offset(value: Vector2) -> Vector2:
	return value * ART_SCALE

static func attach_art(node: Node2D, parent: Node, at: Vector2, art_scale: float = ART_SCALE) -> void:
	# Set the transform BEFORE _ready creates particles/lights. Ownership remains
	# under the requested parent, without multiplying an already-scaled actor twice.
	var world := Transform2D(Vector2(art_scale, 0), Vector2(0, art_scale), at)
	node.transform = (parent as Node2D).global_transform.affine_inverse() * world if parent is Node2D else world
	parent.add_child(node)

static func scale_particles(material: ParticleProcessMaterial, factor: float) -> void:
	# Only call on a fresh, per-emitter copy. Global-coordinate emitters run at
	# identity scale, so their lengths, speeds and accelerations need world units.
	# Read both endpoints before assigning: paired Inspector setters may adjust
	# the other endpoint to preserve min <= max.
	for property: String in ["initial_velocity", "damping", "linear_accel", "radial_accel", "tangential_accel", "scale"]:
		var low: float = material.get(property + "_min") * factor
		var high: float = material.get(property + "_max") * factor
		material.set(property + "_min", low)
		material.set(property + "_max", high)
	material.gravity *= factor
	material.emission_box_extents *= factor
	material.emission_sphere_radius *= factor
	material.emission_ring_radius *= factor
	material.emission_ring_inner_radius *= factor
	material.emission_ring_height *= factor
