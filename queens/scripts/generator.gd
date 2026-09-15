extends RefCounted
## Builds Queens puzzles with exactly one solution.
## 1. Place n queens: one per row and column, none touching (not even diagonally).
## 2. Grow one colored region around each queen until the grid is full.
## 3. While another solution exists, move a cell that solution relies on into a neighboring
##    region, which breaks it without touching the intended one. Start over if stuck.

var n := 8
var rng := RandomNumberGenerator.new()


## Returns {"regions": PackedInt32Array (region per cell), "solution": PackedInt32Array (queen column per row)}.
func generate(size: int, seed_value: int) -> Dictionary:
	n = size
	rng.seed = seed_value
	for attempt in 400:
		var solution := _place_queens()
		var regions := _grow_regions(solution)
		if _make_unique(regions, solution):
			return {"regions": regions, "solution": solution}
	return {}


func _place_queens() -> PackedInt32Array:
	var cols := PackedInt32Array()
	cols.resize(n)
	_place_row(cols, 0, 0)
	return cols


func _place_row(cols: PackedInt32Array, row: int, used: int) -> bool:
	if row == n:
		return true
	var order := range(n)
	_shuffle(order)
	for col: int in order:
		if used & (1 << col):
			continue
		if row > 0 and absi(cols[row - 1] - col) <= 1:
			continue
		cols[row] = col
		if _place_row(cols, row + 1, used | (1 << col)):
			return true
	return false


func _grow_regions(solution: PackedInt32Array) -> PackedInt32Array:
	var regions := PackedInt32Array()
	regions.resize(n * n)
	regions.fill(-1)
	# Uneven growth weights give a mix of big and small regions, like hand-made puzzles.
	var weights := PackedFloat32Array()
	for row in n:
		regions[row * n + solution[row]] = row
		weights.append(0.15 + pow(rng.randf(), 2.0))
	var left := n * n - n
	while left > 0:
		var region := _weighted_pick(weights)
		var options := PackedInt32Array()
		for cell in n * n:
			if regions[cell] != region:
				continue
			for other in _neighbors(cell):
				if regions[other] == -1:
					options.append(other)
		if options.is_empty():
			weights[region] = 0.0
			if _sum(weights) <= 0.0:
				# Every region is boxed in; hand leftover cells to any bordering region.
				for cell in n * n:
					if regions[cell] == -1:
						for other in _neighbors(cell):
							if regions[other] != -1:
								regions[cell] = regions[other]
								left -= 1
								break
				weights.fill(1.0)
			continue
		regions[options[rng.randi() % options.size()]] = region
		left -= 1
	return regions


func _make_unique(regions: PackedInt32Array, target: PackedInt32Array) -> bool:
	for step in 150:
		var solutions := solve(regions, 2)
		var other := PackedInt32Array()
		for s: PackedInt32Array in solutions:
			if s != target:
				other = s
				break
		if other.is_empty():
			return true
		# Cells where the unwanted solution has a queen but ours doesn't.
		var fixed := false
		var rows := range(n)
		_shuffle(rows)
		for row: int in rows:
			if other[row] == target[row]:
				continue
			var cell: int = row * n + other[row]
			var candidates := []
			for neighbor in _neighbors(cell):
				if regions[neighbor] != regions[cell] and not candidates.has(regions[neighbor]):
					candidates.append(regions[neighbor])
			_shuffle(candidates)
			for new_region: int in candidates:
				var old_region := regions[cell]
				regions[cell] = new_region
				if _connected(regions, old_region):
					fixed = true
					break
				regions[cell] = old_region
			if fixed:
				break
		if not fixed:
			return false
	return false


## All solutions for these regions (as queen column per row), stopping after `limit`.
## Places one queen per region, smallest regions first: they have the fewest options,
## so dead ends are found early.
func solve(regions: PackedInt32Array, limit: int) -> Array:
	var cells_by_region := []
	for r in n:
		cells_by_region.append(PackedInt32Array())
	for cell in n * n:
		cells_by_region[regions[cell]].append(cell)
	var order := range(n)
	order.sort_custom(func(a: int, b: int) -> bool: return cells_by_region[a].size() < cells_by_region[b].size())
	var cols := PackedInt32Array()
	cols.resize(n)
	cols.fill(-1)
	var found := []
	_solve_region(cells_by_region, order, 0, cols, 0, 0, found, limit)
	return found


func _solve_region(cells_by_region: Array, order: Array, index: int, cols: PackedInt32Array, used_rows: int, used_cols: int, found: Array, limit: int) -> void:
	if index == n:
		found.append(cols.duplicate())
		return
	var cells: PackedInt32Array = cells_by_region[order[index]]
	for cell in cells:
		var row := cell / n
		var col := cell % n
		if used_rows & (1 << row) or used_cols & (1 << col):
			continue
		# Queens in the rows just above and below must not touch this one.
		if row > 0 and cols[row - 1] >= 0 and absi(cols[row - 1] - col) <= 1:
			continue
		if row < n - 1 and cols[row + 1] >= 0 and absi(cols[row + 1] - col) <= 1:
			continue
		cols[row] = col
		_solve_region(cells_by_region, order, index + 1, cols, used_rows | (1 << row), used_cols | (1 << col), found, limit)
		cols[row] = -1
		if found.size() >= limit:
			return


func _connected(regions: PackedInt32Array, region: int) -> bool:
	var start := -1
	var total := 0
	for cell in n * n:
		if regions[cell] == region:
			total += 1
			if start < 0:
				start = cell
	if total == 0:
		return false
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var cell: int = stack.pop_back()
		for other in _neighbors(cell):
			if regions[other] == region and not seen.has(other):
				seen[other] = true
				stack.append(other)
	return seen.size() == total


func _neighbors(cell: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var row := cell / n
	var col := cell % n
	if row > 0:
		out.append(cell - n)
	if row < n - 1:
		out.append(cell + n)
	if col > 0:
		out.append(cell - 1)
	if col < n - 1:
		out.append(cell + 1)
	return out


func _weighted_pick(weights: PackedFloat32Array) -> int:
	var roll := rng.randf() * _sum(weights)
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0 and weights[i] > 0.0:
			return i
	for i in range(weights.size() - 1, -1, -1):
		if weights[i] > 0.0:
			return i
	return 0


func _sum(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
