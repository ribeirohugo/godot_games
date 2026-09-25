extends Node3D
## One match: two squads of soldiers, rounds, money and the bomb.
##
## Each round starts with a short freeze time for buying. Attackers win by planting the bomb on a
## bomb site and letting it explode, or by killing every defender. Defenders win by defusing the bomb,
## by killing every attacker before it is planted, or when the round clock runs out. Money works like
## the classic games: kill rewards by weapon, a win bonus, and a loss bonus that grows with each loss
## in a row. At the half the squads swap sides and start again with a pistol and $800.

const WorldScript := preload("res://scripts/world.gd")
const SoldierScript := preload("res://scripts/soldier.gd")
const BotScript := preload("res://scripts/bot.gd")
const ViewScript := preload("res://scripts/view.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Maps := preload("res://scripts/maps.gd")
const Models := preload("res://scripts/models.gd")

const FREEZE := 6.0
const ROUND := 115.0
const BOMB_TIME := 40.0
const BUY_TIME := 20.0
const END_DELAY := 5.0
const START_MONEY := 800
const WIN_ELIMINATION := 3250
const WIN_OBJECTIVE := 3500
const LOSS_BONUS := 1400
const LOSS_STEP := 500
const PLANT_BONUS := 800
const LENGTHS := [[16, 9], [30, 16]]  # [rounds, rounds to win]
const NAMES := ["Viper", "Ghost", "Havoc", "Nomad", "Rook", "Blaze", "Kestrel", "Onyx", "Talon", "Sable",
		"Jackal", "Frost", "Mako", "Raven", "Bishop", "Cobra", "Dune", "Ember", "Flint", "Hex"]

var game  # main.gd
var world
var view
var settings := {}
var soldiers: Array = []
var human
var side_of := ["att", "def"]  # squad -> side
var score := [0, 0]  # by squad
var streak := [0, 0]  # rounds lost in a row, by squad
var max_rounds := 16
var to_win := 9
var round_n := 0
var phase := "freeze"  # freeze, live, over, done
var phase_t := FREEZE
var round_clock := 0.0  # seconds since the round went live
var bomb_state := "carried"  # carried, dropped, planted, defused, exploded
var bomb_node: Node3D
var bomb_led: MeshInstance3D
var bomb_t := BOMB_TIME
var beep_t := 0.0
var planted_site := ""
var plan_site := "a"
var contact_site := ""  # the site where defenders last met attackers this round
var swapped_this_round := false
var feed: Array = []  # {killer, victim, weapon, headshot, t}
var banner := {"text": "", "sub": "", "color": Color.WHITE, "t": 0.0}
var spotted := {}  # soldier -> seconds they stay on the radar
var spot_t := 0.0
var pickup_t := 0.0
var round_winner := ""
var mvp_text := ""


func start(game_ref, options: Dictionary) -> void:
	game = game_ref
	settings = options
	max_rounds = LENGTHS[options["length"]][0]
	to_win = LENGTHS[options["length"]][1]
	world = WorldScript.new()
	add_child(world)
	world.build(game, self, Maps.MAPS[options["map"]])
	var side: String = options["side"]
	if side == "auto":
		side = "att" if randf() < 0.5 else "def"
	side_of = [side, "def" if side == "att" else "att"]
	var names := NAMES.duplicate()
	names.shuffle()
	var size: int = options["size"]
	for squad in 2:
		for i in size:
			var s = SoldierScript.new()
			add_child(s)
			var is_player: bool = squad == 0 and i == 0
			s.setup(world, self, game, side_of[squad], squad, tr("you") if is_player else names.pop_back(), is_player)
			s.money = START_MONEY
			if is_player:
				human = s
			else:
				var brain = BotScript.new()
				brain.setup(s, self, world, options["skill"])
				s.brain = brain
			soldiers.append(s)
	view = ViewScript.new()
	add_child(view)
	view.setup(self, game)
	_start_round()


# --- Queries -------------------------------------------------------------------------------

func side_team(team: String) -> Array:
	var list := []
	for s in soldiers:
		if s.team == team:
			list.append(s)
	return list


func alive_count(team: String) -> int:
	var n := 0
	for s in soldiers:
		if s.team == team and s.alive:
			n += 1
	return n


func enemies_of(s) -> Array:
	return side_team("def" if s.team == "att" else "att")


func squad_of_side(team: String) -> int:
	return 0 if side_of[0] == team else 1


func scope_fov(s) -> float:
	var d := Weapons.data(s.current)
	if s.scope <= 0 or not d.has("scope"):
		return 74.0
	return d["scope"][s.scope - 1]


func time_left() -> float:
	if phase == "freeze":
		return phase_t
	if bomb_state == "planted":
		return bomb_t
	return maxf(phase_t, 0.0) if phase == "live" else 0.0


func can_plant() -> bool:
	return phase == "live" and bomb_state == "carried"


func bomb_position() -> Vector3:
	if bomb_state == "planted" or bomb_state == "dropped":
		if bomb_state == "planted":
			return bomb_node.position
		for d in world.drops:
			if d.get_meta("id") == "bomb":
				return d.position
	for s in soldiers:
		if s.alive and s.has_bomb:
			return s.position
	return Vector3.INF


func bomb_carrier():
	for s in soldiers:
		if s.alive and s.has_bomb:
			return s
	return null


## True while buying is open for s: freeze time and the first seconds of the round, in their spawn.
func can_buy(s) -> bool:
	if not s.alive or phase == "over" or phase == "done":
		return false
	if phase == "live" and round_clock > BUY_TIME:
		return false
	for spot: Vector3 in world.spawns[s.team]:
		if Vector2(spot.x - s.position.x, spot.z - s.position.z).length() < 12.0:
			return true
	return false


# --- Rounds --------------------------------------------------------------------------------

func _start_round() -> void:
	round_n += 1
	world.clear_round()
	if bomb_node != null:
		bomb_node.queue_free()
		bomb_node = null
	bomb_state = "carried"
	bomb_t = BOMB_TIME
	planted_site = ""
	contact_site = ""
	phase = "freeze"
	phase_t = FREEZE
	round_clock = 0.0
	feed.clear()
	spotted.clear()
	for team in ["att", "def"]:
		var spots: Array = world.spawns[team].duplicate()
		spots.shuffle()
		var far: Vector3 = centroid(world.spawns["def" if team == "att" else "att"])
		var i := 0
		for s in side_team(team):
			var spot: Vector3 = spots[i % spots.size()]
			i += 1
			var to := far - spot
			var keep: bool = s.alive and round_n > 1 and not swapped_this_round
			s.respawn(spot + Vector3(0, 0.05, 0), atan2(-to.x, -to.z), keep)
			s.frozen = true
	var attackers := side_team("att")
	if not attackers.is_empty():
		attackers[randi() % attackers.size()].give("bomb")
	plan_site = "a" if randf() < 0.5 else "b"
	for s in soldiers:
		if s.brain != null:
			_bot_buy(s)
			s.equip(s.best_weapon())
	var defenders := side_team("def")
	defenders.shuffle()
	for i in defenders.size():
		if defenders[i].brain != null:
			defenders[i].brain.guard_site = "a" if i % 2 == 0 else "b"
	for s in soldiers:
		if s.brain != null:
			s.brain.new_round()
	swapped_this_round = false
	view.on_round_start()
	var half := max_rounds / 2
	var text := tr("round_n") % round_n
	if round_n == max_rounds:
		text = tr("last_round")
	elif score[0] == to_win - 1 or score[1] == to_win - 1:
		text = tr("match_point") % round_n
	elif round_n == half:
		text = tr("last_round_half")
	_banner(text, tr("buy_hint") if human.alive else "", Color(1, 1, 1))


func centroid(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	for p: Vector3 in points:
		sum += p
	return sum / maxf(points.size(), 1.0)


func _physics_process(delta: float) -> void:
	for i in range(feed.size() - 1, -1, -1):
		feed[i]["t"] -= delta
		if feed[i]["t"] <= 0.0:
			feed.remove_at(i)
	banner["t"] = maxf(banner["t"] - delta, 0.0)
	match phase:
		"freeze":
			phase_t -= delta
			if phase_t <= 0.0:
				phase = "live"
				phase_t = ROUND
				for s in soldiers:
					s.frozen = false
				game.sfx.play("radio", -4.0)
				_banner(tr("go"), "", Color(1.0, 0.85, 0.4), 1.5)
		"live":
			round_clock += delta
			if bomb_state == "planted":
				_tick_bomb(delta)
			else:
				phase_t -= delta
				if phase_t <= 0.0:
					_end_round("def", "time")
		"over":
			if bomb_state == "planted":
				_tick_bomb(delta)
			phase_t -= delta
			if phase_t <= 0.0:
				_next_round()
	_update_spotted(delta)
	pickup_t -= delta
	if pickup_t <= 0.0:
		pickup_t = 0.1
		_auto_pickups()


func _tick_bomb(delta: float) -> void:
	bomb_t -= delta
	beep_t -= delta
	if beep_t <= 0.0:
		beep_t = lerpf(0.12, 1.0, clampf(bomb_t / BOMB_TIME, 0.0, 1.0))
		game.sfx.play_at("beep", bomb_node.position + Vector3.UP * 0.2, -2.0)
		bomb_led.visible = true
	elif beep_t < 0.06:
		bomb_led.visible = false
	if bomb_t <= 0.0:
		_explode()


func _explode() -> void:
	bomb_state = "exploded"
	var pos := bomb_node.position
	world.explosion(pos + Vector3.UP * 0.5, 7.0)
	for i in 5:
		world.explosion(pos + Vector3(randf_range(-4, 4), randf_range(0.5, 4.0), randf_range(-4, 4)), 3.0)
	game.sfx.play("bomb_explode")
	game.shake(1.0)
	bomb_node.visible = false
	for s in soldiers:
		if not s.alive:
			continue
		var d: float = s.position.distance_to(pos)
		if d < 24.0:
			s.take_blast(500.0 * pow(1.0 - d / 24.0, 1.4), null, "bomb")
	if phase != "over":
		_end_round("att", "bomb")


func _end_round(winner: String, reason: String) -> void:
	if phase == "over" or phase == "done":
		return
	phase = "over"
	phase_t = END_DELAY
	round_winner = winner
	var loser := "def" if winner == "att" else "att"
	var win_squad := squad_of_side(winner)
	var lose_squad := 1 - win_squad
	score[win_squad] += 1
	var bonus := LOSS_BONUS + LOSS_STEP * mini(streak[lose_squad], 4)
	streak[lose_squad] += 1
	streak[win_squad] = maxi(streak[win_squad] - 1, 0)
	for s in soldiers:
		if s.team == winner:
			add_money(s, WIN_OBJECTIVE if reason in ["bomb", "defuse"] else WIN_ELIMINATION)
		elif reason == "time" and s.alive:
			pass  # attackers who hid until time ran out get nothing
		else:
			var extra := PLANT_BONUS if loser == "att" and planted_site != "" else 0
			add_money(s, bonus + extra)
	var title := tr("att_win") if winner == "att" else tr("def_win")
	var sub: String = tr("reason_" + reason)
	var color := Color(1.0, 0.72, 0.3) if winner == "att" else Color(0.45, 0.7, 1.0)
	_banner(title, sub, color, END_DELAY)
	game.sfx.play("win" if win_squad == 0 else "lose", -3.0)


func _next_round() -> void:
	var half := max_rounds / 2
	if score[0] >= to_win or score[1] >= to_win or round_n >= max_rounds:
		phase = "done"
		game.match_over(score[0], score[1])
		return
	if round_n == half:
		side_of = [side_of[1], side_of[0]]
		for s in soldiers:
			s.set_team(side_of[s.squad])
			s.money = START_MONEY
		streak = [0, 0]
		swapped_this_round = true
		game.message(tr("halftime"))
	_start_round()


func _banner(text: String, sub: String, color: Color, seconds := 3.0) -> void:
	banner = {"text": text, "sub": sub, "color": color, "t": seconds}


func add_money(s, amount: int) -> void:
	s.money = clampi(s.money + amount, 0, SoldierScript.MAX_MONEY)


# --- Events --------------------------------------------------------------------------------

func on_death(victim, killer, weapon: String, headshot: bool) -> void:
	if game.autotest and killer != null:
		print("    kill %s(%s,%s) -> %s(%s,%s,%s) %s d=%.0f t=%.0f" % [killer.team, killer.brain.task if killer.brain else "-", "mv" if killer.is_moving() else "st",
				victim.team, victim.brain.task if victim.brain else "-", "mv" if victim.is_moving() else "st", "tgt" if victim.brain and victim.brain.target == killer else ("busy" if victim.brain and victim.brain.target else "unaware"),
				weapon, killer.position.distance_to(victim.position), round_clock])
	feed.append({"killer": killer, "victim": victim, "weapon": weapon, "headshot": headshot, "t": 7.0,
			"killer_team": killer.team if killer != null else "", "victim_team": victim.team})
	if feed.size() > 6:
		feed.pop_front()
	if killer != null and killer != victim:
		if killer.team != victim.team:
			killer.kills += 1
			add_money(killer, int(Weapons.data(weapon).get("reward", 300)))
			if killer == human:
				game.sfx.play("hit_head" if headshot else "hit_flesh", -2.0)
		else:
			killer.kills -= 1
			add_money(killer, -300)
	if victim == human:
		view.on_player_died(killer)
	for s in soldiers:
		if s.brain != null and s.alive and s.team == victim.team and s.position.distance_to(victim.position) < 30.0:
			s.brain.hear(victim.position, killer)
	if victim.team == "def":
		report_contact(victim.position, victim)
	if phase != "live" and phase != "freeze":
		return
	if alive_count("def") == 0:
		_end_round("att", "elimination")
	elif alive_count("att") == 0 and bomb_state != "planted":
		_end_round("def", "elimination")


func plant(s) -> void:
	bomb_state = "planted"
	planted_site = world.site_at(s.position)
	bomb_node = Node3D.new()
	bomb_node.position = Vector3(s.position.x, s.position.y + 0.04, s.position.z)
	bomb_node.rotation.y = s.yaw
	add_child(bomb_node)
	bomb_led = Models.bomb_model(bomb_node)
	bomb_t = BOMB_TIME
	beep_t = 0.0
	add_money(s, 300)
	game.sfx.play("planted", -2.0)
	_banner(tr("bomb_planted"), tr("site_n") % planted_site.to_upper(), Color(1.0, 0.35, 0.25), 3.0)
	for b in soldiers:
		if b.brain != null:
			b.brain.on_planted()


func on_defuse_start(s) -> void:
	world.noise(s.position, 25.0, s)


func defuse(s) -> void:
	if bomb_state != "planted":
		return
	bomb_state = "defused"
	bomb_led.visible = false
	add_money(s, 300)
	game.sfx.play("defused")
	_end_round("def", "defuse")


func on_bomb_dropped() -> void:
	bomb_state = "dropped"
	for s in soldiers:
		if s.brain != null:
			s.brain.on_bomb_dropped()


## A defender met attackers at pos: most of those guarding the other site come over to help.
func report_contact(pos: Vector3, reporter) -> void:
	if reporter.team != "def" or bomb_state == "planted":
		return
	var site: String = world.site_at(pos)
	if site == "":
		for key: String in world.sites:
			if world.site_center(key).distance_to(pos) < 26.0:
				site = key
	if site == "" or site == contact_site:
		return
	contact_site = site
	for d in side_team("def"):
		if d.alive and d.brain != null and d.brain.guard_site != site and d.brain.target == null and randf() < 0.75:
			d.brain.rotate_to(site)


func on_noise(pos: Vector3, radius: float, source) -> void:
	for s in soldiers:
		if s.brain != null and s.alive and source != null and s.team != source.team:
			if s.position.distance_to(pos) < radius:
				s.brain.hear(pos, source)


## An HE grenade or the bomb: damage that fades with distance and stops at walls.
func blast(pos: Vector3, radius: float, damage: float, owner, weapon: String) -> void:
	for s in soldiers:
		if not s.alive or (owner != null and s != owner and s.team == owner.team):
			continue
		var chest: Vector3 = s.position + Vector3(0, 1.0, 0)
		var d := chest.distance_to(pos)
		if d < radius and world.clear_line(pos, chest):
			s.take_blast(damage * pow(1.0 - d / radius, 1.2), owner, weapon)


func flashbang(pos: Vector3) -> void:
	for s in soldiers:
		if not s.alive:
			continue
		var eye: Vector3 = s.eye_position()
		var d := eye.distance_to(pos)
		if d > 28.0 or not world.clear_line(pos, eye) or world.smoke_between(pos, eye):
			continue
		var facing: Vector3 = s.view_basis() * Vector3.FORWARD
		var dot := facing.dot((pos - eye).normalized())
		var seconds := 4.0 if dot > 0.6 else (2.2 if dot > 0.0 else 0.6)
		s.blind(seconds * (0.35 + 0.65 * (1.0 - d / 28.0)))


# --- Weapons on the ground -----------------------------------------------------------------

## The player pressed use: swap for the weapon at their feet (or pick up the bomb).
func try_pickup(s) -> void:
	var best: Node3D = null
	var best_d := 1.8
	for d in world.drops:
		var dist: float = Vector2(d.position.x - s.position.x, d.position.z - s.position.z).length()
		if dist < best_d and absf(d.position.y - s.position.y) < 1.6:
			best = d
			best_d = dist
	if best != null:
		_take(s, best)


func _take(s, drop_node: Node3D) -> bool:
	var id: String = drop_node.get_meta("id")
	if id == "bomb":
		if s.team != "att":
			return false
		s.give("bomb")
		bomb_state = "carried"
		if s.is_human:
			game.message(tr("got_bomb"))
	else:
		s.give(id, drop_node.get_meta("mag"), drop_node.get_meta("reserve"))
	world.remove_drop(drop_node)
	if s.is_human:
		game.sfx.play("pickup")
	return true


## Walking over a weapon picks it up when its slot is empty; attackers pick up the bomb.
func _auto_pickups() -> void:
	for s in soldiers:
		if not s.alive:
			continue
		for d in world.drops.duplicate():
			if d.get_meta("age") < 0.8:
				continue
			if Vector2(d.position.x - s.position.x, d.position.z - s.position.z).length() > 1.1 or absf(d.position.y - s.position.y) > 1.4:
				continue
			var id: String = d.get_meta("id")
			if id == "bomb":
				if s.team == "att" and not s.has_bomb:
					_take(s, d)
			elif Weapons.data(id)["slot"] == 0 and s.primary == "":
				_take(s, d)
			elif Weapons.data(id)["slot"] == 1 and s.secondary == "":
				_take(s, d)


# --- Buying --------------------------------------------------------------------------------

func price_for(s, id: String) -> int:
	if id == "vest_helmet" and s.armor >= 100.0 and not s.helmet:
		return 350
	return Weapons.price(id)


## Why s can't buy id, or "" when they can.
func buy_problem(s, id: String) -> String:
	var team_only := Weapons.team_of(id)
	if team_only != "" and team_only != s.team:
		return "other_side"
	match id:
		"vest":
			if s.armor >= 100.0:
				return "owned"
		"vest_helmet":
			if s.armor >= 100.0 and s.helmet:
				return "owned"
		"kit":
			if s.has_kit:
				return "owned"
		"he", "flash", "smoke":
			if s.grenades.count(id) >= Weapons.MAX_GRENADES[id] or s.grenades.size() >= Weapons.GRENADE_LIMIT:
				return "owned"
		_:
			if s.primary == id or s.secondary == id:
				return "owned"
	if price_for(s, id) > s.money:
		return "money"
	return ""


func buy(s, id: String) -> bool:
	if not can_buy(s) or buy_problem(s, id) != "":
		if s.is_human:
			game.sfx.play("denied")
		return false
	add_money(s, -price_for(s, id))
	match id:
		"vest":
			s.armor = 100.0
		"vest_helmet":
			s.armor = 100.0
			s.helmet = true
		"kit":
			s.has_kit = true
		_:
			s.give(id)
	if s.is_human:
		game.sfx.play("buy", -4.0)
	return true


## What a bot buys with its money: a rifle and armor when it can afford both, cheaper guns on a
## smaller budget, and it saves when that would leave nothing for armor.
func _bot_buy(s) -> void:
	var pistol_round: bool = round_n == 1 or swapped_this_round or round_n == max_rounds / 2 + 1
	var rifle := "ar7" if s.team == "att" else "m4"
	var cheap := "viper" if s.team == "att" else "f90"
	if s.primary == "":
		if s.money >= 5750 and randf() < 0.2:
			buy(s, "longbow")
		elif s.money >= Weapons.price(rifle) + 1000:
			buy(s, rifle)
		elif s.money >= Weapons.price(cheap) + 650 and (streak[s.squad] >= 2 or s.money >= 3200):
			buy(s, cheap)
		elif s.money >= 2300 and not pistol_round and randf() < 0.6:
			buy(s, ["mx9", "u45", "pump"][randi() % 3])
	var armed: bool = s.primary != ""
	if armed or pistol_round or s.money >= 3000:
		if s.money >= 1000:
			buy(s, "vest_helmet")
		elif s.money >= 650:
			buy(s, "vest")
	if pistol_round and s.money >= 300 and randf() < 0.5:
		buy(s, "m25")
	if not armed and not pistol_round and s.money >= 700 and s.money < 2000 and randf() < 0.3:
		buy(s, "magnum")
	if s.team == "def" and s.money >= 400 and (armed or randf() < 0.3):
		buy(s, "kit")
	if armed and s.money >= 300 and randf() < 0.6:
		buy(s, "he")


# --- Radar ---------------------------------------------------------------------------------

## Enemies of the player's squad that someone in it can see show up on the radar.
func _update_spotted(delta: float) -> void:
	for s in spotted.keys():
		spotted[s] -= delta
		if spotted[s] <= 0.0 or not s.alive:
			spotted.erase(s)
	spot_t -= delta
	if spot_t > 0.0:
		return
	spot_t = 0.2
	for enemy in soldiers:
		if enemy.squad == 0 or not enemy.alive:
			continue
		for friend in soldiers:
			if friend.squad != 0 or not friend.alive:
				continue
			var eye: Vector3 = friend.eye_position()
			var target: Vector3 = enemy.position + Vector3(0, 1.3, 0)
			if eye.distance_to(target) > 60.0:
				continue
			var facing: Vector3 = friend.view_basis() * Vector3.FORWARD
			if facing.dot((target - eye).normalized()) < 0.35:
				continue
			if world.clear_line(eye, target) and not world.smoke_between(eye, target):
				spotted[enemy] = 1.0
				break
