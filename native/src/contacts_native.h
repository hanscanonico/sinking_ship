// The floating furniture's contacts in C++ (#410): where her solid props stand
// (core/prop_stands.gd, NativeStands), what holds a circle back in the deck plane
// (Surfaces.obstacle_contacts, rail_contacts and airborne_rail_contacts, NativeSurfaces),
// and the cargo's contact passes (Hazards._move, NativeCrates), each giving the GDScript's
// answers bit for bit. The GDScript keeps every state and hands each a mirror of it: her
// layout once, and what changes as it changes.

#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <vector>

namespace godot {

// A circle held back (Surfaces.Contact).
struct ContactHit {
	Vector2 normal;
	double depth = 0.0;
	int32_t railing = -1;
	int32_t prop = -1;
};

// SpatialIndex, as filled: its cells and bands and what each holds.
struct ContactGrid {
	Vector2 origin;
	double side = 1.0;
	int32_t size_x = 1;
	int32_t size_y = 1;
	double low = 0.0;
	double band = 1.0;
	int32_t bands = 1;
	double scan_over = 0.0;
	std::vector<int32_t> columns_from;
	std::vector<int32_t> columns;
	std::vector<int32_t> cells_from;
	std::vector<int32_t> cells;
	std::vector<int32_t> all;

	void take(const Array &p_layout);
	Vector2i cell_of(const Vector2 &p_point) const;
	int32_t band_of(double p_height) const;
	void near(const Vector2 &p_position, const Vector2 &p_end, double p_bottom, double p_top,
			std::vector<int32_t> &r_found) const;
};

class NativeStands : public RefCounted {
	GDCLASS(NativeStands, RefCounted)

public:
	void setup(const PackedFloat64Array &p_radii, const PackedFloat64Array &p_heights, const Vector2 &p_origin,
			int64_t p_columns, int64_t p_rows);
	void put(int64_t p_prop, const Vector3 &p_at);
	void take(int64_t p_prop);
	void clear();
	PackedInt32Array near(double p_x, double p_z, double p_reach, int64_t p_except) const;
	PackedVector3Array feet_of(const PackedInt32Array &p_props) const;
	PackedByteArray gone_of(const PackedInt32Array &p_props) const;

	void near_into(double p_x, double p_z, double p_reach, int32_t p_except, std::vector<int32_t> &r_found) const;
	const Vector3 &foot(int32_t p_prop) const { return feet_[p_prop]; }
	double radius(int32_t p_prop) const { return radii_[p_prop]; }
	double height(int32_t p_prop) const { return heights_[p_prop]; }

protected:
	static void _bind_methods();

private:
	std::vector<double> radii_;
	std::vector<double> heights_;
	std::vector<Vector3> feet_;
	std::vector<uint8_t> gone_;
	double widest_ = 0.0;
	Vector2 origin_;
	int32_t columns_ = 1;
	int32_t rows_ = 1;
	std::vector<std::vector<int32_t>> cells_;
	std::vector<int32_t> round_;
	std::vector<int32_t> cell_of_;

	int32_t cell(double p_x, double p_z) const;
	Vector2i cell_xz(double p_x, double p_z) const;
	void count_round(int32_t p_cell, int32_t p_by);
};

class NativeSurfaces : public RefCounted {
	GDCLASS(NativeSurfaces, RefCounted)

public:
	void setup(const PackedInt32Array &p_firsts, const PackedVector2Array &p_areas,
			const PackedFloat64Array &p_bottoms, const PackedFloat64Array &p_tops, const PackedByteArray &p_gone,
			const PackedByteArray &p_round, const PackedVector2Array &p_centres, const PackedFloat64Array &p_radii,
			const PackedByteArray &p_ramp_x, const PackedFloat64Array &p_ramp_heights, const Array &p_grid,
			const Ref<NativeStands> &p_stands);
	void railings(const PackedVector2Array &p_ends, const PackedVector2Array &p_normals,
			const PackedInt32Array &p_platforms, const PackedInt32Array &p_platform_rails_from,
			const PackedInt32Array &p_platform_rails, const PackedByteArray &p_gone, const Array &p_grid);
	void doors(const PackedInt32Array &p_axes, const PackedFloat64Array &p_planes, const PackedFloat64Array &p_jambs,
			const PackedFloat64Array &p_widths, const PackedFloat64Array &p_sills, const PackedFloat64Array &p_heads);
	void shut(const PackedFloat64Array &p_shut);
	void felled(const PackedVector3Array &p_bases, const PackedFloat64Array &p_sizes, const PackedVector2Array &p_along);
	void masked(const PackedByteArray &p_gone, const PackedByteArray &p_rail_gone);
	void topped(const PackedFloat64Array &p_tops);
	void lidded(const PackedByteArray &p_lids);

	PackedFloat64Array obstacle_contacts(const Vector3 &p_ship_point, double p_radius, double p_body_height,
			double p_step, int64_t p_except_prop, double p_crawl_height, double p_crawl_reach) const;
	PackedFloat64Array rail_contacts(const Vector3 &p_ship_point, double p_radius, int64_t p_surface) const;
	PackedFloat64Array airborne_rail_contacts(const Vector3 &p_ship_point, const Vector2 &p_came_from,
			double p_radius, double p_body_height, double p_railing_height) const;

	void obstacles(const Vector3 &p_ship_point, double p_radius, double p_body_height, double p_step,
			int32_t p_except_prop, double p_crawl_height, double p_crawl_reach, std::vector<ContactHit> &r_found) const;
	void rails(const Vector3 &p_ship_point, double p_radius, int32_t p_surface, std::vector<ContactHit> &r_found) const;
	void airborne_rails(const Vector3 &p_ship_point, const Vector2 &p_came_from, double p_radius,
			double p_body_height, double p_railing_height, std::vector<ContactHit> &r_found) const;
	int64_t landing(const Vector3 &p_ship_point, int64_t p_except_prop) const;
	double ceiling(const Vector3 &p_ship_point, double p_clearance) const;
	NativeStands *stands() const { return stands_.ptr(); }

	// Surfaces.under and BotFloorWay._find (floor_way_native.cpp).
	void floors(const PackedInt32Array &p_from, const PackedInt32Array &p_floors,
			const PackedFloat64Array &p_clearances);
	int64_t under(const Vector3 &p_ship_point, double p_step, int64_t p_except_prop) const;
	PackedVector3Array floor_way(const Vector3 &p_from, const Vector3 &p_end, const PackedInt32Array &p_keep,
			const PackedFloat64Array &p_rules) const;
	// WalkPieces._read's squares (floor_way_native.cpp).
	PackedByteArray stands_grid(const Vector2 &p_origin, int64_t p_width, int64_t p_depth, double p_side,
			double p_height, const Rect2 &p_within, const PackedFloat64Array &p_rules) const;

protected:
	static void _bind_methods();

private:
	int32_t first_ramp_ = 0;
	int32_t first_top_ = 0;
	int32_t first_lid_ = 0;
	std::vector<Vector2> area_position_;
	std::vector<Vector2> area_size_;
	std::vector<double> bottoms_;
	std::vector<double> tops_;
	std::vector<uint8_t> gone_;
	// Per blocker: 1 for a round one, its centre and radius.
	std::vector<uint8_t> round_;
	std::vector<Vector2> centres_;
	std::vector<double> radii_;
	// Per ramp: 1 along x, its start and end heights.
	std::vector<uint8_t> ramp_x_;
	std::vector<double> ramp_start_;
	std::vector<double> ramp_end_;
	ContactGrid grid_;
	Ref<NativeStands> stands_;
	// Per prop, 1 where its top is a lid a body may stand on (PropStands.lids).
	std::vector<uint8_t> lids_;
	// Per railing: its ends, its normal onto its platform, its platform and whether it is
	// gone; per platform its railings.
	std::vector<Vector2> rail_from_;
	std::vector<Vector2> rail_to_;
	std::vector<Vector2> rail_normals_;
	std::vector<int32_t> rail_platforms_;
	std::vector<int32_t> platform_rails_from_;
	std::vector<int32_t> platform_rails_;
	std::vector<uint8_t> rail_gone_;
	ContactGrid rail_grid_;
	// DoorLeaves: per door its axis, plane, jamb, width, sill, head and how far shut.
	std::vector<int32_t> door_axes_;
	std::vector<double> door_planes_;
	std::vector<double> door_jambs_;
	std::vector<double> door_widths_;
	std::vector<double> door_sills_;
	std::vector<double> door_heads_;
	std::vector<double> door_shut_;
	// FallenFunnels: per fall down its funnel's foot, radius and height, and its way.
	std::vector<Vector3> fall_bases_;
	std::vector<double> fall_radii_;
	std::vector<double> fall_heights_;
	std::vector<Vector2> fall_along_;
	// Surfaces' floors: per cell of grid_ its platforms, and for each the nearest the height
	// of any other surface of the cell comes to it (FloorClearances).
	std::vector<int32_t> floors_from_;
	std::vector<int32_t> floors_;
	std::vector<double> clearances_;

	int32_t under_at(const Vector3 &p_ship_point, double p_step, int32_t p_except_prop) const;
	double height_on(int32_t p_surface, double p_x, double p_z) const;
	bool stands_at(const Vector3 &p_point, int32_t p_surface, const std::vector<int32_t> &p_keep, double p_radius,
			double p_step, double p_body_height, double p_crawl_height) const;
	double height_at(int32_t p_surface, double p_x, double p_z) const;
	double ramp_height(int32_t p_surface, double p_x, double p_z) const;
	bool contains(int32_t p_surface, double p_x, double p_z) const;
	bool holds(int32_t p_surface, double p_x, double p_z) const;
	int32_t highest_ship(const Vector3 &p_ship_point) const;
	int32_t stair_under(const Vector2 &p_point, double p_feet, double p_step) const;
	double along(int32_t p_stair, const Vector2 &p_at, double p_feet) const;
	bool crawls_under(int32_t p_surface, const Vector2 &p_point, double p_reach, double p_feet, double p_step,
			double p_crawl_height, int32_t p_stair) const;
	bool climb_contact(int32_t p_surface, const Vector2 &p_point, double p_radius, double p_reach,
			ContactHit &r_hit) const;
	bool rail_contact(int32_t p_index, const Vector2 &p_point, double p_radius, ContactHit &r_hit) const;
};

class NativeCrates : public RefCounted {
	GDCLASS(NativeCrates, RefCounted)

public:
	void setup(const Ref<NativeSurfaces> &p_surfaces, const Ref<NativeStands> &p_at_rest,
			const PackedFloat64Array &p_radii, const PackedFloat64Array &p_heights,
			const PackedFloat64Array &p_masses, const PackedByteArray &p_solid, const PackedByteArray &p_harmless,
			const PackedFloat64Array &p_rules);
	PackedInt32Array move(const Array &p_props, const PackedInt32Array &p_crates, int64_t p_steps, double p_dt,
			int64_t p_tick, const PackedByteArray &p_turn, const PackedFloat64Array &p_feet_before,
			const PackedVector2Array &p_came_from, const Callable &p_damage);
	PackedInt32Array moving() const;
	PackedInt32Array woken() const;
	PackedFloat64Array feet_before() const;
	PackedVector2Array came_from() const;

protected:
	static void _bind_methods();

private:
	Ref<NativeSurfaces> surfaces_;
	Ref<NativeStands> at_rest_;
	std::vector<double> radii_;
	std::vector<double> heights_;
	std::vector<double> masses_;
	std::vector<uint8_t> solid_;
	std::vector<uint8_t> harmless_;
	double step_height_ = 0.0;
	double railing_height_ = 0.0;
	double railing_break_speed_ = 0.0;
	double crate_impact_speed_ = 0.0;
	double crate_restitution_ = 0.0;
	int64_t credit_window_ticks_ = 0;
	int64_t contact_passes_ = 0;

	// The call under way: per prop its state as it goes, whether it was read from its
	// PropState, how the tick takes it, where its underside stood and its middle.
	struct Crate {
		Vector3 pos;
		Vector3 vel;
		int32_t body = 0;
		int32_t surface = -1;
		int64_t shoved_by = -1;
		int64_t shoved_at = -1;
	};
	std::vector<Crate> state_;
	std::vector<uint8_t> read_;
	std::vector<uint8_t> turn_;
	std::vector<double> feet_before_;
	std::vector<Vector2> came_from_;
	std::vector<int32_t> crates_;
	std::vector<int32_t> woken_;
	const Array *props_ = nullptr;
	int64_t tick_ = 0;

	Crate &crate(int32_t p_prop);
	void write_back() const;
	void stand_one(int32_t p_prop);
	void stir_near(int32_t p_prop);
	void wake(int32_t p_other);
	int32_t after(int32_t p_at, int32_t p_prop) const;
	bool blockers(int32_t p_prop);
	bool railings(int32_t p_prop, const Callable &p_damage);
	void hold(Crate &r_crate, const ContactHit &p_contact) const;
	void knock(int32_t p_prop, int32_t p_other, const ContactHit &p_contact);
};

} // namespace godot
