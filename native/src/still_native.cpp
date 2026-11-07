// See still_native.h.

#include "still_native.h"

#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

void NativeStill::_bind_methods() {
	ClassDB::bind_method(D_METHOD("hold", "instances"), &NativeStill::hold);
	ClassDB::bind_method(
			D_METHOD("hold_each", "instances", "locals"), &NativeStill::hold_each);
	ClassDB::bind_method(D_METHOD("place", "at"), &NativeStill::place);
	ClassDB::bind_method(D_METHOD("placed", "at"), &NativeStill::placed);
	ClassDB::bind_method(D_METHOD("size"), &NativeStill::size);
}

void NativeStill::hold(const TypedArray<RID> &p_instances) {
	instances_.clear();
	locals_.clear();
	instances_.reserve(p_instances.size());
	for (int64_t index = 0; index < p_instances.size(); index++) {
		instances_.push_back(p_instances[index]);
	}
}

void NativeStill::hold_each(
		const TypedArray<RID> &p_instances, const TypedArray<Transform3D> &p_locals) {
	hold(p_instances);
	ERR_FAIL_COND_MSG(p_locals.size() != p_instances.size(), "one transform an instance");
	locals_.reserve(p_locals.size());
	for (int64_t index = 0; index < p_locals.size(); index++) {
		locals_.push_back(p_locals[index]);
	}
}

Transform3D NativeStill::standing(size_t p_index, const Transform3D &p_at) const {
	// Node3D's global transform: the parent's times the child's own.
	return locals_.empty() ? p_at : p_at * locals_[p_index];
}

void NativeStill::place(const Transform3D &p_at) const {
	RenderingServer *server = RenderingServer::get_singleton();
	for (size_t index = 0; index < instances_.size(); index++) {
		server->instance_set_transform(instances_[index], standing(index, p_at));
	}
}

TypedArray<Transform3D> NativeStill::placed(const Transform3D &p_at) const {
	TypedArray<Transform3D> found;
	for (size_t index = 0; index < instances_.size(); index++) {
		found.push_back(standing(index, p_at));
	}
	return found;
}

int64_t NativeStill::size() const {
	return int64_t(instances_.size());
}

} // namespace godot
