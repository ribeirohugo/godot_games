extends RefCounted
## Builds Patches puzzles with exactly one solution.
## 1. Split the grid into random rectangles (the hidden solution).
## 2. Put one clue in each rectangle: its area, its shape (square / wide / tall), or both.
## 3. Start with partial clues. While another solution exists, reveal the missing part of a
##    clue that solution gets wrong. Start over if every clue is already complete.

enum Shape { SQUARE, WIDE, TALL }

var n := 6
var rng := RandomNumberGenerator.new()
var max_area := 6


## Returns {"solution": Array of Rect2i, "clues": Array of {cell, area, shape, show_area, show_shape}}.
## `full_clues` is the chance a clue starts with both its number and its shape (easier);
## the rest show only one of them, more often the number.
func generate(size: int, seed_value: int, full_clues := 0.3) -> Dictionary:
	n = size
	rng.seed = seed_value
	max_area = {5: 5, 6: 6, 7: 8, 8: 9, 9: 10}.get(size, 8)
	for attempt in 200:
		var rects := _partition()
		var clues := []
		for rect: Rect2i in rects:
			var cell := (rect.position.y + rng.randi_range(0, rect.size.y - 1)) * n + rect.position.x + rng.randi_range(0, rect.size.x - 1)
			var full := rng.randf() < full_clues
			var number := full or rng.randf() < 0.6
			clues.append({
				"cell": cell, "area": rect.get_area(), "shape": shape_of(rect.size),
				"show_area": number, "show_shape": full or not number,
			})
		if _make_unique(clues, rects):
			return {"solution": rects, "clues": clues}
	return {}


static func shape_of(dims: Vector2i) -> int:
	if dims.x == dims.y:
		return Shape.SQUARE
	return Shape.WIDE if dims.x > dims.y else Shape.TALL


## Does a rectangle of this size satisfy the clue (only its revealed parts)?
static func fits(clue: Dictionary, dims: Vector2i) -> bool:
	if clue.show_area and dims.x * dims.y != int(clue.area):
		return false
	if clue.show_shape and shape_of(dims) != int(clue.shape):
		return false
	return true


func _partition() -> Array:
	var owner := PackedInt32Array()
	owner.resize(n * n)
	owner.fill(-1)
	var rects := []
	for cell in n * n:
		if owner[cell] != -1:
			continue
		var row := cell / n
		var col := cell % n
		var run := 0
		while col + run < n and owner[row * n + col + run] == -1:
			run += 1
		var options := []
		var weights := PackedFloat32Array()
		for h in range(1, n - row + 1):
			for w in range(1, run + 1):
				var area := w * h
				if area > max_area:
					continue
				options.append(Vector2i(w, h))
				# Favor mid-sized patches; single cells and long thin strips are rarer.
				var weight := 1.0
				if area == 1:
					weight = 0.12
				elif area == 2:
					weight = 0.6
				if maxi(w, h) >= 5:
					weight *= 0.5
				weights.append(weight)
		var dims: Vector2i = options[_weighted(weights)]
		var rect := Rect2i(col, row, dims.x, dims.y)
		for y in dims.y:
			for x in dims.x:
				owner[(row + y) * n + col + x] = rects.size()
		rects.append(rect)
	return rects


func _make_unique(clues: Array, target: Array) -> bool:
	for step in 80:
		var solutions := solve(clues, 2)
		var other := []
		for s: Array in solutions:
			if not _same(s, target):
				other = s
				break
		if other.is_empty():
			return solutions.size() == 1
		# Reveal more of a clue whose patch the other solution draws differently.
		var order := range(clues.size())
		_shuffle(order)
		var upgraded := false
		for i: int in order:
			if other[i] == target[i]:
				continue
			var clue: Dictionary = clues[i]
			if not clue.show_area:
				clue.show_area = true
			elif not clue.show_shape:
				clue.show_shape = true
			else:
				continue
			upgraded = true
			break
		if not upgraded:
			return false
	return false


## Solutions as arrays of Rect2i indexed like `clues`, stopping after `limit`.
func solve(clues: Array, limit: int) -> Array:
	var clue_at := PackedInt32Array()
	clue_at.resize(n * n)
	clue_at.fill(-1)
	for i in clues.size():
		clue_at[clues[i].cell] = i
	var filled := PackedByteArray()
	filled.resize(n * n)
	var rects := []
	rects.resize(clues.size())
	var found := []
	_solve_from(clues, clue_at, filled, rects, 0, found, limit)
	return found


func _solve_from(clues: Array, clue_at: PackedInt32Array, filled: PackedByteArray, rects: Array, start: int, found: Array, limit: int) -> void:
	var cell := start
	while cell < n * n and filled[cell]:
		cell += 1
	if cell == n * n:
		found.append(rects.duplicate())
		return
	var row := cell / n
	var col := cell % n
	# The first empty cell must be a patch's top-left corner.
	var max_w := 0
	while col + max_w < n and not filled[row * n + col + max_w]:
		max_w += 1
	for h in range(1, n - row + 1):
		if max_w == 0:
			break
		var w := 1
		while w <= max_w:
			# Is the new row (row + h - 1) free across this width?
			var bottom := (row + h - 1) * n + col + w - 1
			if filled[bottom]:
				max_w = w - 1
				break
			var clue := -1
			var count := 0
			for y in h:
				for x in w:
					var c := clue_at[(row + y) * n + col + x]
					if c >= 0:
						clue = c
						count += 1
			if count > 1:
				# Wider only adds more clues; this width and beyond are out.
				max_w = w - 1
				break
			if count == 1 and fits(clues[clue], Vector2i(w, h)):
				for y in h:
					for x in w:
						filled[(row + y) * n + col + x] = 1
				rects[clue] = Rect2i(col, row, w, h)
				_solve_from(clues, clue_at, filled, rects, cell + w, found, limit)
				for y in h:
					for x in w:
						filled[(row + y) * n + col + x] = 0
				if found.size() >= limit:
					return
			w += 1


func _same(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _weighted(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
