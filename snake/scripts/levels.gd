extends RefCounted
## The five campaign worlds and their levels.
##
## A level is numbered world-stage, so 3-2 is the second level of the third world.
## The worlds run from soft meadow grass down to the inferno, getting drier, faster
## and more crowded with hazards as they go.
##
## Every level paints its board from 16 rows of 24 characters:
##   `.`  open ground
##   `#`  wall - the snake dies on it, like the outer fence
##   `>`  where the snake starts and which way it heads (also `<`, `^`, `v`)
##   `H`  blade patrolling left and right along its row
##   `V`  blade patrolling up and down along its column
##   `A`  a portal; the two `A` cells link to each other, and `B` likewise
##
## `goal` is what clears the level:
##   {"kind": "apples", "count": n}   eat n apples (golden ones count too)
##   {"kind": "golden", "count": n}   eat n golden apples
##   {"kind": "length", "count": n}   grow to n body segments
##   {"kind": "survive", "count": n}  stay alive for n seconds
##
## Optional per level, filled in from DEFAULTS: `step` (seconds per move at the
## start), `speedup` (how much each apple shortens the step), `golden` (chance of
## a golden apple after each apple), `poison` (poison apples on the board at once)
## and `time` (countdown in seconds, 0 for no limit).
##
## A world's `theme` repaints the whole board. `back` is the page behind it, `light`
## and `dark` are the checker, `frame` is the border from outside in plus its stud
## colour, `wall` is the stone's edge, face and lit top, and `accent` tints the
## level's name and its progress bar. `decor` is a cumulative pick list of scatter
## kinds, drawn with the colours below it.

const COLS := 24
const ROWS := 16

const DEFAULTS := {
	"step": 0.12,
	"speedup": 0.0015,
	"golden": 0.25,
	"poison": 0,
	"time": 0.0,
}

const WORLDS := [
	{
		"name": "Meadow",
		"blurb": "Soft grass and room to think.",
		"theme": {
			"back": Color("16241a"),
			"light": Color("4f8a3c"),
			"dark": Color("467d35"),
			"frame": [Color("2b1d12"), Color("6b4a2b"), Color("8a6239"), Color("24170d"), Color("c9a26b")],
			"wall": [Color("22261f"), Color("5c6353"), Color("7f8872")],
			"accent": Color("a4d13a"),
			"decor": [["tuft", 0.6], ["flower", 0.85], ["pebble", 1.0]],
			"tuft": Color("64a64a"),
			"flowers": [Color("f4f1de"), Color("f7b2c4"), Color("b8c5ff")],
			"pebble": [Color("6f7a64"), Color("9aa38e")],
			"ember": Color("ffd23f"),
			"crack": Color("3c6b2e"),
			"bone": Color("e8e2cd"),
		},
		"levels": [
			{
				"name": "First Steps",
				"hint": "Open field, thirty apples. Plenty of room to learn how a long snake handles.",
				"goal": {"kind": "apples", "count": 30},
				"step": 0.15,
				"speedup": 0.0013,
				"golden": 0.15,
				"rows": [
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"....>...................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
				],
			},
			{
				"name": "Four Corners",
				"hint": "Stone in every corner. Thirty-two apples, and your own tail crowds the lanes as you grow.",
				"goal": {"kind": "apples", "count": 32},
				"step": 0.145,
				"speedup": 0.0013,
				"golden": 0.2,
				"rows": [
					"........................",
					"........................",
					"..####............####..",
					"..####............####..",
					"........................",
					"........................",
					"........................",
					"........................",
					"....>...................",
					"........................",
					"........................",
					"........................",
					"..####............####..",
					"..####............####..",
					"........................",
					"........................",
				],
			},
			{
				"name": "Tight Squeeze",
				"hint": "No apple count here - grow to thirty-six segments, which is thirty-two apples.",
				"goal": {"kind": "length", "count": 36},
				"step": 0.14,
				"speedup": 0.0013,
				"golden": 0.2,
				"rows": [
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"..........####..........",
					"....>.....####..........",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
					"........................",
				],
			},
			{
				"name": "The Orchard",
				"hint": "A grove of stone. Thirty-four apples without barging into a trunk.",
				"goal": {"kind": "apples", "count": 34},
				"step": 0.135,
				"speedup": 0.0013,
				"rows": [
					"........................",
					"....##....##....##......",
					"....##....##....##......",
					"........................",
					".......##....##....##...",
					".......##....##....##...",
					"........................",
					"....##....##....##......",
					"....##....##....##......",
					"....>...................",
					".......##....##....##...",
					".......##....##....##...",
					"........................",
					"....##....##....##......",
					"....##....##....##......",
					"........................",
				],
			},
		],
	},
	{
		"name": "Dustfields",
		"blurb": "The grass has gone to straw, and something is spinning out there.",
		"theme": {
			"back": Color("1e2118"),
			"light": Color("7e8a46"),
			"dark": Color("74803f"),
			"frame": [Color("241c12"), Color("5e4a2e"), Color("7a6440"), Color("1d160c"), Color("bda87c")],
			"wall": [Color("262419"), Color("6b6550"), Color("8e876c")],
			"accent": Color("d8c95f"),
			"decor": [["tuft", 0.5], ["pebble", 0.8], ["flower", 1.0]],
			"tuft": Color("9aa356"),
			"flowers": [Color("e8d9a0"), Color("cbbf86"), Color("d9c79b")],
			"pebble": [Color("7a7355"), Color("a39a75")],
			"ember": Color("ffd23f"),
			"crack": Color("5e5836"),
			"bone": Color("e0dabf"),
		},
		"levels": [
			{
				"name": "Dry Season",
				"hint": "Thickets of stone, and less room than the meadow gave you. Thirty-four apples.",
				"goal": {"kind": "apples", "count": 34},
				"step": 0.13,
				"speedup": 0.001,
				"rows": [
					"........................",
					"..###..............###..",
					"..###..............###..",
					"........................",
					"........................",
					".......#####..#####.....",
					"........................",
					"....>...................",
					"........................",
					".......#####..#####.....",
					"........................",
					"........................",
					"..###..............###..",
					"..###..............###..",
					"........................",
					"........................",
				],
			},
			{
				"name": "Windbreaks",
				"hint": "Four long walls, gaps at alternating ends. Thirty-six apples is a lot of laps.",
				"goal": {"kind": "apples", "count": 36},
				"step": 0.128,
				"speedup": 0.001,
				"rows": [
					"....>...................",
					"........................",
					"..##################....",
					"........................",
					"........................",
					"....##################..",
					"........................",
					"........................",
					"..##################....",
					"........................",
					"........................",
					"....##################..",
					"........................",
					"........................",
					"........................",
					"........................",
				],
			},
			{
				"name": "First Blades",
				"hint": "Blades sweep the open ground for thirty-four apples. They shred the head - the body they pass right over.",
				"goal": {"kind": "apples", "count": 34},
				"step": 0.125,
				"speedup": 0.001,
				"rows": [
					"........................",
					"........................",
					"......H.................",
					"........................",
					"..####..........####....",
					"........................",
					"........................",
					"........................",
					"....>...................",
					"........................",
					"........................",
					"........................",
					"..####..........####....",
					"........................",
					"................H.......",
					"........................",
				],
			},
			{
				"name": "The Thresher",
				"hint": "Four blades now, and they cross. Thirty-six apples with your head always moving.",
				"goal": {"kind": "apples", "count": 36},
				"step": 0.12,
				"speedup": 0.001,
				"rows": [
					"........................",
					"...####........####.....",
					"...####........####.....",
					"........................",
					".........H..............",
					"........................",
					".......V........V.......",
					"........................",
					"....>...................",
					"........................",
					".............H..........",
					"........................",
					"...####........####.....",
					"...####........####.....",
					"........................",
					"........................",
				],
			},
		],
	},
	{
		"name": "Badlands",
		"blurb": "Baked red rock. The fruit out here is not all good for you.",
		"theme": {
			"back": Color("241a12"),
			"light": Color("a37a4a"),
			"dark": Color("996f42"),
			"frame": [Color("2b2016"), Color("7a5533"), Color("9c6f45"), Color("251a10"), Color("d4b183")],
			"wall": [Color("2a1d16"), Color("7a5340"), Color("9c6d52")],
			"accent": Color("f0a83d"),
			"decor": [["pebble", 0.4], ["crack", 0.75], ["bone", 1.0]],
			"tuft": Color("9c8a52"),
			"flowers": [Color("e8c9a0"), Color("d4a67a"), Color("c9b08a")],
			"pebble": [Color("8a6b48"), Color("b0906a")],
			"ember": Color("ffb03f"),
			"crack": Color("6f4c2c"),
			"bone": Color("e6dcc4"),
		},
		"levels": [
			{
				"name": "Cracked Earth",
				"hint": "Purple apples are rotten. One costs you three segments and fifteen points - and kills outright if you have not got three to spare.",
				"goal": {"kind": "apples", "count": 36},
				"step": 0.118,
				"speedup": 0.0008,
				"poison": 2,
				"rows": [
					"........................",
					"..#####.........#####...",
					"........................",
					"........................",
					".........#####..........",
					"........................",
					"........................",
					"....>...................",
					"........................",
					"........................",
					".........#####..........",
					"........................",
					"........................",
					"..#####.........#####...",
					"........................",
					"........................",
				],
			},
			{
				"name": "Mirage",
				"hint": "Twelve golden apples before the clock runs out. Red ones only summon the next gold.",
				"goal": {"kind": "golden", "count": 12},
				"step": 0.115,
				"speedup": 0.0008,
				"golden": 0.5,
				"time": 170.0,
				"rows": [
					"........................",
					"........................",
					"...........##...........",
					"..........####..........",
					".........##..##.........",
					"........##....##........",
					".......##......##.......",
					"........................",
					".......##......##.......",
					"........##....##........",
					".........##..##.........",
					"..........####..........",
					"...........##...........",
					"........................",
					"....>...................",
					"........................",
				],
			},
			{
				"name": "Scorpion Run",
				"hint": "Blades and rot in the same canyon, for thirty-eight apples. Watch both.",
				"goal": {"kind": "apples", "count": 38},
				"step": 0.112,
				"speedup": 0.0008,
				"poison": 2,
				"rows": [
					"........................",
					"....#########...........",
					"........................",
					"........................",
					"......V..........V......",
					"........................",
					"...........#########....",
					"........................",
					"....>...................",
					"........................",
					"....#########...........",
					"........................",
					"......H..........H......",
					"........................",
					"...........#########....",
					"........................",
				],
			},
			{
				"name": "The Canyon",
				"hint": "Narrow lanes and three rotten apples. Forty segments, and every bite of rot sets you back three.",
				"goal": {"kind": "length", "count": 40},
				"step": 0.108,
				"speedup": 0.0008,
				"poison": 3,
				"rows": [
					"........................",
					"..####..####..####..###.",
					"........................",
					"........................",
					".####..####..####..####.",
					"........................",
					"........................",
					"....>...................",
					"........................",
					"........................",
					".####..####..####..####.",
					"........................",
					"........................",
					"..####..####..####..###.",
					"........................",
					"........................",
				],
			},
		],
	},
	{
		"name": "Ashlands",
		"blurb": "Cold ash over old fire. The ground here does not stay put.",
		"theme": {
			"back": Color("121116"),
			"light": Color("3a3a3f"),
			"dark": Color("333338"),
			"frame": [Color("1a1a1e"), Color("44454d"), Color("5c5e68"), Color("121215"), Color("8b8f9c")],
			"wall": [Color("17161a"), Color("5d5c68"), Color("85838f")],
			"accent": Color("c2bcd0"),
			"decor": [["pebble", 0.45], ["ember", 0.8], ["crack", 1.0]],
			"tuft": Color("5e5a55"),
			"flowers": [Color("8b8f9c"), Color("6f6b72"), Color("a6a2ad")],
			"pebble": [Color("5a5962"), Color("7a7984")],
			"ember": Color("ff8a3d"),
			"crack": Color("6f5f57"),
			"bone": Color("cfc7bb"),
		},
		"levels": [
			{
				"name": "Ashfall",
				"hint": "Matching portals link up: ride one and the rest of you follows. Thirty-eight apples.",
				"goal": {"kind": "apples", "count": 38},
				"step": 0.105,
				"speedup": 0.00075,
				"rows": [
					"........................",
					"..A..................A..",
					"........................",
					"........................",
					"......#####..#####......",
					"......#..........#......",
					".................#......",
					"......#..........#......",
					"......#.................",
					"......#..........#......",
					"......#####..#####......",
					"........................",
					"........................",
					"..B..................B..",
					"........................",
					"....>...................",
				],
			},
			{
				"name": "Emberways",
				"hint": "Two portal pairs and two blades, for forty apples. The short way is not always the safe way.",
				"goal": {"kind": "apples", "count": 40},
				"step": 0.102,
				"speedup": 0.00075,
				"rows": [
					"..A..................A..",
					"........................",
					"...####..........####...",
					"........................",
					"........H...............",
					"........................",
					"........................",
					"....>...................",
					"........................",
					"........................",
					"...............H........",
					"........................",
					"...####..........####...",
					"........................",
					"........................",
					"..B..................B..",
				],
			},
			{
				"name": "The Rift",
				"hint": "Portals across a walled rift, rot on both sides, and forty-four segments to grow.",
				"goal": {"kind": "length", "count": 44},
				"step": 0.1,
				"speedup": 0.00075,
				"poison": 2,
				"rows": [
					"........................",
					"......#############.....",
					"........................",
					"..A..................A..",
					"........................",
					"........................",
					"....>...................",
					"........................",
					"........................",
					"........................",
					"..B..................B..",
					"........................",
					".....#############......",
					"........................",
					"........................",
					"........................",
				],
			},
			{
				"name": "Cinder Run",
				"hint": "No apples to chase. Ninety seconds - and eating only makes you longer and harder to steer.",
				"goal": {"kind": "survive", "count": 90},
				"step": 0.097,
				"speedup": 0.0,
				"poison": 2,
				"rows": [
					"........................",
					"........................",
					".....########...........",
					"........................",
					"..H..................H..",
					"........................",
					"..........########......",
					"........................",
					".......V........V.......",
					"........................",
					".....########...........",
					"........................",
					"..H..................H..",
					"........................",
					"....>...................",
					"........................",
				],
			},
		],
	},
	{
		"name": "Inferno",
		"blurb": "Black rock and open fire. Everything at once, and nothing forgiving.",
		"theme": {
			"back": Color("120606"),
			"light": Color("2b0f0a"),
			"dark": Color("240b07"),
			"frame": [Color("0a0303"), Color("3d1610"), Color("63241a"), Color("060202"), Color("ff7a3c")],
			"wall": [Color("120504"), Color("522016"), Color("8c3a22")],
			"accent": Color("ff7a45"),
			"decor": [["ember", 0.55], ["crack", 0.85], ["bone", 1.0]],
			"tuft": Color("5c241a"),
			"flowers": [Color("ff7a3c"), Color("ffb03f"), Color("e04a1f")],
			"pebble": [Color("48180f"), Color("6b2a1a")],
			"ember": Color("ff5a1f"),
			"crack": Color("ff3d1a"),
			"bone": Color("d8c6b0"),
		},
		"levels": [
			{
				"name": "Brimstone",
				"hint": "Broken ground, four blades and rot, for forty-two apples. This is the shallow end.",
				"goal": {"kind": "apples", "count": 42},
				"step": 0.095,
				"speedup": 0.0007,
				"poison": 2,
				"rows": [
					"........................",
					"...##....##....##....##.",
					"........................",
					".......H.........H......",
					"........................",
					"..##....##....##....##..",
					"........................",
					"....>...................",
					"........................",
					"...##....##....##....##.",
					"........................",
					".......V.........V......",
					"........................",
					"..##....##....##....##..",
					"........................",
					"........................",
				],
			},
			{
				"name": "Hellmouth",
				"hint": "Fifteen golden apples in three and a half minutes, with the portals as the only quick way across.",
				"goal": {"kind": "golden", "count": 15},
				"step": 0.092,
				"speedup": 0.0007,
				"golden": 0.55,
				"time": 210.0,
				"poison": 2,
				"rows": [
					"..A..................A..",
					"........................",
					"....##############......",
					"........................",
					"........H...............",
					"........................",
					"......##########........",
					"........................",
					"....>...................",
					"........................",
					"......##########........",
					"........................",
					"...............H........",
					"........................",
					"....##############......",
					"..B..................B..",
				],
			},
			{
				"name": "The Furnace",
				"hint": "Two minutes in the fire. Blades, portals, rot, and nowhere quiet to wait it out.",
				"goal": {"kind": "survive", "count": 120},
				"step": 0.09,
				"speedup": 0.0,
				"poison": 3,
				"rows": [
					"..A..................A..",
					"..####..........####....",
					"........................",
					"......V..........V......",
					"........................",
					"..........####..........",
					"........................",
					"....>...................",
					"........................",
					"..........####..........",
					"........................",
					"......H..........H......",
					"........................",
					"..####..........####....",
					"........................",
					"..B..................B..",
				],
			},
			{
				"name": "The Gauntlet",
				"hint": "Everything at once, and forty-eight segments to reach. Good luck.",
				"goal": {"kind": "length", "count": 48},
				"step": 0.087,
				"speedup": 0.0007,
				"poison": 3,
				"rows": [
					"..A..................A..",
					"........................",
					"...####..........####...",
					"...####..........####...",
					"........H...............",
					"........................",
					".......####..####.......",
					"........................",
					"....>...................",
					"........................",
					".......####..####.......",
					"........................",
					"...............H........",
					"...####..........####...",
					"...####..........####...",
					"..B..................B..",
				],
			},
		],
	},
]


static func world_count() -> int:
	return WORLDS.size()


static func stage_count(world: int) -> int:
	return WORLDS[world].levels.size()


static func total() -> int:
	var sum := 0
	for entry in WORLDS:
		sum += entry.levels.size()
	return sum


## Levels are unlocked in one running order, so each one also has a flat number.
static func flat(world: int, stage: int) -> int:
	var sum := 0
	for i in world:
		sum += WORLDS[i].levels.size()
	return sum + stage


## The world and stage a flat number lands on, clamped to the last level.
static func split(index: int) -> Vector2i:
	var left := index
	for world in WORLDS.size():
		var size: int = WORLDS[world].levels.size()
		if left < size:
			return Vector2i(world, left)
		left -= size
	var last: int = WORLDS.size() - 1
	return Vector2i(last, WORLDS[last].levels.size() - 1)


static func label(world: int, stage: int) -> String:
	return "%d-%d" % [world + 1, stage + 1]


static func theme(world: int) -> Dictionary:
	return WORLDS[world].theme


static func world_name(world: int) -> String:
	return WORLDS[world].name


static func world_blurb(world: int) -> String:
	return WORLDS[world].blurb


## A level with the optional fields filled in from DEFAULTS.
static func get_level(world: int, stage: int) -> Dictionary:
	var data: Dictionary = DEFAULTS.duplicate()
	data.merge(WORLDS[world].levels[stage], true)
	return data
