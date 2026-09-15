extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. Game names (Zip Path) are not translated.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"]]

const TEXT := {
	# Levels and main controls.
	"level_easy": ["Easy", "Fácil", "Fácil", "Facile", "Leicht"],
	"level_medium": ["Medium", "Médio", "Medio", "Moyen", "Mittel"],
	"level_hard": ["Hard", "Difícil", "Difícil", "Difficile", "Schwer"],
	"best_short": ["best %s", "melhor %s", "mejor %s", "record %s", "Bestzeit %s"],
	"new_game": ["New game", "Novo jogo", "Nuevo juego", "Nouvelle partie", "Neues Spiel"],
	"undo": ["Undo", "Desfazer", "Deshacer", "Annuler", "Zurück"],
	"clear": ["Clear", "Limpar", "Borrar", "Effacer", "Leeren"],
	"hint": ["Hint", "Dica", "Pista", "Indice", "Tipp"],

	# Hints and help.
	"z_hint_next": ["Head here next.", "Segue para aqui.", "Sigue por aquí.", "Va par ici ensuite.", "Geh als Nächstes hierhin."],
	"z_hint_off": ["This path won't reach the end. Undo back to the highlighted cell.",
			"Este caminho não chega ao fim. Desfaz até à casa marcada.",
			"Este camino no llega al final. Deshaz hasta la casilla marcada.",
			"Ce chemin n'arrive pas au bout. Annule jusqu'à la case marquée.",
			"Dieser Weg führt nicht zum Ziel. Mach bis zum markierten Feld rückgängig."],
	"z_rules": ["Drag from 1 through every cell, in order, to the last number. Don't cross your own line or a wall.",
			"Arrasta a partir do 1 por todas as casas, em ordem, até ao último número. Não cruzes a tua linha nem uma parede.",
			"Arrastra desde el 1 por todas las casillas, en orden, hasta el último número. No cruces tu línea ni una pared.",
			"Trace depuis le 1 à travers toutes les cases, dans l'ordre, jusqu'au dernier numéro. Ne croise ni ta ligne ni un mur.",
			"Zieh vom 1er durch jedes Feld, der Reihe nach, bis zur letzten Zahl. Kreuze weder deine eigene Linie noch eine Wand."],
	"z_pad_help": ["D-pad draw/undo one  ·  B undo  ·  Y clear  ·  LB undo  ·  RB hint  ·  LT/RT level  ·  Start new",
			"D-pad traçar/desfazer  ·  B desfazer  ·  Y limpar  ·  LB desfazer  ·  RB dica  ·  LT/RT nível  ·  Start novo",
			"D-pad trazar/deshacer  ·  B deshacer  ·  Y borrar  ·  LB deshacer  ·  RB pista  ·  LT/RT nivel  ·  Start nuevo",
			"D-pad tracer/annuler  ·  B annuler  ·  Y effacer  ·  LB annuler  ·  RB indice  ·  LT/RT niveau  ·  Start nouveau",
			"D-Pad zeichnen/zurück  ·  B zurück  ·  Y leeren  ·  LB zurück  ·  RB Tipp  ·  LT/RT Stufe  ·  Start neu"],

	# Winning.
	"you_win": ["You win!", "Ganhaste!", "¡Has ganado!", "Gagné !", "Gewonnen!"],
	"hint_used_one": ["1 hint used · not counted for best time", "1 dica usada · não conta para o melhor tempo",
			"1 pista usada · no cuenta para el mejor tiempo", "1 indice utilisé · non compté pour le record",
			"1 Tipp genutzt · zählt nicht für die Bestzeit"],
	"hints_used": ["%d hints used · not counted for best time", "%d dicas usadas · não contam para o melhor tempo",
			"%d pistas usadas · no cuentan para el mejor tiempo", "%d indices utilisés · non comptés pour le record",
			"%d Tipps genutzt · zählen nicht für die Bestzeit"],
	"new_best": ["New best time on %s!", "Novo melhor tempo em %s!", "¡Nuevo mejor tiempo en %s!", "Nouveau record en %s !", "Neue Bestzeit auf %s!"],
	"best_on": ["Best on %s: %s", "Melhor tempo em %s: %s", "Mejor tiempo en %s: %s", "Record en %s : %s", "Bestzeit auf %s: %s"],
	"view_board": ["View board", "Ver tabuleiro", "Ver tablero", "Voir la grille", "Brett ansehen"],
	"solved_results": ["Solved in %s  ·  See results", "Resolvido em %s  ·  Ver resultados", "Resuelto en %s  ·  Ver resultados",
			"Résolu en %s  ·  Voir les résultats", "Gelöst in %s  ·  Ergebnisse"],

	# Statistics.
	"statistics": ["Statistics", "Estatísticas", "Estadísticas", "Statistiques", "Statistik"],
	"played": ["Played", "Jogados", "Jugados", "Jouées", "Gespielt"],
	"solved": ["Solved", "Resolvidos", "Resueltos", "Résolues", "Gelöst"],
	"win_rate": ["Win rate", "Vitórias", "Victorias", "Réussite", "Quote"],
	"current_streak": ["Streak", "Sequência", "Racha", "Série", "Serie"],
	"best_streak": ["Best streak", "Melhor sequência", "Mejor racha", "Meilleure série", "Beste Serie"],
	"level": ["Level", "Nível", "Nivel", "Niveau", "Stufe"],
	"best_time": ["Best", "Melhor", "Mejor", "Record", "Bestzeit"],
	"average": ["Average", "Média", "Media", "Moyenne", "Schnitt"],
	"no_hints": ["No hints", "Sem dicas", "Sin pistas", "Sans indice", "Ohne Tipps"],
	"reset_stats": ["Reset statistics", "Repor estatísticas", "Restablecer estadísticas", "Réinitialiser", "Statistik zurücksetzen"],
	"confirm_reset": ["Press again to reset", "Carrega outra vez para repor", "Pulsa otra vez para restablecer",
			"Appuie encore pour réinitialiser", "Nochmal drücken zum Zurücksetzen"],
	"stats_empty": ["Solve a puzzle to start your statistics.", "Resolve um puzzle para começares as tuas estatísticas.",
			"Resuelve un puzle para empezar tus estadísticas.", "Résous une grille pour lancer tes statistiques.",
			"Löse ein Rätsel, um deine Statistik zu starten."],

	# Settings.
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache"],
	"sound": ["Sound effects", "Efeitos sonoros", "Efectos de sonido", "Effets sonores", "Soundeffekte"],
	"sound_desc": ["Clicks, moves and the win jingle.", "Cliques, jogadas e a música de vitória.", "Clics, jugadas y la melodía de victoria.",
			"Clics, coups et la musique de victoire.", "Klicks, Züge und die Siegesmelodie."],
	"vibration": ["Controller vibration", "Vibração do comando", "Vibración del mando", "Vibration de la manette", "Controller-Vibration"],
	"vibration_desc": ["Rumble on an Xbox or other controller.", "Vibração num comando Xbox ou outro.", "Vibración en un mando Xbox u otro.",
			"Vibration sur une manette Xbox ou autre.", "Vibration auf einem Xbox- oder anderen Controller."],
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
