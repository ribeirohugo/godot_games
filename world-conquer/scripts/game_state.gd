extends RefCounted
## The rules: who owns what, turns and phases, reinforcements, cards, battles and moves.
## Knows nothing about drawing; the game scene and the AI both work through this.

signal changed
signal message(text: String)

const START_ARMIES := {2: 50, 3: 42, 4: 36, 5: 31, 6: 27}
const TRADE_VALUES := [4, 6, 8, 10, 12, 15]  # then +5 per trade
const CARD_NAMES := ["Infantaria", "Cavalaria", "Artilharia"]
const MAX_CARDS := 5  # holding this many forces a trade before reinforcing

var data
var players := []  # {name, color, human, alive, cards: Array[int]}
var owner := {}  # region id -> player index
var armies := {}  # region id -> int
var current := 0
var turn := 1
var phase := "reinforce"  # reinforce, attack, occupy, fortify, over
var reinforcements := 0
var trades := 0
var conquered_this_turn := false
var occupy := {}  # after a conquest: {from, to, min, max}
var winner := -1
var last_battle := {}  # {from, to, attack: Array, defend: Array, attacker_lost, defender_lost, conquered}


func setup(map_data, player_list: Array) -> void:
	data = map_data
	players = player_list
	var ids: Array = data.ids.duplicate()
	ids.shuffle()
	for i in ids.size():
		owner[ids[i]] = i % players.size()
		armies[ids[i]] = 1

	# Spread the rest of each player's starting armies over their regions at random.
	var start: int = START_ARMIES[players.size()]
	for p in players.size():
		var mine := regions_of(p)
		for i in maxi(start - mine.size(), 0):
			armies[mine[randi() % mine.size()]] += 1

	current = randi() % players.size()
	_start_turn()


# --- Queries ---------------------------------------------------------------------

func regions_of(p: int) -> Array:
	return data.ids.filter(func(id): return owner[id] == p)


func armies_of(p: int) -> int:
	var total := 0
	for id in data.ids:
		if owner[id] == p:
			total += armies[id]
	return total


func owned_continents(p: int) -> Array:
	var result := []
	for code in data.continents:
		if data.continents[code].regions.all(func(id): return owner[id] == p):
			result.append(code)
	return result


func income(p: int) -> int:
	var total := maxi(3, regions_of(p).size() / 3)
	for code in owned_continents(p):
		total += data.continents[code].bonus
	return total


func enemy_neighbours(id: String) -> Array:
	return data.neighbours[id].filter(func(n): return owner[n] != owner[id])


func can_attack_from(id: String) -> bool:
	return phase == "attack" and owner[id] == current and armies[id] >= 2 and not enemy_neighbours(id).is_empty()


func can_attack(from: String, to: String) -> bool:
	return can_attack_from(from) and owner[to] != current and data.are_neighbours(from, to)


## Regions reachable from `from` through a chain of the same owner's regions.
func reachable(from: String) -> Array:
	var p: int = owner[from]
	var seen := {from: true}
	var stack := [from]
	while not stack.is_empty():
		for n in data.neighbours[stack.pop_back()]:
			if owner[n] == p and not seen.has(n):
				seen[n] = true
				stack.append(n)
	seen.erase(from)
	return seen.keys()


func next_trade_value() -> int:
	return TRADE_VALUES[trades] if trades < TRADE_VALUES.size() else 15 + 5 * (trades - TRADE_VALUES.size() + 1)


## Indices of three cards that can be traded (three alike or one of each), or [].
func find_card_set(p: int) -> Array:
	var cards: Array = players[p].cards
	var by_kind := [[], [], []]
	for i in cards.size():
		by_kind[cards[i]].append(i)
	for kind in by_kind:
		if kind.size() >= 3:
			return kind.slice(0, 3)
	if by_kind.all(func(k): return not k.is_empty()):
		return [by_kind[0][0], by_kind[1][0], by_kind[2][0]]
	return []


func must_trade() -> bool:
	return phase == "reinforce" and players[current].cards.size() >= MAX_CARDS and not find_card_set(current).is_empty()


# --- Actions ---------------------------------------------------------------------

func place(id: String, count: int = 1) -> bool:
	if phase != "reinforce" or owner[id] != current or must_trade():
		return false
	count = mini(count, reinforcements)
	if count <= 0:
		return false
	armies[id] += count
	reinforcements -= count
	if reinforcements == 0:
		phase = "attack"
	changed.emit()
	return true


func trade_cards() -> bool:
	var card_set := find_card_set(current)
	if phase != "reinforce" or card_set.is_empty():
		return false
	card_set.sort()
	var cards: Array = players[current].cards
	for i in range(card_set.size() - 1, -1, -1):
		cards.remove_at(card_set[i])
	var value := next_trade_value()
	trades += 1
	reinforcements += value
	message.emit(_says(current, "Trocaste cartas por %d exércitos." % value,
		"%s trocou cartas por %d exércitos." % [players[current].name, value]))
	changed.emit()
	return true


## One round of dice. Returns false when the attack isn't allowed.
func attack(from: String, to: String) -> bool:
	if not can_attack(from, to):
		return false
	var defender: int = owner[to]
	var attack_dice := _roll(mini(3, armies[from] - 1))
	var defend_dice := _roll(mini(2, armies[to]))
	var attacker_lost := 0
	var defender_lost := 0
	for i in mini(attack_dice.size(), defend_dice.size()):
		if attack_dice[i] > defend_dice[i]:
			defender_lost += 1
		else:
			attacker_lost += 1
	armies[from] -= attacker_lost
	armies[to] -= defender_lost

	last_battle = {
		"from": from, "to": to, "attack": attack_dice, "defend": defend_dice,
		"attacker_lost": attacker_lost, "defender_lost": defender_lost, "conquered": false,
	}
	if armies[to] <= 0:
		last_battle.conquered = true
		owner[to] = current
		armies[to] = 0
		conquered_this_turn = true
		occupy = {"from": from, "to": to, "min": mini(attack_dice.size(), armies[from] - 1), "max": armies[from] - 1}
		phase = "occupy"
		message.emit(_says(current, "Conquistaste %s." % data.regions[to].name,
			"%s conquistou %s." % [players[current].name, data.regions[to].name]))
		_check_elimination(defender)
	changed.emit()
	return true


## Moves armies into a just-conquered region.
func occupy_with(count: int) -> void:
	if phase != "occupy":
		return
	count = clampi(count, occupy.min, occupy.max)
	armies[occupy.from] -= count
	armies[occupy.to] += count
	occupy = {}
	phase = "over" if winner >= 0 else "attack"
	changed.emit()


func end_attacks() -> void:
	if phase != "attack":
		return
	if conquered_this_turn:
		var card := randi() % 3
		players[current].cards.append(card)
		if players[current].human:
			message.emit("Recebeste uma carta: %s." % CARD_NAMES[card])
	phase = "fortify"
	changed.emit()


func fortify(from: String, to: String, count: int) -> bool:
	if phase != "fortify" or owner[from] != current or not (to in reachable(from)):
		return false
	count = clampi(count, 1, armies[from] - 1)
	armies[from] -= count
	armies[to] += count
	var amount := "1 exército" if count == 1 else "%d exércitos" % count
	message.emit(_says(current, "Moveste %s para %s." % [amount, data.regions[to].name],
		"%s moveu %s para %s." % [players[current].name, amount, data.regions[to].name]))
	end_turn()
	return true


func end_turn() -> void:
	if phase == "over":
		return
	if phase == "attack":
		end_attacks()
	var next := current
	for i in players.size():
		next = (next + 1) % players.size()
		if players[next].alive:
			break
	if next <= current:
		turn += 1
	current = next
	_start_turn()


func _start_turn() -> void:
	phase = "reinforce"
	conquered_this_turn = false
	reinforcements = income(current)
	changed.emit()


func _check_elimination(p: int) -> void:
	if not regions_of(p).is_empty():
		return
	players[p].alive = false
	players[current].cards.append_array(players[p].cards)
	players[p].cards.clear()
	message.emit(_says(p, "Foste eliminado!", "%s foi eliminado!" % players[p].name))
	var alive := players.filter(func(pl): return pl.alive)
	if alive.size() == 1:
		winner = current


## Picks the "you" wording for the human player and the third-person one for the others.
func _says(p: int, to_human: String, to_others: String) -> String:
	return to_human if players[p].human else to_others


func _roll(count: int) -> Array:
	var dice := []
	for i in count:
		dice.append(randi_range(1, 6))
	dice.sort()
	dice.reverse()
	return dice
