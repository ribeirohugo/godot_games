extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. Game and machine names are not translated.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"]]

const TEXT := {
	# Lobby.
	"balance": ["BALANCE", "SALDO", "SALDO", "SOLDE", "GUTHABEN"],
	"choose": ["Choose a machine", "Escolhe uma máquina", "Elige una máquina", "Choisis une machine", "Wähle einen Automaten"],
	"play": ["PLAY", "JOGAR", "JUGAR", "JOUER", "SPIELEN"],
	"format": ["%d reels · %d lines", "%d rolos · %d linhas", "%d rodillos · %d líneas", "%d rouleaux · %d lignes", "%d Walzen · %d Linien"],
	"jackpot": ["JACKPOT", "JACKPOT", "JACKPOT", "JACKPOT", "JACKPOT"],
	"free_spins_badge": ["FREE SPINS", "RODADAS GRÁTIS", "GIROS GRATIS", "TOURS GRATUITS", "FREISPIELE"],
	"classic_badge": ["CLASSIC", "CLÁSSICA", "CLÁSICA", "CLASSIQUE", "KLASSIK"],

	# Machine panel.
	"lobby": ["Lobby", "Lobby", "Lobby", "Lobby", "Lobby"],
	"bet": ["TOTAL BET", "APOSTA TOTAL", "APUESTA TOTAL", "MISE TOTALE", "GESAMTEINSATZ"],
	"win": ["WIN", "GANHO", "GANANCIA", "GAIN", "GEWINN"],
	"lines": ["LINES", "LINHAS", "LÍNEAS", "LIGNES", "LINIEN"],
	"spin": ["SPIN", "GIRAR", "GIRAR", "LANCER", "DREHEN"],
	"stop": ["STOP", "PARAR", "PARAR", "STOP", "STOPP"],
	"auto": ["AUTO", "AUTO", "AUTO", "AUTO", "AUTO"],
	"turbo": ["TURBO", "TURBO", "TURBO", "TURBO", "TURBO"],
	"max_bet": ["MAX BET", "APOSTA MÁX", "APUESTA MÁX", "MISE MAX", "MAX EINSATZ"],
	"refill": ["+5000", "+5000", "+5000", "+5000", "+5000"],

	# Messages.
	"good_luck": ["Good luck!", "Boa sorte!", "¡Buena suerte!", "Bonne chance !", "Viel Glück!"],
	"no_money": ["Not enough coins for this bet", "Moedas insuficientes para esta aposta", "Monedas insuficientes para esta apuesta",
			"Pas assez de pièces pour cette mise", "Nicht genug Münzen für diesen Einsatz"],
	"broke": ["Out of coins! Press SPIN for 5000 more.", "Sem moedas! Carrega em GIRAR para receber 5000.", "¡Sin monedas! Pulsa GIRAR para recibir 5000.",
			"Plus de pièces ! Appuie sur LANCER pour en avoir 5000.", "Keine Münzen! Drück DREHEN für 5000 neue."],
	"line_win": ["Line %d · %d× pays %s", "Linha %d · %d× paga %s", "Línea %d · %d× paga %s", "Ligne %d · %d× paie %s", "Linie %d · %d× zahlt %s"],
	"total_win": ["You won %s!", "Ganhaste %s!", "¡Ganaste %s!", "Tu as gagné %s !", "Du hast %s gewonnen!"],
	"no_win": ["Spin again!", "Gira outra vez!", "¡Gira otra vez!", "Relance !", "Nochmal drehen!"],
	"help": ["Space spin · ↑↓ bet · A auto · T turbo · I pay table · Esc lobby",
			"Espaço girar · ↑↓ aposta · A auto · T turbo · I tabela · Esc lobby",
			"Espacio girar · ↑↓ apuesta · A auto · T turbo · I tabla · Esc lobby",
			"Espace lancer · ↑↓ mise · A auto · T turbo · I gains · Échap lobby",
			"Leertaste drehen · ↑↓ Einsatz · A Auto · T Turbo · I Gewinne · Esc Lobby"],

	# Big moments.
	"big_win": ["BIG WIN", "GRANDE GANHO", "GRAN PREMIO", "GROS GAIN", "GROSSER GEWINN"],
	"mega_win": ["MEGA WIN", "MEGA GANHO", "MEGA PREMIO", "MÉGA GAIN", "MEGA GEWINN"],
	"epic_win": ["EPIC WIN", "GANHO ÉPICO", "PREMIO ÉPICO", "GAIN ÉPIQUE", "EPISCHER GEWINN"],
	"free_spins": ["FREE SPINS", "RODADAS GRÁTIS", "GIROS GRATIS", "TOURS GRATUITS", "FREISPIELE"],
	"free_spins_won": ["%d free spins · all wins ×%d", "%d rodadas grátis · ganhos ×%d", "%d giros gratis · premios ×%d",
			"%d tours gratuits · gains ×%d", "%d Freispiele · Gewinne ×%d"],
	"more_spins": ["+%d FREE SPINS", "+%d RODADAS GRÁTIS", "+%d GIROS GRATIS", "+%d TOURS GRATUITS", "+%d FREISPIELE"],
	"free_left": ["FREE SPIN %d / %d", "RODADA GRÁTIS %d / %d", "GIRO GRATIS %d / %d", "TOUR GRATUIT %d / %d", "FREISPIEL %d / %d"],
	"free_total": ["Free spins won", "Ganho nas rodadas grátis", "Ganado en giros gratis", "Gains des tours gratuits", "Freispiel-Gewinn"],
	"tap_continue": ["Click to continue", "Clica para continuar", "Haz clic para continuar", "Clique pour continuer", "Klicken zum Fortfahren"],

	# Pay table.
	"paytable": ["Pay table", "Tabela de prémios", "Tabla de premios", "Table des gains", "Gewinntabelle"],
	"paytable_note": ["Wins pay left to right on active lines. Values shown for the current bet.",
			"Os ganhos pagam da esquerda para a direita nas linhas ativas. Valores para a aposta atual.",
			"Los premios pagan de izquierda a derecha en las líneas activas. Valores para la apuesta actual.",
			"Les gains se lisent de gauche à droite sur les lignes actives. Valeurs pour la mise actuelle.",
			"Gewinne zählen von links nach rechts auf aktiven Linien. Werte für den aktuellen Einsatz."],
	"wild_rule": ["WILD replaces every symbol except BONUS. %d WILDs on a line win the jackpot.",
			"WILD substitui todos os símbolos menos o BONUS. %d WILD numa linha ganham o jackpot.",
			"WILD sustituye a todos los símbolos menos BONUS. %d WILD en una línea ganan el jackpot.",
			"WILD remplace tous les symboles sauf BONUS. %d WILD sur une ligne gagnent le jackpot.",
			"WILD ersetzt alle Symbole außer BONUS. %d WILDs auf einer Linie gewinnen den Jackpot."],
	"scatter_rule": ["3 or more BONUS anywhere: %d free spins with all wins ×%d.",
			"3 ou mais BONUS em qualquer lugar: %d rodadas grátis com ganhos ×%d.",
			"3 o más BONUS en cualquier lugar: %d giros gratis con premios ×%d.",
			"3 BONUS ou plus n'importe où : %d tours gratuits, gains ×%d.",
			"3 oder mehr BONUS irgendwo: %d Freispiele, alle Gewinne ×%d."],
	"paylines": ["Paylines", "Linhas de pagamento", "Líneas de pago", "Lignes de paiement", "Gewinnlinien"],
	"return": ["Return to player: about 96%", "Retorno ao jogador: cerca de 96%", "Retorno al jugador: cerca del 96%",
			"Taux de retour : environ 96 %", "Auszahlungsquote: etwa 96 %"],

	# Menu.
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache"],
	"sound": ["Sound effects", "Efeitos sonoros", "Efectos de sonido", "Effets sonores", "Soundeffekte"],
	"statistics": ["Statistics", "Estatísticas", "Estadísticas", "Statistiques", "Statistik"],
	"spins": ["Spins", "Jogadas", "Tiradas", "Lancers", "Drehungen"],
	"biggest_win": ["Biggest win", "Maior ganho", "Mayor ganancia", "Plus gros gain", "Größter Gewinn"],
	"jackpots_won": ["Jackpots won", "Jackpots ganhos", "Jackpots ganados", "Jackpots gagnés", "Gewonnene Jackpots"],
	"free_rounds": ["Free spin rounds", "Rondas de rodadas grátis", "Rondas de giros gratis", "Séries de tours gratuits", "Freispielrunden"],
	"reset": ["Start over with 5000 coins", "Recomeçar com 5000 moedas", "Empezar de nuevo con 5000 monedas",
			"Recommencer avec 5000 pièces", "Neu starten mit 5000 Münzen"],
	"confirm_reset": ["Press again to start over", "Carrega outra vez para recomeçar", "Pulsa otra vez para empezar de nuevo",
			"Appuie encore pour recommencer", "Nochmal drücken zum Neustart"],
	"play_money": ["Play money only. Just for fun, no real prizes.", "Apenas dinheiro fictício. Só por diversão, sem prémios reais.",
			"Solo dinero ficticio. Solo por diversión, sin premios reales.", "Argent fictif uniquement. Pour le plaisir, sans vrais gains.",
			"Nur Spielgeld. Nur zum Spaß, keine echten Preise."],
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
