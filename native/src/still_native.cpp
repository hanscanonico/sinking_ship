// See still_native.h.

#include "still_native.h"

#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

void NativeStill::_bind_methods() {
	ClassDB::bind_method(D_METHOD("hold", "instances"), &NativeStill::hold);
	ClassDB::bind_method(D_METHOD("place", "at"), &NativeStill::place);
	ClassDB::bind_method(D_METHOD("size"), &NativeStill::size);
}

void NativeStill::hold(const TypedArray<RID> &p_instances) {
	instances_.clear();
	instances_.reserve(p_instances.size());
	for (int64_t index = 0; index < p_instances.size(); index++) {
		instances_.push_back(p_instances[index]);
	}
}

void NativeStill::place(const Transform3D &p_at) const {
	RenderingServer *server = RenderingServer::get_singleton();
	for (const RID &instance : instances_) {
		server->instance_set_transform(instance, p_at);
	}
}

int64_t NativeStill::size() const {
	return int64_t(instances_.size());
}

} // namespace godot
