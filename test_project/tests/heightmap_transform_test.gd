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


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
