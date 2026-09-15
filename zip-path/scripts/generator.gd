extends RefCounted
## Builds Zip puzzles with exactly one solution.
## 1. Build a random Hamiltonian path across the grid (a route that visits every cell once),
##    using a randomized, dead-end-avoiding search.
## 2. Pick evenly spaced cells along it as the numbered checkpoints, first and last included.
## 3. While another route also satisfies the checkpoints, wall off one of the edges it uses
##    that our route doesn't. Start over if a route can't be walled off without touching ours.

var n := 6
var rng := RandomNumberGenerator.new()
var _calls := 0
var _budget := 0
var _adj: Array[PackedInt32Array] = []  # every cell's grid neighbors, ignoring walls
var _free_adj: Array[PackedInt32Array] = []  # a solve() call's neighbors, with walled edges removed


## Returns {"path": PackedInt32Array (the solution route, cell per step),
## "numbers": PackedInt32Array (cell for each checkpoint, in order), "walls": Dictionary edge->true}.
func generate(size: int, numbers_count: int, max_walls: int, seed_value: int) -> Dictionary:
	n = size
	rng.seed = seed_value
	_build_adjacency()
	for attempt in 60:
		var path := _random_hamiltonian_path()
		if path.is_empty():
			continue
		var numbers := _pick_numbers(path, numbers_count)
		var walls := {}
		if _make_unique(path, numbers, walls, max_walls):
			return {"path": path, "numbers": numbers, "walls": walls}
	return {}


func _build_adjacency() -> void:
	_adj.resize(n * n)
	for cell in n * n:
		_adj[cell] = _neighbors(cell)


# --- Building a random route ----------------------------------------------------------------

## A Hamiltonian path from a random start: always steps into whichever unvisited neighbor has
## the fewest onward options (so corners and near-dead-ends get used up early), picking randomly
## among ties. Falls back to backtracking if that greedy choice ever runs out of cells.
func _random_hamiltonian_path() -> PackedInt32Array:
	var total := n * n
	var visited := {}
	var path := PackedInt32Array()
	var start := rng.randi() % total
	visited[start] = true
	path.append(start)
	_calls = 0
	_budget = 40000
	if _extend_path(visited, path, total):
		return path
	return PackedInt32Array()


func _extend_path(visited: Dictionary, path: PackedInt32Array, total: int) -> bool:
	_calls += 1
	if _calls > _budget:
		return false
	if path.size() == total:
		return true
	var current: int = path[path.size() - 1]
	var options := []
	for next in _adj[current]:
		if not visited.has(next):
			options.append(next)
	_shuffle(options)
	options.sort_custom(func(a: int, b: int) -> bool: return _free_degree(visited, a) < _free_degree(visited, b))
	for next in options:
		visited[next] = true
		path.append(next)
		if _extend_path(visited, path, total):
			return true
		path.remove_at(path.size() - 1)
		visited.erase(next)
	return false


func _free_degree(visited: Dictionary, cell: int) -> int:
	var count := 0
	for other in _adj[cell]:
		if not visited.has(other):
			count += 1
	return count


## Spreads `count` checkpoints across the route: index 0 and the last index always included,
## the rest picked at a random offset inside their share of the remaining stretch.
func _pick_numbers(path: PackedInt32Array, count: int) -> PackedInt32Array:
	var total := path.size()
	count = clampi(count, 2, total)
	var indices := PackedInt32Array([0])
	if count > 2:
		var span := total - 2  # interior indices run 1 .. total - 2
		var bands := count - 1
		var prev := 0
		for b in range(bands - 1):
			var lo := 1 + int(floor(float(b) * span / bands))
			var hi := 1 + int(floor(float(b + 1) * span / bands)) - 1
			lo = maxi(lo, prev + 1)
			hi = maxi(hi, lo)
			var pick := lo + rng.randi() % (hi - lo + 1)
			indices.append(pick)
			prev = pick
	indices.append(total - 1)
	var numbers := PackedInt32Array()
	for idx in indices:
		numbers.append(path[idx])
	return numbers


# --- Uniqueness ---------------------------------------------------------------------------

func _make_unique(target: PackedInt32Array, numbers: PackedInt32Array, walls: Dictionary, max_walls: int) -> bool:
	var target_edges := {}
	for i in range(target.size() - 1):
		target_edges[_edge_key(target[i], target[i + 1])] = true
	for step in 200:
		var result := solve(numbers, walls, 2, 30000)
		var solutions: Array = result.solutions
		if solutions.size() <= 1:
			return not result.gave_up  # a lone solution only counts if the search actually finished
		var other: PackedInt32Array = solutions[1] if solutions[0] == target else solutions[0]
		var candidates := []
		for i in range(other.size() - 1):
			var key := _edge_key(other[i], other[i + 1])
			if not target_edges.has(key) and not walls.has(key):
				candidates.append(key)
		if candidates.is_empty() or walls.size() >= max_walls:
			return false
		walls[candidates[rng.randi() % candidates.size()]] = true
	return false


## All Hamiltonian routes that start at numbers[0], end at numbers[-1], cross no wall and hit
## every checkpoint in order, stopping after `limit`. `gave_up` is true if the `budget` search
## steps ran out before the search could exhaust itself, so the result can't be trusted as final.
func solve(numbers: PackedInt32Array, walls: Dictionary, limit: int, budget: int) -> Dictionary:
	if _adj.is_empty():
		_build_adjacency()
	var total := n * n
	_free_adj.resize(total)
	for cell in total:
		var open := PackedInt32Array()
		for other in _adj[cell]:
			if not walls.has(_edge_key(cell, other)):
				open.append(other)
		_free_adj[cell] = open
	var cell_index := {}
	for i in numbers.size():
		cell_index[numbers[i]] = i
	var visited := PackedByteArray()
	visited.resize(total)
	var start: int = numbers[0]
	visited[start] = 1
	var found := []
	_calls = 0
	_budget = budget
	var path := PackedInt32Array([start])
	var gave_up := _solve_step(visited, start, 1, path, numbers, cell_index, total, found, limit)
	return {"solutions": found, "gave_up": gave_up and found.size() < limit}


## Returns true if the search gave up on the remaining budget rather than exhausting itself.
func _solve_step(visited: PackedByteArray, current: int, next_needed: int, path: PackedInt32Array,
		numbers: PackedInt32Array, cell_index: Dictionary, total: int, found: Array, limit: int) -> bool:
	_calls += 1
	if _calls > _budget:
		return true
	if path.size() == total:
		if current == numbers[numbers.size() - 1]:
			found.append(path.duplicate())
		return false
	for next in _free_adj[current]:
		if visited[next]:
			continue
		var index: int = cell_index.get(next, -1)
		if index != -1:
			if index != next_needed:
				continue
			# The final checkpoint may only be entered as the very last cell of the route.
			if index == numbers.size() - 1 and path.size() + 1 != total:
				continue
		visited[next] = 1
		path.append(next)
		if not _is_dead(visited, next, total, numbers[numbers.size() - 1]):
			if _solve_step(visited, next, next_needed + (1 if index != -1 else 0), path, numbers, cell_index, total, found, limit):
				visited[next] = 0
				path.remove_at(path.size() - 1)
				return true
		visited[next] = 0
		path.remove_at(path.size() - 1)
		if found.size() >= limit:
			return false
	return false


## True if some unvisited cell can no longer possibly be reached, or can be reached but not
## also left again (every cell but `end_cell` needs both an entry and an exit).
func _is_dead(visited: PackedByteArray, current: int, total: int, end_cell: int) -> bool:
	var unvisited_total := 0
	for cell in total:
		if not visited[cell]:
			unvisited_total += 1
	if unvisited_total == 0:
		return false
	var seen := {current: true}
	var stack := [current]
	var reached := 0
	while not stack.is_empty():
		var cell: int = stack.pop_back()
		for other in _free_adj[cell]:
			if visited[other] or seen.has(other):
				continue
			seen[other] = true
			reached += 1
			stack.append(other)
	if reached != unvisited_total:
		return true
	for cell in total:
		if visited[cell]:
			continue
		var avail := 0
		for other in _free_adj[cell]:
			if not visited[other] or other == current:
				avail += 1
		if avail < (1 if cell == end_cell else 2):
			return true
	return false


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


func _edge_key(a: int, b: int) -> int:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return lo * (n * n) + hi


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
