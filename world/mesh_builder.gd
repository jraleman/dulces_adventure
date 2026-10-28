extends RefCounted

## Bakes game-owned details into a few lit surfaces instead of hundreds of draw calls.
##
## Copied from Cube Trials' `world/mesh_builder.gd` and adapted (no game-to-game
## dependency): the coil-spring helper is gone, and an empty batch is allowed,
## because a streamed stretch of the run can legitimately hold no scenery.

var _surface := SurfaceTool.new()
var _vertex_count := 0


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


## Normals describe the exterior; Godot's front-facing index order is clockwise.
func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	_vertex(a, normal, color)
	_vertex(c, normal, color)
	_vertex(b, normal, color)


## Two triangles sharing the a-c diagonal.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	triangle(a, b, c, color)
	triangle(a, c, d, color)


## Native primitive normals also work for rotated planks and small fittings.
func box(at: Vector3, dimensions: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	var primitive := BoxMesh.new()
	primitive.size = dimensions
	_append(primitive, Transform3D(Basis.from_euler(rotation), at), color)


## Real rounded edges catch sunlight even on the Compatibility renderer.
func rounded_box(
	at: Vector3, dimensions: Vector3, radius: float, color: Color,
	rotation := Vector3.ZERO
) -> void:
	var half := dimensions * 0.5
	var cut := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.9)
	var core := half - Vector3.ONE * cut
	var transform := Transform3D(Basis.from_euler(rotation), at)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var us: Array[float] = [-half[u], -core[u], core[u], half[u]]
		var vs: Array[float] = [-half[v], -core[v], core[v], half[v]]
		for sign_value: float in [-1.0, 1.0]:
			for row in 3:
				for column in 3:
					var points: Array[Vector3] = []
					var normals: Array[Vector3] = []
					for corner in [Vector2i(0, 0), Vector2i(1, 0),
						Vector2i(1, 1), Vector2i(0, 1)]:
						var raw := Vector3.ZERO
						raw[axis] = half[axis] * sign_value
						raw[u] = us[column + corner.x]
						raw[v] = vs[row + corner.y]
						var inner := raw.clamp(-core, core)
						var normal := (raw - inner).normalized()
						points.append(transform * (inner + normal * cut))
						normals.append(transform.basis * normal)
					for indices in [Vector3i(0, 1, 2), Vector3i(0, 2, 3)]:
						var a: int = indices.x
						var b: int = indices.y
						var c: int = indices.z
						var outward := (points[b] - points[a]).cross(points[c] - points[a])
						if outward.dot(normals[a] + normals[b] + normals[c]) < 0.0:
							var swap := b
							b = c
							c = swap
						for index in [a, c, b]:
							_vertex(points[index], normals[index], color)


## A 2D profile pushed out to `depth`, centred on z = 0.
func extrude(profile: PackedVector2Array, depth: float, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(profile)
	for offset in range(0, indices.size(), 3):
		var points: Array[Vector3] = []
		for corner in 3:
			var p := profile[indices[offset + corner]]
			points.append(Vector3(p.x, p.y, depth * 0.5))
		if (points[1] - points[0]).cross(points[2] - points[0]).z < 0.0:
			var swap := points[1]
			points[1] = points[2]
			points[2] = swap
		triangle(points[0], points[1], points[2], color)
		var back := Vector3(0, 0, -depth)
		triangle(points[2] + back, points[1] + back, points[0] + back, color)
	var clockwise := Geometry2D.is_polygon_clockwise(profile)
	for index in profile.size():
		var a := profile[index]
		var b := profile[(index + 1) % profile.size()]
		if clockwise:
			var swap := a
			a = b
			b = swap
		quad(Vector3(a.x, a.y, depth * 0.5), Vector3(a.x, a.y, -depth * 0.5),
			Vector3(b.x, b.y, -depth * 0.5), Vector3(b.x, b.y, depth * 0.5), color)


## A beam's length and orientation come from its endpoints, not guessed Euler angles.
func beam(a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var primitive := BoxMesh.new()
	primitive.size = Vector3(thickness, a.distance_to(b), thickness)
	var basis := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	_append(primitive, Transform3D(basis, (a + b) * 0.5), color)


## Circular parts remain geometry: posts, pots, lanterns.
func cylinder(
	at: Vector3, radius: float, height: float, color: Color,
	rotation := Vector3.ZERO, segments := 20, top_ratio := 1.0
) -> void:
	var primitive := CylinderMesh.new()
	primitive.top_radius = radius * top_ratio
	primitive.bottom_radius = radius
	primitive.height = height
	primitive.radial_segments = segments
	primitive.rings = 1
	_append(primitive, Transform3D(Basis.from_euler(rotation), at), color)


## Smooth rings that do not depend on screen-space effects.
func torus(
	at: Vector3, inner: float, outer: float, color: Color, rotation := Vector3.ZERO
) -> void:
	var primitive := TorusMesh.new()
	primitive.inner_radius = inner
	primitive.outer_radius = outer
	primitive.rings = 32
	primitive.ring_segments = 10
	_append(primitive, Transform3D(Basis.from_euler(rotation), at), color)


## Small, fully three-dimensional rounded forms: Dulce's placeholder, bushes, buns.
func ellipsoid(at: Vector3, dimensions: Vector3, color: Color, segments := 12) -> void:
	var primitive := SphereMesh.new()
	primitive.radius = 0.5
	primitive.height = 1.0
	primitive.radial_segments = segments
	primitive.rings = maxi(4, segments / 2)
	_append(primitive, Transform3D(Basis.from_scale(dimensions), at), color)


## One surface per finish makes static terrain inexpensive to draw.
func finish(indexed := true) -> ArrayMesh:
	if _vertex_count == 0:
		return ArrayMesh.new()
	if indexed:
		_surface.index()
	return _surface.commit()


func _append(primitive: Mesh, transform: Transform3D, color: Color) -> void:
	var arrays := primitive.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	for index in indices:
		_vertex(transform * vertices[index], (normal_basis * normals[index]).normalized(), color)


func _vertex(point: Vector3, normal: Vector3, color: Color) -> void:
	_surface.set_color(color)
	_surface.set_normal(normal)
	_surface.add_vertex(point)
	_vertex_count += 1
