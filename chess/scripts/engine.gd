extends RefCounted
## Chess rules and the computer player.
## The board is a 10x12 mailbox: squares 21..98 are on the board (a8 = 21, h8 = 28, a1 = 91,
## h1 = 98) and every other cell is OFF, so moves that leave the board stop without bounds checks.
## Pieces are PAWN..KING for White and the same | BLACK_BIT for Black. A move is one int, see _move().
## The computer searches a copy of the game (copy_from) in its own thread and returns with think().

const EMPTY := 0
const OFF := -1
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const WHITE := 0
const BLACK := 1
const BLACK_BIT := 8

const FLAG_EP := 1
const FLAG_CASTLE := 2
const FLAG_DOUBLE := 4

const KNIGHT_STEPS := [-21, -19, -12, -8, 8, 12, 19, 21]
const BISHOP_STEPS := [-11, -9, 9, 11]
const ROOK_STEPS := [-10, -1, 1, 10]
const KING_STEPS := [-11, -10, -9, -1, 1, 9, 10, 11]

const VALUE := [0, 100, 320, 330, 500, 900, 0]
const PHASE := [0, 0, 1, 1, 2, 4, 0]  # game phase weights: 24 with all pieces, 0 with none
const MATE := 100000
const MATE_NEAR := MATE - 1000  # scores past this are mates

## Castling rights: 1 White short, 2 White long, 4 Black short, 8 Black long.
## A move from or to one of these squares keeps only the rights in the mask.
const CASTLE_MASK := {95: 12, 98: 14, 91: 13, 25: 3, 28: 11, 21: 7}

const TT_EXACT := 0
const TT_LOWER := 1
const TT_UPPER := 2

# Piece-square tables (Simplified Evaluation Function), a8 first, from White's side.
const PST_PAWN := [
	0, 0, 0, 0, 0, 0, 0, 0,
	50, 50, 50, 50, 50, 50, 50, 50,
	10, 10, 20, 30, 30, 20, 10, 10,
	5, 5, 10, 25, 25, 10, 5, 5,
	0, 0, 0, 20, 20, 0, 0, 0,
	5, -5, -10, 0, 0, -10, -5, 5,
	5, 10, 10, -20, -20, 10, 10, 5,
	0, 0, 0, 0, 0, 0, 0, 0]
const PST_KNIGHT := [
	-50, -40, -30, -30, -30, -30, -40, -50,
	-40, -20, 0, 0, 0, 0, -20, -40,
	-30, 0, 10, 15, 15, 10, 0, -30,
	-30, 5, 15, 20, 20, 15, 5, -30,
	-30, 0, 15, 20, 20, 15, 0, -30,
	-30, 5, 10, 15, 15, 10, 5, -30,
	-40, -20, 0, 5, 5, 0, -20, -40,
	-50, -40, -30, -30, -30, -30, -40, -50]
const PST_BISHOP := [
	-20, -10, -10, -10, -10, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 10, 10, 5, 0, -10,
	-10, 5, 5, 10, 10, 5, 5, -10,
	-10, 0, 10, 10, 10, 10, 0, -10,
	-10, 10, 10, 10, 10, 10, 10, -10,
	-10, 5, 0, 0, 0, 0, 5, -10,
	-20, -10, -10, -10, -10, -10, -10, -20]
const PST_ROOK := [
	0, 0, 0, 0, 0, 0, 0, 0,
	5, 10, 10, 10, 10, 10, 10, 5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	0, 0, 0, 5, 5, 0, 0, 0]
const PST_QUEEN := [
	-20, -10, -10, -5, -5, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 5, 5, 5, 0, -10,
	-5, 0, 5, 5, 5, 5, 0, -5,
	0, 0, 5, 5, 5, 5, 0, -5,
	-10, 5, 5, 5, 5, 5, 0, -10,
	-10, 0, 5, 0, 0, 0, 0, -10,
	-20, -10, -10, -5, -5, -10, -10, -20]
const PST_KING_MIDDLE := [
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-20, -30, -30, -40, -40, -30, -30, -20,
	-10, -20, -20, -20, -20, -20, -20, -10,
	20, 20, 0, 0, 0, 0, 20, 20,
	20, 30, 10, 0, 0, 10, 30, 20]
const PST_KING_END := [
	-50, -40, -30, -20, -20, -30, -40, -50,
	-30, -20, -10, 0, 0, -10, -20, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -30, 0, 0, 0, 0, -30, -30,
	-50, -30, -30, -30, -30, -30, -30, -50]

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

# Tables shared by every copy, built once by the first engine (on the main thread).
static var pst := PackedInt32Array()  # [piece * 120 + square]: material + position, White positive
static var king_middle := PackedInt32Array()  # [color * 120 + square], signed like pst
static var king_end := PackedInt32Array()
static var zobrist := PackedInt64Array()  # [piece * 120 + square]
static var zobrist_castle := PackedInt64Array()
static var zobrist_ep := PackedInt64Array()
static var zobrist_side := 0

var board := PackedInt32Array()
var side := WHITE
var castling := 15
var ep := 0  # square a pawn can capture en passant on, 0 if none
var halfmove := 0
var fullmove := 1
var kings := [95, 25]
var zkey := 0  # Zobrist key of the position
var score := 0  # material + piece-square of everything but the kings, White positive
var phase := 24
var undo_stack := []
var history := PackedInt64Array()  # Zobrist key of every position so far, the current one last

# Search.
var stop := false  # set from the main thread to end think() early
var nodes := 0
var deadline := 0
var tt := {}
var killers := PackedInt32Array()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	if pst.is_empty():
		_build_tables()
	killers.resize(256)
	reset()


static func _build_tables() -> void:
	var tables := [[], PST_PAWN, PST_KNIGHT, PST_BISHOP, PST_ROOK, PST_QUEEN]
	pst.resize(15 * 120)
	king_middle.resize(240)
	king_end.resize(240)
	for i in 64:
		var sq := 21 + (i / 8) * 10 + i % 8
		var mirrored := (7 - i / 8) * 8 + i % 8
		for type in range(PAWN, KING):
			pst[type * 120 + sq] = VALUE[type] + tables[type][i]
			pst[(type | BLACK_BIT) * 120 + sq] = -(VALUE[type] + tables[type][mirrored])
		king_middle[sq] = PST_KING_MIDDLE[i]
		king_middle[120 + sq] = -PST_KING_MIDDLE[mirrored]
		king_end[sq] = PST_KING_END[i]
		king_end[120 + sq] = -PST_KING_END[mirrored]
	var r := RandomNumberGenerator.new()
	r.seed = 20260922
	zobrist.resize(15 * 120)
	for i in zobrist.size():
		zobrist[i] = (r.randi() << 32) ^ r.randi()
	zobrist_castle.resize(16)
	for i in 16:
		zobrist_castle[i] = (r.randi() << 32) ^ r.randi()
	zobrist_ep.resize(120)
	for i in 120:
		zobrist_ep[i] = (r.randi() << 32) ^ r.randi()
	zobrist_side = (r.randi() << 32) ^ r.randi()


# --- Position ----------------------------------------------------------------------------------

func reset() -> void:
	load_fen(START_FEN)


func load_fen(fen: String) -> void:
	var parts := fen.split(" ")
	board.resize(120)
	board.fill(OFF)
	var sq := 21
	for ch in parts[0]:
		if ch == "/":
			sq += 2
		elif ch.is_valid_int():
			for i in int(ch):
				board[sq] = EMPTY
				sq += 1
		else:
			var type := "pnbrqk".find(ch.to_lower()) + 1
			board[sq] = type if ch == ch.to_upper() else type | BLACK_BIT
			if type == KING:
				kings[0 if ch == ch.to_upper() else 1] = sq
			sq += 1
	side = BLACK if parts.size() > 1 and parts[1] == "b" else WHITE
	castling = 0
	if parts.size() > 2:
		for i in 4:
			if parts[2].contains("KQkq"[i]):
				castling |= 1 << i
	ep = square_index(parts[3]) if parts.size() > 3 and parts[3] != "-" else 0
	halfmove = int(parts[4]) if parts.size() > 4 else 0
	fullmove = int(parts[5]) if parts.size() > 5 else 1
	score = 0
	phase = 0
	zkey = zobrist_castle[castling] ^ (zobrist_ep[ep] if ep else 0) ^ (zobrist_side if side == BLACK else 0)
	for s in range(21, 99):
		var p := board[s]
		if p > 0:
			zkey ^= zobrist[p * 120 + s]
			if p & 7 != KING:
				score += pst[p * 120 + s]
				phase += PHASE[p & 7]
	undo_stack.clear()
	history = PackedInt64Array([zkey])


## Copies the position (and its history, for repetitions) so a thread can search it.
func copy_from(other) -> void:
	board = other.board.duplicate()
	side = other.side
	castling = other.castling
	ep = other.ep
	halfmove = other.halfmove
	fullmove = other.fullmove
	kings = other.kings.duplicate()
	zkey = other.zkey
	score = other.score
	phase = other.phase
	history = other.history.duplicate()
	undo_stack.clear()


static func square_index(name: String) -> int:
	return 21 + (8 - int(name[1])) * 10 + "abcdefgh".find(name[0])


static func square_name(sq: int) -> String:
	return "abcdefgh"[sq % 10 - 1] + str(10 - sq / 10)


static func move_from(m: int) -> int:
	return m & 127


static func move_to(m: int) -> int:
	return (m >> 7) & 127


static func move_promo(m: int) -> int:
	return (m >> 14) & 7


static func move_flags(m: int) -> int:
	return m >> 17


static func _move(from: int, to: int, promo := 0, flags := 0) -> int:
	return from | (to << 7) | (promo << 14) | (flags << 17)


func uci(m: int) -> String:
	var text := square_name(move_from(m)) + square_name(move_to(m))
	if move_promo(m):
		text += "..nbrq"[move_promo(m)]
	return text


func find_uci(text: String) -> int:
	for m in legal_moves():
		if uci(m) == text:
			return m
	return 0


# --- Moves -------------------------------------------------------------------------------------

func make_move(m: int) -> void:
	var from := m & 127
	var to := (m >> 7) & 127
	var promo := (m >> 14) & 7
	var flags := m >> 17
	var piece := board[from]
	var captured := board[to]
	undo_stack.append([m, captured, castling, ep, halfmove, zkey, score, phase])

	zkey ^= zobrist[piece * 120 + from]
	score -= pst[piece * 120 + from]
	board[from] = EMPTY
	if captured != EMPTY:
		zkey ^= zobrist[captured * 120 + to]
		score -= pst[captured * 120 + to]
		phase -= PHASE[captured & 7]
	if flags & FLAG_EP:
		var taken := to + (10 if side == WHITE else -10)
		var pawn := board[taken]
		zkey ^= zobrist[pawn * 120 + taken]
		score -= pst[pawn * 120 + taken]
		board[taken] = EMPTY
	var placed := piece
	if promo:
		placed = promo | (side << 3)
		phase += PHASE[promo]
	board[to] = placed
	zkey ^= zobrist[placed * 120 + to]
	score += pst[placed * 120 + to]
	if flags & FLAG_CASTLE:
		var rook_from := to + 1 if to % 10 == 7 else to - 2
		var rook_to := to - 1 if to % 10 == 7 else to + 1
		var rook := board[rook_from]
		board[rook_from] = EMPTY
		board[rook_to] = rook
		zkey ^= zobrist[rook * 120 + rook_from] ^ zobrist[rook * 120 + rook_to]
		score += pst[rook * 120 + rook_to] - pst[rook * 120 + rook_from]
	if piece & 7 == KING:
		kings[side] = to

	if ep:
		zkey ^= zobrist_ep[ep]
		ep = 0
	if flags & FLAG_DOUBLE:
		# Only remember the en passant square when an enemy pawn could really take there,
		# so positions that only differ by a useless one still count as repetitions.
		var enemy_pawn := PAWN | ((side ^ 1) << 3)
		if board[to - 1] == enemy_pawn or board[to + 1] == enemy_pawn:
			ep = (from + to) / 2
			zkey ^= zobrist_ep[ep]
	var mask: int = CASTLE_MASK.get(from, 15) & CASTLE_MASK.get(to, 15)
	if castling & ~mask:
		zkey ^= zobrist_castle[castling]
		castling &= mask
		zkey ^= zobrist_castle[castling]
	halfmove = 0 if piece & 7 == PAWN or captured != EMPTY else halfmove + 1
	if side == BLACK:
		fullmove += 1
	side ^= 1
	zkey ^= zobrist_side
	history.append(zkey)


func unmake_move() -> void:
	var u: Array = undo_stack.pop_back()
	history.resize(history.size() - 1)
	side ^= 1
	var m: int = u[0]
	var from := m & 127
	var to := (m >> 7) & 127
	var flags := m >> 17
	var piece := board[to]
	if (m >> 14) & 7:
		piece = PAWN | (side << 3)
	board[from] = piece
	board[to] = u[1]
	if flags & FLAG_EP:
		board[to + (10 if side == WHITE else -10)] = PAWN | ((side ^ 1) << 3)
	if flags & FLAG_CASTLE:
		var rook_from := to + 1 if to % 10 == 7 else to - 2
		var rook_to := to - 1 if to % 10 == 7 else to + 1
		board[rook_from] = board[rook_to]
		board[rook_to] = EMPTY
	if piece & 7 == KING:
		kings[side] = from
	castling = u[2]
	ep = u[3]
	halfmove = u[4]
	zkey = u[5]
	score = u[6]
	phase = u[7]
	if side == BLACK:
		fullmove -= 1


## Moves that follow the piece rules; some may leave the own king in check.
func _generate(captures_only := false) -> PackedInt32Array:
	var moves := PackedInt32Array()
	var us := side
	for sq in range(21, 99):
		var p := board[sq]
		if p <= 0 or (p >> 3) != us:
			continue
		match p & 7:
			PAWN:
				var dir := -10 if us == WHITE else 10
				var one := sq + dir
				var last_row := one < 30 or one > 90
				if board[one] == EMPTY and (not captures_only or last_row):
					_add_pawn(moves, sq, one, last_row, captures_only)
					var start_row := sq > 80 if us == WHITE else sq < 40
					if start_row and not captures_only and board[one + dir] == EMPTY:
						moves.append(_move(sq, one + dir, 0, FLAG_DOUBLE))
				for to in [one - 1, one + 1]:
					var t := board[to]
					if t > 0 and (t >> 3) != us:
						_add_pawn(moves, sq, to, last_row, captures_only)
					elif ep != 0 and to == ep:
						moves.append(_move(sq, to, 0, FLAG_EP))
			KNIGHT:
				_add_steps(moves, sq, KNIGHT_STEPS, captures_only)
			BISHOP:
				_add_slides(moves, sq, BISHOP_STEPS, captures_only)
			ROOK:
				_add_slides(moves, sq, ROOK_STEPS, captures_only)
			QUEEN:
				_add_slides(moves, sq, BISHOP_STEPS, captures_only)
				_add_slides(moves, sq, ROOK_STEPS, captures_only)
			KING:
				_add_steps(moves, sq, KING_STEPS, captures_only)
				if not captures_only and castling:
					_add_castling(moves)
	return moves


func _add_pawn(moves: PackedInt32Array, from: int, to: int, last_row: bool, captures_only: bool) -> void:
	if not last_row:
		moves.append(_move(from, to))
		return
	moves.append(_move(from, to, QUEEN))
	if not captures_only:
		for promo in [KNIGHT, ROOK, BISHOP]:
			moves.append(_move(from, to, promo))


func _add_steps(moves: PackedInt32Array, from: int, steps: Array, captures_only: bool) -> void:
	for step: int in steps:
		var to := from + step
		var t := board[to]
		if t == EMPTY:
			if not captures_only:
				moves.append(_move(from, to))
		elif t > 0 and (t >> 3) != side:
			moves.append(_move(from, to))


func _add_slides(moves: PackedInt32Array, from: int, steps: Array, captures_only: bool) -> void:
	for step: int in steps:
		var to := from + step
		while board[to] == EMPTY:
			if not captures_only:
				moves.append(_move(from, to))
			to += step
		var t := board[to]
		if t > 0 and (t >> 3) != side:
			moves.append(_move(from, to))


func _add_castling(moves: PackedInt32Array) -> void:
	var them := side ^ 1
	var home := 95 if side == WHITE else 25
	if kings[side] != home or attacked(home, them):
		return
	if castling & (1 if side == WHITE else 4) and board[home + 1] == EMPTY and board[home + 2] == EMPTY \
			and not attacked(home + 1, them) and not attacked(home + 2, them):
		moves.append(_move(home, home + 2, 0, FLAG_CASTLE))
	if castling & (2 if side == WHITE else 8) and board[home - 1] == EMPTY and board[home - 2] == EMPTY \
			and board[home - 3] == EMPTY and not attacked(home - 1, them) and not attacked(home - 2, them):
		moves.append(_move(home, home - 2, 0, FLAG_CASTLE))


## True if a piece of color `by` attacks square `sq`.
func attacked(sq: int, by: int) -> bool:
	var bit := by << 3
	if by == WHITE:
		if board[sq + 9] == PAWN or board[sq + 11] == PAWN:
			return true
	elif board[sq - 9] == PAWN | BLACK_BIT or board[sq - 11] == PAWN | BLACK_BIT:
		return true
	for step: int in KNIGHT_STEPS:
		if board[sq + step] == KNIGHT | bit:
			return true
	for step: int in KING_STEPS:
		if board[sq + step] == KING | bit:
			return true
	for step: int in BISHOP_STEPS:
		var to := sq + step
		while board[to] == EMPTY:
			to += step
		if board[to] == BISHOP | bit or board[to] == QUEEN | bit:
			return true
	for step: int in ROOK_STEPS:
		var to := sq + step
		while board[to] == EMPTY:
			to += step
		if board[to] == ROOK | bit or board[to] == QUEEN | bit:
			return true
	return false


func in_check(color := -1) -> bool:
	var c := side if color < 0 else color
	return attacked(kings[c], c ^ 1)


func legal_moves() -> PackedInt32Array:
	var legal := PackedInt32Array()
	for m in _generate():
		make_move(m)
		if not in_check(side ^ 1):
			legal.append(m)
		unmake_move()
	return legal


# --- Game end ------------------------------------------------------------------------------------

## "" while the game goes on, else how it ended: checkmate, stalemate, repetition, fifty or material.
func status(legal_count: int) -> String:
	if legal_count == 0:
		return "checkmate" if in_check() else "stalemate"
	if halfmove >= 100:
		return "fifty"
	if repetitions() >= 3:
		return "repetition"
	if insufficient_material():
		return "material"
	return ""


## How many times the current position has appeared, counting this one.
func repetitions() -> int:
	var count := 1
	var i := history.size() - 3
	var oldest := history.size() - 1 - halfmove
	while i >= oldest and i >= 0:
		if history[i] == zkey:
			count += 1
		i -= 2
	return count


## Neither side can ever mate: kings alone, one minor piece, or bishops all on one square color.
func insufficient_material() -> bool:
	var minors := 0
	var knights := 0
	var bishop_colors := {}
	for sq in range(21, 99):
		var p := board[sq]
		if p <= 0:
			continue
		match p & 7:
			PAWN, ROOK, QUEEN:
				return false
			KNIGHT:
				minors += 1
				knights += 1
			BISHOP:
				minors += 1
				bishop_colors[(sq / 10 + sq % 10) % 2] = true
	return minors <= 1 or (knights == 0 and bishop_colors.size() == 1)


## The move in standard notation, split so the game can draw the piece as a figure:
## {piece: type or 0 for pawns and castling, text: "xe5", promo: type or 0, suffix: "+" / "#" / ""}.
func notation(m: int) -> Dictionary:
	var from := move_from(m)
	var to := move_to(m)
	var piece := board[from]
	var type := piece & 7
	var record := {"piece": 0, "text": "", "promo": move_promo(m), "suffix": ""}
	if move_flags(m) & FLAG_CASTLE:
		record.text = "O-O" if to % 10 == 7 else "O-O-O"
	else:
		var capture := board[to] != EMPTY or move_flags(m) & FLAG_EP
		var text := ""
		if type == PAWN:
			if capture:
				text = square_name(from)[0]
		else:
			record.piece = type
			var ambiguous := false
			var same_file := false
			var same_rank := false
			for other in legal_moves():
				var other_from := move_from(other)
				if other_from != from and move_to(other) == to and board[other_from] == piece:
					ambiguous = true
					same_file = same_file or other_from % 10 == from % 10
					same_rank = same_rank or other_from / 10 == from / 10
			if ambiguous:
				if not same_file:
					text += square_name(from)[0]
				elif not same_rank:
					text += square_name(from)[1]
				else:
					text += square_name(from)
		if capture:
			text += "x"
		text += square_name(to)
		if record.promo:
			text += "="
		record.text = text
	make_move(m)
	if in_check():
		record.suffix = "#" if legal_moves().is_empty() else "+"
	unmake_move()
	return record


# --- Computer player ---------------------------------------------------------------------------

## Finds a move for the side to play: iterative deepening up to `max_depth` or `time_ms`.
## `noise` adds up to that many centipawns of randomness to each first move, to play weaker.
func think(max_depth: int, time_ms: int, noise: int, seed_value: int) -> int:
	stop = false
	nodes = 0
	deadline = Time.get_ticks_msec() + time_ms
	rng.seed = seed_value
	killers.fill(0)
	if tt.size() > 300000:
		tt.clear()
	var root := legal_moves()
	if root.is_empty():
		return 0
	if root.size() == 1:
		return root[0]
	var jitter := PackedInt32Array()
	for i in root.size():
		jitter.append(rng.randi_range(-noise, noise) if noise > 0 else 0)
	var best: int = root[0]
	var started := Time.get_ticks_msec()
	for depth in range(1, max_depth + 1):
		var best_here := 0
		var best_score := -MATE - 1
		var alpha := -MATE - 1
		for i in root.size():
			var m: int = root[i]
			make_move(m)
			# With noise every move needs its true score, so search them all with a full window.
			var s := -_search(depth - 1, -MATE - 1, -alpha if noise == 0 else MATE + 1, 1)
			unmake_move()
			if stop:
				break
			s += jitter[i]
			if s > best_score:
				best_score = s
				best_here = m
			if noise == 0 and s > alpha:
				alpha = s
		if stop:
			# An unfinished depth still counts if its first move (last depth's best) was searched.
			if best_here != 0 and best_score > -MATE:
				best = best_here
			break
		best = best_here
		# Search the best move first next time.
		var at := root.find(best)
		root.remove_at(at)
		root.insert(0, best)
		var j := jitter[at]
		jitter.remove_at(at)
		jitter.insert(0, j)
		if absi(best_score) > MATE_NEAR:
			break
		# The next depth takes several times longer: don't start one that can't finish.
		if Time.get_ticks_msec() - started > (deadline - started) / 3:
			break
	return best


func _search(depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if nodes & 1023 == 0 and Time.get_ticks_msec() > deadline:
		stop = true
	if stop:
		return 0
	if halfmove >= 100 or _repeated():
		return 0
	var checked := in_check()
	if checked:
		depth += 1  # look further when in check
	if depth <= 0:
		return _quiesce(alpha, beta, ply)
	if ply >= 60:
		return evaluate()

	var tt_move := 0
	var entry: Variant = tt.get(zkey)
	if entry != null:
		tt_move = entry[3]
		if entry[0] >= depth:
			var s: int = entry[1]
			if s > MATE_NEAR:
				s -= ply
			elif s < -MATE_NEAR:
				s += ply
			match entry[2]:
				TT_EXACT:
					return s
				TT_LOWER:
					if s >= beta:
						return s
				TT_UPPER:
					if s <= alpha:
						return s

	var moves := _generate()
	var keys := _order(moves, tt_move, ply)
	var start_alpha := alpha
	var best := -MATE - 1
	var best_move := 0
	var legal := 0
	for i in moves.size():
		_pick(moves, keys, i)
		var m := moves[i]
		make_move(m)
		if in_check(side ^ 1):
			unmake_move()
			continue
		legal += 1
		var s := -_search(depth - 1, -beta, -alpha, ply + 1)
		unmake_move()
		if stop:
			return 0
		if s > best:
			best = s
			best_move = m
		if s > alpha:
			alpha = s
		if alpha >= beta:
			if board[move_to(m)] == EMPTY and not move_promo(m):
				killers[ply] = m
			break
	if legal == 0:
		return -MATE + ply if checked else 0

	var stored := best
	if stored > MATE_NEAR:
		stored += ply
	elif stored < -MATE_NEAR:
		stored -= ply
	var flag := TT_EXACT
	if best <= start_alpha:
		flag = TT_UPPER
	elif best >= beta:
		flag = TT_LOWER
	tt[zkey] = [depth, stored, flag, best_move]
	return best


## Only captures (and queen promotions) until the position is quiet.
func _quiesce(alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if nodes & 1023 == 0 and Time.get_ticks_msec() > deadline:
		stop = true
	if stop:
		return 0
	var stand := evaluate()
	if stand >= beta or ply >= 60:
		return stand
	if stand > alpha:
		alpha = stand
	var moves := _generate(true)
	var keys := _order(moves, 0, ply)
	for i in moves.size():
		_pick(moves, keys, i)
		var m := moves[i]
		make_move(m)
		if in_check(side ^ 1):
			unmake_move()
			continue
		var s := -_quiesce(-beta, -alpha, ply + 1)
		unmake_move()
		if stop:
			return 0
		if s >= beta:
			return s
		if s > alpha:
			alpha = s
	return alpha


## Sort keys: the remembered best move, then captures (most valuable victim, least valuable
## attacker), promotions, the killer move, then the rest.
func _order(moves: PackedInt32Array, tt_move: int, ply: int) -> PackedInt32Array:
	var keys := PackedInt32Array()
	keys.resize(moves.size())
	var killer := killers[ply] if ply < killers.size() else 0
	for i in moves.size():
		var m := moves[i]
		var victim := board[move_to(m)]
		var key := 0
		if m == tt_move:
			key = 1000000
		elif victim > 0:
			key = 100000 + VALUE[victim & 7] * 10 - VALUE[board[move_from(m)] & 7] / 10
		elif move_flags(m) & FLAG_EP:
			key = 100000 + 1000 - 10
		elif move_promo(m):
			key = 90000 + VALUE[move_promo(m)]
		elif m == killer:
			key = 50000
		keys[i] = key
	return keys


## Moves the best remaining move to index `i` (a selection sort, one step per move tried).
func _pick(moves: PackedInt32Array, keys: PackedInt32Array, i: int) -> void:
	var best := i
	for j in range(i + 1, moves.size()):
		if keys[j] > keys[best]:
			best = j
	if best != i:
		var m := moves[i]
		moves[i] = moves[best]
		moves[best] = m
		var k := keys[i]
		keys[i] = keys[best]
		keys[best] = k


## The position repeats one seen earlier (a draw the side ahead would avoid).
func _repeated() -> bool:
	var i := history.size() - 3
	var oldest := history.size() - 1 - halfmove
	while i >= oldest and i >= 0:
		if history[i] == zkey:
			return true
		i -= 2
	return false


## Score for the side to move, in centipawns.
func evaluate() -> int:
	var s := score
	var middle := mini(phase, 24)
	for c in 2:
		var k: int = kings[c] + c * 120
		s += (king_middle[k] * middle + king_end[k] * (24 - middle)) / 24
	# Endgame with a clear material lead: drive the lone king to the edge and walk up to it.
	if phase <= 8 and absi(score) >= 400:
		var strong := WHITE if score > 0 else BLACK
		var loser: int = kings[strong ^ 1]
		var winner: int = kings[strong]
		var file := loser % 10 - 1
		var rank := loser / 10 - 2
		var edge := maxi(3 - file, file - 4) + maxi(3 - rank, rank - 4)
		var distance := absi(loser % 10 - winner % 10) + absi(loser / 10 - winner / 10)
		var bonus := edge * 12 + (14 - distance) * 5
		s += bonus if strong == WHITE else -bonus
	return s if side == WHITE else -s
