extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capsule_body: StaticBody3D = _make_capsule_body()
	var floor_body: StaticBody3D = _make_floor_body()

	await physics_frame
	await physics_frame

	var state: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	var ray_from: Vector3 = Vector3(0, 2, 0)
	var ray_to: Vector3 = Vector3(0, -4, 0)

	var outside_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	outside_query.hit_from_inside = false
	var outside_hit: Dictionary = state.intersect_ray(outside_query)
	var outside_position: Vector3 = outside_hit.get(&"position", Vector3.ZERO)
	_check(outside_hit.get(&"collider") == floor_body, "hit_from_inside false skips the containing capsule")
	_check(
		is_equal_approx(outside_position.y, -1.0),
		"hit_from_inside false continues to the farther floor",
	)

	var inside_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	inside_query.hit_from_inside = true
	var inside_hit: Dictionary = state.intersect_ray(inside_query)
	var inside_position: Vector3 = inside_hit.get(&"position", Vector3.ZERO)
	var inside_normal: Vector3 = inside_hit.get(&"normal", Vector3.ONE)
	_check(inside_hit.get(&"collider") == capsule_body, "hit_from_inside true reports the containing capsule")
	_check(
		inside_position.is_equal_approx(ray_from),
		"an inside hit reports the ray origin",
	)
	_check(
		inside_normal.is_zero_approx(),
		"an inside hit reports a zero normal",
	)

	if failures == 0:
		print("RESULT: PASS - ray hit_from_inside semantics match Godot")
	else:
		print("RESULT: FAIL - ", failures, " ray hit_from_inside assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _make_capsule_body() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(0, 2, 0)
	body.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 3.0
	collision.shape = capsule
	body.add_child(collision)
	root.add_child(body)
	return body


func _make_floor_body() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(0, -1.5, 0)
	body.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 1, 4)
	collision.shape = box
	body.add_child(collision)
	root.add_child(body)
	return body


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
