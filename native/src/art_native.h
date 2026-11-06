// The dressed ship's face emission in C++ (#411): ShipMesh's faces, quads and boxes
// cut at the chunk and room lines (face, splits, needed), each piece judged indoors or
// out and gathered by paint and chunk (_batch_for, _emit), with the fading pieces'
// boxes (_seal); and IndoorGrid's reads of her rooms that judge them (outdoors,
// outdoors_over, ceiling). Each gives the GDScript's answers bit for bit: the same
// arrays, in the same order. What is GDScript's own — a room's ceiling worked out
// (ShipSpace._ceiling_at), what fades — the extension calls back for.

#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <map>
#include <unordered_map>
#include <vector>

namespace godot {

// IndoorGrid's grid of her rooms, handed over once it is built, and its ceilings by cell.
class NativeIndoorGrid : public RefCounted {
	GDCLASS(NativeIndoorGrid, RefCounted)

public:
	void setup(const Vector2 &p_origin, const Vector2i &p_size, double p_low, int64_t p_bands,
			const PackedFloat64Array &p_bounds, const PackedInt32Array &p_cells_from,
			const PackedInt32Array &p_cells, const Callable &p_ceiling_at, const Callable &p_edges_of);
	bool outdoors(const Vector3 &p_point, const Array &p_boxes);
	Array outdoors_over(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
			const PackedFloat32Array &p_u_cuts, const PackedFloat32Array &p_v_cuts, const Vector3 &p_normal,
			double p_probe, const Array &p_boxes);
	double ceiling(int64_t p_index, double p_x, double p_z);
	void set_columns(const PackedInt32Array &p_columns_from, const PackedInt32Array &p_columns);

	// The same, for NativeShipMesh and NativeLining.
	const int32_t *rooms_over(double p_x, double p_z, int64_t &r_count) const;
	bool outdoors_of(const Vector3 &p_point, const std::vector<AABB> &p_boxes);
	bool outdoors_over_of(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
			const std::vector<float> &p_u_cuts, const std::vector<float> &p_v_cuts, const Vector3 &p_normal,
			double p_probe, const std::vector<AABB> &p_boxes, std::vector<uint8_t> &r_shows);

protected:
	static void _bind_methods();

private:
	// IndoorGrid.FaceProbes.
	struct Probes {
		std::vector<double> values[3];
		int by[3] = { 2, 2, 2 };
		int64_t rows = 0;
		std::vector<double> rising[3];
		double signs[3] = { 1.0, 1.0, 1.0 };
		bool order();
		Vector3 low() const;
		Vector3 high() const;
		Vector2i span(int p_axis, double p_low, double p_high) const;
		int axis_of(int p_source) const;
	};
	struct Ceilings {
		bool gathered = false;
		std::vector<double> xs;
		std::vector<double> zs;
		std::unordered_map<int64_t, double> cells;
	};

	Ceilings &_ceiling_cells(int64_t p_index);
	double _cell_ceiling(int64_t p_index, Ceilings &p_cells, int64_t p_cell, double p_x, double p_z);
	double _ceiling_at(int64_t p_index, double p_x, double p_z);
	int64_t _square(double p_x, double p_z) const;
	Vector2i _square_of(double p_x, double p_z) const;
	int64_t _band(double p_y) const;
	const int32_t *_near(int64_t p_cell, int64_t &r_count) const;
	void _rooms_reaching(const Vector3 &p_low, const Vector3 &p_high, std::vector<int32_t> &r_found);
	void _mark_box(const AABB &p_box, const Probes &p_face, std::vector<uint8_t> &r_marked) const;
	void _mark_room(int64_t p_index, const Probes &p_face, std::vector<uint8_t> &r_marked);
	void _mark_level(int64_t p_index, const Probes &p_face, const int32_t p_spans[4],
			const std::vector<int32_t> &p_columns, const std::vector<int32_t> &p_rows,
			std::vector<uint8_t> &r_marked);

	Vector2 _origin;
	Vector2i _size = Vector2i(1, 1);
	double _low = 0.0;
	int64_t _bands = 1;
	int64_t _squares = 1;
	std::vector<double> _bounds;
	std::vector<int32_t> _cells_from;
	std::vector<int32_t> _cells;
	std::vector<int32_t> _columns_from;
	std::vector<int32_t> _columns;
	Callable _ceiling_at_call;
	Callable _edges_of;
	std::vector<Ceilings> _ceilings;
	// _rooms_reaching's seen rooms: the call each was last seen in.
	std::vector<uint32_t> _seen;
	uint32_t _seen_mark = 0;
};

// RoomDressing's linings as LinedFaces reads them: each room's lining paints by part, its
// lined box, its area and floor, over a NativeIndoorGrid; the paints by number, 0 none.
class NativeLining : public RefCounted {
	GDCLASS(NativeLining, RefCounted)

public:
	struct Paint {
		int64_t finish = 0;
		Color colour;
		int64_t finish_in = 0;
		Color colour_in;
	};

	void setup(const Ref<NativeIndoorGrid> &p_grid, const PackedByteArray &p_lined, const Array &p_boxes,
			const Array &p_areas, const PackedFloat64Array &p_floors, const PackedInt32Array &p_parts,
			const Array &p_paints);

	bool lined_near(const AABB &p_box) const;
	void lining_lines(const AABB &p_box, std::vector<float> r_lines[3]) const;
	int32_t lining(const Vector3 &p_point, int64_t p_part) const;
	const Paint &paint(int32_t p_id) const;

protected:
	static void _bind_methods();

private:
	Ref<NativeIndoorGrid> _grid;
	std::vector<uint8_t> _lined;
	std::vector<AABB> _boxes;
	std::vector<Rect2> _areas;
	std::vector<double> _floors;
	std::vector<int32_t> _parts;
	std::vector<Paint> _paints;
	std::vector<int32_t> _lined_rooms;
};

// One ShipMesh's batches, and the faces, quads and boxes it draws into them.
class NativeShipMesh : public RefCounted {
	GDCLASS(NativeShipMesh, RefCounted)

public:
	void setup(const Array &p_cuts, const Callable &p_outdoors);
	void set_cut_above(double p_cut_above);
	void set_keep(const Vector2 &p_keep);
	void set_fading(const Callable &p_fading);
	void set_outdoors_over(const Callable &p_outdoors_over);
	void set_grid(const Ref<NativeIndoorGrid> &p_grid, const Array &p_boxes);
	void set_roofed(double p_weather_floor, const PackedFloat64Array &p_sections, const Array &p_outlines,
			const Array &p_areas, const PackedFloat64Array &p_heights);

	void box(const Rect2 &p_area, double p_bottom, double p_top, int64_t p_finish, const Color &p_colour,
			int64_t p_finish_in, const Color &p_colour_in, int64_t p_faces, double p_foot, double p_head);
	void face(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v, int64_t p_finish,
			const Color &p_colour, int64_t p_finish_in, const Color &p_colour_in, int64_t p_rims, double p_foot,
			double p_head);
	void quad(const Vector3 &p_a, const Vector3 &p_b, const Vector3 &p_c, const Vector3 &p_d,
			const Vector3 &p_normal, int64_t p_finish, const Color &p_colour, int64_t p_finish_in,
			const Color &p_colour_in, int64_t p_rims, double p_foot, double p_head);
	void turned_box(const Transform3D &p_place, const Vector3 &p_size, int64_t p_finish, const Color &p_colour,
			int64_t p_finish_in, const Color &p_colour_in, int64_t p_rims);
	void model_surface(const Transform3D &p_place, const Basis &p_turn, bool p_mirrored,
			const PackedVector3Array &p_points, const PackedVector3Array &p_normals, const PackedInt32Array &p_order,
			const PackedColorArray &p_inks, int64_t p_finish, const Color &p_colour, int64_t p_finish_in,
			const Color &p_colour_in, double p_foot, double p_head);
	void lined_face(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v, int64_t p_finish,
			const Color &p_colour, int64_t p_finish_in, const Color &p_colour_in, int64_t p_part, double p_foot,
			double p_head, const Ref<NativeLining> &p_lining);
	int64_t batch_for(const Vector3 &p_middle, const Vector3 &p_normal, int64_t p_finish, int64_t p_finish_in);
	bool last_outdoors() const;
	void emit(int64_t p_batch, const PackedInt32Array &p_order, const PackedVector3Array &p_points,
			const PackedVector3Array &p_normals, const Color &p_colour, const PackedVector2Array &p_uvs,
			const PackedVector2Array &p_uv2s);
	void open();
	void close();
	Array batches() const;
	void clear();

	PackedFloat32Array splits(const Vector3 &p_origin, const Vector3 &p_edge, const Array &p_lines) const;
	Array needed(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
			const PackedFloat32Array &p_u_cuts, const PackedFloat32Array &p_v_cuts, const Array &p_shows) const;

protected:
	static void _bind_methods();

private:
	struct Paint {
		int64_t finish;
		Color colour;
		int64_t finish_in;
		Color colour_in;
	};
	struct Batch {
		String key;
		int64_t finish = 0;
		std::vector<int32_t> indices;
		std::vector<Vector3> vertices;
		std::vector<Vector3> normals;
		std::vector<Color> colours;
		std::vector<Vector2> uvs;
		std::vector<Vector2> uv2s;
		std::vector<float> pieces;
		std::vector<float> halves;
	};
	struct Place {
		int64_t finish;
		int32_t x;
		int32_t y;
		int32_t z;
		bool operator<(const Place &p_other) const;
	};

	void _face(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v, const Paint &p_paint,
			int64_t p_rims, double p_foot, double p_head);
	void _quad(const Vector3 &p_a, const Vector3 &p_b, const Vector3 &p_c, const Vector3 &p_d,
			const Vector3 &p_normal, const Paint &p_paint, int64_t p_rims, double p_foot, double p_head);
	bool _kept(double p_aft, double p_fore) const;
	bool _outdoors(const Vector3 &p_point);
	int64_t _batch_for(const Vector3 &p_middle, const Vector3 &p_normal, int64_t p_finish, int64_t p_finish_in);
	void _emit(int64_t p_batch, const int32_t *p_order, int64_t p_order_count, const Vector3 *p_points,
			const Vector3 *p_normals, int64_t p_count, const Color &p_colour, const Vector2 *p_uvs,
			const Vector2 *p_uv2s);
	void _seal();

	static void _splits(const Vector3 &p_origin, const Vector3 &p_edge, const std::vector<float> *p_lines,
			std::vector<float> &r_kept);
	static void _needed(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
			const std::vector<float> &p_u_cuts, const std::vector<float> &p_v_cuts, const uint8_t *p_shows,
			std::vector<float> &r_u, std::vector<float> &r_v);
	template <typename Differs>
	static void _needed_by(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
			const std::vector<float> &p_u_cuts, const std::vector<float> &p_v_cuts, Differs p_differs,
			std::vector<float> &r_u, std::vector<float> &r_v);

	std::vector<float> _cuts[3];
	double _cut_above = INFINITY;
	Vector2 _keep = Vector2(-INFINITY, INFINITY);
	Callable _outdoors_call;
	Callable _outdoors_over;
	Callable _fading;
	Ref<NativeIndoorGrid> _grid;
	std::vector<AABB> _boxes;
	// RoofedIndoors: her lowest weather deck, her sections (x and length) and their
	// outlines, her platforms (area and height) and, per square of the plane, those
	// reaching into it; whether any is set.
	bool _roofed = false;
	double _weather_floor = -INFINITY;
	std::vector<double> _section_x;
	std::vector<double> _section_length;
	std::vector<std::vector<Vector2>> _outlines;
	std::vector<Rect2> _platform_areas;
	std::vector<double> _platform_heights;
	std::map<std::pair<int64_t, int64_t>, std::vector<int32_t>> _platform_squares;
	bool _holds(const Vector3 &p_point) const;
	double _reach(size_t p_section, double p_y, int64_t p_side) const;
	double _half_breadth(double p_x, double p_y, int64_t p_side) const;
	std::vector<Batch> _batches;
	std::map<Place, int64_t> _placed;
	bool _last_outdoors = true;
	int64_t _depth = 0;
	AABB _piece;
	std::vector<int64_t> _reached;
};

} // namespace godot
