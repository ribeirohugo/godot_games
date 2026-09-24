extends RefCounted
## Exact rational arithmetic and the brute-force 24 solver. A rational is a Vector2i (numerator, denominator).

const SYMBOLS := {"+": "+", "-": "−", "*": "×", "/": "÷"}


static func _gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return maxi(a, 1)


static func reduce(n: int, d: int) -> Vector2i:
	var g := _gcd(n, d)
	n /= g
	d /= g
	if d < 0:
		n = -n
		d = -d
	return Vector2i(n, d)


## a op b, or null when dividing by zero.
static func compute(a: Vector2i, b: Vector2i, op: String) -> Variant:
	match op:
		"+":
			return reduce(a.x * b.y + b.x * a.y, a.y * b.y)
		"-":
			return reduce(a.x * b.y - b.x * a.y, a.y * b.y)
		"*":
			return reduce(a.x * b.x, a.y * b.y)
		"/":
			if b.x == 0:
				return null
			return reduce(a.x * b.y, a.y * b.x)
	return null


static func is_24(v: Vector2i) -> bool:
	return v.x == 24 * v.y


static func to_text(v: Vector2i) -> String:
	return str(v.x) if v.y == 1 else "%d/%d" % [v.x, v.y]


## An expression that makes 24 from the numbers with the allowed operators, or "" when there is none.
static func solve_numbers(numbers: Array, ops: Array) -> String:
	var items: Array = []
	for n: int in numbers:
		items.append({"v": Vector2i(n, 1), "e": str(n)})
	var found := _solve(items, ops)
	if found.begins_with("(") and found.ends_with(")"):
		found = found.substr(1, found.length() - 2)
	return found


static func _solve(items: Array, ops: Array) -> String:
	if items.size() == 1:
		return str(items[0].e) if is_24(items[0].v) else ""
	for i in items.size():
		for j in items.size():
			if i == j:
				continue
			var rest: Array = []
			for k in items.size():
				if k != i and k != j:
					rest.append(items[k])
			for op: String in ops:
				var result: Variant = compute(items[i].v, items[j].v, op)
				if result == null:
					continue
				var expr := "(%s %s %s)" % [items[i].e, SYMBOLS[op], items[j].e]
				var found := _solve(rest + [{"v": result, "e": expr}], ops)
				if found != "":
					return found
	return ""
