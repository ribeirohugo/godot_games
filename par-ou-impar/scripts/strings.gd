extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. The game name is the one reserved for that language in the
## Store ("title").

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"],
		["it", "Italiano"], ["nl", "Nederlands"], ["ro", "Română"], ["sv", "Svenska"], ["nb", "Norsk"], ["pl", "Polski"],
		["tr", "Türkçe"]]

const TEXT := {
	"title": ["Odds or Evens", "Par ou Ímpar", "Pares o Nones", "Pair ou Impair", "Gerade oder ungerade",
			"Parí o Dispari", "Even of oneven", "Par sau impar", "Udda eller jämnt", "Partall eller oddetall", "Parzyste czy nieparzyste", "Tek mi çift mi?"],

	# Players and sides.
	"you": ["YOU", "TU", "TÚ", "TOI", "DU", "TU", "JIJ", "TU", "DU", "DU", "TY", "SEN"],
	"cpu": ["CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU"],
	"even": ["EVEN", "PAR", "PAR", "PAIR", "GERADE", "PARI", "EVEN", "PAR", "JÄMNT", "PARTALL", "PARZYSTE", "ÇİFT"],
	"odd": ["ODD", "ÍMPAR", "IMPAR", "IMPAIR", "UNGERADE", "DISPARI", "ONEVEN", "IMPAR", "UDDA", "ODDETALL", "NIEPARZYSTE", "TEK"],
	"player_1": ["Player 1", "Jogador 1", "Jugador 1", "Joueur 1", "Spieler 1", "Giocatore 1", "Speler 1", "Jucătorul 1", "Spelare 1",
			"Spiller 1", "Gracz 1", "Oyuncu 1"],
	"player_2": ["Player 2", "Jogador 2", "Jugador 2", "Joueur 2", "Spieler 2", "Giocatore 2", "Speler 2", "Jucătorul 2", "Spelare 2",
			"Spiller 2", "Gracz 2", "Oyuncu 2"],
	"first_to": ["First to %d", "Primeiro a %d", "Gana quien llegue a %d", "Premier à %d", "Wer zuerst %d hat", "Vince chi arriva a %d",
			"Wie het eerst %d heeft", "Primul la %d", "Först till %d", "Først til %d", "Do %d wygranych", "%d puana ilk ulaşan"],

	# The chant while the hands shake.
	"chant_1": ["Odds…", "Par…", "Pares…", "Pair…", "Gerade…", "Pari…", "Even…", "Par…", "Udda…", "Partall…", "Parzyste…", "Tek mi…"],
	"chant_2": ["or…", "ou…", "o…", "ou…", "oder…", "o…", "of…", "sau…", "eller…", "eller…", "czy…", "çift mi…"],
	"chant_3": ["evens!", "ímpar!", "¡nones!", "impair !", "ungerade!", "dispari!", "oneven!", "impar!", "jämnt!", "oddetall!", "nieparzyste!", "hadi!"],

	# Main menu.
	"vs_cpu": ["vs CPU", "Contra o CPU", "Contra la CPU", "Contre le CPU", "Gegen die CPU", "Contro la CPU", "Tegen de CPU",
			"Contra CPU", "Mot datorn", "Mot CPU-en", "Z komputerem", "CPU'ya karşı"],
	"vs_cpu_hint": ["Play against the computer", "Joga contra o computador", "Juega contra el ordenador", "Joue contre l'ordinateur",
			"Spiel gegen den Computer", "Gioca contro il computer", "Speel tegen de computer", "Joacă împotriva computerului",
			"Spela mot datorn", "Spill mot datamaskinen", "Graj przeciwko komputerowi", "Bilgisayara karşı oyna"],
	"two_players": ["2 Players", "2 Jogadores", "2 Jugadores", "2 Joueurs", "2 Spieler", "2 Giocatori", "2 Spelers", "2 Jucători",
			"2 Spelare", "2 Spillere", "2 Graczy", "2 Oyuncu"],
	"two_players_hint": ["Take turns on this device", "À vez, no mesmo dispositivo", "Por turnos en este dispositivo",
			"Chacun son tour sur cet appareil", "Abwechselnd auf diesem Gerät", "A turno su questo dispositivo",
			"Om de beurt op dit apparaat", "Pe rând, pe acest dispozitiv", "Turas om på den här enheten", "Bytt på på denne enheten",
			"Na zmianę na tym urządzeniu", "Bu cihazda sırayla oynayın"],
	"play": ["Play", "Jogar", "Jugar", "Jouer", "Spielen", "Gioca", "Spelen", "Joacă", "Spela", "Spill", "Graj", "Oyna"],
	"continue": ["Continue", "Continuar", "Continuar", "Continuer", "Weiterspielen", "Continua", "Doorgaan", "Continuă", "Fortsätt",
			"Fortsett", "Kontynuuj", "Devam et"],
	"main_menu": ["Main menu", "Menu principal", "Menú principal", "Menu principal", "Hauptmenü", "Menu principale", "Hoofdmenu",
			"Meniul principal", "Huvudmeny", "Hovedmeny", "Menu główne", "Ana menü"],

	# Panel.
	"your_call": ["Your call", "A tua aposta", "Tu apuesta", "Ton choix", "Deine Wahl", "La tua scelta", "Jouw keuze", "Alegerea ta",
			"Ditt val", "Ditt valg", "Twój wybór", "Seçimin"],
	"show_fingers": ["Show your fingers", "Mostra os dedos", "Saca los dedos", "Montre tes doigts", "Zeig deine Finger", "Mostra le dita",
			"Laat je vingers zien", "Arată degetele", "Visa dina fingrar", "Vis fingrene dine", "Pokaż palce", "Parmaklarını göster"],

	# Messages.
	"pick": ["Pick EVEN or ODD, then show 0 to 5 fingers", "Escolhe PAR ou ÍMPAR e mostra de 0 a 5 dedos",
			"Elige PAR o IMPAR y saca de 0 a 5 dedos", "Choisis PAIR ou IMPAIR, puis montre de 0 à 5 doigts",
			"Wähle GERADE oder UNGERADE und zeig 0 bis 5 Finger", "Scegli PARI o DISPARI e mostra da 0 a 5 dita",
			"Kies EVEN of ONEVEN en laat 0 tot 5 vingers zien", "Alege PAR sau IMPAR și arată de la 0 la 5 degete",
			"Välj JÄMNT eller UDDA och visa 0 till 5 fingrar", "Velg PARTALL eller ODDETALL og vis 0 til 5 fingre",
			"Wybierz PARZYSTE lub NIEPARZYSTE i pokaż od 0 do 5 palców", "TEK ya da ÇİFT seç, sonra 0 ile 5 arası parmak göster"],
	"you_win_round": ["You win the round!", "Ganhaste esta ronda!", "¡Ganas esta ronda!", "Tu gagnes la manche !", "Du gewinnst die Runde!",
			"Hai vinto il round!", "Jij wint de ronde!", "Ai câștigat runda!", "Du vinner rundan!", "Du vinner runden!", "Wygrywasz rundę!", "Turu kazandın!"],
	"cpu_wins_round": ["CPU wins the round", "O CPU ganha esta ronda", "La CPU gana esta ronda", "Le CPU gagne la manche",
			"Die CPU gewinnt die Runde", "La CPU vince il round", "De CPU wint de ronde", "CPU câștigă runda", "Datorn vinner rundan",
			"CPU-en vinner runden", "Komputer wygrywa rundę", "Turu CPU kazandı"],
	"you_win_match": ["You win the match!", "Ganhaste a partida!", "¡Ganas la partida!", "Tu gagnes la partie !", "Du gewinnst das Spiel!",
			"Hai vinto la partita!", "Jij wint de wedstrijd!", "Ai câștigat meciul!", "Du vinner matchen!", "Du vinner kampen!",
			"Wygrywasz mecz!", "Maçı kazandın!"],
	"cpu_wins_match": ["CPU wins the match", "O CPU ganha a partida", "La CPU gana la partida", "Le CPU gagne la partie",
			"Die CPU gewinnt das Spiel", "La CPU vince la partita", "De CPU wint de wedstrijd", "CPU câștigă meciul", "Datorn vinner matchen",
			"CPU-en vinner kampen", "Komputer wygrywa mecz", "Maçı CPU kazandı"],
	"turn_fingers": ["%s: show your fingers", "%s: mostra os dedos", "%s: saca los dedos", "%s : montre tes doigts", "%s: zeig deine Finger",
			"%s: mostra le dita", "%s: laat je vingers zien", "%s: arată degetele", "%s: visa dina fingrar", "%s: vis fingrene dine",
			"%s: pokaż palce", "%s: parmaklarını göster"],
	"pick_2p": ["%s picks EVEN or ODD and shows 0 to 5 fingers first", "%s escolhe PAR ou ÍMPAR e mostra primeiro de 0 a 5 dedos",
			"%s elige PAR o IMPAR y saca primero de 0 a 5 dedos", "%s choisit PAIR ou IMPAIR et montre d'abord de 0 à 5 doigts",
			"%s wählt GERADE oder UNGERADE und zeigt zuerst 0 bis 5 Finger", "%s sceglie PARI o DISPARI e mostra per primo da 0 a 5 dita",
			"%s kiest EVEN of ONEVEN en laat als eerste 0 tot 5 vingers zien",
			"%s alege PAR sau IMPAR și arată primul de la 0 la 5 degete", "%s väljer JÄMNT eller UDDA och visar först 0 till 5 fingrar",
			"%s velger PARTALL eller ODDETALL og viser først 0 til 5 fingre",
			"%s wybiera PARZYSTE lub NIEPARZYSTE i pierwszy pokazuje od 0 do 5 palców", "%s önce TEK ya da ÇİFT seçer ve 0 ile 5 arası parmak gösterir"],
	"second_turn": ["%s, your turn! No peeking, %s.", "%s, é a tua vez! Não espreites, %s.", "¡%s, te toca! No mires, %s.",
			"%s, à toi ! Ne regarde pas, %s.", "%s, du bist dran! Nicht schauen, %s!", "%s, tocca a te! Non sbirciare, %s.",
			"%s, jouw beurt! Niet kijken, %s.", "%s, e rândul tău! Nu te uita, %s.", "%s, din tur! Ingen tjuvkikning, %s.",
			"%s, din tur! Ikke kikk, %s.", "%s, twoja kolej! Nie podglądaj, %s.", "%s, sıra sende! Bakmak yok, %s."],
	"wins_round": ["%s wins the round!", "%s ganha esta ronda!", "¡%s gana esta ronda!", "%s gagne la manche !", "%s gewinnt die Runde!",
			"%s vince il round!", "%s wint de ronde!", "%s câștigă runda!", "%s vinner rundan!", "%s vinner runden!", "%s wygrywa rundę!", "%s turu kazandı!"],
	"wins_match": ["%s wins the match!", "%s ganha a partida!", "¡%s gana la partida!", "%s gagne la partie !", "%s gewinnt das Spiel!",
			"%s vince la partita!", "%s wint de wedstrijd!", "%s câștigă meciul!", "%s vinner matchen!", "%s vinner kampen!", "%s wygrywa mecz!", "%s maçı kazandı!"],
	"new_match": ["New match", "Nova partida", "Nueva partida", "Nouvelle partie", "Neues Spiel", "Nuova partita", "Nieuwe wedstrijd",
			"Meci nou", "Ny match", "Ny kamp", "Nowy mecz", "Yeni maç"],

	# Menu.
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen", "Impostazioni", "Instellingen", "Setări",
			"Inställningar", "Innstillinger", "Ustawienia", "Ayarlar"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache", "Lingua", "Taal", "Limba", "Språk", "Språk", "Język", "Dil"],
	"sound": ["Sound effects", "Efeitos sonoros", "Efectos de sonido", "Effets sonores", "Soundeffekte", "Effetti sonori", "Geluidseffecten",
			"Efecte sonore", "Ljudeffekter", "Lydeffekter", "Efekty dźwiękowe", "Ses efektleri"],
	"difficulty": ["CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "Datorn", "CPU", "Komputer", "CPU"],
	"easy": ["Random", "Aleatório", "Aleatoria", "Aléatoire", "Zufällig", "Casuale", "Willekeurig", "Aleatoriu", "Slumpmässig", "Tilfeldig",
			"Losowy", "Rastgele"],
	"hard": ["Clever", "Esperto", "Lista", "Malin", "Schlau", "Furba", "Slim", "Isteț", "Smart", "Lur", "Sprytny", "Akıllı"],
	"hard_hint": ["The clever CPU learns your habits", "O CPU esperto aprende os teus hábitos", "La CPU lista aprende tus costumbres",
			"Le CPU malin apprend tes habitudes", "Die schlaue CPU lernt deine Gewohnheiten", "La CPU furba impara le tue abitudini",
			"De slimme CPU leert je gewoontes", "CPU-ul isteț îți învață obiceiurile", "Den smarta datorn lär sig dina vanor",
			"Den lure CPU-en lærer vanene dine", "Sprytny komputer uczy się twoich nawyków", "Akıllı CPU alışkanlıklarını öğrenir"],
	"match_length": ["Match length", "Duração da partida", "Duración de la partida", "Durée de la partie", "Spiellänge", "Durata della partita",
			"Wedstrijdlengte", "Durata meciului", "Matchlängd", "Kamplengde", "Długość meczu", "Maç uzunluğu"],
	"statistics": ["Statistics", "Estatísticas", "Estadísticas", "Statistiques", "Statistik", "Statistiche", "Statistieken", "Statistici",
			"Statistik", "Statistikk", "Statystyki", "İstatistikler"],
	"rounds": ["Rounds played", "Rondas jogadas", "Rondas jugadas", "Manches jouées", "Gespielte Runden", "Round giocati", "Gespeelde rondes",
			"Runde jucate", "Spelade rundor", "Spilte runder", "Rozegrane rundy", "Oynanan turlar"],
	"rounds_won": ["Rounds won", "Rondas ganhas", "Rondas ganadas", "Manches gagnées", "Gewonnene Runden", "Round vinti", "Gewonnen rondes",
			"Runde câștigate", "Vunna rundor", "Vunne runder", "Wygrane rundy", "Kazanılan turlar"],
	"matches": ["Matches won / lost", "Partidas ganhas / perdidas", "Partidas ganadas / perdidas", "Parties gagnées / perdues",
			"Spiele gewonnen / verloren", "Partite vinte / perse", "Wedstrijden gewonnen / verloren", "Meciuri câștigate / pierdute",
			"Matcher vunna / förlorade", "Kamper vunnet / tapt", "Mecze wygrane / przegrane", "Kazanılan / kaybedilen maçlar"],
	"best_streak": ["Longest winning streak", "Maior série de vitórias", "Mejor racha de victorias", "Plus longue série de victoires",
			"Längste Siegesserie", "Serie di vittorie più lunga", "Langste winstreeks", "Cea mai lungă serie de victorii", "Längsta vinstsvit",
			"Lengste seiersrekke", "Najdłuższa seria zwycięstw", "En uzun galibiyet serisi"],
	"reset": ["Reset statistics", "Apagar estatísticas", "Borrar estadísticas", "Effacer les statistiques", "Statistik zurücksetzen",
			"Azzera le statistiche", "Statistieken wissen", "Resetează statisticile", "Nollställ statistiken", "Nullstill statistikken",
			"Wyzeruj statystyki", "İstatistikleri sıfırla"],
	"confirm_reset": ["Press again to reset", "Carrega outra vez para apagar", "Pulsa otra vez para borrar", "Appuie encore pour effacer",
			"Nochmal drücken zum Zurücksetzen", "Premi di nuovo per azzerare", "Druk nogmaals om te wissen", "Apasă din nou pentru resetare",
			"Tryck igen för att nollställa", "Trykk igjen for å nullstille", "Naciśnij ponownie, aby wyzerować", "Sıfırlamak için tekrar bas"],
	"keys_help": ["0–5 show fingers · ← → switch side · Enter new match · H main menu · Esc settings",
			"0–5 mostrar dedos · ← → trocar de lado · Enter nova partida · H menu principal · Esc definições",
			"0–5 sacar dedos · ← → cambiar de lado · Enter nueva partida · H menú principal · Esc ajustes",
			"0–5 montrer les doigts · ← → changer de camp · Entrée nouvelle partie · H menu principal · Échap paramètres",
			"0–5 Finger zeigen · ← → Seite wechseln · Enter neues Spiel · H Hauptmenü · Esc Einstellungen",
			"0–5 mostra le dita · ← → cambia lato · Invio nuova partita · H menu principale · Esc impostazioni",
			"0–5 vingers tonen · ← → kant wisselen · Enter nieuwe wedstrijd · H hoofdmenu · Esc instellingen",
			"0–5 arată degetele · ← → schimbă partea · Enter meci nou · H meniul principal · Esc setări",
			"0–5 visa fingrar · ← → byt sida · Enter ny match · H huvudmeny · Esc inställningar",
			"0–5 vis fingre · ← → bytt side · Enter ny kamp · H hovedmeny · Esc innstillinger",
			"0–5 pokaż palce · ← → zmień stronę · Enter nowy mecz · H menu główne · Esc ustawienia", "0–5 parmak göster · ← → taraf değiştir · Enter yeni maç · H ana menü · Esc ayarlar"],
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
	# Norwegian systems may report "no" or "nn"; the game's Norwegian is Bokmål.
	if lang == "no" or lang == "nn":
		lang = "nb"
	for entry in LANGUAGES:
		if entry[0] == lang:
			return lang
	return "en"
