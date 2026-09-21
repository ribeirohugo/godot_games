extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. The game name (Chess) is not translated.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"]]

const TEXT := {
	# Main buttons.
	"new_game": ["New game", "Novo jogo", "Nueva partida", "Nouvelle partie", "Neues Spiel"],
	"undo": ["Undo", "Desfazer", "Deshacer", "Annuler", "Zurück"],
	"hint": ["Hint", "Dica", "Pista", "Indice", "Tipp"],
	"flip": ["Flip", "Rodar", "Girar", "Tourner", "Drehen"],
	"moves": ["Moves", "Lances", "Jugadas", "Coups", "Züge"],

	# New game.
	"opponent": ["Opponent", "Adversário", "Rival", "Adversaire", "Gegner"],
	"vs_computer": ["Computer", "Computador", "Ordenador", "Ordinateur", "Computer"],
	"two_players": ["2 players", "2 jogadores", "2 jugadores", "2 joueurs", "2 Spieler"],
	"level": ["Level", "Nível", "Nivel", "Niveau", "Stufe"],
	"level_easy": ["Easy", "Fácil", "Fácil", "Facile", "Leicht"],
	"level_medium": ["Medium", "Médio", "Medio", "Moyen", "Mittel"],
	"level_hard": ["Hard", "Difícil", "Difícil", "Difficile", "Schwer"],
	"play_as": ["Play as", "Jogar com", "Jugar con", "Jouer avec", "Spielen mit"],
	"white": ["White", "Brancas", "Blancas", "Blancs", "Weiß"],
	"black": ["Black", "Pretas", "Negras", "Noirs", "Schwarz"],
	"random": ["Random", "Aleatório", "Al azar", "Au hasard", "Zufällig"],
	"start": ["Play", "Jogar", "Jugar", "Jouer", "Spielen"],
	"two_players_note": ["Take turns on this device. Flip the board whenever you like.",
			"Joguem à vez neste dispositivo. Rodem o tabuleiro quando quiserem.",
			"Jugad por turnos en este dispositivo. Girad el tablero cuando queráis.",
			"Jouez à tour de rôle sur cet appareil. Tournez l'échiquier quand vous voulez.",
			"Abwechselnd an diesem Gerät spielen. Das Brett lässt sich jederzeit drehen."],

	# Players and turns.
	"you": ["You", "Tu", "Tú", "Vous", "Du"],
	"computer_level": ["Computer · %s", "Computador · %s", "Ordenador · %s", "Ordinateur · %s", "Computer · %s"],
	"your_turn": ["Your turn", "A tua vez", "Tu turno", "À vous", "Du bist dran"],
	"to_move": ["To move", "A jogar", "Juega", "Au trait", "Am Zug"],
	"thinking": ["Thinking", "A pensar", "Pensando", "Réflexion", "Denkt nach"],
	"check": ["Check!", "Xeque!", "¡Jaque!", "Échec !", "Schach!"],

	# End of the game.
	"you_win": ["You win!", "Ganhaste!", "¡Has ganado!", "Gagné !", "Gewonnen!"],
	"you_lose": ["You lose", "Perdeste", "Has perdido", "Perdu", "Verloren"],
	"white_wins": ["White wins", "Ganham as brancas", "Ganan las blancas", "Les blancs gagnent", "Weiß gewinnt"],
	"black_wins": ["Black wins", "Ganham as pretas", "Ganan las negras", "Les noirs gagnent", "Schwarz gewinnt"],
	"draw": ["Draw", "Empate", "Tablas", "Partie nulle", "Remis"],
	"checkmate": ["Checkmate", "Xeque-mate", "Jaque mate", "Échec et mat", "Schachmatt"],
	"stalemate": ["Stalemate", "Rei afogado", "Rey ahogado", "Pat", "Patt"],
	"repetition": ["Threefold repetition", "Repetição tripla", "Triple repetición", "Triple répétition", "Dreifache Wiederholung"],
	"fifty": ["Fifty-move rule", "Regra dos 50 lances", "Regla de los 50 movimientos", "Règle des 50 coups", "50-Züge-Regel"],
	"material": ["Insufficient material", "Material insuficiente", "Material insuficiente", "Matériel insuffisant", "Ungenügendes Material"],
	"play_again": ["Play again", "Jogar outra vez", "Jugar otra vez", "Rejouer", "Nochmal"],
	"view_board": ["View board", "Ver tabuleiro", "Ver tablero", "Voir l'échiquier", "Brett ansehen"],
	"in_moves": ["in %d moves", "em %d lances", "en %d jugadas", "en %d coups", "in %d Zügen"],

	# Help.
	"help_mouse": ["Drag a piece, or click it and then click where it goes.",
			"Arrasta uma peça, ou clica nela e depois no destino.",
			"Arrastra una pieza, o haz clic en ella y luego en el destino.",
			"Faites glisser une pièce, ou cliquez dessus puis sur sa destination.",
			"Ziehe eine Figur, oder klicke sie an und dann ihr Ziel."],
	"help_keys": ["Arrows + Enter move  ·  U undo  ·  H hint  ·  F flip  ·  N new game",
			"Setas + Enter jogar  ·  U desfazer  ·  H dica  ·  F rodar  ·  N novo jogo",
			"Flechas + Enter mover  ·  U deshacer  ·  H pista  ·  F girar  ·  N nueva partida",
			"Flèches + Entrée jouer  ·  U annuler  ·  H indice  ·  F tourner  ·  N nouvelle partie",
			"Pfeile + Enter ziehen  ·  U zurück  ·  H Tipp  ·  F drehen  ·  N neues Spiel"],
	"help_pad": ["A pick up / put down  ·  B cancel  ·  LB undo  ·  X hint  ·  Y flip  ·  Start new game",
			"A pegar / pousar  ·  B cancelar  ·  LB desfazer  ·  X dica  ·  Y rodar  ·  Start novo jogo",
			"A coger / soltar  ·  B cancelar  ·  LB deshacer  ·  X pista  ·  Y girar  ·  Start nueva partida",
			"A prendre / poser  ·  B annuler  ·  LB annuler  ·  X indice  ·  Y tourner  ·  Start nouvelle partie",
			"A nehmen / setzen  ·  B abbrechen  ·  LB zurück  ·  X Tipp  ·  Y drehen  ·  Start neues Spiel"],

	# Settings.
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache"],
	"board": ["Board", "Tabuleiro", "Tablero", "Échiquier", "Brett"],
	"theme_wood": ["Wood", "Madeira", "Madera", "Bois", "Holz"],
	"theme_green": ["Green", "Verde", "Verde", "Vert", "Grün"],
	"theme_blue": ["Blue", "Azul", "Azul", "Bleu", "Blau"],
	"sound": ["Sound effects", "Efeitos sonoros", "Efectos de sonido", "Effets sonores", "Soundeffekte"],
	"sound_desc": ["Moves, captures and game results", "Jogadas, capturas e resultados", "Jugadas, capturas y resultados",
			"Coups, prises et résultats", "Züge, Schlagen und Ergebnisse"],
	"legal_moves": ["Show possible moves", "Mostrar jogadas possíveis", "Mostrar movimientos posibles",
			"Afficher les coups possibles", "Mögliche Züge zeigen"],
	"legal_moves_desc": ["Dots on the squares the chosen piece can reach", "Pontos nas casas onde a peça escolhida pode ir",
			"Puntos en las casillas a las que puede ir la pieza", "Des points sur les cases que la pièce peut atteindre",
			"Punkte auf den Feldern, die die Figur erreichen kann"],
	"coordinates": ["Coordinates", "Coordenadas", "Coordenadas", "Coordonnées", "Koordinaten"],
	"coordinates_desc": ["Letters and numbers along the board's edge", "Letras e números na borda do tabuleiro",
			"Letras y números en el borde del tablero", "Lettres et chiffres au bord de l'échiquier",
			"Buchstaben und Zahlen am Brettrand"],

	# Statistics.
	"statistics": ["Statistics", "Estatísticas", "Estadísticas", "Statistiques", "Statistik"],
	"played": ["Played", "Jogos", "Partidas", "Parties", "Gespielt"],
	"won": ["Won", "Vitórias", "Ganadas", "Gagnées", "Gewonnen"],
	"drawn": ["Drawn", "Empates", "Tablas", "Nulles", "Remis"],
	"lost": ["Lost", "Derrotas", "Perdidas", "Perdues", "Verloren"],
	"win_rate": ["Win rate", "% vitórias", "% victorias", "% victoires", "Quote"],
	"two_player_games": ["Games for 2 players: %d", "Jogos a 2 jogadores: %d", "Partidas de 2 jugadores: %d",
			"Parties à 2 joueurs : %d", "Spiele zu zweit: %d"],
	"stats_empty": ["Finish a game against the computer to see your results here.",
			"Termina um jogo contra o computador para veres aqui os teus resultados.",
			"Termina una partida contra el ordenador para ver aquí tus resultados.",
			"Terminez une partie contre l'ordinateur pour voir vos résultats ici.",
			"Beende ein Spiel gegen den Computer, um hier deine Ergebnisse zu sehen."],
	"reset_stats": ["Reset statistics", "Repor estatísticas", "Restablecer estadísticas", "Réinitialiser les statistiques", "Statistik zurücksetzen"],
	"confirm_reset": ["Click again to reset", "Clica outra vez para repor", "Haz clic otra vez para restablecer",
			"Cliquez encore pour réinitialiser", "Nochmal klicken zum Zurücksetzen"],
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
