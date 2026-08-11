extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain: StaticBody3D = _make_heightmap()
	var mover: AnimatableBody3D = _make_capsule_body()

	await physics_frame
	await physics_frame

	var exclude: Array[RID] = []
	var initial_fraction: float = Box3DPhysicsServer3D.body_cast_mover(
		mover.get_rid(),
		Transform3D(Basis(), Vector3(15, 6, 0)),
		Vector3(0, -4, 0),
		0.0,
		exclude,
	)
	_check(
		initial_fraction > 0.35 and initial_fraction < 0.65,
		"heightmap honors its centered local shape transform",
	)

	var collision: CollisionShape3D = terrain.get_node("CollisionShape3D") as CollisionShape3D
	var heightmap: HeightMapShape3D = collision.shape as HeightMapShape3D
	heightmap.map_data = PackedFloat32Array(
		[
			1.0, 1.0, 1.0,
			1.0, 1.0, 1.0,
			1.0, 1.0, 1.0,
		],
	)
	await physics_frame
	await physics_frame
	var updated_fraction: float = Box3DPhysicsServer3D.body_cast_mover(
		mover.get_rid(),
		Transform3D(Basis(), Vector3(15, 6, 0)),
		Vector3(0, -4, 0),
		0.0,
		exclude,
	)
	_check(
		updated_fraction < initial_fraction - 0.15,
		"attached heightmap rebuilds after map_data changes",
	)

	terrain.position.x = 20
	await physics_frame
	await physics_frame

	var old_fraction: float = Box3DPhysicsServer3D.body_cast_mover(
		mover.get_rid(),
		Transform3D(Basis(), Vector3(15, 6, 0)),
		Vector3(0, -4, 0),
		0.0,
		exclude,
	)
	var moved_fraction: float = Box3DPhysicsServer3D.body_cast_mover(
		mover.get_rid(),
		Transform3D(Basis(), Vector3(25, 6, 0)),
		Vector3(0, -4, 0),
		0.0,
		exclude,
	)
	_check(is_equal_approx(old_fraction, 1.0), "heightmap leaves its old body position")
	_check(
		absf(moved_fraction - updated_fraction) < 0.05,
		"heightmap follows later body transforms",
	)

	var boundary_holes: PackedFloat32Array = _filled_heights(5, 1.0)
	boundary_holes[0] = NAN
	boundary_holes[boundary_holes.size() - 1] = NAN
	_set_heightmap_data(heightmap, 5, boundary_holes)
	await physics_frame
	await physics_frame
	var boundary_fraction: float = _cast_down(mover, Vector3(25, 6, 0))
	_check(
		boundary_fraction < 0.75,
		"boundary NaNs do not poison finite heightfield cells",
	)

	var interior_hole: PackedFloat32Array = _filled_heights(5, 1.0)
	interior_hole[2 * 5 + 2] = NAN
	_set_heightmap_data(heightmap, 5, interior_hole)
	await physics_frame
	await physics_frame
	var hole_fraction: float = _cast_down(mover, Vector3(25, 6, 0))
	var solid_fraction: float = _cast_down(mover, Vector3(26.5, 6, 1.5))
	_check(is_equal_approx(hole_fraction, 1.0), "interior NaN creates a collision hole")
	_check(solid_fraction < 0.75, "interior NaN preserves neighboring finite cells")

	_set_heightmap_data(heightmap, 5, _filled_heights(5, NAN))
	await physics_frame
	await physics_frame
	var all_hole_fraction: float = _cast_down(mover, Vector3(25, 6, 0))
	_check(is_equal_approx(all_hole_fraction, 1.0), "all-NaN heightmap creates no live shape")

	if failures == 0:
		print("RESULT: PASS - heightmap transforms")
	else:
		print("RESULT: FAIL - ", failures, " heightmap transform assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _make_heightmap() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(10, 2, 0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.position = Vector3(5, 1, 0)
	var heightmap: HeightMapShape3D = HeightMapShape3D.new()
	heightmap.map_width = 3
	heightmap.map_depth = 3
	heightmap.map_data = PackedFloat32Array(
		[
			0.0, 0.0, 0.0,
			0.0, 0.0, 0.0,
			0.0, 0.0, 0.0,
		],
	)
	collision.shape = heightmap
	body.add_child(collision)
	root.add_child(body)
	return body


func _make_capsule_body() -> AnimatableBody3D:
	var body: AnimatableBody3D = AnimatableBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	collision.shape = capsule
	body.add_child(collision)
	root.add_child(body)
	return body


func _filled_heights(size: int, value: float) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(size * size)
	result.fill(value)
	return result


func _set_heightmap_data(heightmap: HeightMapShape3D, size: int, data: PackedFloat32Array) -> void:
	heightmap.map_width = size
	heightmap.map_depth = size
	heightmap.map_data = data


func _cast_down(mover: AnimatableBody3D, origin: Vector3) -> float:
	var exclude: Array[RID] = []
	return Box3DPhysicsServer3D.body_cast_mover(
		mover.get_rid(),
		Transform3D(Basis(), origin),
		Vector3(0, -4, 0),
		0.0,
		exclude,
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
