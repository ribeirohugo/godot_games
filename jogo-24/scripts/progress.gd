extends RefCounted
## Brain training progress: the daily streak (days in a row with at least one finished card), brain points,
## brain levels, the daily goal and badges. Pure logic; main.gd draws it and saves it (see to_dict()).
##
## Points for a solved card: 10 · 20 · 30 · 40 by difficulty, ×1.5 in Double Cards, +10 under 30 s or
## +5 under 60 s, +5 without viewing the solution, and on the first win of the day +5 per streak day
## (up to +35). Viewing the solution halves the base points and drops every bonus. A lost card scores
## nothing but still counts as a day played. Each full week of the streak gives +100, the daily goal +20.
##
## Brain levels climb fast at first and then slow down: level 10 takes about a year of intensive daily
## play. At most DAILY_CAP points a day count (the 7-day bonus comes on top), so even the most intense
## player earns under 190,000 points in a year and can't pass level 10 (level 11 needs 250,000) in their
## first year. Past level 10 every level costs another 150,000 points.

const LEVEL_POINTS := [10, 20, 30, 40]
const DAILY_GOAL := 3  # cards solved per day
const GOAL_BONUS := 20
const WEEK := 7
const WEEK_BONUS := 100
const DAILY_CAP := 500
## Points needed for brain levels 1-10; their names are "rank_1".."rank_10".
const LEVELS := [0, 100, 500, 1500, 4000, 9000, 20000, 40000, 75000, 150000]
## Level 11 and up ("rank_legend"): LEGEND_START, then LEGEND_STEP more for each level.
const LEGEND_START := 250000
const LEGEND_STEP := 150000
## Badges in display order; each has "b_<id>" (name) and "b_<id>_desc" texts.
const BADGES := ["first", "week", "quick", "solo", "double", "expert"]
const QUICK_SECONDS := 20.0
const SOLO_WINS := 10

var points := 0
var streak := 0  # days in a row, ending on last_day
var best_streak := 0
var last_day := -1  # day number of the last day played
var goal_day := -1
var goal_count := 0  # cards solved on goal_day
var solo_wins := 0  # cards solved without viewing the solution
var badges := {}  # badge id -> true
var day_points := 0  # points counted towards DAILY_CAP on day_points_day
var day_points_day := -1


## Today's local date as a day number (days since 1970), so consecutive days differ by one.
static func today() -> int:
	var d := Time.get_date_dict_from_system()
	var noon := {"year": d.year, "month": d.month, "day": d.day, "hour": 12, "minute": 0, "second": 0}
	return int(Time.get_unix_time_from_datetime_dict(noon) / 86400)


## The streak as it stands on `day`: it breaks once a whole day passes without playing.
func current_streak(day: int) -> int:
	return streak if last_day >= day - 1 else 0


## Cards solved on `day`, towards the daily goal.
func goal_progress(day: int) -> int:
	return goal_count if goal_day == day else 0


## Points needed for brain level `index` + 1 (index 0 is level 1). There is no top level.
static func threshold(index: int) -> int:
	return LEVELS[index] if index < LEVELS.size() else LEGEND_START + (index - LEVELS.size()) * LEGEND_STEP


## The name key of brain level `index` + 1.
static func rank_key(index: int) -> String:
	return "rank_%d" % (index + 1) if index < LEVELS.size() else "rank_legend"


func rank_index() -> int:
	var index := 0
	while points >= threshold(index + 1):
		index += 1
	return index


## Points still needed for the next brain level.
func points_to_next() -> int:
	return threshold(rank_index() + 1) - points


## Share of the way from this brain level to the next.
func rank_progress() -> float:
	var index := rank_index()
	var low := threshold(index)
	return float(points - low) / float(threshold(index + 1) - low)


## Points counted towards today's DAILY_CAP.
func points_today(day: int) -> int:
	return day_points if day_points_day == day else 0


## Records a finished card and returns what it earned:
## {"points": total, "parts": [[text key, points], ...], "helped": bool, "capped": bool (the daily limit cut points),
## "events": [{"kind", ...}, ...]}.
## Event kinds: "first_day", "streak" (days), "week" (days), "goal", "badge" (id), "rank" (key).
func record_round(won: bool, level: int, mode: int, seconds: float, helped: bool, day: int) -> Dictionary:
	var reward := {"points": 0, "parts": [], "helped": helped, "capped": false, "events": []}
	var rank_before := rank_index()
	if day_points_day != day:
		day_points_day = day
		day_points = 0
	# The day counts as played whether the card was won or lost.
	if last_day != day:
		streak = streak + 1 if last_day == day - 1 else 1
		last_day = day
		best_streak = maxi(best_streak, streak)
		if streak == 1:
			reward.events.append({"kind": "first_day"})
		elif streak % WEEK == 0:
			reward.events.append({"kind": "week", "days": streak})
			_add(reward, "week_challenge", WEEK_BONUS, false)
			_badge(reward, "week")
		else:
			reward.events.append({"kind": "streak", "days": streak})
	if won:
		if goal_day != day:
			goal_day = day
			goal_count = 0
		var first_win_today := goal_count == 0
		var base: int = LEVEL_POINTS[level]
		if mode == 1:
			base = base * 3 / 2
		if helped:
			_add(reward, "r_solved", base / 2)
		else:
			_add(reward, "r_solved", base)
			if seconds < 30.0:
				_add(reward, "r_fast", 10)
			elif seconds < 60.0:
				_add(reward, "r_fast", 5)
			_add(reward, "r_solo", 5)
			if first_win_today:
				_add(reward, "r_daily", 5 * mini(streak, WEEK))
			solo_wins += 1
		goal_count += 1
		if goal_count == DAILY_GOAL:
			_add(reward, "daily_goal", GOAL_BONUS)
			reward.events.append({"kind": "goal"})
		_badge(reward, "first")
		if mode == 1:
			_badge(reward, "double")
		if level == 3:
			_badge(reward, "expert")
		if not helped and seconds < QUICK_SECONDS:
			_badge(reward, "quick")
		if solo_wins >= SOLO_WINS:
			_badge(reward, "solo")
	if rank_index() > rank_before:
		reward.events.append({"kind": "rank", "key": rank_key(rank_index())})
	return reward


## Adds points, cut to what is left of today's DAILY_CAP unless `capped` is false.
func _add(reward: Dictionary, key: String, amount: int, capped := true) -> void:
	if capped:
		var room := maxi(DAILY_CAP - day_points, 0)
		if amount > room:
			amount = room
			reward.capped = true
		day_points += amount
	if amount <= 0:
		return
	points += amount
	reward.points += amount
	reward.parts.append([key, amount])


func _badge(reward: Dictionary, id: String) -> void:
	if badges.has(id):
		return
	badges[id] = true
	reward.events.append({"kind": "badge", "id": id})


func to_dict() -> Dictionary:
	return {"points": points, "streak": streak, "best_streak": best_streak, "last_day": last_day, "goal_day": goal_day,
			"goal_count": goal_count, "solo_wins": solo_wins, "badges": badges.keys(), "day_points": day_points,
			"day_points_day": day_points_day}


func from_dict(data: Dictionary) -> void:
	points = maxi(int(data.get("points", 0)), 0)
	streak = maxi(int(data.get("streak", 0)), 0)
	best_streak = maxi(int(data.get("best_streak", 0)), streak)
	last_day = int(data.get("last_day", -1))
	goal_day = int(data.get("goal_day", -1))
	goal_count = maxi(int(data.get("goal_count", 0)), 0)
	solo_wins = maxi(int(data.get("solo_wins", 0)), 0)
	day_points = clampi(int(data.get("day_points", 0)), 0, DAILY_CAP)
	day_points_day = int(data.get("day_points_day", -1))
	badges.clear()
	var saved: Variant = data.get("badges", [])
	if saved is Array:
		for id in saved:
			if str(id) in BADGES:
				badges[str(id)] = true
