extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. The game name (Roleta) is not translated.

const LANGUAGES := [["en", "English"], ["pt", "Português"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"]]

const TEXT := {
	# Header.
	"balance": ["BALANCE", "SALDO", "SALDO", "SOLDE", "GUTHABEN"],
	"total_bet": ["BET", "APOSTA", "APUESTA", "MISE", "EINSATZ"],
	"last_win": ["WIN", "GANHO", "GANANCIA", "GAIN", "GEWINN"],
	"history": ["LAST NUMBERS", "ÚLTIMOS NÚMEROS", "ÚLTIMOS NÚMEROS", "DERNIERS NUMÉROS", "LETZTE ZAHLEN"],

	# Table.
	"red": ["RED", "VERMELHO", "ROJO", "ROUGE", "ROT"],
	"black": ["BLACK", "PRETO", "NEGRO", "NOIR", "SCHWARZ"],
	"even": ["EVEN", "PAR", "PAR", "PAIR", "GERADE"],
	"odd": ["ODD", "ÍMPAR", "IMPAR", "IMPAIR", "UNGERADE"],
	"low": ["1 TO 18", "1 A 18", "1 A 18", "1 À 18", "1 BIS 18"],
	"high": ["19 TO 36", "19 A 36", "19 A 36", "19 À 36", "19 BIS 36"],
	"dozen_1": ["1st 12", "1ª DÚZIA", "1ª DOCENA", "1ère DOUZ.", "1. DUTZEND"],
	"dozen_2": ["2nd 12", "2ª DÚZIA", "2ª DOCENA", "2e DOUZ.", "2. DUTZEND"],
	"dozen_3": ["3rd 12", "3ª DÚZIA", "3ª DOCENA", "3e DOUZ.", "3. DUTZEND"],
	"green": ["GREEN", "VERDE", "VERDE", "VERT", "GRÜN"],

	# Buttons.
	"spin": ["SPIN", "GIRAR", "GIRAR", "LANCER", "DREHEN"],
	"clear": ["Clear", "Limpar", "Borrar", "Effacer", "Leeren"],
	"undo": ["Undo", "Desfazer", "Deshacer", "Annuler", "Zurück"],
	"rebet": ["Rebet", "Repetir", "Repetir", "Remiser", "Wiederholen"],
	"double": ["Double", "Dobrar", "Doblar", "Doubler", "Verdoppeln"],
	"refill": ["Get 1000 chips", "Receber 1000 fichas", "Recibir 1000 fichas", "Recevoir 1000 jetons", "1000 Chips holen"],

	# Messages.
	"place_bets": ["Place your bets", "Façam as vossas apostas", "Hagan sus apuestas", "Faites vos jeux", "Machen Sie Ihr Spiel"],
	"no_more_bets": ["No more bets!", "Nada mais vai!", "¡No va más!", "Rien ne va plus !", "Nichts geht mehr!"],
	"need_bet": ["Place a chip on the table first", "Coloca primeiro uma ficha na mesa", "Coloca primero una ficha en la mesa",
			"Pose d'abord un jeton sur la table", "Setze zuerst einen Chip auf den Tisch"],
	"no_money": ["Not enough chips", "Fichas insuficientes", "Fichas insuficientes", "Pas assez de jetons", "Nicht genug Chips"],
	"table_max": ["Table limit reached on this spot", "Limite da mesa atingido nesta aposta", "Límite de mesa alcanzado en esta apuesta",
			"Limite de la table atteinte ici", "Tischlimit auf diesem Feld erreicht"],
	"you_win": ["You win %s!", "Ganhaste %s!", "¡Ganas %s!", "Tu gagnes %s !", "Du gewinnst %s!"],
	"you_lose": ["No luck this time", "Não foi desta vez", "No hubo suerte", "Pas de chance", "Diesmal kein Glück"],
	"broke": ["Out of chips! Get more to keep playing.", "Sem fichas! Recebe mais para continuar.", "¡Sin fichas! Recibe más para seguir.",
			"Plus de jetons ! Recharge pour continuer.", "Keine Chips mehr! Hol dir neue."],
	"bet_help": ["Click to bet · right click removes · edges and corners bet on several numbers",
			"Clica para apostar · botão direito retira · bordas e cantos apostam em vários números",
			"Clic para apostar · clic derecho quita · bordes y esquinas apuestan a varios números",
			"Clic pour miser · clic droit retire · bords et coins misent sur plusieurs numéros",
			"Klick setzt · Rechtsklick entfernt · Kanten und Ecken setzen auf mehrere Zahlen"],
	"pays": ["pays %d to 1", "paga %d para 1", "paga %d a 1", "paie %d contre 1", "zahlt %d zu 1"],

	# Menu.
	"settings": ["Settings", "Definições", "Ajustes", "Paramètres", "Einstellungen"],
	"language": ["Language", "Idioma", "Idioma", "Langue", "Sprache"],
	"sound": ["Sound effects", "Efeitos sonoros", "Efectos de sonido", "Effets sonores", "Soundeffekte"],
	"statistics": ["Statistics", "Estatísticas", "Estadísticas", "Statistiques", "Statistik"],
	"spins": ["Spins", "Jogadas", "Tiradas", "Lancers", "Drehungen"],
	"wins": ["Winning spins", "Jogadas ganhas", "Tiradas ganadas", "Lancers gagnants", "Gewinndrehungen"],
	"biggest_win": ["Biggest win", "Maior ganho", "Mayor ganancia", "Plus gros gain", "Größter Gewinn"],
	"best_balance": ["Best balance", "Melhor saldo", "Mejor saldo", "Meilleur solde", "Höchstes Guthaben"],
	"reset": ["Start over with 1000", "Recomeçar com 1000", "Empezar de nuevo con 1000", "Recommencer avec 1000", "Neu starten mit 1000"],
	"confirm_reset": ["Press again to start over", "Carrega outra vez para recomeçar", "Pulsa otra vez para empezar de nuevo",
			"Appuie encore pour recommencer", "Nochmal drücken zum Neustart"],
	"play_money": ["Play money only. Just for fun.", "Apenas dinheiro fictício. Só por diversão.", "Solo dinero ficticio. Solo por diversión.",
			"Argent fictif uniquement. Juste pour le plaisir.", "Nur Spielgeld. Nur zum Spaß."],
	"keys_help": ["Space spin · Backspace clear · Z undo · R rebet · D double · 1–6 chips",
			"Espaço girar · Backspace limpar · Z desfazer · R repetir · D dobrar · 1–6 fichas",
			"Espacio girar · Retroceso borrar · Z deshacer · R repetir · D doblar · 1–6 fichas",
			"Espace lancer · Retour effacer · Z annuler · R remiser · D doubler · 1–6 jetons",
			"Leertaste drehen · Rücktaste leeren · Z zurück · R wiederholen · D verdoppeln · 1–6 Chips"],
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
