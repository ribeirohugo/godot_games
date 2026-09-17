extends RefCounted
## Every text in the game, in each language. Controls show them with their `text` set to the
## key (Godot auto-translates), formatted strings use tr("key") % values directly.
## Values follow the order of LANGUAGES. The game's own name is not translated.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"]]

const TEXT := {
	# HUD.
	"next_tile_header": ["NEXT PIECE", "PRÓXIMA PEÇA", "PRÓXIMA PIEZA", "PROCHAINE PIÈCE", "NÄCHSTES TEIL"],
	"points_suffix": ["+%d points", "+%d pontos", "+%d puntos", "+%d points", "+%d Punkte"],
	"tiles_left": ["Pieces: %d", "Peças: %d", "Piezas: %d", "Pièces : %d", "Teile: %d"],
	"score_header": ["SCORE", "PONTUAÇÃO", "PUNTUACIÓN", "SCORE", "PUNKTZAHL"],
	"round_label": ["Round %d · %s", "Ronda %d · %s", "Ronda %d · %s", "Manche %d · %s", "Runde %d · %s"],
	"best": ["Best: %d", "Recorde: %d", "Récord: %d", "Record : %d", "Bestwert: %d"],
	"hint_build": ["Click a slot to place the piece. %d left.", "Clica num espaço para pôr a peça. Faltam %d.",
			"Toca en una casilla para colocar la pieza. Quedan %d.",
			"Cliquez sur une case pour poser la pièce. Il en reste %d.",
			"Klicke auf ein Feld, um das Teil zu legen. Noch %d übrig."],
	"hint_walk": ["%s always turns left when it can...", "%s vira sempre para a esquerda quando pode...",
			"%s siempre gira a la izquierda cuando puede...", "%s tourne toujours à gauche quand il peut...",
			"%s biegt immer links ab, wenn es kann..."],

	# Title screen.
	"title_body": ["Choose an animal and a difficulty, then place tiles in the sea to build it a path to its food.\nThen it walks on its own, always turning left when it can.",
			"Escolhe um animal e uma dificuldade, e coloca as peças no mar para lhe fazer um caminho até à comida.\nDepois ele anda sozinho e vira sempre para a esquerda quando pode.",
			"Elige un animal y una dificultad, y coloca las piezas en el mar para hacerle un camino hasta la comida.\nDespués camina solo y siempre gira a la izquierda cuando puede.",
			"Choisis un animal et une difficulté, puis pose les pièces en mer pour lui tracer un chemin jusqu'à sa nourriture.\nEnsuite, il avance seul et tourne toujours à gauche quand il peut.",
			"Wähle ein Tier und einen Schwierigkeitsgrad, und lege Teile ins Meer, um ihm einen Weg zu seinem Futter zu bauen.\nDanach läuft es von selbst und biegt immer links ab, wenn es kann."],
	"play": ["Play", "Jogar", "Jugar", "Jouer", "Spielen"],
	"play_again": ["Play again", "Jogar outra vez", "Jugar otra vez", "Rejouer", "Nochmal spielen"],
	"round_button": ["Round %d", "Ronda %d", "Ronda %d", "Manche %d", "Runde %d"],

	# Winning and losing.
	"win_body": ["%s reached the island.\nRound bonus: +%d\nScore: %d",
			"%s chegou à ilha.\nBónus da ronda: +%d\nPontuação: %d",
			"%s llegó a la isla.\nBonificación de la ronda: +%d\nPuntuación: %d",
			"%s est arrivé sur l'île.\nBonus de la manche : +%d\nScore : %d",
			"%s hat die Insel erreicht.\nRundenbonus: +%d\nPunktzahl: %d"],
	"bonus_float": ["BONUS +%d", "BÓNUS +%d", "BONO +%d", "BONUS +%d", "BONUS +%d"],
	"final_score": ["Final score: %d", "Pontuação final: %d", "Puntuación final: %d", "Score final : %d", "Endpunktzahl: %d"],
	"new_record": ["New record!", "Novo recorde!", "¡Nuevo récord!", "Nouveau record !", "Neuer Rekord!"],
	"lose_title_splash": ["Splash!", "Splash!", "¡Splash!", "Splash !", "Platsch!"],
	"lose_body_splash": ["%s jumped into the water: there was no land ahead.",
			"%s saltou para a água: não havia terra à frente.",
			"%s saltó al agua: no había tierra por delante.",
			"%s a sauté à l'eau : il n'y avait pas de terre devant.",
			"%s ist ins Wasser gesprungen: es gab kein Land voraus."],
	"lose_title_noway": ["No way out!", "Sem saída!", "¡Sin salida!", "Sans issue !", "Kein Ausweg!"],
	"lose_body_noway": ["%s couldn't find a path to its food and went back to the start.",
			"%s não encontrou caminho até à comida e voltou ao início.",
			"%s no encontró un camino hasta la comida y volvió al principio.",
			"%s n'a pas trouvé de chemin jusqu'à sa nourriture et est retourné au début.",
			"%s hat keinen Weg zum Futter gefunden und ist zum Start zurückgekehrt."],
	"lose_title_lost": ["Lost!", "Perdido!", "¡Perdido!", "Perdu !", "Verloren!"],
	"lose_body_lost": ["%s wandered around without reaching its food.",
			"%s andou às voltas sem chegar à comida.",
			"%s dio vueltas sin llegar a la comida.",
			"%s a tourné en rond sans atteindre sa nourriture.",
			"%s ist herumgelaufen, ohne sein Futter zu erreichen."],

	# Animals (picker label, capitalized) and their subject phrase (lowercase, mid-sentence).
	"animal_monkey": ["Monkey", "Macaco", "Mono", "Singe", "Affe"],
	"animal_horse": ["Horse", "Cavalo", "Caballo", "Cheval", "Pferd"],
	"animal_cat": ["Cat", "Gato", "Gato", "Chat", "Katze"],
	"animal_dog": ["Dog", "Cão", "Perro", "Chien", "Hund"],
	"who_monkey": ["the monkey", "o macaco", "el mono", "le singe", "der Affe"],
	"who_horse": ["the horse", "o cavalo", "el caballo", "le cheval", "das Pferd"],
	"who_cat": ["the cat", "o gato", "el gato", "le chat", "die Katze"],
	"who_dog": ["the dog", "o cão", "el perro", "le chien", "der Hund"],
	"win_bananas": ["Bananas!", "Bananas!", "¡Plátanos!", "Des bananes !", "Bananen!"],
	"win_carrots": ["Carrots!", "Cenouras!", "¡Zanahorias!", "Des carottes !", "Karotten!"],
	"win_fish": ["Fish!", "Peixe!", "¡Pescado!", "Du poisson !", "Fisch!"],
	"win_bone": ["Bone!", "Osso!", "¡Hueso!", "Un os !", "Knochen!"],

	# Difficulties.
	"difficulty_easy": ["Easy", "Fácil", "Fácil", "Facile", "Leicht"],
	"difficulty_medium": ["Medium", "Médio", "Medio", "Moyen", "Mittel"],
	"difficulty_hard": ["Hard", "Difícil", "Difícil", "Difficile", "Schwer"],

	# Settings and menu.
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache"],
	"sound": ["Sound", "Som", "Sonido", "Son", "Ton"],
	"sound_on": ["Sound: On", "Som: Ligado", "Sonido: Activado", "Son : Activé", "Ton: Ein"],
	"sound_off": ["Sound: Off", "Som: Desligado", "Sonido: Desactivado", "Son : Désactivé", "Ton: Aus"],
	"close": ["Close", "Fechar", "Cerrar", "Fermer", "Schließen"],
	"menu": ["Menu", "Menu", "Menú", "Menu", "Menü"],
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
