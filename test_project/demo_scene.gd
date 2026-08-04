class_name Box3DDemoScene
extends Node3D

# Spawns a ground plane, falling rigid bodies, a monitored area, and a hinge
# joint door entirely from code so the scene can be opened and played without
# hand-authored .tscn node trees.

var _door: RigidBody3D
var _door_swung: bool = false
var _pendulum_joint: PinJoint3D


func _ready() -> void:
	print("Active physics engine setting: ", ProjectSettings.get_setting("physics/3d/physics_engine"))
	_add_camera()
	_add_light()
	_add_ground()
	_add_trimesh_plane()
	_add_falling_bodies()
	_add_monitored_area()
	_add_hinge_door()
	_add_impact_reporter()
	_add_zero_gravity_well()
	_add_gravity_orb()
	_add_exception_pair()
	_add_pendulum()


func _add_camera() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 8, 16)
	camera.rotation_degrees = Vector3(-20, 0, 0)
	add_child(camera)


func _add_light() -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	add_child(light)


func _add_ground() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	ground.position = Vector3(0, -0.5, 0)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(20, 1, 20)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = shape.size
	mesh.mesh = box_mesh
	ground.add_child(mesh)

	add_child(ground)


func _add_trimesh_plane() -> void:
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(6, 6)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TrimeshFloor"
	body.position = Vector3(0, 2.5, 4)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = plane_mesh.create_trimesh_shape()
	body.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = plane_mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.45, 0.2)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	body.add_child(mesh)

	add_child(body)

	var dropper: RigidBody3D = RigidBody3D.new()
	dropper.name = "TrimeshDropper"
	dropper.position = Vector3(0, 8, 4)
	var dropper_shape: CollisionShape3D = CollisionShape3D.new()
	var dropper_box: BoxShape3D = BoxShape3D.new()
	dropper_box.size = Vector3(0.8, 0.8, 0.8)
	dropper_shape.shape = dropper_box
	dropper.add_child(dropper_shape)
	var dropper_mesh: MeshInstance3D = MeshInstance3D.new()
	var dropper_box_mesh: BoxMesh = BoxMesh.new()
	dropper_box_mesh.size = dropper_box.size
	dropper_mesh.mesh = dropper_box_mesh
	dropper.add_child(dropper_mesh)
	add_child(dropper)


func _add_falling_bodies() -> void:
	var positions: Array[Vector3] = [
		Vector3(-4, 6, -2),
		Vector3(-2, 8, -2),
		Vector3(0, 10, -2),
		Vector3(2, 8, -2),
		Vector3(4, 6, -2),
	]
	for i in positions.size():
		var use_sphere: bool = i % 2 == 0
		var body: RigidBody3D = RigidBody3D.new()
		body.name = "FallingBody%d" % i
		body.position = positions[i]

		var collision: CollisionShape3D = CollisionShape3D.new()
		var mesh: MeshInstance3D = MeshInstance3D.new()
		if use_sphere:
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = 0.5
			collision.shape = sphere
			var sphere_mesh: SphereMesh = SphereMesh.new()
			sphere_mesh.radius = 0.5
			sphere_mesh.height = 1.0
			mesh.mesh = sphere_mesh
		else:
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(0.8, 0.8, 0.8)
			collision.shape = box
			var box_mesh: BoxMesh = BoxMesh.new()
			box_mesh.size = box.size
			mesh.mesh = box_mesh

		body.add_child(collision)
		body.add_child(mesh)
		add_child(body)


func _add_monitored_area() -> void:
	var area: Area3D = Area3D.new()
	area.name = "TriggerArea"
	area.position = Vector3(-4, 3, 4)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3, 6, 3)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = shape.size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.6, 1.0, 0.25)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.mesh = box_mesh
	mesh.material_override = material
	area.add_child(mesh)

	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)
	add_child(area)

	var dropper: RigidBody3D = RigidBody3D.new()
	dropper.name = "AreaDropper"
	dropper.position = Vector3(-4, 12, 4)
	var dropper_shape: CollisionShape3D = CollisionShape3D.new()
	var dropper_sphere: SphereShape3D = SphereShape3D.new()
	dropper_sphere.radius = 0.4
	dropper_shape.shape = dropper_sphere
	dropper.add_child(dropper_shape)
	var dropper_mesh: MeshInstance3D = MeshInstance3D.new()
	var dropper_sphere_mesh: SphereMesh = SphereMesh.new()
	dropper_sphere_mesh.radius = 0.4
	dropper_sphere_mesh.height = 0.8
	dropper_mesh.mesh = dropper_sphere_mesh
	dropper.add_child(dropper_mesh)
	add_child(dropper)


func _on_area_body_entered(body: Node3D) -> void:
	print("[Area] entered by: ", body.name)


func _on_area_body_exited(body: Node3D) -> void:
	print("[Area] exited by: ", body.name)


# A ball on a pin joint whose anchor is swept sideways every frame in _process.
func _add_pendulum() -> void:
	var anchor: StaticBody3D = StaticBody3D.new()
	anchor.name = "PendulumAnchor"
	anchor.position = Vector3(0, 7, -8)
	var anchor_shape: CollisionShape3D = CollisionShape3D.new()
	var anchor_box: BoxShape3D = BoxShape3D.new()
	anchor_box.size = Vector3(0.3, 0.3, 0.3)
	anchor_shape.shape = anchor_box
	anchor.add_child(anchor_shape)
	var anchor_mesh: MeshInstance3D = MeshInstance3D.new()
	var anchor_box_mesh: BoxMesh = BoxMesh.new()
	anchor_box_mesh.size = anchor_box.size
	anchor_mesh.mesh = anchor_box_mesh
	anchor.add_child(anchor_mesh)
	add_child(anchor)

	var ball: RigidBody3D = RigidBody3D.new()
	ball.name = "PendulumBall"
	ball.position = Vector3(0, 4, -8)
	var ball_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.4
	ball_shape.shape = sphere
	ball.add_child(ball_shape)
	var ball_mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = sphere.radius
	sphere_mesh.height = sphere.radius * 2.0
	ball_mesh.mesh = sphere_mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.4, 0.9)
	ball_mesh.material_override = material
	ball.add_child(ball_mesh)
	add_child(ball)

	_pendulum_joint = PinJoint3D.new()
	_pendulum_joint.position = anchor.position
	add_child(_pendulum_joint)
	_pendulum_joint.node_a = _pendulum_joint.get_path_to(anchor)
	_pendulum_joint.node_b = _pendulum_joint.get_path_to(ball)


# Two overlapping boxes with a collision exception pass through each other, while a third
# without one bounces off the stack below it.
func _add_exception_pair() -> void:
	var base: Vector3 = Vector3(-8, 1.0, 6)

	var first: RigidBody3D = _make_exception_box(base, Color(0.4, 0.6, 1.0))
	var second: RigidBody3D = _make_exception_box(base + Vector3(0.4, 0.3, 0), Color(0.2, 0.35, 0.8))
	first.add_collision_exception_with(second)

	_make_exception_box(base + Vector3(3, 0, 0), Color(1.0, 0.6, 0.2))


func _make_exception_box(position: Vector3, color: Color) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.position = position
	body.gravity_scale = 0.0
	body.angular_velocity = Vector3(0, 1.5, 0)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = shape.size
	mesh.mesh = box_mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)

	add_child(body)
	return body


# Point gravity pulling toward a center offset from the area's own origin.
func _add_gravity_orb() -> void:
	var center: Vector3 = Vector3(0, 3, 0)

	var area: Area3D = Area3D.new()
	area.name = "GravityOrb"
	area.position = Vector3(14, 2, 0)
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.gravity_point = true
	area.gravity_point_center = center
	area.gravity = 15.0

	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 7.0
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)

	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: SphereMesh = SphereMesh.new()
	marker_mesh.radius = 0.3
	marker_mesh.height = 0.6
	marker.mesh = marker_mesh
	marker.position = center
	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.85, 0.2)
	marker_material.emission_enabled = true
	marker_material.emission = Color(1.0, 0.85, 0.2)
	marker.material_override = marker_material
	area.add_child(marker)
	add_child(area)

	for i in 4:
		var ball: RigidBody3D = RigidBody3D.new()
		ball.name = "OrbBall%d" % i
		ball.position = area.position + center + Vector3(3.5 - i * 0.5, 2.0 + i, 0)
		ball.gravity_scale = 1.0
		var ball_collision: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.3
		ball_collision.shape = sphere
		ball.add_child(ball_collision)
		var ball_mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere_mesh: SphereMesh = SphereMesh.new()
		sphere_mesh.radius = sphere.radius
		sphere_mesh.height = sphere.radius * 2.0
		ball_mesh.mesh = sphere_mesh
		ball.add_child(ball_mesh)
		add_child(ball)


# Spheres fall into an area that replaces gravity with zero and damps them to a stop.
func _add_zero_gravity_well() -> void:
	var area: Area3D = Area3D.new()
	area.name = "ZeroGravityWell"
	area.position = Vector3(-8, 4, -4)
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.gravity = 0.0
	area.linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.linear_damp = 1.0

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(5, 6, 5)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = shape.size
	mesh.mesh = box_mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.9, 0.4, 0.25)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	area.add_child(mesh)
	add_child(area)

	for i in 3:
		var ball: RigidBody3D = RigidBody3D.new()
		ball.name = "WellBall%d" % i
		ball.position = Vector3(-9.0 + i, 9.0 + i, -4)
		var ball_collision: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.4
		ball_collision.shape = sphere
		ball.add_child(ball_collision)
		var ball_mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere_mesh: SphereMesh = SphereMesh.new()
		sphere_mesh.radius = sphere.radius
		sphere_mesh.height = sphere.radius * 2.0
		ball_mesh.mesh = sphere_mesh
		ball.add_child(ball_mesh)
		add_child(ball)


# Drops a body that prints its landing contacts.
func _add_impact_reporter() -> void:
	var body: RigidBody3D = RigidBody3D.new()
	body.name = "ImpactReporter"
	body.position = Vector3(7, 6, -3)
	body.contact_monitor = true
	body.max_contacts_reported = 4

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = shape.size
	mesh.mesh = box_mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.3, 0.3)
	mesh.material_override = material
	body.add_child(mesh)

	body.body_entered.connect(_on_impact_body_entered.bind(body))
	add_child(body)


func _on_impact_body_entered(other: Node, body: RigidBody3D) -> void:
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state == null or state.get_contact_count() == 0:
		return
	print("[Impact] %s hit %s at %v, normal %v, impulse %.2f" % [
		body.name,
		other.name,
		state.get_contact_local_position(0),
		state.get_contact_local_normal(0),
		state.get_contact_impulse(0).length(),
	])


func _add_hinge_door() -> void:
	var anchor: StaticBody3D = StaticBody3D.new()
	anchor.name = "DoorAnchor"
	anchor.position = Vector3(4, 1.5, 4)
	var anchor_shape: CollisionShape3D = CollisionShape3D.new()
	var anchor_box: BoxShape3D = BoxShape3D.new()
	anchor_box.size = Vector3(0.2, 3, 0.2)
	anchor_shape.shape = anchor_box
	anchor.add_child(anchor_shape)
	var anchor_mesh: MeshInstance3D = MeshInstance3D.new()
	var anchor_box_mesh: BoxMesh = BoxMesh.new()
	anchor_box_mesh.size = anchor_box.size
	anchor_mesh.mesh = anchor_box_mesh
	anchor.add_child(anchor_mesh)
	add_child(anchor)

	_door = RigidBody3D.new()
	_door.name = "Door"
	_door.position = Vector3(5, 1.5, 4)
	_door.gravity_scale = 0.0
	var door_shape: CollisionShape3D = CollisionShape3D.new()
	var door_box: BoxShape3D = BoxShape3D.new()
	door_box.size = Vector3(2, 3, 0.1)
	door_shape.shape = door_box
	_door.add_child(door_shape)
	var door_mesh: MeshInstance3D = MeshInstance3D.new()
	var door_box_mesh: BoxMesh = BoxMesh.new()
	door_box_mesh.size = door_box.size
	door_mesh.mesh = door_box_mesh
	_door.add_child(door_mesh)
	add_child(_door)

	var hinge: HingeJoint3D = HingeJoint3D.new()
	hinge.position = Vector3(4, 1.5, 4)
	add_child(hinge)
	hinge.node_a = hinge.get_path_to(anchor)
	hinge.node_b = hinge.get_path_to(_door)


func _process(_delta: float) -> void:
	if not _door_swung and Engine.get_physics_frames() > 30:
		_door_swung = true
		_door.apply_torque_impulse(Vector3(0, 3.0, 0))

	# A stiff pin spring pumps energy if the anchor jumps, so sweep it slowly and gently.
	if _pendulum_joint != null:
		var sweep: float = sin(Engine.get_physics_frames() * 0.01) * 0.6
		PhysicsServer3D.pin_joint_set_local_a(_pendulum_joint.get_rid(), Vector3(sweep, 0, 0))
