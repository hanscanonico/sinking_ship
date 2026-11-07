// Her still art placed in C++ (#410): the instances of a dressed ship's art that never
// move under her (StillInstances) stand apart from her node (top level), and each frame
// one call sets every one's RenderingServer transform to where her piece stands now —
// the very transform the GDScript hands RenderingServer one instance at a time, so each
// is drawn to the bit where the other draws it.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/typed_array.hpp>

#include <vector>

namespace godot {

class NativeStill : public RefCounted {
	GDCLASS(NativeStill, RefCounted)

public:
	// The instances (RenderingServer RIDs) it places from now on, in place of any before.
	void hold(const TypedArray<RID> &p_instances);
	// Sets every instance held to stand at p_at.
	void place(const Transform3D &p_at) const;
	int64_t size() const;

protected:
	static void _bind_methods();

private:
	std::vector<RID> instances_;
};

} // namespace godot
