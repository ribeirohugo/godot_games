extends RefCounted
## Every text in the game. The game shows them with tr("key").
## The game is only in Portuguese, so each value holds a single entry (the order of LANGUAGES).

const LANGUAGES := [["pt", "Português"]]

const TEXT := {
	# Title screen.
	"subtitle": ["O clássico jogo de cartas português"],
	"play": ["Jogar"],
	"continue": ["Continuar"],
	"new_match": ["Nova partida"],
	"rules": ["Regras"],

	# Players.
	"name_0": ["Tu"],
	"name_1": ["Zé"],
	"name_2": ["Rita"],
	"name_3": ["Manel"],

	# Table.
	"us": ["NÓS"],
	"them": ["ELES"],
	"points": ["PONTOS"],
	"games": ["JOGOS"],
	"hand_n": ["MÃO %d"],
	"trump": ["TRUNFO"],
	"hearts": ["Copas"],
	"diamonds": ["Ouros"],
	"spades": ["Espadas"],
	"clubs": ["Paus"],
	"last_trick": ["Última vaza"],
	"shuffling": ["A baralhar…"],
	"dealer_you": ["És tu a dar as cartas"],
	"dealer_other": ["%s dá as cartas"],
	"your_turn": ["A tua vez: escolhe uma carta"],
	"must_follow": ["Tens de assistir: joga uma carta de %s"],
	"cut": ["Corte!"],

	# End of a hand.
	"won_hand": ["Ganhámos a mão!"],
	"lost_hand": ["Perdemos a mão"],
	"draw_hand": ["Empate!"],
	"won_match": ["Ganhámos a partida!"],
	"lost_match": ["Perdemos a partida"],
	"simple": ["Vitória simples"],
	"simple_loss": ["Derrota simples"],
	"capote": ["Capote!"],
	"bandeira": ["Bandeira!"],
	"games_us_1": ["+1 jogo para nós"],
	"games_us_n": ["+%d jogos para nós"],
	"games_them_1": ["+1 jogo para eles"],
	"games_them_n": ["+%d jogos para eles"],
	"draw_note": ["60 a 60: ninguém ganha jogos"],
	"tricks_n": ["%d vazas"],
	"next_hand": ["Próxima mão"],
	"match_to": ["Ganha a partida quem fizer %d jogos"],

	# Menu.
	"settings": ["Definições"],
	"sound": ["Efeitos sonoros"],
	"speed": ["Velocidade do jogo"],
	"speed_normal": ["Normal"],
	"speed_fast": ["Rápida"],
	"statistics": ["Estatísticas"],
	"matches": ["Partidas jogadas"],
	"match_wins": ["Partidas ganhas"],
	"hands": ["Mãos jogadas"],
	"hand_wins": ["Mãos ganhas"],
	"capotes": ["Capotes"],
	"bandeiras": ["Bandeiras"],
	"best_hand": ["Melhor mão (pontos)"],
	"confirm_new": ["Carrega outra vez para recomeçar"],
	"sure": ["Tens a certeza?"],
	"keys_help": ["← → escolher carta · Enter jogar · Esc menu"],

	# Rules.
	"rules_title": ["Regras da Sueca"],
	"rules_1": ["Jogam quatro, em duas equipas: tu e a tua parceira (à tua frente) contra os dois jogadores dos lados. Joga-se no sentido contrário ao dos ponteiros do relógio."],
	"rules_2": ["Usa-se um baralho de 40 cartas (sem 8, 9 e 10) e cada jogador recebe 10. A última carta de quem dá fica à vista: o seu naipe é o trunfo."],
	"rules_3": ["Começa o jogador à direita de quem deu. É obrigatório assistir, isto é, jogar uma carta do naipe que saiu. Quem não tem pode cortar com trunfo ou jogar outra carta qualquer."],
	"rules_4": ["A vaza é de quem jogar o trunfo mais alto ou, se não houver trunfos, a carta mais alta do naipe que saiu. Quem ganha a vaza começa a seguinte."],
	"rules_5": ["Ordem das cartas: Ás, 7 (a bisca), Rei, Valete, Dama, 6, 5, 4, 3 e 2. Valem pontos o Ás (11), o 7 (10), o Rei (4), o Valete (3) e a Dama (2): 120 pontos no total."],
	"rules_6": ["Ganha a mão a equipa que fizer 61 pontos ou mais: 1 jogo. Com 91 ou mais é capote (2 jogos) e com todas as vazas é bandeira (4 jogos). Com 60 a 60 ninguém ganha."],
	"rules_7": ["Ganha a partida a primeira equipa a chegar aos 4 jogos."],
	"rules_cards": ["Nas cartas: R = Rei, V = Valete, D = Dama"],
}


## Registers all languages with Godot's TranslationServer.
static func install() -> void:
	for i in LANGUAGES.size():
		var translation := Translation.new()
		translation.locale = LANGUAGES[i][0]
		for key: String in TEXT:
			translation.add_message(key, TEXT[key][i])
		TranslationServer.add_translation(translation)


## The game only has Portuguese.
static func system_language() -> String:
	return "pt"
