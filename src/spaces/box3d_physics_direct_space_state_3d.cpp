#include "box3d_physics_direct_space_state_3d.hpp"

#include "../misc/box3d_shape_proxy.hpp"
#include "../misc/type_conversions.hpp"
#include "../objects/box3d_area_impl_3d.hpp"
#include "../objects/box3d_body_impl_3d.hpp"
#include "../objects/box3d_shaped_object_impl_3d.hpp"
#include "../servers/box3d_physics_server_3d.hpp"
#include "../shapes/box3d_capsule_shape_impl_3d.hpp"
#include "../shapes/box3d_shape_impl_3d.hpp"
#include "../shapes/box3d_shape_instance_3d.hpp"
#include "../shapes/box3d_sphere_shape_impl_3d.hpp"
#include "box3d_query_filter_3d.hpp"
#include "box3d_space_3d.hpp"

#include <box3d/box3d.h>

#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace {

struct OverlapContext {
	const Box3DQueryFilter3D* filter = nullptr;
	PhysicsServer3DExtensionShapeResult* results = nullptr;
	int32_t max_results = 0;
	int32_t count = 0;
};

bool should_report(void* p_user_data, const Box3DQueryFilter3D& p_filter, Box3DShapedObjectImpl3D*& r_object) {
	auto* object = static_cast<Box3DShapedObjectImpl3D*>(p_user_data);
	if (object == nullptr) {
		return false;
	}
	const bool is_area = dynamic_cast<Box3DAreaImpl3D*>(object) != nullptr;
	if (is_area && !p_filter.collide_with_areas) {
		return false;
	}
	if (!is_area && !p_filter.collide_with_bodies) {
		return false;
	}
	if (p_filter.should_exclude(object->get_rid())) {
		return false;
	}
	r_object = object;
	return true;
}

bool overlap_result_fcn(b3ShapeId p_shape_id, void* p_context) {
	auto* ctx = static_cast<OverlapContext*>(p_context);
	if (ctx->count >= ctx->max_results) {
		return false;
	}

	const b3BodyId body_id = b3Shape_GetBody(p_shape_id);
	Box3DShapedObjectImpl3D* object = nullptr;
	if (!should_report(b3Body_GetUserData(body_id), *ctx->filter, object)) {
		return true;
	}

	PhysicsServer3DExtensionShapeResult& result = ctx->results[ctx->count];
	result.rid = object->get_rid();
	result.collider_id = object->get_instance_id();
	result.shape = 0;
	ctx->count++;
	return true;
}

struct MoverPlaneHit {
	b3PlaneResult result{};
	Box3DShapedObjectImpl3D* object = nullptr;
	int32_t collider_shape = 0;
};

struct MoverPlaneContext {
	const Box3DQueryFilter3D* filter = nullptr;
	LocalVector<MoverPlaneHit> hits;
	int32_t max_hits = 0;
};

bool mover_plane_result_fcn(b3ShapeId p_shape_id, const b3PlaneResult* p_planes, int p_plane_count, void* p_context) {
	auto* ctx = static_cast<MoverPlaneContext*>(p_context);
	const b3BodyId body_id = b3Shape_GetBody(p_shape_id);
	Box3DShapedObjectImpl3D* object = nullptr;
	if (!should_report(b3Body_GetUserData(body_id), *ctx->filter, object)) {
		return true;
	}

	const auto* shape_instance = static_cast<const Box3DShapeInstance3D*>(b3Shape_GetUserData(p_shape_id));
	const int32_t collider_shape = shape_instance != nullptr ? (int32_t)shape_instance->get_index() : 0;

	for (int i = 0; i < p_plane_count && (int32_t)ctx->hits.size() < ctx->max_hits; i++) {
		MoverPlaneHit hit;
		hit.result = p_planes[i];
		hit.object = object;
		hit.collider_shape = collider_shape;
		ctx->hits.push_back(hit);
	}
	return (int32_t)ctx->hits.size() < ctx->max_hits;
}

bool mover_filter_fcn(b3ShapeId p_shape_id, void* p_context) {
	const auto* filter = static_cast<const Box3DQueryFilter3D*>(p_context);
	const b3BodyId body_id = b3Shape_GetBody(p_shape_id);
	Box3DShapedObjectImpl3D* object = nullptr;
	return should_report(b3Body_GetUserData(body_id), *filter, object);
}

Box3DQueryFilter3D make_mover_filter(const Box3DShapedObjectImpl3D& p_body, const TypedArray<RID>& p_exclude) {
	Box3DQueryFilter3D filter;
	const b3Filter body_filter = godot_to_b3_filter(p_body.get_collision_layer(), p_body.get_collision_mask());
	filter.filter.categoryBits = body_filter.categoryBits;
	filter.filter.maskBits = body_filter.maskBits;
	filter.exclude.insert(p_body.get_rid());
	for (int32_t i = 0; i < p_exclude.size(); i++) {
		filter.exclude.insert((RID)p_exclude[i]);
	}
	if (const auto* body = dynamic_cast<const Box3DBodyImpl3D*>(&p_body)) {
		for (const KeyValue<RID, Box3DFilterJointImpl3D*>& entry : body->get_collision_exceptions()) {
			filter.exclude.insert(entry.key);
		}
	}
	return filter;
}

bool try_build_mover_capsule(const Box3DShapedObjectImpl3D& p_body, const Transform3D& p_transform, double p_margin,
							 b3Pos& r_origin, b3Capsule& r_mover, int32_t& r_local_shape) {
	int32_t shape_index = -1;
	for (int32_t i = 0; i < p_body.get_shape_count(); i++) {
		if (p_body.is_shape_disabled(i)) {
			continue;
		}
		if (shape_index != -1) {
			return false;
		}
		shape_index = i;
	}
	if (shape_index == -1) {
		return false;
	}

	const Box3DShapeImpl3D* shape = p_body.get_shape(shape_index);
	const Transform3D shape_transform = p_transform * p_body.get_shape_transform(shape_index);
	const Vector3 origin = p_transform.origin;
	const float margin = (float)MAX(p_margin, 0.0);

	switch (shape->get_type()) {
	case PhysicsServer3D::SHAPE_CAPSULE: {
		const auto* capsule = static_cast<const Box3DCapsuleShapeImpl3D*>(shape);
		const float radius = (float)capsule->get_radius();
		const float half_segment = MAX(0.0f, (float)capsule->get_height() * 0.5f - radius);
		r_mover.center1 = godot_to_b3(shape_transform.xform(Vector3(0, half_segment, 0)) - origin);
		r_mover.center2 = godot_to_b3(shape_transform.xform(Vector3(0, -half_segment, 0)) - origin);
		r_mover.radius = radius + margin;
		break;
	}
	case PhysicsServer3D::SHAPE_SPHERE: {
		const auto* sphere = static_cast<const Box3DSphereShapeImpl3D*>(shape);
		const b3Vec3 center = godot_to_b3(shape_transform.origin - origin);
		r_mover.center1 = center;
		r_mover.center2 = center;
		r_mover.radius = (float)sphere->get_radius() + margin;
		break;
	}
	default:
		return false;
	}

	r_origin = godot_to_b3(origin);
	r_local_shape = shape_index;
	return true;
}

struct CollideShapeContext {
	const Box3DQueryFilter3D* filter = nullptr;
	const b3ShapeProxy* query_proxy = nullptr;
	Vector3* results = nullptr;
	int32_t max_results = 0;
	int32_t count = 0;
};

// Reports the closest points between the query shape and one overlapping shape. Godot wants
// world-space pairs, and b3ShapeDistance runs in frame A, which is world space here because
// Box3DShapeProxy3D already bakes the transform into its points.
bool collide_shape_result_fcn(b3ShapeId p_shape_id, void* p_context) {
	auto* ctx = static_cast<CollideShapeContext*>(p_context);
	if (ctx->count >= ctx->max_results) {
		return false;
	}

	const b3BodyId body_id = b3Shape_GetBody(p_shape_id);
	Box3DShapedObjectImpl3D* object = nullptr;
	if (!should_report(b3Body_GetUserData(body_id), *ctx->filter, object)) {
		return true;
	}

	const Transform3D object_transform = object->get_transform();
	for (int32_t i = 0; i < object->get_shape_count(); i++) {
		if (!object->has_shape_id(i) || !B3_ID_EQUALS(object->get_shape_id(i), p_shape_id)) {
			continue;
		}

		const Box3DShapeProxy3D other_proxy(object->get_shape(i), object_transform * object->get_shape_transform(i));
		if (!other_proxy.is_supported()) {
			return true;
		}

		b3DistanceInput input{};
		input.proxyA = *ctx->query_proxy;
		input.proxyB = other_proxy.get_proxy();
		input.transform = b3Transform_identity;
		input.useRadii = true;

		b3SimplexCache cache{};
		const b3DistanceOutput output = b3ShapeDistance(&input, &cache, nullptr, 0);

		// GJK cannot recover penetration depth, so an overlapping pair reports its witness
		// point for both sides rather than a fabricated depth.
		ctx->results[ctx->count * 2 + 0] = b3_to_godot(output.pointA);
		ctx->results[ctx->count * 2 + 1] = b3_to_godot(output.pointB);
		ctx->count++;
		return true;
	}
	return true;
}

struct RayContext {
	const Box3DQueryFilter3D* filter = nullptr;
	bool hit_from_inside = false;
	bool has_hit = false;
	b3ShapeId shape_id = b3_nullShapeId;
	b3Pos point{};
	b3Vec3 normal{};
	float fraction = 1.0f;
};

float cast_result_fcn(b3ShapeId p_shape_id, b3Pos p_point, b3Vec3 p_normal, float p_fraction, uint64_t, int, int,
					  void* p_context) {
	auto* ctx = static_cast<RayContext*>(p_context);

	const b3BodyId body_id = b3Shape_GetBody(p_shape_id);
	Box3DShapedObjectImpl3D* object = nullptr;
	if (!should_report(b3Body_GetUserData(body_id), *ctx->filter, object)) {
		return -1.0f;
	}

	ctx->has_hit = true;
	ctx->shape_id = p_shape_id;
	ctx->point = p_point;
	ctx->normal = p_normal;
	ctx->fraction = p_fraction;
	return p_fraction;
}

} // namespace

bool Box3DPhysicsDirectSpaceState3D::_intersect_ray(const Vector3& p_from, const Vector3& p_to,
													uint32_t p_collision_mask, bool p_collide_with_bodies,
													bool p_collide_with_areas, bool p_hit_from_inside,
													bool p_hit_back_faces, bool p_pick_ray,
													PhysicsServer3DExtensionRayResult* p_result) {
	ERR_FAIL_NULL_V(space, false);

	Box3DQueryFilter3D filter(p_collision_mask, p_collide_with_bodies, p_collide_with_areas);
	filter.direct_state = this;

	RayContext context;
	context.filter = &filter;
	context.hit_from_inside = p_hit_from_inside;

	const b3Vec3 origin = godot_to_b3(p_from);
	const b3Vec3 translation = godot_to_b3(p_to - p_from);

	b3World_CastRay(space->get_world_id(), origin, translation, filter.filter, cast_result_fcn, &context);

	if (!context.has_hit) {
		return false;
	}

	const b3BodyId body_id = b3Shape_GetBody(context.shape_id);
	auto* object = static_cast<Box3DShapedObjectImpl3D*>(b3Body_GetUserData(body_id));
	if (object == nullptr) {
		return false;
	}

	p_result->position = b3_to_godot(context.point);
	p_result->normal = b3_to_godot(context.normal);
	p_result->rid = object->get_rid();
	p_result->collider_id = object->get_instance_id();
	p_result->shape = 0;
	return true;
}

int32_t Box3DPhysicsDirectSpaceState3D::_intersect_point(const Vector3& p_position, uint32_t p_collision_mask,
														 bool p_collide_with_bodies, bool p_collide_with_areas,
														 PhysicsServer3DExtensionShapeResult* p_results,
														 int32_t p_max_results) {
	ERR_FAIL_NULL_V(space, 0);

	Box3DQueryFilter3D filter(p_collision_mask, p_collide_with_bodies, p_collide_with_areas);
	filter.direct_state = this;

	const b3Vec3 point = godot_to_b3(p_position);
	b3ShapeProxy proxy;
	proxy.points = &point;
	proxy.count = 1;
	proxy.radius = 0.0f;

	OverlapContext context;
	context.filter = &filter;
	context.results = p_results;
	context.max_results = p_max_results;

	b3World_OverlapShape(space->get_world_id(), b3Vec3_zero, &proxy, filter.filter, overlap_result_fcn, &context);

	return context.count;
}

int32_t Box3DPhysicsDirectSpaceState3D::_intersect_shape(const RID& p_shape_rid, const Transform3D& p_transform,
														 const Vector3& p_motion, double p_margin,
														 uint32_t p_collision_mask, bool p_collide_with_bodies,
														 bool p_collide_with_areas,
														 PhysicsServer3DExtensionShapeResult* p_results,
														 int32_t p_max_results) {
	ERR_FAIL_NULL_V(space, 0);

	Box3DShapeImpl3D* shape = Box3DPhysicsServer3D::get_singleton()->get_shape(p_shape_rid);
	ERR_FAIL_NULL_V(shape, 0);

	const Box3DShapeProxy3D shape_proxy(shape, p_transform);
	if (!shape_proxy.is_supported()) {
		return 0;
	}

	Box3DQueryFilter3D filter(p_collision_mask, p_collide_with_bodies, p_collide_with_areas);
	filter.direct_state = this;

	OverlapContext context;
	context.filter = &filter;
	context.results = p_results;
	context.max_results = p_max_results;

	b3World_OverlapShape(space->get_world_id(), b3Vec3_zero, &shape_proxy.get_proxy(), filter.filter,
						 overlap_result_fcn, &context);

	return context.count;
}

bool Box3DPhysicsDirectSpaceState3D::_cast_motion(const RID& p_shape_rid, const Transform3D& p_transform,
												  const Vector3& p_motion, double p_margin, uint32_t p_collision_mask,
												  bool p_collide_with_bodies, bool p_collide_with_areas,
												  float* p_closest_safe, float* p_closest_unsafe,
												  PhysicsServer3DExtensionShapeRestInfo* p_info) {
	ERR_FAIL_NULL_V(space, false);

	Box3DShapeImpl3D* shape = Box3DPhysicsServer3D::get_singleton()->get_shape(p_shape_rid);
	ERR_FAIL_NULL_V(shape, false);

	const Box3DShapeProxy3D shape_proxy(shape, p_transform);
	if (!shape_proxy.is_supported()) {
		*p_closest_safe = 1.0;
		*p_closest_unsafe = 1.0;
		return false;
	}

	Box3DQueryFilter3D filter(p_collision_mask, p_collide_with_bodies, p_collide_with_areas);
	filter.direct_state = this;

	RayContext context;
	context.filter = &filter;

	b3World_CastShape(space->get_world_id(), b3Vec3_zero, &shape_proxy.get_proxy(), godot_to_b3(p_motion),
					  filter.filter, cast_result_fcn, &context);

	if (!context.has_hit) {
		*p_closest_safe = 1.0;
		*p_closest_unsafe = 1.0;
		return false;
	}

	*p_closest_safe = context.fraction;
	*p_closest_unsafe = context.fraction;
	return true;
}

bool Box3DPhysicsDirectSpaceState3D::_collide_shape(const RID& p_shape_rid, const Transform3D& p_transform,
													const Vector3& p_motion, double p_margin, uint32_t p_collision_mask,
													bool p_collide_with_bodies, bool p_collide_with_areas,
													void* p_results, int32_t p_max_results, int32_t* p_result_count) {
	*p_result_count = 0;
	ERR_FAIL_NULL_V(space, false);
	if (p_max_results <= 0) {
		return false;
	}

	Box3DShapeImpl3D* shape = Box3DPhysicsServer3D::get_singleton()->get_shape(p_shape_rid);
	ERR_FAIL_NULL_V(shape, false);

	const Box3DShapeProxy3D shape_proxy(shape, p_transform);
	if (!shape_proxy.is_supported()) {
		return false;
	}

	Box3DQueryFilter3D filter(p_collision_mask, p_collide_with_bodies, p_collide_with_areas);
	filter.direct_state = this;

	CollideShapeContext context;
	context.filter = &filter;
	context.query_proxy = &shape_proxy.get_proxy();
	context.results = static_cast<Vector3*>(p_results);
	context.max_results = p_max_results;

	b3World_OverlapShape(space->get_world_id(), b3Vec3_zero, &shape_proxy.get_proxy(), filter.filter,
						 collide_shape_result_fcn, &context);

	*p_result_count = context.count;
	return context.count > 0;
}

bool Box3DPhysicsDirectSpaceState3D::_rest_info(const RID& p_shape_rid, const Transform3D& p_transform,
												const Vector3& p_motion, double p_margin, uint32_t p_collision_mask,
												bool p_collide_with_bodies, bool p_collide_with_areas,
												PhysicsServer3DExtensionShapeRestInfo* p_info) {
	ERR_FAIL_NULL_V(space, false);

	Box3DShapeImpl3D* shape = Box3DPhysicsServer3D::get_singleton()->get_shape(p_shape_rid);
	ERR_FAIL_NULL_V(shape, false);

	const Box3DShapeProxy3D shape_proxy(shape, p_transform);
	if (!shape_proxy.is_supported()) {
		return false;
	}

	Box3DQueryFilter3D filter(p_collision_mask, p_collide_with_bodies, p_collide_with_areas);
	filter.direct_state = this;

	RayContext context;
	context.filter = &filter;

	b3World_CastShape(space->get_world_id(), b3Vec3_zero, &shape_proxy.get_proxy(), godot_to_b3(p_motion),
					  filter.filter, cast_result_fcn, &context);

	if (!context.has_hit) {
		return false;
	}

	const b3BodyId body_id = b3Shape_GetBody(context.shape_id);
	auto* object = static_cast<Box3DShapedObjectImpl3D*>(b3Body_GetUserData(body_id));
	if (object == nullptr) {
		return false;
	}

	p_info->point = b3_to_godot(context.point);
	p_info->normal = b3_to_godot(context.normal);
	p_info->rid = object->get_rid();
	p_info->collider_id = object->get_instance_id();
	p_info->shape = 0;

	auto* body = dynamic_cast<Box3DBodyImpl3D*>(object);
	if (body != nullptr) {
		p_info->linear_velocity = body->get_linear_velocity();
	}

	return true;
}

Vector3 Box3DPhysicsDirectSpaceState3D::_get_closest_point_to_object_volume(const RID& p_object,
																			const Vector3& p_point) const {
	Box3DShapedObjectImpl3D* object = Box3DPhysicsServer3D::get_singleton()->get_body(p_object);
	if (object == nullptr) {
		object = Box3DPhysicsServer3D::get_singleton()->get_area(p_object);
	}
	if (object == nullptr || !object->has_body_id()) {
		return p_point;
	}

	b3Vec3 result_point{};
	b3Body_GetClosestPoint(object->get_body_id(), &result_point, godot_to_b3(p_point));
	return b3_to_godot(result_point);
}

Dictionary Box3DPhysicsDirectSpaceState3D::collide_mover(const Box3DShapedObjectImpl3D& p_body,
														 const Transform3D& p_transform, double p_margin,
														 int32_t p_max_results,
														 const TypedArray<RID>& p_exclude) const {
	Dictionary result;
	PackedVector3Array normals;
	PackedVector3Array points;
	PackedFloat32Array offsets;
	PackedInt64Array collider_ids;
	PackedInt32Array local_shapes;
	PackedInt32Array collider_shapes;
	TypedArray<RID> colliders;

	result["normals"] = normals;
	result["points"] = points;
	result["offsets"] = offsets;
	result["collider_ids"] = collider_ids;
	result["local_shapes"] = local_shapes;
	result["collider_shapes"] = collider_shapes;
	result["colliders"] = colliders;

	ERR_FAIL_NULL_V(space, result);
	p_max_results = CLAMP(p_max_results, 0, 32);
	if (p_max_results == 0) {
		return result;
	}

	b3Pos origin{};
	b3Capsule mover{};
	int32_t local_shape = -1;
	if (!try_build_mover_capsule(p_body, p_transform, p_margin, origin, mover, local_shape)) {
		return result;
	}

	const Box3DQueryFilter3D filter = make_mover_filter(p_body, p_exclude);
	MoverPlaneContext context;
	context.filter = &filter;
	context.max_hits = p_max_results;

	b3World_CollideMover(space->get_world_id(), origin, &mover, filter.filter, mover_plane_result_fcn, &context);

	const Vector3 world_origin = b3_to_godot(origin);
	for (const MoverPlaneHit& hit : context.hits) {
		normals.push_back(b3_to_godot(hit.result.plane.normal));
		points.push_back(world_origin + b3_to_godot(hit.result.point));
		offsets.push_back(hit.result.plane.offset);
		collider_ids.push_back((int64_t)hit.object->get_instance_id());
		local_shapes.push_back(local_shape);
		collider_shapes.push_back(hit.collider_shape);
		colliders.push_back(hit.object->get_rid());
	}

	result["normals"] = normals;
	result["points"] = points;
	result["offsets"] = offsets;
	result["collider_ids"] = collider_ids;
	result["local_shapes"] = local_shapes;
	result["collider_shapes"] = collider_shapes;
	result["colliders"] = colliders;
	return result;
}

double Box3DPhysicsDirectSpaceState3D::cast_mover(const Box3DShapedObjectImpl3D& p_body, const Transform3D& p_transform,
												  const Vector3& p_motion, double p_margin,
												  const TypedArray<RID>& p_exclude) const {
	ERR_FAIL_NULL_V(space, 1.0);

	b3Pos origin{};
	b3Capsule mover{};
	int32_t local_shape = -1;
	if (!try_build_mover_capsule(p_body, p_transform, p_margin, origin, mover, local_shape)) {
		return 1.0;
	}

	Box3DQueryFilter3D filter = make_mover_filter(p_body, p_exclude);
	return b3World_CastMover(space->get_world_id(), origin, &mover, godot_to_b3(p_motion), filter.filter,
							 mover_filter_fcn, &filter);
}

bool Box3DPhysicsDirectSpaceState3D::test_body_motion(Box3DShapedObjectImpl3D& p_body, const Transform3D& p_transform,
													  const Vector3& p_motion, double p_margin,
													  int32_t p_max_collisions, bool p_recovery_as_collision,
													  PhysicsServer3DExtensionMotionResult* p_result) const {
	ERR_FAIL_NULL_V(space, false);

	p_result->travel = Vector3();
	p_result->remainder = p_motion;
	p_result->collision_depth = 0.0f;
	p_result->collision_safe_fraction = 1.0f;
	p_result->collision_unsafe_fraction = 1.0f;
	p_result->collision_count = 0;

	if (p_body.get_shape_count() == 0) {
		p_result->travel = p_motion;
		p_result->remainder = Vector3();
		return false;
	}

	Box3DShapeImpl3D* first_shape = p_body.get_shape(0);
	if (first_shape == nullptr) {
		p_result->travel = p_motion;
		p_result->remainder = Vector3();
		return false;
	}

	Box3DQueryFilter3D filter;
	filter.set_collision_mask(p_body.get_collision_mask());
	filter.exclude.insert(p_body.get_rid());

	const Box3DShapeProxy3D shape_proxy(first_shape, p_transform * p_body.get_shape_transform(0));
	if (!shape_proxy.is_supported()) {
		p_result->travel = p_motion;
		p_result->remainder = Vector3();
		return false;
	}

	RayContext context;
	context.filter = &filter;

	b3World_CastShape(space->get_world_id(), b3Vec3_zero, &shape_proxy.get_proxy(), godot_to_b3(p_motion),
					  filter.filter, cast_result_fcn, &context);

	if (!context.has_hit) {
		p_result->travel = p_motion;
		p_result->remainder = Vector3();
		return false;
	}

	p_result->travel = p_motion * context.fraction;
	p_result->remainder = p_motion * (1.0f - context.fraction);
	p_result->collision_safe_fraction = context.fraction;
	p_result->collision_unsafe_fraction = context.fraction;

	const b3BodyId body_id = b3Shape_GetBody(context.shape_id);
	auto* other = static_cast<Box3DShapedObjectImpl3D*>(b3Body_GetUserData(body_id));
	if (other != nullptr && p_max_collisions > 0) {
		PhysicsServer3DExtensionMotionCollision& collision = p_result->collisions[0];
		collision.position = b3_to_godot(context.point);
		collision.normal = b3_to_godot(context.normal);
		collision.collider = other->get_rid();
		collision.collider_id = other->get_instance_id();
		collision.collider_shape = 0;
		collision.depth = 0.0f;
		p_result->collision_count = 1;
	}

	return true;
}
