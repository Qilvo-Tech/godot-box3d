extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var body: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(body, root.world_3d.space)

	var shape: RID = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, Vector3.ONE)
	PhysicsServer3D.body_add_shape(body, shape)
	_check(PhysicsServer3D.body_get_shape_count(body) == 1, "shape attaches to body")

	PhysicsServer3D.free_rid(shape)
	_check(PhysicsServer3D.body_get_shape_count(body) == 0, "freeing shape detaches it from body")

	PhysicsServer3D.free_rid(body)
	if failures == 0:
		print("RESULT: PASS - shape free detaches")
	else:
		print("RESULT: FAIL - ", failures, " shape free assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
