extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. The game name (Par ou Ímpar) is not translated.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"]]

const TEXT := {
	# Players and sides.
	"you": ["YOU", "TU", "TÚ", "TOI", "DU"],
	"cpu": ["CPU", "CPU", "CPU", "CPU", "CPU"],
	"even": ["EVEN", "PAR", "PAR", "PAIR", "GERADE"],
	"odd": ["ODD", "ÍMPAR", "IMPAR", "IMPAIR", "UNGERADE"],
	"first_to": ["First to %d", "Primeiro a %d", "Gana quien llegue a %d", "Premier à %d", "Wer zuerst %d hat"],

	# The chant while the hands shake.
	"chant_1": ["Odds…", "Par…", "Pares…", "Pair…", "Gerade…"],
	"chant_2": ["or…", "ou…", "o…", "ou…", "oder…"],
	"chant_3": ["evens!", "ímpar!", "¡nones!", "impair !", "ungerade!"],

	# Panel.
	"your_call": ["Your call", "A tua aposta", "Tu apuesta", "Ton choix", "Deine Wahl"],
	"show_fingers": ["Show your fingers", "Mostra os dedos", "Saca los dedos", "Montre tes doigts", "Zeig deine Finger"],

	# Messages.
	"pick": ["Pick EVEN or ODD, then show 0 to 5 fingers", "Escolhe PAR ou ÍMPAR e mostra de 0 a 5 dedos",
			"Elige PAR o IMPAR y saca de 0 a 5 dedos", "Choisis PAIR ou IMPAIR, puis montre de 0 à 5 doigts",
			"Wähle GERADE oder UNGERADE und zeig 0 bis 5 Finger"],
	"you_win_round": ["You win the round!", "Ganhaste esta ronda!", "¡Ganas esta ronda!", "Tu gagnes la manche !", "Du gewinnst die Runde!"],
	"cpu_wins_round": ["CPU wins the round", "O CPU ganha esta ronda", "La CPU gana esta ronda", "Le CPU gagne la manche", "Die CPU gewinnt die Runde"],
	"you_win_match": ["You win the match!", "Ganhaste a partida!", "¡Ganas la partida!", "Tu gagnes la partie !", "Du gewinnst das Spiel!"],
	"cpu_wins_match": ["CPU wins the match", "O CPU ganha a partida", "La CPU gana la partida", "Le CPU gagne la partie", "Die CPU gewinnt das Spiel"],
	"new_match": ["New match", "Nova partida", "Nueva partida", "Nouvelle partie", "Neues Spiel"],

	# Menu.
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache"],
	"sound": ["Sound effects", "Efeitos sonoros", "Efectos de sonido", "Effets sonores", "Soundeffekte"],
	"difficulty": ["CPU", "CPU", "CPU", "CPU", "CPU"],
	"easy": ["Random", "Aleatório", "Aleatoria", "Aléatoire", "Zufällig"],
	"hard": ["Clever", "Esperto", "Lista", "Malin", "Schlau"],
	"hard_hint": ["The clever CPU learns your habits", "O CPU esperto aprende os teus hábitos", "La CPU lista aprende tus costumbres",
			"Le CPU malin apprend tes habitudes", "Die schlaue CPU lernt deine Gewohnheiten"],
	"match_length": ["Match length", "Duração da partida", "Duración de la partida", "Durée de la partie", "Spiellänge"],
	"statistics": ["Statistics", "Estatísticas", "Estadísticas", "Statistiques", "Statistik"],
	"rounds": ["Rounds played", "Rondas jogadas", "Rondas jugadas", "Manches jouées", "Gespielte Runden"],
	"rounds_won": ["Rounds won", "Rondas ganhas", "Rondas ganadas", "Manches gagnées", "Gewonnene Runden"],
	"matches": ["Matches won / lost", "Partidas ganhas / perdidas", "Partidas ganadas / perdidas", "Parties gagnées / perdues",
			"Spiele gewonnen / verloren"],
	"best_streak": ["Longest winning streak", "Maior série de vitórias", "Mejor racha de victorias", "Plus longue série de victoires",
			"Längste Siegesserie"],
	"reset": ["Reset statistics", "Apagar estatísticas", "Borrar estadísticas", "Effacer les statistiques", "Statistik zurücksetzen"],
	"confirm_reset": ["Press again to reset", "Carrega outra vez para apagar", "Pulsa otra vez para borrar", "Appuie encore pour effacer",
			"Nochmal drücken zum Zurücksetzen"],
	"keys_help": ["0–5 show fingers · ← → switch side · Enter new match · Esc menu",
			"0–5 mostrar dedos · ← → trocar de lado · Enter nova partida · Esc menu",
			"0–5 sacar dedos · ← → cambiar de lado · Enter nueva partida · Esc menú",
			"0–5 montrer les doigts · ← → changer de camp · Entrée nouvelle partie · Échap menu",
			"0–5 Finger zeigen · ← → Seite wechseln · Enter neues Spiel · Esc Menü"],
}


## Registers all languages with Godot's TranslationServer.
static func install() -> void:
	for i in LANGUAGES.size():
		var translation := Translation.new()
		translation.locale = LANGUAGES[i][0]
		for key: String in TEXT:
			translation.add_message(key, TEXT[key][i])
		TranslationServer.add_translation(translation)


## The player's system language if the game has it, otherwise English.
static func system_language() -> String:
	var lang := OS.get_locale_language()
	for entry in LANGUAGES:
		if entry[0] == lang:
			return lang
	return "en"
