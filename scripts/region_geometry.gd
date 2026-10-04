@tool
class_name RegionGeometry
extends RefCounted
## One millimetre at the authored world scale; only cosmetic clipping slivers.
const POLYGON_EPSILON_METRES: float = 0.001

static func drawable_polygon(points: PackedVector2Array) -> PackedVector2Array:
	# Work on a copy. Boolean clipping can leave repeated endpoints and collapsed
	# edges that CanvasItem's triangulator cannot use. Call with local coordinates.
	var cleaned := PackedVector2Array()
	var epsilon_squared: float = POLYGON_EPSILON_METRES*POLYGON_EPSILON_METRES
	for point: Vector2 in points:
		if not point.is_finite(): return PackedVector2Array()
		if cleaned.is_empty() or cleaned[-1].distance_squared_to(point)>epsilon_squared:
			cleaned.append(point)
	while cleaned.size()>1 and cleaned[0].distance_squared_to(cleaned[-1])<=epsilon_squared:
		cleaned.remove_at(cleaned.size()-1)
	var removed: bool = true
	while removed and cleaned.size()>=3:
		removed = false
		for i in cleaned.size():
			var previous: Vector2 = cleaned[posmod(i-1,cleaned.size())]
			var next: Vector2 = cleaned[(i+1)%cleaned.size()]
			var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(cleaned[i],previous,next)
			if cleaned[i].distance_squared_to(nearest)<=epsilon_squared:
				cleaned.remove_at(i)
				removed = true
				break
	if cleaned.size()<3 or area(cleaned)<=epsilon_squared: return PackedVector2Array()
	# A non-empty contour is not necessarily a drawable polygon. Never hand a
	# failed triangulation to the canvas renderer (which logs on every draw).
	if Geometry2D.triangulate_polygon(cleaned).is_empty(): return PackedVector2Array()
	return cleaned

static func clip_local_polygons(subject: PackedVector2Array, bounds: Rect2) -> Array[PackedVector2Array]:
	## Return validated pieces relative to bounds.position, not world coordinates.
	var result: Array[PackedVector2Array] = []
	if subject.size()<3 or not bounds.has_area(): return result
	var local_subject := PackedVector2Array()
	for point: Vector2 in subject:
		if not point.is_finite(): return result
		local_subject.append(point-bounds.position)
	var clip: PackedVector2Array = rect_polygon(Rect2(Vector2.ZERO,bounds.size))
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(local_subject,clip):
		var cleaned: PackedVector2Array = drawable_polygon(piece)
		if not cleaned.is_empty(): result.append(cleaned)
	return result

static func ribbon(route: RegionRouteDefinition, width_factor: float = 1.0) -> PackedVector2Array:
	var samples := PackedVector2Array()
	var points: PackedVector2Array = route.points_metres
	for i in range(1,points.size()):
		var count: int = maxi(1,ceili(points[i-1].distance_to(points[i])/2.0))
		for j in count: samples.append(points[i-1].lerp(points[i],float(j)/count))
	if points.size()>0: samples.append(points[-1])
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in samples.size():
		var before: Vector2 = samples[maxi(0,i-1)]
		var after: Vector2 = samples[mini(samples.size()-1,i+1)]
		var normal: Vector2 = (after-before).normalized().orthogonal()
		var width: float = route.width_metres*width_factor*0.5*(1.0+sin(samples[i].x*0.43+samples[i].y*0.31)*0.06)
		left.append(samples[i]+normal*width)
		right.append(samples[i]-normal*width)
	right.reverse()
	left.append_array(right)
	return left

static func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func area(points: PackedVector2Array) -> float:
	var sum: float = 0
	for i in points.size(): sum += points[i].cross(points[(i+1)%points.size()])
	return absf(sum)*0.5
