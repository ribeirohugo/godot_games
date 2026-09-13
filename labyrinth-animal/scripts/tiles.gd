extends RefCounted
## The tile set. Each tile is a 3x3 patch of land ("1") and water ("0"), read row by row,
## where row 0 is the tile's north side and column 0 its west side.

const PATTERNS := [
	"000111000",  # 1  straight west-east
	"010010010",  # 2  straight north-south
	"010011000",  # 3  bend north-east
	"000011010",  # 4  bend east-south
	"000110010",  # 5  bend south-west
	"010110000",  # 6  bend west-north
	"010011010",  # 7  T north-east-south
	"000111010",  # 8  T east-south-west
	"010110010",  # 9  T south-west-north
	"010111000",  # 10 T west-north-east
	"010111010",  # 11 crossroads
	"010010000",  # 12 dead end north
	"000011000",  # 13 dead end east
	"000010010",  # 14 dead end south
	"000110000",  # 15 dead end west
	"111111111",  # 16 meadow
	"111101111",  # 17 ring
	"100110011",  # 18 stairs down-right
	"001011110",  # 19 stairs down-left
	"111000000",  # 20 north shore
	"000000111",  # 21 south shore
	"100100100",  # 22 west shore
	"001001001",  # 23 east shore
	"101101111",  # 24 U open north
	"111101101",  # 25 U open south
	"111100111",  # 26 U open east
	"111001111",  # 27 U open west
	"110010011",  # 28 zigzag
	"001111100",  # 29 zigzag across
	"111100100",  # 30 north-west shore
	"111001001",  # 31 north-east shore
	"100010001",  # 32 stepping stones (too far apart to walk)
]

const POINTS := [
	10, 10, 20, 20, 20, 20, 30, 30, 30, 30, 40, 50, 50, 50, 50, 5,
	60, 70, 70, 30, 30, 30, 30, 50, 50, 50, 50, 60, 60, 40, 40, 100,
]


static func count() -> int:
	return PATTERNS.size()


static func is_land(tile: int, x: int, y: int) -> bool:
	return PATTERNS[tile - 1][y * 3 + x] == "1"


static func points(tile: int) -> int:
	return POINTS[tile - 1]
