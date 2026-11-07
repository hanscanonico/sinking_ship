// Her still art placed in C++ (#410): the instances of a dressed ship's art that never
// move under her (StillInstances) stand apart from her node (top level), and each frame
// one call sets every one's RenderingServer transform to where her piece stands now —
// the very transform the GDScript hands RenderingServer one instance at a time, so each
// is drawn to the bit where the other draws it. A group of them hung each at its own
// transform under one node of her (StillGroup) is placed at that node's transform times
// each one's own, multiplied as Godot's Node3D multiplies a child's global transform.

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
	// The same, each placed at p_locals' own transform under where it is told to stand.
	void hold_each(const TypedArray<RID> &p_instances, const TypedArray<Transform3D> &p_locals);
	// Sets every instance held to stand at p_at — times its own, if held each.
	void place(const Transform3D &p_at) const;
	// Where place(p_at) stands each instance held, in order.
	TypedArray<Transform3D> placed(const Transform3D &p_at) const;
	int64_t size() const;

protected:
	static void _bind_methods();

private:
	// Where place(p_at) stands instance p_index.
	Transform3D standing(size_t p_index, const Transform3D &p_at) const;

	std::vector<RID> instances_;
	// Each instance's own transform; empty when every one stands at p_at itself.
	std::vector<Transform3D> locals_;
};

} // namespace godot
