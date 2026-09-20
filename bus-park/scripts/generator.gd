extends RefCounted
## Builds a solvable "car jam" puzzle: a grid of parked vehicles, one of them the bus, which
## must slide out through a gap in the boundary.
##
## Guaranteeing a solution without a solver: start from the SOLVED board (bus already at the
## gap, ready to leave) and apply random *legal* moves to scramble it. Every slide is trivially
## reversible (the vacated cell is always free to slide back into), so undoing the exact
## scramble moves in reverse always reaches the solved board again - the puzzle is solvable by
## construction, however scrambled it looks.

const SIZES := [6, 7, 8]
const VEHICLE_TARGET := [7, 10, 14]  # blocking vehicles to try to place
const SCRAMBLE_MOVES := [30, 55, 90]
const BUS_LENGTH := 3

const CAR_COLORS := [
	Color("e74c3c"), Color("3498db"), Color("2ecc71"), Color("9b59b6"),
	Color("e67e22"), Color("1abc9c"), Color("34495e"), Color("e84393"),
]
const BUS_COLOR := Color("f6c945")


## Returns {"size": int, "exit_side": int, "vehicles": Array}. Each vehicle is
## {"row", "col", "len", "horizontal", "color", "is_bus"}; (row, col) is its front-most cell
## (leftmost if horizontal, topmost if vertical). exit_side: 0 right, 1 left, 2 bottom, 3 top.
static func generate(difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var size: int = SIZES[difficulty]
	var exit_side := rng.randi() % 4
	var horizontal := exit_side == 0 or exit_side == 1
	var lane := rng.randi_range(0, size - 1)

	var grid := []
	for r in size:
		var row := []
		row.resize(size)
		row.fill(-1)
		grid.append(row)
	var vehicles := []

	# 1) The bus, already parked at the gap - the solved position.
	var bus := {"len": BUS_LENGTH, "horizontal": horizontal, "color": BUS_COLOR, "is_bus": true}
	if horizontal:
		bus.row = lane
		bus.col = (size - BUS_LENGTH) if exit_side == 0 else 0
	else:
		bus.col = lane
		bus.row = (size - BUS_LENGTH) if exit_side == 2 else 0
	_place(grid, vehicles, bus)

	# 2) Fill the rest of the board with parked cars and vans around it.
	var target: int = VEHICLE_TARGET[difficulty]
	var tries := 0
	var color_i := 0
	while vehicles.size() - 1 < target and tries < target * 25:
		tries += 1
		var vlen := 3 if rng.randf() < 0.3 else 2
		var vhoriz := rng.randf() < 0.5
		var vrow := rng.randi_range(0, size - (1 if vhoriz else vlen))
		var vcol := rng.randi_range(0, size - (vlen if vhoriz else 1))
		var car := {
			"row": vrow, "col": vcol, "len": vlen, "horizontal": vhoriz,
			"color": CAR_COLORS[color_i % CAR_COLORS.size()], "is_bus": false,
		}
		if _fits(grid, size, car):
			_place(grid, vehicles, car)
			color_i += 1

	# 3) Scramble with random legal moves - every one reversible, so the result always has a way
	# back to the solved board above, however tangled it looks. `scramble` (the exact moves
	# applied) is returned only so tests can prove that reversing it always re-solves the
	# puzzle; the game itself never looks at it.
	var moves: int = SCRAMBLE_MOVES[difficulty]
	var attempts := 0
	var scramble := []
	while attempts < moves * 6 and moves > 0:
		attempts += 1
		var idx := rng.randi_range(0, vehicles.size() - 1)
		var step := 1 if rng.randf() < 0.5 else -1
		if slide(grid, size, vehicles, idx, step, false):
			moves -= 1
			scramble.append({"idx": idx, "step": step})

	return {"size": size, "exit_side": exit_side, "vehicles": vehicles, "scramble": scramble}


static func build_grid(vehicles: Array, size: int) -> Array:
	var grid := []
	for r in size:
		var row := []
		row.resize(size)
		row.fill(-1)
		grid.append(row)
	for i in vehicles.size():
		for c in cells(vehicles[i]):
			if c.x >= 0 and c.x < size and c.y >= 0 and c.y < size:
				grid[c.y][c.x] = i
	return grid


static func cells(v: Dictionary) -> Array:
	var out := []
	for i in v.len:
		out.append(Vector2i(v.col + (i if v.horizontal else 0), v.row + (0 if v.horizontal else i)))
	return out


static func _fits(grid: Array, size: int, v: Dictionary) -> bool:
	for c in cells(v):
		if c.x < 0 or c.x >= size or c.y < 0 or c.y >= size or grid[c.y][c.x] != -1:
			return false
	return true


static func _place(grid: Array, vehicles: Array, v: Dictionary) -> int:
	var idx := vehicles.size()
	vehicles.append(v)
	for c in cells(v):
		grid[c.y][c.x] = idx
	return idx


## Moves vehicle `idx` one cell along its own axis, if that cell is empty and (unless
## `allow_exit`) still inside the grid. Used both to scramble (allow_exit false) and to play
## (allow_exit true, so the bus can slide past the boundary and out).
static func slide(grid: Array, size: int, vehicles: Array, idx: int, step: int, allow_exit: bool) -> bool:
	var v: Dictionary = vehicles[idx]
	var d := Vector2i(step, 0) if v.horizontal else Vector2i(0, step)
	var old_cells := cells(v)
	var front: Vector2i = old_cells[0] if step < 0 else old_cells[old_cells.size() - 1]
	var target: Vector2i = front + d
	var inside := target.x >= 0 and target.x < size and target.y >= 0 and target.y < size
	if not inside:
		if not (allow_exit and v.is_bus):
			return false
	elif grid[target.y][target.x] != -1:
		return false

	for c in old_cells:
		if c.x >= 0 and c.x < size and c.y >= 0 and c.y < size:
			grid[c.y][c.x] = -1
	v.row += d.y
	v.col += d.x
	for c in cells(v):
		if c.x >= 0 and c.x < size and c.y >= 0 and c.y < size:
			grid[c.y][c.x] = idx
	return true
