extends RefCounted
## Every weapon and piece of gear, with the numbers that drive it. Distances are meters, times seconds,
## angles radians. The values follow the classic round-based shooters: a rifle's headshot kills through
## a helmet, SMGs pay more per kill, the sniper rifle is deadly but slow and pays little.
##
##   slot       0 primary, 1 pistol, 2 knife, 3 grenade, 4 bomb
##   team       "att" or "def" when only that side can buy it
##   damage     per bullet (per pellet for the shotgun), before hit-group and armor
##   pen        share of the damage that goes through armor
##   rate       seconds between shots
##   spread     inaccuracy standing still;  move: extra at full running speed
##   recoil     view kick per shot;  falloff: damage kept per 12.7 m
##   speed      running speed while holding it
##   reward     money for a kill with it
##   scope      zoom levels of a sniper scope (camera field of view, degrees)
##   ads        field of view while aiming down the gun's own sights

const HEAD := 4.0
const STOMACH := 1.25
const LEGS := 0.75

const LIST := {
	"knife": {"name": "Knife", "slot": 2, "kind": "knife", "price": 0, "damage": 40.0, "pen": 0.85,
			"rate": 0.45, "reach": 1.9, "speed": 6.35, "reward": 1500},

	"p18": {"name": "P-18", "ads": 62.0, "slot": 1, "kind": "pistol", "team": "att", "price": 200, "damage": 30.0, "pen": 0.47,
			"rate": 0.15, "mag": 20, "reserve": 120, "reload": 2.2, "speed": 6.1, "spread": 0.012, "move": 0.035,
			"recoil": 0.012, "falloff": 0.85, "reward": 300},
	"k45": {"name": "K-45", "ads": 62.0, "slot": 1, "kind": "pistol", "team": "def", "price": 200, "damage": 35.0, "pen": 0.5,
			"rate": 0.17, "mag": 12, "reserve": 36, "reload": 2.2, "speed": 6.1, "spread": 0.008, "move": 0.03,
			"recoil": 0.015, "falloff": 0.91, "reward": 300},
	"m25": {"name": "M-25", "ads": 62.0, "slot": 1, "kind": "pistol", "price": 300, "damage": 38.0, "pen": 0.64,
			"rate": 0.15, "mag": 13, "reserve": 26, "reload": 2.2, "speed": 6.1, "spread": 0.011, "move": 0.04,
			"recoil": 0.02, "falloff": 0.86, "reward": 300},
	"magnum": {"name": "Magnum .50", "ads": 58.0, "slot": 1, "kind": "magnum", "price": 700, "damage": 63.0, "pen": 0.93,
			"rate": 0.25, "mag": 7, "reserve": 35, "reload": 2.2, "speed": 5.85, "spread": 0.01, "move": 0.07,
			"recoil": 0.05, "falloff": 0.81, "reward": 300},

	"mx9": {"name": "MX-9", "ads": 60.0, "slot": 0, "kind": "smg", "price": 1250, "damage": 26.0, "pen": 0.6, "auto": true,
			"rate": 0.075, "mag": 30, "reserve": 120, "reload": 2.6, "speed": 6.1, "spread": 0.02, "move": 0.02,
			"recoil": 0.012, "falloff": 0.87, "reward": 600},
	"u45": {"name": "U-45", "ads": 58.0, "slot": 0, "kind": "smg", "price": 1200, "damage": 35.0, "pen": 0.65, "auto": true,
			"rate": 0.09, "mag": 25, "reserve": 100, "reload": 3.5, "speed": 5.9, "spread": 0.018, "move": 0.025,
			"recoil": 0.016, "falloff": 0.85, "reward": 600},
	"pump": {"name": "Pump-12", "ads": 64.0, "slot": 0, "kind": "shotgun", "price": 1050, "damage": 26.0, "pen": 0.5,
			"pellets": 9, "rate": 0.88, "mag": 8, "reserve": 32, "reload": 3.0, "speed": 5.6, "spread": 0.07,
			"move": 0.03, "recoil": 0.06, "falloff": 0.7, "reward": 900},
	"viper": {"name": "Viper", "ads": 54.0, "slot": 0, "kind": "rifle", "team": "att", "price": 1800, "damage": 30.0, "pen": 0.775,
			"auto": true, "rate": 0.09, "mag": 35, "reserve": 90, "reload": 3.0, "speed": 5.9, "spread": 0.007,
			"move": 0.09, "recoil": 0.018, "falloff": 0.98, "reward": 300},
	"f90": {"name": "F-90", "ads": 52.0, "slot": 0, "kind": "rifle", "team": "def", "price": 2050, "damage": 30.0, "pen": 0.7,
			"auto": true, "rate": 0.09, "mag": 25, "reserve": 90, "reload": 3.3, "speed": 5.9, "spread": 0.006,
			"move": 0.09, "recoil": 0.017, "falloff": 0.96, "reward": 300},
	"ar7": {"name": "AR-7", "ads": 54.0, "slot": 0, "kind": "ak", "team": "att", "price": 2700, "damage": 36.0, "pen": 0.775,
			"auto": true, "rate": 0.1, "mag": 30, "reserve": 90, "reload": 2.5, "speed": 5.46, "spread": 0.005,
			"move": 0.11, "recoil": 0.022, "falloff": 0.98, "reward": 300},
	"m4": {"name": "M4 Sentinel", "ads": 50.0, "slot": 0, "kind": "m4", "team": "def", "price": 3100, "damage": 33.0, "pen": 0.7,
			"auto": true, "rate": 0.09, "mag": 30, "reserve": 90, "reload": 3.1, "speed": 5.72, "spread": 0.004,
			"move": 0.1, "recoil": 0.019, "falloff": 0.97, "reward": 300},
	"scout": {"name": "Scout", "slot": 0, "kind": "scout", "price": 1700, "damage": 88.0, "pen": 0.85,
			"rate": 1.25, "mag": 10, "reserve": 90, "reload": 3.7, "speed": 6.1, "spread": 0.002, "unscoped": 0.035,
			"move": 0.08, "recoil": 0.04, "falloff": 0.98, "scope": [30.0], "reward": 300},
	"longbow": {"name": "Longbow", "slot": 0, "kind": "sniper", "price": 4750, "damage": 115.0, "pen": 0.975,
			"rate": 1.46, "mag": 5, "reserve": 30, "reload": 3.7, "speed": 5.08, "spread": 0.001, "unscoped": 0.1,
			"move": 0.16, "recoil": 0.06, "falloff": 0.99, "scope": [26.0, 10.0], "reward": 100},

	"he": {"name": "HE Grenade", "slot": 3, "kind": "he", "price": 300, "speed": 6.1, "rate": 1.0, "reward": 300},
	"flash": {"name": "Flashbang", "slot": 3, "kind": "flash", "price": 200, "speed": 6.1, "rate": 1.0, "reward": 300},
	"smoke": {"name": "Smoke Grenade", "slot": 3, "kind": "smoke", "price": 300, "speed": 6.1, "rate": 1.0, "reward": 300},
	"bomb": {"name": "Bomb", "slot": 4, "kind": "bomb", "price": 0, "speed": 6.1, "rate": 0.5, "reward": 300},

	# Campaign only (never in the shop): what the HELIX creatures fight with, and the First's rifle.
	"claws": {"name": "Claws", "slot": 2, "kind": "claws", "price": 0, "damage": 16.0, "pen": 1.0,
			"rate": 0.7, "reach": 2.0, "speed": 6.9, "reward": 0},
	"maul": {"name": "Maul", "slot": 2, "kind": "claws", "price": 0, "damage": 42.0, "pen": 1.0,
			"rate": 1.3, "reach": 2.6, "speed": 5.0, "reward": 0},
	"helix": {"name": "HX-1", "slot": 0, "kind": "rifle", "price": 0, "damage": 24.0, "pen": 0.9, "auto": true,
			"rate": 0.11, "mag": 40, "reserve": 999, "reload": 1.6, "speed": 6.4, "spread": 0.012, "move": 0.02,
			"recoil": 0.01, "falloff": 0.97, "reward": 0},
}

## What the buy menu offers, column by column. Gear ids are not weapons: rules.gd handles them.
const SHOP := [
	["buy_pistols", ["p18", "k45", "m25", "magnum"]],
	["buy_heavy", ["pump", "mx9", "u45"]],
	["buy_rifles", ["viper", "f90", "ar7", "m4", "scout", "longbow"]],
	["buy_gear", ["vest", "vest_helmet", "kit", "he", "flash", "smoke"]],
]
const GEAR := {
	"vest": {"name": "Kevlar Vest", "price": 650},
	"vest_helmet": {"name": "Kevlar + Helmet", "price": 1000},
	"kit": {"name": "Defuse Kit", "price": 400, "team": "def"},
}
const MAX_GRENADES := {"he": 1, "flash": 2, "smoke": 1}
const GRENADE_LIMIT := 4
const START_PISTOL := {"att": "p18", "def": "k45"}


static func data(id: String) -> Dictionary:
	return LIST.get(id, LIST["knife"])


static func is_gun(id: String) -> bool:
	return LIST.has(id) and LIST[id].has("mag")


static func price(id: String) -> int:
	if GEAR.has(id):
		return GEAR[id]["price"]
	return LIST[id]["price"]


static func name_of(id: String) -> String:
	if GEAR.has(id):
		return GEAR[id]["name"]
	return LIST[id]["name"]


## Which side can buy it: "" for both.
static func team_of(id: String) -> String:
	if GEAR.has(id):
		return GEAR[id].get("team", "")
	return LIST[id].get("team", "")
