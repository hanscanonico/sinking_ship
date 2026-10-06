class_name CellSurface
extends RefCounted
## A cell's water drawn level with the world however she leans (§5b.1, InnerWater): a
## sheet turned back against her rotation through the point over the cell's middle where
## its water stands, stretched each time it is placed just far enough to cover the box
## at that lean — its shader clips it to the box (inner_water.gdshader), so it piles into
## the box's low corner. Presentation only: it reads where the view has put the ship and
## the level the pose gives.


## A flat unit sheet, fitted to its box as it is placed; its wobble is the shader's.
static func sheet() -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	return plane


## Where, in ship space, the sheet over [param box] stands with its water at world height
## [param level] on a ship drawn at [param drawn], [param level_basis] the basis that
## lays a sheet in her level with the world: over the box's middle, as wide and as deep
## as the box reaches along the sheet's own two ways.
static func placed(drawn: Transform3D, level_basis: Basis, box: AABB, level: float) -> Transform3D:
	var middle := box.get_center()
	var half := box.size * 0.5
	var across := level_basis.x
	var along := level_basis.z
	var wide := absf(across.x) * half.x + absf(across.y) * half.y + absf(across.z) * half.z
	var deep := absf(along.x) * half.x + absf(along.y) * half.y + absf(along.z) * half.z
	var up := level_basis.y
	return Transform3D(
		Basis(across * 2.0 * wide, up, along * 2.0 * deep),
		middle + up * (level - (drawn * middle).y)
	)


## The world heights [param box]'s lowest and highest corners stand at on a ship drawn at
## [param drawn]: its middle's, less and plus how far its half extents reach up.
static func reach(drawn: Transform3D, box: AABB) -> Vector2:
	var basis := drawn.basis
	var half := box.size * 0.5
	var middle := (drawn * box.get_center()).y
	var spread := absf(basis.x.y) * half.x + absf(basis.y.y) * half.y + absf(basis.z.y) * half.z
	return Vector2(middle - spread, middle + spread)
