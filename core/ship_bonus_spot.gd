class_name ShipBonusSpot
extends Resource
## A bonus spot of hers (D6, #307): a point on a floor in a room below her main deck —
## a room whose floor stands under zero — where a bonus can come aboard, one in each
## such room. Her layout puts it there; the seed says which spot and when. No rule reads
## it yet (#308).

## Where a bonus there lies, ship-local: a point on its room's floor.
@export var point: Vector3
## The room it lies in, by its index in [member ShipLayout.rooms]; -1 for none.
@export var room: int = -1
