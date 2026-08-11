extends SceneTree

const TASK_COUNT: int = 32
const SHAPES_PER_TASK: int = 256

var _created_shapes: Array[RID] = []
var _created_shapes_mutex := Mutex.new()
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check(
		ProjectSettings.get_setting("physics/3d/physics_engine", "") == "Box3D Physics",
		"test project requests the Box3D backend",
	)
	_check(ClassDB.class_exists(&"Box3DPhysicsServer3D"), "Box3D extension is loaded")
	if _failures > 0:
		quit(1)
		return

	var task_id: int = WorkerThreadPool.add_group_task(_create_shapes, TASK_COUNT)
	WorkerThreadPool.wait_for_group_task_completion(task_id)

	_check(
		_created_shapes.size() == TASK_COUNT * SHAPES_PER_TASK,
		"all worker-created shape RIDs are collected",
	)
	var unique_ids: Dictionary[int, bool] = {}
	for shape_rid: RID in _created_shapes:
		unique_ids[shape_rid.get_id()] = true
	_check(unique_ids.size() == _created_shapes.size(), "concurrent shape allocation produces unique RIDs")
	var all_shapes_resolve: bool = true
	for shape_rid: RID in _created_shapes:
		if PhysicsServer3D.shape_get_type(shape_rid) != PhysicsServer3D.SHAPE_SPHERE:
			all_shapes_resolve = false
		PhysicsServer3D.free_rid(shape_rid)
	_check(all_shapes_resolve, "every worker-created shape RID resolves to its sphere")

	if _failures == 0:
		print("RESULT: PASS - physics RID owners support concurrent shape creation")
	else:
		print("RESULT: FAIL - ", _failures, " threaded RID assertion(s) failed")
	quit(1 if _failures > 0 else 0)


func _create_shapes(_task_index: int) -> void:
	var local_shapes: Array[RID] = []
	local_shapes.resize(SHAPES_PER_TASK)
	for index: int in SHAPES_PER_TASK:
		var shape_rid: RID = PhysicsServer3D.sphere_shape_create()
		PhysicsServer3D.shape_set_data(shape_rid, 0.5)
		local_shapes[index] = shape_rid
	_created_shapes_mutex.lock()
	_created_shapes.append_array(local_shapes)
	_created_shapes_mutex.unlock()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
