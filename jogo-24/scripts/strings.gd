extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"]]

const TEXT := {
	# Menu.
	"title": ["Game of 24", "Jogo do 24", "Juego del 24", "Jeu du 24", "Spiel 24"],
	"instructions": [
		"Combine the four numbers using +, −, × and ÷ until only one is left. If it is 24, you win!",
		"Combina os quatro números com +, −, × e ÷ até restar apenas um. Se for 24, ganhaste!",
		"Combina los cuatro números con +, −, × y ÷ hasta que quede solo uno. ¡Si es 24, ganas!",
		"Combine les quatre nombres avec +, −, × et ÷ jusqu'à ce qu'il n'en reste qu'un. S'il vaut 24, tu gagnes !",
		"Kombiniere die vier Zahlen mit +, −, × und ÷, bis nur noch eine übrig ist. Ist sie 24, hast du gewonnen!"],
	"choose_difficulty": ["Choose difficulty", "Escolhe a dificuldade", "Elige la dificultad", "Choisis la difficulté", "Schwierigkeit wählen"],
	"level_easy": ["Easy", "Fácil", "Fácil", "Facile", "Leicht"],
	"level_medium": ["Medium", "Médio", "Medio", "Moyen", "Mittel"],
	"level_hard": ["Hard", "Difícil", "Difícil", "Difficile", "Schwer"],
	"level_very_hard": ["Very Hard", "Muito Difícil", "Muy Difícil", "Très Difficile", "Sehr Schwer"],
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache"],
	"sound": ["Sound effects", "Efeitos sonoros", "Efectos de sonido", "Effets sonores", "Soundeffekte"],
	"sound_desc": ["Clicks, moves and the win jingle.", "Cliques, jogadas e a música de vitória.", "Clics, jugadas y la melodía de victoria.",
			"Clics, coups et la musique de victoire.", "Klicks, Züge und die Siegesmelodie."],
	"volume": ["Volume", "Volume", "Volumen", "Volume", "Lautstärke"],

	# Game.
	"menu": ["‹ Menu", "‹ Menu", "‹ Menú", "‹ Menu", "‹ Menü"],
	"status_start": ["Select a number to begin.", "Seleciona um número para começar.", "Selecciona un número para empezar.",
			"Sélectionne un nombre pour commencer.", "Wähle eine Zahl, um zu beginnen."],
	"status_continue": ["Select a number to continue.", "Seleciona um número para continuar.", "Selecciona un número para continuar.",
			"Sélectionne un nombre pour continuer.", "Wähle eine Zahl, um fortzufahren."],
	"status_operator": ["Now choose an operation.", "Agora escolhe uma operação.", "Ahora elige una operación.",
			"Choisis maintenant une opération.", "Wähle jetzt eine Operation."],
	"status_second": ["Now select the second number.", "Agora seleciona o segundo número.", "Ahora selecciona el segundo número.",
			"Sélectionne maintenant le deuxième nombre.", "Wähle jetzt die zweite Zahl."],
	"status_win": ["You reached 24!", "Chegaste ao 24!", "¡Llegaste a 24!", "Tu as atteint 24 !", "Du hast 24 erreicht!"],
	"status_div0": ["Cannot divide by 0. Choose another combination.", "Não é possível dividir por 0. Escolhe outra combinação.",
			"No se puede dividir por 0. Elige otra combinación.", "Impossible de diviser par 0. Choisis une autre combinaison.",
			"Division durch 0 ist nicht möglich. Wähle eine andere Kombination."],
	"status_wrong": ["Got %s, not 24. Use Undo or start over.", "Deu %s, não 24. Usa Desfazer ou começa de novo.",
			"Salió %s, no 24. Usa Deshacer o empieza de nuevo.", "Résultat %s, pas 24. Utilise Annuler ou recommence.",
			"%s statt 24. Nutze Rückgängig oder starte neu."],
	"won_elapsed": ["You reached 24 in %s!", "Chegaste ao 24 em %s!", "¡Llegaste a 24 en %s!", "Tu as atteint 24 en %s !", "Du hast 24 in %s erreicht!"],
	"solution_found": ["Possible solution: %s = 24", "Solução possível: %s = 24", "Solución posible: %s = 24",
			"Solution possible : %s = 24", "Mögliche Lösung: %s = 24"],
	"solution_none": ["No solution for these numbers.", "Sem solução para estes números.", "No hay solución para estos números.",
			"Aucune solution pour ces nombres.", "Keine Lösung für diese Zahlen."],
	"undo": ["Undo", "Desfazer", "Deshacer", "Annuler", "Rückgängig"],
	"view_solution": ["View Solution", "Ver Solução", "Ver Solución", "Voir la Solution", "Lösung Anzeigen"],
	"new_game": ["New Game", "Novo Jogo", "Nueva Partida", "Nouvelle Partie", "Neues Spiel"],
	"next_game": ["Next Game", "Próximo Jogo", "Siguiente Partida", "Partie Suivante", "Nächstes Spiel"],

	# Statistics.
	"statistics": ["Statistics", "Estatísticas", "Estadísticas", "Statistiques", "Statistiken"],
	"wins": ["Wins", "Vitórias", "Victorias", "Victoires", "Siege"],
	"current_streak": ["Current streak", "Sequência atual", "Racha actual", "Série actuelle", "Aktuelle Serie"],
	"best_streak": ["Best streak", "Melhor sequência", "Mejor racha", "Meilleure série", "Beste Serie"],
	"win_rate": ["Win rate", "Taxa de vitória", "Porcentaje de victorias", "Taux de victoire", "Siegquote"],
	"by_difficulty": ["By difficulty", "Por dificuldade", "Por dificultad", "Par difficulté", "Nach Schwierigkeit"],
	"level_detail": ["%d wins out of %d games", "%d vitórias em %d jogos", "%d victorias de %d partidas", "%d victoires sur %d parties",
			"%d Siege von %d Spielen"],
	"recent_history": ["Recent history", "Histórico recente", "Historial reciente", "Historique récent", "Letzte Spiele"],
	"no_games": ["No games recorded yet.", "Ainda não há jogos registados.", "Todavía no hay partidas registradas.",
			"Aucune partie enregistrée pour l'instant.", "Noch keine Spiele aufgezeichnet."],
	"clear_stats": ["Clear Statistics", "Limpar Estatísticas", "Borrar Estadísticas", "Effacer les Statistiques", "Statistiken Löschen"],
	"confirm_clear": ["Press again to erase everything", "Carrega outra vez para apagar tudo", "Pulsa otra vez para borrarlo todo",
			"Appuie encore pour tout effacer", "Nochmal drücken, um alles zu löschen"],
	"won_lost_hint": ["Green = won, red = lost", "Verde = vitória, vermelho = derrota", "Verde = victoria, rojo = derrota",
			"Vert = victoire, rouge = défaite", "Grün = gewonnen, rot = verloren"],
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
