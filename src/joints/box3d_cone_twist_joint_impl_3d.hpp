#pragma once

#include "box3d_joint_impl_3d.hpp"

// ConeTwistJoint3D maps to Box3D's spherical joint with its cone and symmetric
// twist limits enabled. Box3D does not expose Godot's bias/softness/relaxation
// tuning, so those values are retained for API round-tripping only.
class Box3DConeTwistJointImpl3D final : public Box3DJointImpl3D {
public:
	using Param = PhysicsServer3D::ConeTwistJointParam;

	Box3DConeTwistJointImpl3D(Box3DBodyImpl3D* p_body_a, Box3DBodyImpl3D* p_body_b, const Transform3D& p_local_frame_a, const Transform3D& p_local_frame_b);

	PhysicsServer3D::JointType get_type() const override { return PhysicsServer3D::JOINT_TYPE_CONE_TWIST; }

	real_t get_param(Param p_param) const;

	void set_param(Param p_param, real_t p_value);

protected:
	b3JointId _create_joint_id(b3WorldId p_world_id, b3BodyId p_body_a, b3BodyId p_body_b, b3Transform p_local_frame_a, b3Transform p_local_frame_b) override;

private:
	void _apply_swing_limit();

	void _apply_twist_limit();

	real_t swing_span = Math_PI * 0.25;
	real_t twist_span = Math_PI;
	real_t bias = 0.3;
	real_t softness = 0.8;
	real_t relaxation = 1.0;
};
