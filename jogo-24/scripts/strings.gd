extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["pt_BR", "Português (Brasil)"], ["es", "Español"], ["fr", "Français"],
		["de", "Deutsch"], ["it", "Italiano"], ["nl", "Nederlands"], ["pl", "Polski"], ["sv", "Svenska"]]

const TEXT := {
	# Menu.
	"title": ["24 Game Pro", "Jogo do 24 Pro", "Jogo do 24 Pro", "24 Game Pro", "24 Game Pro", "24 Game Pro", "24 Game Pro", "24 Game Pro",
			"24 Game Pro", "24 Game Pro"],
	"instructions": ["Combine the four numbers using +, −, × and ÷ until only one is left. If it is 24, you win!",
			"Combina os quatro números com +, −, × e ÷ até restar apenas um. Se for 24, ganhaste!",
			"Combine os quatro números com +, −, × e ÷ até sobrar apenas um. Se for 24, você ganhou!",
			"Combina los cuatro números con +, −, × y ÷ hasta que quede solo uno. ¡Si es 24, ganas!",
			"Combine les quatre nombres avec +, −, × et ÷ jusqu'à ce qu'il n'en reste qu'un. S'il vaut 24, tu gagnes !",
			"Kombiniere die vier Zahlen mit +, −, × und ÷, bis nur noch eine übrig ist. Ist sie 24, hast du gewonnen!",
			"Combina i quattro numeri con +, −, × e ÷ finché ne resta solo uno. Se è 24, hai vinto!",
			"Combineer de vier getallen met +, −, × en ÷ tot er nog maar één over is. Is het 24, dan win je!",
			"Łącz cztery liczby za pomocą +, −, × i ÷, aż zostanie tylko jedna. Jeśli to 24, wygrywasz!",
			"Kombinera de fyra talen med +, −, × och ÷ tills bara ett är kvar. Blir det 24 vinner du!"],
	"title_name": ["24 Game", "Jogo do 24", "Jogo do 24", "24 Game", "24 Game", "24 Game", "24 Game", "24 Game", "24 Game", "24 Game"],  # the title without "Pro", for the logo
	"mode_classic": ["Classic", "Clássico", "Clássico", "Clásico", "Classique", "Klassisch", "Classica", "Klassiek", "Klasyczny", "Klassiskt"],
	"mode_double": ["Double Cards", "Cartas Duplas", "Cartas Duplas", "Cartas Dobles", "Cartes Doubles", "Doppelkarten", "Carte Doppie",
			"Dubbele Kaarten", "Podwójne Karty", "Dubbelkort"],
	"instructions_double": ["Double Cards: combine all six numbers with +, −, × and ÷ until only one is left. If it is 24, you win!",
			"Cartas Duplas: combina os seis números com +, −, × e ÷ até restar apenas um. Se for 24, ganhaste!",
			"Cartas Duplas: combine os seis números com +, −, × e ÷ até sobrar apenas um. Se for 24, você ganhou!",
			"Cartas Dobles: combina los seis números con +, −, × y ÷ hasta que quede solo uno. ¡Si es 24, ganas!",
			"Cartes Doubles : combine les six nombres avec +, −, × et ÷ jusqu'à ce qu'il n'en reste qu'un. S'il vaut 24, tu gagnes !",
			"Doppelkarten: Kombiniere alle sechs Zahlen mit +, −, × und ÷, bis nur noch eine übrig ist. Ist sie 24, hast du gewonnen!",
			"Carte Doppie: combina i sei numeri con +, −, × e ÷ finché ne resta solo uno. Se è 24, hai vinto!",
			"Dubbele Kaarten: combineer alle zes getallen met +, −, × en ÷ tot er nog maar één over is. Is het 24, dan win je!",
			"Podwójne Karty: łącz wszystkie sześć liczb za pomocą +, −, × i ÷, aż zostanie tylko jedna. Jeśli to 24, wygrywasz!",
			"Dubbelkort: kombinera alla sex tal med +, −, × och ÷ tills bara ett är kvar. Blir det 24 vinner du!"],
	"choose_difficulty": ["Choose difficulty", "Escolhe a dificuldade", "Escolha a dificuldade", "Elige la dificultad",
			"Choisis la difficulté", "Schwierigkeit wählen", "Scegli la difficoltà", "Kies de moeilijkheid", "Wybierz poziom trudności",
			"Välj svårighetsgrad"],
	"level_easy": ["Easy", "Fácil", "Fácil", "Fácil", "Facile", "Leicht", "Facile", "Makkelijk", "Łatwy", "Lätt"],
	"level_medium": ["Medium", "Médio", "Médio", "Medio", "Moyen", "Mittel", "Medio", "Gemiddeld", "Średni", "Medel"],
	"level_hard": ["Hard", "Difícil", "Difícil", "Difícil", "Difficile", "Schwer", "Difficile", "Moeilijk", "Trudny", "Svår"],
	"level_very_hard": ["Very Hard", "Muito Difícil", "Muito Difícil", "Muy Difícil", "Très Difficile", "Sehr Schwer", "Molto Difficile",
			"Zeer Moeilijk", "Bardzo Trudny", "Mycket Svår"],
	"settings": ["Settings", "Definições", "Configurações", "Ajustes", "Paramètres", "Einstellungen", "Impostazioni", "Instellingen",
			"Ustawienia", "Inställningar"],
	"language": ["Language", "Idioma", "Idioma", "Idioma", "Langue", "Sprache", "Lingua", "Taal", "Język", "Språk"],
	"sound": ["Sound effects", "Efeitos sonoros", "Efeitos sonoros", "Efectos de sonido", "Effets sonores", "Soundeffekte",
			"Effetti sonori", "Geluidseffecten", "Efekty dźwiękowe", "Ljudeffekter"],
	"sound_desc": ["Clicks, moves and the win jingle.", "Cliques, jogadas e a música de vitória.",
			"Cliques, jogadas e a música de vitória.", "Clics, jugadas y la melodía de victoria.",
			"Clics, coups et la musique de victoire.", "Klicks, Züge und die Siegesmelodie.", "Clic, mosse e la musica di vittoria.",
			"Klikken, zetten en het overwinningsdeuntje.", "Kliknięcia, ruchy i melodia zwycięstwa.", "Klick, drag och segermelodin."],
	"volume": ["Volume", "Volume", "Volume", "Volumen", "Volume", "Lautstärke", "Volume", "Volume", "Głośność", "Volym"],

	# Game.
	"menu": ["‹ Menu", "‹ Menu", "‹ Menu", "‹ Menú", "‹ Menu", "‹ Menü", "‹ Menu", "‹ Menu", "‹ Menu", "‹ Meny"],
	"status_start": ["Select a number to begin.", "Seleciona um número para começar.", "Selecione um número para começar.",
			"Selecciona un número para empezar.", "Sélectionne un nombre pour commencer.", "Wähle eine Zahl, um zu beginnen.",
			"Seleziona un numero per iniziare.", "Kies een getal om te beginnen.", "Wybierz liczbę, aby zacząć.",
			"Välj ett tal för att börja."],
	"status_continue": ["Select a number to continue.", "Seleciona um número para continuar.", "Selecione um número para continuar.",
			"Selecciona un número para continuar.", "Sélectionne un nombre pour continuer.", "Wähle eine Zahl, um fortzufahren.",
			"Seleziona un numero per continuare.", "Kies een getal om verder te gaan.", "Wybierz liczbę, aby kontynuować.",
			"Välj ett tal för att fortsätta."],
	"status_operator": ["Now choose an operation.", "Agora escolhe uma operação.", "Agora escolha uma operação.",
			"Ahora elige una operación.", "Choisis maintenant une opération.", "Wähle jetzt eine Operation.", "Ora scegli un'operazione.",
			"Kies nu een bewerking.", "Teraz wybierz działanie.", "Välj nu ett räknesätt."],
	"status_second": ["Now select the second number.", "Agora seleciona o segundo número.", "Agora selecione o segundo número.",
			"Ahora selecciona el segundo número.", "Sélectionne maintenant le deuxième nombre.", "Wähle jetzt die zweite Zahl.",
			"Ora seleziona il secondo numero.", "Kies nu het tweede getal.", "Teraz wybierz drugą liczbę.", "Välj nu det andra talet."],
	"status_win": ["You reached 24!", "Chegaste ao 24!", "Você chegou ao 24!", "¡Llegaste a 24!", "Tu as atteint 24 !",
			"Du hast 24 erreicht!", "Hai raggiunto 24!", "Je hebt 24 bereikt!", "Udało ci się uzyskać 24!", "Du nådde 24!"],
	"status_div0": ["Cannot divide by 0. Choose another combination.", "Não é possível dividir por 0. Escolhe outra combinação.",
			"Não é possível dividir por 0. Escolha outra combinação.", "No se puede dividir por 0. Elige otra combinación.",
			"Impossible de diviser par 0. Choisis une autre combinaison.",
			"Division durch 0 ist nicht möglich. Wähle eine andere Kombination.",
			"Impossibile dividere per 0. Scegli un'altra combinazione.", "Delen door 0 kan niet. Kies een andere combinatie.",
			"Nie można dzielić przez 0. Wybierz inną kombinację.", "Det går inte att dela med 0. Välj en annan kombination."],
	"status_wrong": ["Got %s, not 24. Use Undo or start over.", "Deu %s, não 24. Usa Desfazer ou começa de novo.",
			"Deu %s, não 24. Use Desfazer ou comece de novo.", "Salió %s, no 24. Usa Deshacer o empieza de nuevo.",
			"Résultat %s, pas 24. Utilise Annuler ou recommence.", "%s statt 24. Nutze Rückgängig oder starte neu.",
			"Risultato %s, non 24. Usa Annulla o ricomincia.", "%s in plaats van 24. Gebruik Ongedaan maken of begin opnieuw.",
			"Wynik %s, a nie 24. Użyj Cofnij lub zacznij od nowa.", "Det blev %s, inte 24. Använd Ångra eller börja om."],
	"won_elapsed": ["You reached 24 in %s!", "Chegaste ao 24 em %s!", "Você chegou ao 24 em %s!", "¡Llegaste a 24 en %s!",
			"Tu as atteint 24 en %s !", "Du hast 24 in %s erreicht!", "Hai raggiunto 24 in %s!", "Je hebt 24 bereikt in %s!",
			"Udało ci się uzyskać 24 w %s!", "Du nådde 24 på %s!"],
	"solution_found": ["Possible solution: %s = 24", "Solução possível: %s = 24", "Solução possível: %s = 24", "Solución posible: %s = 24",
			"Solution possible : %s = 24", "Mögliche Lösung: %s = 24", "Soluzione possibile: %s = 24", "Mogelijke oplossing: %s = 24",
			"Możliwe rozwiązanie: %s = 24", "Möjlig lösning: %s = 24"],
	"solution_none": ["No solution for these numbers.", "Sem solução para estes números.", "Sem solução para estes números.",
			"No hay solución para estos números.", "Aucune solution pour ces nombres.", "Keine Lösung für diese Zahlen.",
			"Nessuna soluzione per questi numeri.", "Geen oplossing voor deze getallen.", "Brak rozwiązania dla tych liczb.",
			"Ingen lösning för de här talen."],
	"undo": ["Undo", "Desfazer", "Desfazer", "Deshacer", "Annuler", "Rückgängig", "Annulla", "Ongedaan maken", "Cofnij", "Ångra"],
	"view_solution": ["View Solution", "Ver Solução", "Ver Solução", "Ver Solución", "Voir la Solution", "Lösung Anzeigen",
			"Vedi Soluzione", "Oplossing Tonen", "Pokaż Rozwiązanie", "Visa Lösning"],
	"new_game": ["New Game", "Novo Jogo", "Novo Jogo", "Nueva Partida", "Nouvelle Partie", "Neues Spiel", "Nuova Partita", "Nieuw Spel",
			"Nowa Gra", "Nytt Spel"],
	"next_game": ["Next Game", "Próximo Jogo", "Próximo Jogo", "Siguiente Partida", "Partie Suivante", "Nächstes Spiel",
			"Partita Successiva", "Volgend Spel", "Następna Gra", "Nästa Spel"],

	# Statistics.
	"statistics": ["Statistics", "Estatísticas", "Estatísticas", "Estadísticas", "Statistiques", "Statistiken", "Statistiche",
			"Statistieken", "Statystyki", "Statistik"],
	"wins": ["Wins", "Vitórias", "Vitórias", "Victorias", "Victoires", "Siege", "Vittorie", "Overwinningen", "Wygrane", "Vinster"],
	"current_streak": ["Current streak", "Sequência atual", "Sequência atual", "Racha actual", "Série actuelle", "Aktuelle Serie",
			"Serie attuale", "Huidige reeks", "Obecna seria", "Nuvarande svit"],
	"best_streak": ["Best streak", "Melhor sequência", "Melhor sequência", "Mejor racha", "Meilleure série", "Beste Serie",
			"Serie migliore", "Beste reeks", "Najlepsza seria", "Bästa svit"],
	"win_rate": ["Win rate", "Taxa de vitória", "Taxa de vitória", "Porcentaje de victorias", "Taux de victoire", "Siegquote",
			"Percentuale vittorie", "Winstpercentage", "Procent wygranych", "Vinstandel"],
	"by_difficulty": ["By difficulty", "Por dificuldade", "Por dificuldade", "Por dificultad", "Par difficulté", "Nach Schwierigkeit",
			"Per difficoltà", "Per moeilijkheid", "Według trudności", "Per svårighetsgrad"],
	"level_detail": ["%d wins out of %d games", "%d vitórias em %d jogos", "%d vitórias em %d jogos", "%d victorias de %d partidas",
			"%d victoires sur %d parties", "%d Siege von %d Spielen", "%d vittorie su %d partite", "%d gewonnen van %d spellen",
			"%d wygranych z %d gier", "%d vinster av %d spel"],
	"recent_history": ["Recent history", "Histórico recente", "Histórico recente", "Historial reciente", "Historique récent",
			"Letzte Spiele", "Cronologia recente", "Recente spellen", "Ostatnie gry", "Senaste spel"],
	"no_games": ["No games recorded yet.", "Ainda não há jogos registados.", "Ainda não há jogos registrados.",
			"Todavía no hay partidas registradas.", "Aucune partie enregistrée pour l'instant.", "Noch keine Spiele aufgezeichnet.",
			"Nessuna partita registrata finora.", "Nog geen spellen vastgelegd.", "Brak zapisanych gier.", "Inga spel registrerade än."],
	"clear_stats": ["Clear Statistics", "Limpar Estatísticas", "Limpar Estatísticas", "Borrar Estadísticas", "Effacer les Statistiques",
			"Statistiken Löschen", "Cancella Statistiche", "Statistieken Wissen", "Wyczyść Statystyki", "Rensa Statistik"],
	"confirm_clear": ["Press again to erase everything", "Carrega outra vez para apagar tudo", "Clique de novo para apagar tudo",
			"Pulsa otra vez para borrarlo todo", "Appuie encore pour tout effacer", "Nochmal drücken, um alles zu löschen",
			"Premi di nuovo per cancellare tutto", "Druk nogmaals om alles te wissen", "Naciśnij ponownie, aby wszystko usunąć",
			"Tryck igen för att radera allt"],
	"won_lost_hint": ["Green = won, red = lost", "Verde = vitória, vermelho = derrota", "Verde = vitória, vermelho = derrota",
			"Verde = victoria, rojo = derrota", "Vert = victoire, rouge = défaite", "Grün = gewonnen, rot = verloren",
			"Verde = vittoria, rosso = sconfitta", "Groen = gewonnen, rood = verloren", "Zielony = wygrana, czerwony = przegrana",
			"Grönt = vinst, rött = förlust"],
}


static var installed := false


## Registers all languages with Godot's TranslationServer (once).
static func install() -> void:
	if installed:
		return
	installed = true
	for i in LANGUAGES.size():
		var translation := Translation.new()
		translation.locale = LANGUAGES[i][0]
		for key: String in TEXT:
			translation.add_message(key, TEXT[key][i])
		TranslationServer.add_translation(translation)


## The player's system language if the game has it (Brazilian Portuguese before plain Portuguese), otherwise English.
static func system_language() -> String:
	var locale := OS.get_locale()
	var lang := OS.get_locale_language()
	for code in [locale, lang]:
		for entry in LANGUAGES:
			if entry[0] == code:
				return code
	return "en"
