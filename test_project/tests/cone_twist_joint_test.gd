extends SceneTree

const SWING_SPAN: float = 0.35
const TWIST_SPAN: float = 0.2

var frames: int = 0
var joint: ConeTwistJoint3D


func _initialize() -> void:
	var anchor: StaticBody3D = StaticBody3D.new()
	var anchor_shape: CollisionShape3D = CollisionShape3D.new()
	var anchor_box: BoxShape3D = BoxShape3D.new()
	anchor_box.size = Vector3.ONE
	anchor_shape.shape = anchor_box
	anchor.add_child(anchor_shape)
	root.add_child(anchor)

	var body: RigidBody3D = RigidBody3D.new()
	var body_shape: CollisionShape3D = CollisionShape3D.new()
	var body_box: BoxShape3D = BoxShape3D.new()
	body_box.size = Vector3.ONE
	body_shape.shape = body_box
	body.add_child(body_shape)
	body.gravity_scale = 0.0
	body.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(body)

	joint = ConeTwistJoint3D.new()
	joint.swing_span = SWING_SPAN
	joint.twist_span = TWIST_SPAN
	joint.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(joint)
	joint.node_a = joint.get_path_to(anchor)
	joint.node_b = joint.get_path_to(body)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false

	var joint_rid: RID = joint.get_rid()
	var type_matches: bool = PhysicsServer3D.joint_get_type(joint_rid) == PhysicsServer3D.JOINT_TYPE_CONE_TWIST
	var swing: float = PhysicsServer3D.cone_twist_joint_get_param(
		joint_rid,
		PhysicsServer3D.CONE_TWIST_JOINT_SWING_SPAN,
	)
	var twist: float = PhysicsServer3D.cone_twist_joint_get_param(
		joint_rid,
		PhysicsServer3D.CONE_TWIST_JOINT_TWIST_SPAN,
	)
	var params_match: bool = is_equal_approx(swing, SWING_SPAN) and is_equal_approx(twist, TWIST_SPAN)
	var passed: bool = type_matches and params_match
	print("Cone-twist type matches: ", type_matches)
	print("Cone-twist spans: swing=", swing, " twist=", twist)
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
	return false
