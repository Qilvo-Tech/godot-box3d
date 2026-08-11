#include "box3d_cone_twist_joint_impl_3d.hpp"

#include <box3d/box3d.h>

Box3DConeTwistJointImpl3D::Box3DConeTwistJointImpl3D(
		Box3DBodyImpl3D* p_body_a,
		Box3DBodyImpl3D* p_body_b,
		const Transform3D& p_local_frame_a,
		const Transform3D& p_local_frame_b) :
		Box3DJointImpl3D(p_body_a, p_body_b, p_local_frame_a, p_local_frame_b) {
}

b3JointId Box3DConeTwistJointImpl3D::_create_joint_id(b3WorldId p_world_id, b3BodyId p_body_a, b3BodyId p_body_b, b3Transform p_local_frame_a, b3Transform p_local_frame_b) {
	b3SphericalJointDef def = b3DefaultSphericalJointDef();
	def.base.bodyIdA = p_body_a;
	def.base.bodyIdB = p_body_b;
	def.base.localFrameA = p_local_frame_a;
	def.base.localFrameB = p_local_frame_b;
	def.enableConeLimit = true;
	def.coneAngle = (float)Math::clamp(swing_span, (real_t)0.0, (real_t)Math_PI);
	def.enableTwistLimit = true;
	const real_t clamped_twist = Math::clamp(twist_span, (real_t)0.0, (real_t)(Math_PI * 0.99));
	def.lowerTwistAngle = (float)-clamped_twist;
	def.upperTwistAngle = (float)clamped_twist;
	return b3CreateSphericalJoint(p_world_id, &def);
}

real_t Box3DConeTwistJointImpl3D::get_param(Param p_param) const {
	switch (p_param) {
		case PhysicsServer3D::CONE_TWIST_JOINT_SWING_SPAN:
			return swing_span;
		case PhysicsServer3D::CONE_TWIST_JOINT_TWIST_SPAN:
			return twist_span;
		case PhysicsServer3D::CONE_TWIST_JOINT_BIAS:
			return bias;
		case PhysicsServer3D::CONE_TWIST_JOINT_SOFTNESS:
			return softness;
		case PhysicsServer3D::CONE_TWIST_JOINT_RELAXATION:
			return relaxation;
		default:
			return 0.0;
	}
}

void Box3DConeTwistJointImpl3D::set_param(Param p_param, real_t p_value) {
	switch (p_param) {
		case PhysicsServer3D::CONE_TWIST_JOINT_SWING_SPAN:
			swing_span = p_value;
			_apply_swing_limit();
			break;
		case PhysicsServer3D::CONE_TWIST_JOINT_TWIST_SPAN:
			twist_span = p_value;
			_apply_twist_limit();
			break;
		case PhysicsServer3D::CONE_TWIST_JOINT_BIAS:
			bias = p_value;
			break;
		case PhysicsServer3D::CONE_TWIST_JOINT_SOFTNESS:
			softness = p_value;
			break;
		case PhysicsServer3D::CONE_TWIST_JOINT_RELAXATION:
			relaxation = p_value;
			break;
		default:
			break;
	}
}

void Box3DConeTwistJointImpl3D::_apply_swing_limit() {
	if (has_joint_id()) {
		b3SphericalJoint_SetConeLimit(get_joint_id(), (float)Math::clamp(swing_span, (real_t)0.0, (real_t)Math_PI));
	}
}

void Box3DConeTwistJointImpl3D::_apply_twist_limit() {
	if (has_joint_id()) {
		const real_t clamped_twist = Math::clamp(twist_span, (real_t)0.0, (real_t)(Math_PI * 0.99));
		b3SphericalJoint_SetTwistLimits(get_joint_id(), (float)-clamped_twist, (float)clamped_twist);
	}
}
