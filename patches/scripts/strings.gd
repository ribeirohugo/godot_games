extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. Game names (Patches) are not translated.

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
	"p_hint_wrong": ["This patch isn't right. Try reshaping it.", "Esta peça não está certa. Tenta mudar-lhe a forma.",
			"Esta pieza no es correcta. Prueba otra forma.", "Cette pièce n'est pas bonne. Essaie une autre forme.",
			"Diese Fläche stimmt nicht. Versuch eine andere Form."],
	"p_hint_fit": ["A patch fits exactly here.", "Aqui cabe exatamente uma peça.", "Aquí encaja exactamente una pieza.",
			"Une pièce tient exactement ici.", "Hier passt genau eine Fläche."],
	"p_rules": ["Fill the grid with rectangles. Each holds one clue: its size and its shape.",
			"Preenche a grelha com retângulos. Cada um tem uma pista: a área e a forma.",
			"Llena la cuadrícula con rectángulos. Cada uno tiene una pista: su tamaño y su forma.",
			"Remplis la grille de rectangles. Chacun a un indice : sa taille et sa forme.",
			"Fülle das Raster mit Rechtecken. Jedes hat einen Hinweis: Größe und Form."],

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
	"show_mistakes": ["Show mistakes", "Mostrar erros", "Mostrar errores", "Afficher les erreurs", "Fehler anzeigen"],
	"mistakes_desc": ["Red stripes on patches that break a rule.", "Riscas vermelhas nas peças que quebram uma regra.",
			"Rayas rojas en las piezas que rompen una regla.", "Rayures rouges sur les pièces qui enfreignent une règle.",
			"Rote Streifen auf Flächen, die eine Regel brechen."],
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
