#include "box3d_heightmap_shape_impl_3d.hpp"

#include <box3d/collision.h>

#include <cmath>

#include <godot_cpp/templates/local_vector.hpp>

Box3DHeightMapShapeImpl3D::~Box3DHeightMapShapeImpl3D() {
	if (height_field != nullptr) {
		b3DestroyHeightField(height_field);
		height_field = nullptr;
	}
}

Variant Box3DHeightMapShapeImpl3D::get_data() const {
	Dictionary data;
	data["width"] = width;
	data["depth"] = depth;
	data["heights"] = heights;
	return data;
}

void Box3DHeightMapShapeImpl3D::set_data(const Variant& p_data) {
	ERR_FAIL_COND(p_data.get_type() != Variant::DICTIONARY);

	const Dictionary data = p_data;

	const Variant maybe_heights = data.get("heights", Variant());
	ERR_FAIL_COND(maybe_heights.get_type() != Variant::PACKED_FLOAT32_ARRAY && maybe_heights.get_type() != Variant::PACKED_FLOAT64_ARRAY);

	const Variant maybe_width = data.get("width", Variant());
	ERR_FAIL_COND(maybe_width.get_type() != Variant::INT);

	const Variant maybe_depth = data.get("depth", Variant());
	ERR_FAIL_COND(maybe_depth.get_type() != Variant::INT);

	if (maybe_heights.get_type() == Variant::PACKED_FLOAT64_ARRAY) {
		const PackedFloat64Array heights64 = maybe_heights;
		heights.resize(heights64.size());
		for (int i = 0; i < heights64.size(); i++) {
			heights.set(i, (float)heights64[i]);
		}
	} else {
		heights = maybe_heights;
	}

	width = maybe_width;
	depth = maybe_depth;

	_rebuild();
}

void Box3DHeightMapShapeImpl3D::_rebuild() {
	if (height_field != nullptr) {
		b3DestroyHeightField(height_field);
		height_field = nullptr;
	}
	aabb = AABB();

	if (width < 2 || depth < 2 || heights.size() != width * depth) {
		return;
	}

	float min_height = 0.0f;
	float max_height = 0.0f;
	bool has_finite_height = false;
	for (int i = 0; i < heights.size(); i++) {
		const float h = heights[i];
		if (!std::isfinite(h)) {
			continue;
		}
		if (!has_finite_height) {
			min_height = h;
			max_height = h;
			has_finite_height = true;
		} else if (h < min_height) {
			min_height = h;
		} else if (h > max_height) {
			max_height = h;
		}
	}
	if (!has_finite_height) {
		return;
	}

	if (min_height == max_height) {
		// Box3D requires a non-degenerate quantization range.
		max_height = min_height + 0.001f;
	}

	PackedFloat32Array sanitized_heights = heights;
	for (int i = 0; i < sanitized_heights.size(); i++) {
		if (!std::isfinite(sanitized_heights[i])) {
			sanitized_heights.set(i, min_height);
		}
	}

	LocalVector<uint8_t> material_indices;
	material_indices.resize((width - 1) * (depth - 1));
	for (int z = 0; z < depth - 1; z++) {
		for (int x = 0; x < width - 1; x++) {
			const int top_left = z * width + x;
			const bool is_hole =
					!std::isfinite(heights[top_left]) ||
					!std::isfinite(heights[top_left + 1]) ||
					!std::isfinite(heights[top_left + width]) ||
					!std::isfinite(heights[top_left + width + 1]);
			material_indices[z * (width - 1) + x] = is_hole ? B3_HEIGHT_FIELD_HOLE : 0;
		}
	}

	b3HeightFieldDef def = {};
	def.heights = sanitized_heights.ptrw();
	def.materialIndices = material_indices.ptr();
	def.scale = b3Vec3{1.0f, 1.0f, 1.0f};
	def.countX = width;
	def.countZ = depth;
	def.globalMinimumHeight = min_height;
	def.globalMaximumHeight = max_height;
	def.clockwiseWinding = false;

	height_field = b3CreateHeightField(&def);

	const float half_x = (float)(width - 1) * 0.5f;
	const float half_z = (float)(depth - 1) * 0.5f;
	aabb = AABB(
		Vector3(-half_x, min_height, -half_z),
		Vector3((float)(width - 1), max_height - min_height, (float)(depth - 1))
	);
}
