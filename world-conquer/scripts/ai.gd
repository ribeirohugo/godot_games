extends RefCounted
## Decisions for computer players. Each function looks at the game state and returns one step;
## the game scene carries the steps out with short pauses so the player can follow them.
## difficulty: 0 easy, 1 normal, 2 hard.

var state
var difficulty := 1


func _init(game_state, level: int) -> void:
	state = game_state
	difficulty = level


## Region to put the next reinforcements on, and how many.
func reinforce_step() -> Array:
	var p: int = state.current
	var borders := _borders(p)
	if borders.is_empty():
		borders = state.regions_of(p)
	var best := ""
	var best_score := -INF
	for id in borders:
		var score := _reinforce_score(id)
		if difficulty == 0:
			score += randf() * 8.0
		if score > best_score:
			best_score = score
			best = id
	var count: int = state.reinforcements
	if difficulty == 0:
		count = mini(count, randi_range(1, 3))
	elif difficulty == 1 and borders.size() > 1:
		count = maxi(1, int(ceil(count * 0.6)))
	return [best, count]


## [from, to] for the next attack, or [] to stop attacking.
func attack_step() -> Array:
	var p: int = state.current
	var best := []
	var best_score := -INF
	var min_advantage: int = [3, 1, 0][difficulty]
	for from in state.regions_of(p):
		if state.armies[from] < 2:
			continue
		for to in state.enemy_neighbours(from):
			var attackers: int = state.armies[from] - 1
			var defenders: int = state.armies[to]
			var advantage := attackers - defenders
			if advantage < min_advantage:
				continue
			if difficulty == 2 and attackers < 3 and defenders > 1:
				continue
			var score := float(advantage) + _continent_value(p, to)
			if state.regions_of(state.owner[to]).size() == 1:
				score += 6.0  # eliminating a player gives their cards
			if score > best_score:
				best_score = score
				best = [from, to]
	if difficulty == 0 and randf() < 0.25:
		return []
	return best


## How many armies to move into a region just conquered.
func occupy_count() -> int:
	var info: Dictionary = state.occupy
	var from: String = info.from
	# Keep armies behind when the region we came from still faces other enemies.
	if state.enemy_neighbours(from).is_empty():
		return info.max
	return maxi(info.min, info.max / 2)


## [from, to, count] for the end-of-turn move, or [].
func fortify_step() -> Array:
	var p: int = state.current
	var best := []
	var best_score := 0.0
	for from in state.regions_of(p):
		if state.armies[from] < 2 or not state.enemy_neighbours(from).is_empty():
			continue
		for to in state.reachable(from):
			var threat := _threat(to)
			if threat <= 0.0:
				continue
			var score: float = threat + state.armies[from]
			if score > best_score:
				best_score = score
				best = [from, to, state.armies[from] - 1]
	return best


func _borders(p: int) -> Array:
	return state.regions_of(p).filter(func(id): return not state.enemy_neighbours(id).is_empty())


func _threat(id: String) -> float:
	var total := 0.0
	for n in state.enemy_neighbours(id):
		total += state.armies[n]
	return total


func _reinforce_score(id: String) -> float:
	var p: int = state.current
	var score: float = _threat(id) - state.armies[id] * 0.6
	# Prefer places that can take a weak neighbour, and the continent we're closest to owning.
	for n in state.enemy_neighbours(id):
		if state.armies[n] <= 2:
			score += 2.0
		score += _continent_value(p, n) * 0.5
	var code: String = state.data.regions[id].continent
	score += _continent_share(p, code) * 6.0
	return score


## Bonus for taking `id`: finishing our continent or breaking someone else's.
func _continent_value(p: int, id: String) -> float:
	var code: String = state.data.regions[id].continent
	var continent: Dictionary = state.data.continents[code]
	var value := _continent_share(p, code) * 4.0
	var missing: int = continent.regions.filter(func(r): return state.owner[r] != p).size()
	if missing == 1:
		value += continent.bonus * 2.0
	var holder: int = state.owner[id]
	if continent.regions.all(func(r): return state.owner[r] == holder):
		value += continent.bonus * 1.5
	return value


func _continent_share(p: int, code: String) -> float:
	var regions: Array = state.data.continents[code].regions
	return float(regions.filter(func(r): return state.owner[r] == p).size()) / regions.size()
