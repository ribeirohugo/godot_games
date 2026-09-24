extends RefCounted
## Exact rational arithmetic and the brute-force 24 solver. A rational is a Vector2i (numerator, denominator).

const SYMBOLS := {"+": "+", "-": "−", "*": "×", "/": "÷"}
## Search steps before giving up. Six numbers can have a huge search space; a deal the solver can't settle
## within this many steps is simply redrawn, and the same deal is always solved the same way.
const BUDGET := 40000


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


## An expression that makes 24 from all the numbers with the allowed operators, or "" when there is none
## (or none found within BUDGET steps).
static func solve_numbers(numbers: Array, ops: Array) -> String:
	var items: Array = []
	for n: int in numbers:
		items.append({"v": Vector2i(n, 1), "e": str(n)})
	var found := _solve(items, ops, {"dead": {}, "steps": 0})
	if found.begins_with("(") and found.ends_with(")"):
		found = found.substr(1, found.length() - 2)
	return found


## `ctx.dead` remembers sets of values already known not to reach 24, so each is searched once.
static func _solve(items: Array, ops: Array, ctx: Dictionary) -> String:
	if items.size() == 1:
		return str(items[0].e) if is_24(items[0].v) else ""
	var key := _key(items)
	if ctx.dead.has(key):
		return ""
	ctx.steps += 1
	if ctx.steps > BUDGET:
		return ""
	for i in items.size():
		for j in range(i + 1, items.size()):
			var rest: Array = []
			for k in items.size():
				if k != i and k != j:
					rest.append(items[k])
			for op: String in ops:
				# + and × don't depend on the order; − and ÷ are tried both ways.
				var pairs := [[items[i], items[j]]] if op == "+" or op == "*" else [[items[i], items[j]], [items[j], items[i]]]
				for pair: Array in pairs:
					var result: Variant = compute(pair[0].v, pair[1].v, op)
					if result == null:
						continue
					var expr := "(%s %s %s)" % [pair[0].e, SYMBOLS[op], pair[1].e]
					var found := _solve(rest + [{"v": result, "e": expr}], ops, ctx)
					if found != "":
						return found
	ctx.dead[key] = true
	return ""


static func _key(items: Array) -> String:
	var parts := PackedStringArray()
	for item: Dictionary in items:
		parts.append("%d/%d" % [item.v.x, item.v.y])
	parts.sort()
	return ",".join(parts)
