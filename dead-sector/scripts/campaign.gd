extends RefCounted
## The campaign's catalog: the missions in order, the looks of each place (themes), the kinds of
## enemies and the allies. Each mission's own map and script lives in scripts/missions/.

const MISSIONS := [
	preload("res://scripts/missions/m01.gd"),
]

## How each place looks. Merged under an area's own settings before the world is built.
const THEMES := {
	"night": {"sky": Color(0.04, 0.06, 0.13), "horizon": Color(0.16, 0.15, 0.2), "ground": Color(0.04, 0.04, 0.05),
		"sun": Vector3(-38, 30, 0), "sun_color": Color(0.6, 0.7, 1.0), "sun_energy": 0.7, "ambient": 0.55,
		"ambient_color": Color(0.32, 0.38, 0.55), "fog": 0.009, "fog_color": Color(0.07, 0.08, 0.12), "exposure": 1.35,
		"glow": 0.7, "dark": true},
	"burning": {"sky": Color(0.03, 0.02, 0.03), "horizon": Color(0.3, 0.12, 0.05), "ground": Color(0.04, 0.03, 0.03),
		"sun": Vector3(-35, 60, 0), "sun_color": Color(1.0, 0.55, 0.3), "sun_energy": 0.6, "ambient": 0.55,
		"ambient_color": Color(0.45, 0.32, 0.28),
		"fog": 0.016, "fog_color": Color(0.18, 0.08, 0.04), "exposure": 1.15, "glow": 0.8, "haze": 0.01,
		"haze_color": Color(1.0, 0.6, 0.4), "dark": true},
	"dusk": {"sky": Color(0.22, 0.26, 0.4), "horizon": Color(0.85, 0.5, 0.3), "ground": Color(0.2, 0.16, 0.12),
		"sun": Vector3(-10, 60, 0), "sun_color": Color(1.0, 0.62, 0.38), "sun_energy": 1.0, "ambient": 0.45,
		"fog": 0.006, "exposure": 1.0},
	"overcast": {"sky": Color(0.45, 0.48, 0.5), "horizon": Color(0.62, 0.63, 0.62), "ground": Color(0.3, 0.3, 0.3),
		"sun": Vector3(-60, 20, 0), "sun_color": Color(0.9, 0.92, 1.0), "sun_energy": 0.5, "ambient": 0.6, "fog": 0.008},
	"indoor": {"sky": Color(0.1, 0.1, 0.1), "horizon": Color(0.12, 0.12, 0.12), "ground": Color(0.05, 0.05, 0.05),
		"sun": Vector3(-60, 20, 0), "sun_color": Color(1, 1, 1), "sun_energy": 0.0, "ambient": 0.5,
		"ambient_color": Color(0.4, 0.42, 0.45),
		"fog": 0.006, "fog_color": Color(0.05, 0.05, 0.06), "exposure": 1.2, "glow": 0.5},
	"dark": {"sky": Color(0.02, 0.02, 0.02), "horizon": Color(0.03, 0.03, 0.03), "ground": Color(0.02, 0.02, 0.02),
		"sun": Vector3(-60, 20, 0), "sun_color": Color(1, 1, 1), "sun_energy": 0.0, "ambient": 0.35,
		"ambient_color": Color(0.22, 0.25, 0.3),
		"fog": 0.02, "fog_color": Color(0.02, 0.02, 0.025), "exposure": 1.2, "glow": 0.7, "haze": 0.015,
		"haze_color": Color(0.7, 0.75, 0.8), "dark": true},
}

## Kinds of enemy: look, side, toughness, brain and weapons.
const ENEMIES := {
	"rogue": {"faction": "rogue", "team": "def", "health": 100.0, "armor": 50.0, "brain": "grunt",
		"guns": ["mx9", "ar7", "ar7", "pump", "u45"], "pistol": "k45"},
	"sniper": {"faction": "rogue", "team": "def", "health": 100.0, "armor": 50.0, "brain": "grunt", "guns": ["scout"], "pistol": "k45"},
	"black": {"faction": "black", "team": "def", "health": 100.0, "armor": 100.0, "helmet": true, "brain": "grunt",
		"guns": ["m4", "f90", "m4", "mx9"], "pistol": "m25", "grenades": ["he", "flash"], "skill": 1},
	"army": {"faction": "army", "team": "def", "health": 100.0, "armor": 100.0, "helmet": true, "brain": "grunt",
		"guns": ["m4", "f90", "viper"], "pistol": "m25"},
	"infected": {"faction": "infected", "team": "x", "health": 65.0, "brain": "beast", "gun": "claws",
		"blood": Color(0.3, 0.05, 0.03)},
	"mutant": {"faction": "mutant", "team": "x", "health": 420.0, "scale": 1.3, "brain": "beast", "gun": "maul",
		"blood": Color(0.35, 0.25, 0.05)},
	"first": {"faction": "first", "team": "x", "health": 1600.0, "scale": 1.05, "brain": "boss", "gun": "helix",
		"blood": Color(0.2, 0.7, 0.9)},
}

## Mercer's people.
const ALLIES := {
	"reyes": {"nick": "Reyes", "gun": "m4", "pistol": "m25"},
	"volkov": {"nick": "Volkov", "gun": "pump", "pistol": "m25"},
	"okafor": {"nick": "Okafor", "gun": "f90", "pistol": "k45"},
}

## Who speaks, and the color of their name in the subtitles.
const SPEAKERS := {
	"mercer": Color(0.9, 0.9, 0.85), "reyes": Color(0.5, 0.85, 1.0), "volkov": Color(0.6, 1.0, 0.55),
	"hale": Color(1.0, 0.75, 0.3), "pilot": Color(0.8, 0.8, 1.0), "okafor": Color(1.0, 0.6, 0.8),
	"radio": Color(0.7, 0.7, 0.7), "tv": Color(0.6, 0.7, 1.0), "voss": Color(0.8, 1.0, 0.9), "first": Color(0.3, 0.9, 1.0),
}

const DIFFICULTY := [
	{"taken": 0.4, "skill": 0},
	{"taken": 0.7, "skill": 1},
	{"taken": 1.0, "skill": 2},
	{"taken": 1.35, "skill": 3},
]


static func count() -> int:
	return MISSIONS.size()


static func mission(i: int) -> Dictionary:
	return MISSIONS[i].DATA
