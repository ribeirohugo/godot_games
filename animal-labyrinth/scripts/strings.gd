extends RefCounted
## Every text in the game, in each language. Controls show them with their `text` set to the
## key (Godot auto-translates), formatted strings use tr("key") % values directly.
## Values follow the order of LANGUAGES.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"], ["it", "Italiano"], ["ro", "Română"], ["pl", "Polski"]]

const TEXT := {
	# The game's name, as reserved in the Store for each language.
	"game_name": ["Animal Labyrinth", "Labirinto Animal", "Laberinto Animal", "Labyrinthe Animal", "Tierlabyrinth",
			"Labirinto Animale", "Labirint Animal",
			"Zwierzęcy Labirynt"],

	# Store art only (scripts/store_art.gd).
	"art_tagline": ["Build the path. The animal does the rest!", "Constrói o caminho. O animal faz o resto!",
			"Construye el camino. ¡El animal hace el resto!", "Construis le chemin. L'animal fait le reste !",
			"Bau den Weg. Das Tier macht den Rest!", "Costruisci il percorso. L'animale fa il resto!",
			"Construiește drumul. Animalul face restul!", "Zbuduj drogę. Zwierzak zrobi resztę!"],
	"art_badge": ["4 animals  •  3 difficulties", "4 animais  •  3 dificuldades", "4 animales  •  3 dificultades",
			"4 animaux  •  3 difficultés", "4 Tiere  •  3 Schwierigkeitsgrade", "4 animali  •  3 difficoltà",
			"4 animale  •  3 dificultăți", "4 zwierzęta  •  3 poziomy trudności"],

	# HUD.
	"next_tile_header": ["NEXT PIECE", "PRÓXIMA PEÇA", "PRÓXIMA PIEZA", "PROCHAINE PIÈCE", "NÄCHSTES TEIL", "PROSSIMO PEZZO", "PIESA URMĂTOARE", "NASTĘPNY ELEMENT"],
	"points_suffix": ["+%d points", "+%d pontos", "+%d puntos", "+%d points", "+%d Punkte", "+%d punti", "+%d puncte", "+%d pkt"],
	"tiles_left": ["Pieces: %d", "Peças: %d", "Piezas: %d", "Pièces : %d", "Teile: %d", "Pezzi: %d", "Piese: %d", "Elementy: %d"],
	"score_header": ["SCORE", "PONTUAÇÃO", "PUNTUACIÓN", "SCORE", "PUNKTZAHL", "PUNTEGGIO", "SCOR", "WYNIK"],
	"round_label": ["Round %d · %s", "Ronda %d · %s", "Ronda %d · %s", "Manche %d · %s", "Runde %d · %s", "Turno %d · %s", "Runda %d · %s", "Runda %d · %s"],
	"best": ["Best: %d", "Recorde: %d", "Récord: %d", "Record : %d", "Bestwert: %d", "Record: %d", "Record: %d", "Rekord: %d"],
	"hint_build": ["Click a slot to place the piece. %d left.", "Clica num espaço para pôr a peça. Faltam %d.",
			"Toca en una casilla para colocar la pieza. Quedan %d.",
			"Cliquez sur une case pour poser la pièce. Il en reste %d.",
			"Klicke auf ein Feld, um das Teil zu legen. Noch %d übrig.",
			"Clicca su una casella per mettere il pezzo. Ne restano %d.",
			"Dă clic pe o căsuță ca să pui piesa. Mai sunt %d.",
			"Kliknij pole, aby położyć element. Zostało: %d."],
	"hint_walk": ["%s always turns left when it can...", "%s vira sempre para a esquerda quando pode...",
			"%s siempre gira a la izquierda cuando puede...", "%s tourne toujours à gauche quand il peut...",
			"%s biegt immer links ab, wenn es kann...",
			"%s gira sempre a sinistra quando può...",
			"%s o ia mereu la stânga când poate...",
			"%s zawsze skręca w lewo, gdy może..."],

	# Title screen.
	"title_body": ["Choose an animal and a difficulty, then place tiles in the sea to build it a path to its food.\nThen it walks on its own, always turning left when it can.",
			"Escolhe um animal e uma dificuldade, e coloca as peças no mar para lhe fazer um caminho até à comida.\nDepois ele anda sozinho e vira sempre para a esquerda quando pode.",
			"Elige un animal y una dificultad, y coloca las piezas en el mar para hacerle un camino hasta la comida.\nDespués camina solo y siempre gira a la izquierda cuando puede.",
			"Choisis un animal et une difficulté, puis pose les pièces en mer pour lui tracer un chemin jusqu'à sa nourriture.\nEnsuite, il avance seul et tourne toujours à gauche quand il peut.",
			"Wähle ein Tier und einen Schwierigkeitsgrad, und lege Teile ins Meer, um ihm einen Weg zu seinem Futter zu bauen.\nDanach läuft es von selbst und biegt immer links ab, wenn es kann.",
			"Scegli un animale e una difficoltà, poi metti i pezzi nel mare per costruirgli un percorso fino al cibo.\nPoi cammina da solo, girando sempre a sinistra quando può.",
			"Alege un animal și o dificultate, apoi pune piese în mare ca să-i construiești un drum până la mâncare.\nApoi merge singur și o ia mereu la stânga când poate.",
			"Wybierz zwierzę i poziom trudności, a potem układaj elementy na morzu, aby zbudować mu drogę do jedzenia.\nPotem idzie samo i zawsze skręca w lewo, gdy może."],
	"play": ["Play", "Jogar", "Jugar", "Jouer", "Spielen", "Gioca", "Joacă", "Graj"],
	"play_again": ["Play again", "Jogar outra vez", "Jugar otra vez", "Rejouer", "Nochmal spielen", "Gioca ancora", "Joacă din nou", "Zagraj ponownie"],
	"round_button": ["Round %d", "Ronda %d", "Ronda %d", "Manche %d", "Runde %d", "Turno %d", "Runda %d", "Runda %d"],

	# Winning and losing.
	"win_body": ["%s reached the island.\nRound bonus: +%d\nScore: %d",
			"%s chegou à ilha.\nBónus da ronda: +%d\nPontuação: %d",
			"%s llegó a la isla.\nBonificación de la ronda: +%d\nPuntuación: %d",
			"%s est arrivé sur l'île.\nBonus de la manche : +%d\nScore : %d",
			"%s hat die Insel erreicht.\nRundenbonus: +%d\nPunktzahl: %d",
			"%s ha raggiunto l'isola.\nBonus del turno: +%d\nPunteggio: %d",
			"%s a ajuns pe insulă.\nBonusul rundei: +%d\nScor: %d",
			"%s jest już na wyspie.\nBonus za rundę: +%d\nWynik: %d"],
	"bonus_float": ["BONUS +%d", "BÓNUS +%d", "BONO +%d", "BONUS +%d", "BONUS +%d", "BONUS +%d", "BONUS +%d", "BONUS +%d"],
	"final_score": ["Final score: %d", "Pontuação final: %d", "Puntuación final: %d", "Score final : %d", "Endpunktzahl: %d", "Punteggio finale: %d", "Scor final: %d", "Wynik końcowy: %d"],
	"new_record": ["New record!", "Novo recorde!", "¡Nuevo récord!", "Nouveau record !", "Neuer Rekord!", "Nuovo record!", "Record nou!", "Nowy rekord!"],
	"lose_title_splash": ["Splash!", "Splash!", "¡Splash!", "Splash !", "Platsch!", "Splash!", "Pleosc!", "Plusk!"],
	"lose_body_splash": ["%s jumped into the water: there was no land ahead.",
			"%s saltou para a água: não havia terra à frente.",
			"%s saltó al agua: no había tierra por delante.",
			"%s a sauté à l'eau : il n'y avait pas de terre devant.",
			"%s ist ins Wasser gesprungen: es gab kein Land voraus.",
			"%s ha fatto un tuffo in acqua: davanti non c'era terra.",
			"%s a sărit în apă: nu era uscat în față.",
			"%s wskakuje do wody: dalej nie ma lądu."],
	"lose_title_noway": ["No way out!", "Sem saída!", "¡Sin salida!", "Sans issue !", "Kein Ausweg!", "Nessuna via d'uscita!", "Fără ieșire!", "Bez wyjścia!"],
	"lose_body_noway": ["%s couldn't find a path to its food and went back to the start.",
			"%s não encontrou caminho até à comida e voltou ao início.",
			"%s no encontró un camino hasta la comida y volvió al principio.",
			"%s n'a pas trouvé de chemin jusqu'à sa nourriture et est retourné au début.",
			"%s hat keinen Weg zum Futter gefunden und ist zum Start zurückgekehrt.",
			"%s non ha trovato la strada verso il cibo e ha dovuto tornare al punto di partenza.",
			"%s nu a găsit drumul spre mâncare și s-a întors la start.",
			"%s nie znajduje drogi do jedzenia i wraca na start."],
	"lose_title_lost": ["Lost!", "Perdido!", "¡Perdido!", "Perdu !", "Verloren!", "Perso!", "Rătăcit!", "Zgubiona droga!"],
	"lose_body_lost": ["%s wandered around without reaching its food.",
			"%s andou às voltas sem chegar à comida.",
			"%s dio vueltas sin llegar a la comida.",
			"%s a tourné en rond sans atteindre sa nourriture.",
			"%s ist herumgelaufen, ohne sein Futter zu erreichen.",
			"%s ha girato a vuoto senza raggiungere il cibo.",
			"%s s-a tot învârtit fără să ajungă la mâncare.",
			"%s krąży w kółko i nie dociera do jedzenia."],

	# Animals (picker label, capitalized) and their subject phrase (lowercase, mid-sentence).
	"animal_monkey": ["Monkey", "Macaco", "Mono", "Singe", "Affe", "Scimmia", "Maimuță", "Małpa"],
	"animal_horse": ["Horse", "Cavalo", "Caballo", "Cheval", "Pferd", "Cavallo", "Cal", "Koń"],
	"animal_cat": ["Cat", "Gato", "Gato", "Chat", "Katze", "Gatto", "Pisică", "Kot"],
	"animal_dog": ["Dog", "Cão", "Perro", "Chien", "Hund", "Cane", "Câine", "Pies"],
	"who_monkey": ["the monkey", "o macaco", "el mono", "le singe", "der Affe", "la scimmia", "maimuța", "małpa"],
	"who_horse": ["the horse", "o cavalo", "el caballo", "le cheval", "das Pferd", "il cavallo", "calul", "koń"],
	"who_cat": ["the cat", "o gato", "el gato", "le chat", "die Katze", "il gatto", "pisica", "kot"],
	"who_dog": ["the dog", "o cão", "el perro", "le chien", "der Hund", "il cane", "câinele", "pies"],
	"win_bananas": ["Bananas!", "Bananas!", "¡Plátanos!", "Des bananes !", "Bananen!", "Banane!", "Banane!", "Banany!"],
	"win_carrots": ["Carrots!", "Cenouras!", "¡Zanahorias!", "Des carottes !", "Karotten!", "Carote!", "Morcovi!", "Marchewki!"],
	"win_fish": ["Fish!", "Peixe!", "¡Pescado!", "Du poisson !", "Fisch!", "Pesce!", "Pește!", "Ryba!"],
	"win_bone": ["Bone!", "Osso!", "¡Hueso!", "Un os !", "Knochen!", "Osso!", "Os!", "Kość!"],

	# Difficulties.
	"difficulty_easy": ["Easy", "Fácil", "Fácil", "Facile", "Leicht", "Facile", "Ușor", "Łatwy"],
	"difficulty_medium": ["Medium", "Médio", "Medio", "Moyen", "Mittel", "Medio", "Mediu", "Średni"],
	"difficulty_hard": ["Hard", "Difícil", "Difícil", "Difficile", "Schwer", "Difficile", "Greu", "Trudny"],

	# Settings and menu.
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen", "Impostazioni", "Setări", "Ustawienia"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache", "Lingua", "Limbă", "Język"],
	"sound": ["Sound", "Som", "Sonido", "Son", "Ton", "Suono", "Sunet", "Dźwięk"],
	"sound_on": ["Sound: On", "Som: Ligado", "Sonido: Activado", "Son : Activé", "Ton: Ein", "Suono: Attivo", "Sunet: Pornit", "Dźwięk: Wł."],
	"sound_off": ["Sound: Off", "Som: Desligado", "Sonido: Desactivado", "Son : Désactivé", "Ton: Aus", "Suono: Disattivo", "Sunet: Oprit", "Dźwięk: Wył."],
	"close": ["Close", "Fechar", "Cerrar", "Fermer", "Schließen", "Chiudi", "Închide", "Zamknij"],
	"menu": ["Menu", "Menu", "Menú", "Menu", "Menü", "Menu", "Meniu", "Menu"],
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
