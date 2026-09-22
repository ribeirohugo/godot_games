extends RefCounted
## Every text in the game. The game shows them with tr("key").
## The game is only in Portuguese, so each value holds a single entry (the order of LANGUAGES).

const LANGUAGES := [["pt", "Português"]]

const TEXT := {
	# Title screen.
	"subtitle": ["O clássico jogo de cartas português, a dois"],
	"play": ["Jogar"],
	"continue": ["Continuar"],
	"new_match": ["Nova partida"],
	"rules": ["Regras"],

	# Players.
	"name_0": ["Tu"],
	"name_1": ["Zé"],

	# Table.
	"points": ["PONTOS"],
	"games": ["JOGOS"],
	"hand_n": ["MÃO %d"],
	"trump": ["TRUNFO"],
	"hearts": ["Copas"],
	"diamonds": ["Ouros"],
	"spades": ["Espadas"],
	"clubs": ["Paus"],
	"last_trick": ["Última vaza"],
	"stock_n": ["%d no monte"],
	"stock_empty": ["Acabou o monte: agora é obrigatório assistir"],
	"shuffling": ["A baralhar…"],
	"dealer_you": ["És tu a dar as cartas"],
	"dealer_other": ["%s dá as cartas"],
	"your_turn": ["A tua vez: escolhe uma carta"],
	"must_follow": ["Tens de assistir: joga uma carta de %s"],
	"swap": ["Trocar o 2"],
	"swapped_you": ["Trocaste o 2 pelo trunfo"],
	"swapped_other": ["%s trocou o 2 pelo trunfo"],
	"cut": ["Corte!"],

	# End of a hand.
	"won_hand": ["Ganhaste a mão!"],
	"lost_hand": ["Perdeste a mão"],
	"draw_hand": ["Empate!"],
	"won_match": ["Ganhaste a partida!"],
	"lost_match": ["Perdeste a partida"],
	"simple": ["Vitória simples"],
	"simple_loss": ["Derrota simples"],
	"capote": ["Capote!"],
	"bandeira": ["Bandeira!"],
	"games_you_1": ["+1 jogo para ti"],
	"games_you_n": ["+%d jogos para ti"],
	"games_other_1": ["+1 jogo para o %s"],
	"games_other_n": ["+%d jogos para o %s"],
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
	"variant": ["Variante"],
	"variant_3": ["Bisca de 3"],
	"variant_7": ["Bisca de 7"],
	"variant_9": ["Bisca de 9"],
	"variant_next": ["A variante muda na próxima mão"],
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
	"keys_help": ["← → escolher carta · Enter jogar · T trocar o 2 · Esc menu"],

	# Rules.
	"rules_title": ["Regras da Bisca"],
	"rules_1": ["Joga-se a dois, tu contra o Zé, com um baralho de 40 cartas (sem 8, 9 e 10). Cada jogador recebe 3 cartas (7 ou 9 nas outras variantes) e a carta seguinte fica virada debaixo do monte: o seu naipe é o trunfo."],
	"rules_2": ["Começa quem não deu. Enquanto houver cartas no monte podes jogar qualquer carta: não é obrigatório assistir nem cortar."],
	"rules_3": ["A vaza é de quem jogar o trunfo mais alto ou, se não houver trunfos, a carta mais alta do naipe que saiu. Quem ganha tira primeiro uma carta do monte, a seguir o outro, e começa a vaza seguinte."],
	"rules_4": ["Quem tiver o 2 de trunfo pode, na sua vez, trocá-lo pelo trunfo virado enquanto houver monte. O trunfo virado é a última carta a sair do monte."],
	"rules_5": ["Quando o monte acaba é obrigatório assistir, isto é, jogar uma carta do naipe que saiu. Quem não tem joga outra carta qualquer."],
	"rules_6": ["Ordem das cartas: Ás, 7 (a bisca), Rei, Valete, Dama, 6, 5, 4, 3 e 2. Valem pontos o Ás (11), o 7 (10), o Rei (4), o Valete (3) e a Dama (2): 120 pontos no total."],
	"rules_7": ["Ganha a mão quem fizer 61 pontos ou mais: 1 jogo. Com 91 ou mais é capote (2 jogos) e com os 120 pontos é bandeira (4 jogos). Com 60 a 60 ninguém ganha. Ganha a partida quem chegar primeiro aos 4 jogos."],
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
