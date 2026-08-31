extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mover: AnimatableBody3D = _make_capsule_body()
	var wall: StaticBody3D = _make_concave_wall()

	await physics_frame
	await physics_frame

	_check(
		ClassDB.class_has_method(&"Box3DPhysicsServer3D", &"body_collide_mover"),
		"Box3D Physics exposes body_collide_mover",
	)
	_check(
		ClassDB.class_has_method(&"Box3DPhysicsServer3D", &"body_cast_mover"),
		"Box3D Physics exposes body_cast_mover",
	)

	var exclude: Array[RID] = []
	var touching_from: Transform3D = Transform3D(Basis(), Vector3(1, 0, 0))
	var planes: Dictionary = Box3DPhysicsServer3D.body_collide_mover(
		mover.get_rid(),
		touching_from,
		0.1,
		8,
		exclude,
	)
	var normals: PackedVector3Array = planes.get(&"normals", PackedVector3Array())
	var offsets: PackedFloat32Array = planes.get(&"offsets", PackedFloat32Array())
	var collider_ids: PackedInt64Array = planes.get(
		&"collider_ids",
		PackedInt64Array(),
	)
	var collider_shapes: PackedInt32Array = planes.get(
		&"collider_shapes",
		PackedInt32Array(),
	)

	_check(not normals.is_empty(), "touching capsule reports a speculative plane")
	if not normals.is_empty():
		_check(
			normals[0].dot(Vector3.LEFT) > 0.9,
			"plane normal points away from the wall",
		)
	_check(
		not offsets.is_empty() and is_equal_approx(offsets[0], 0.1),
		"plane offset includes the requested speculative margin",
	)
	_check(
		not collider_ids.is_empty() and collider_ids[0] == wall.get_instance_id(),
		"plane identifies the wall instance",
	)
	_check(
		not collider_shapes.is_empty() and collider_shapes[0] == 0,
		"plane reports the collider shape index",
	)

	var cast_fraction: float = Box3DPhysicsServer3D.body_cast_mover(
		mover.get_rid(),
		Transform3D.IDENTITY,
		Vector3(3, 0, 0),
		0.0,
		exclude,
	)
	_check(
		cast_fraction > 0.2 and cast_fraction < 0.5,
		"capsule cast stops at the wall",
	)

	exclude.append(wall.get_rid())
	var excluded_fraction: float = Box3DPhysicsServer3D.body_cast_mover(
		mover.get_rid(),
		Transform3D.IDENTITY,
		Vector3(3, 0, 0),
		0.0,
		exclude,
	)
	_check(is_equal_approx(excluded_fraction, 1.0), "excluded wall is ignored")

	exclude.clear()
	mover.collision_mask = 0
	wall.collision_mask = 1
	var reverse_mask_fraction: float = Box3DPhysicsServer3D.body_cast_mover(
		mover.get_rid(),
		Transform3D.IDENTITY,
		Vector3(3, 0, 0),
		0.0,
		exclude,
	)
	_check(
		reverse_mask_fraction > 0.2 and reverse_mask_fraction < 0.5,
		"target mask can opt into the mover layer",
	)

	if failures == 0:
		print("RESULT: PASS - native Box3D mover queries")
	else:
		print("RESULT: FAIL - ", failures, " mover query assertion(s) failed")
	quit(1 if failures > 0 else 0)


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


func _make_concave_wall() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(2, 0, 0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var wall: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	var bottom_left: Vector3 = Vector3(-0.5, -2.0, -2.0)
	var top_left: Vector3 = Vector3(-0.5, 2.0, -2.0)
	var top_right: Vector3 = Vector3(-0.5, 2.0, 2.0)
	var bottom_right: Vector3 = Vector3(-0.5, -2.0, 2.0)
	wall.set_faces(
		PackedVector3Array(
			[
				bottom_left,
				top_left,
				top_right,
				bottom_left,
				top_right,
				bottom_right,
			],
		),
	)
	collision.shape = wall
	body.add_child(collision)
	root.add_child(body)
	return body


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
