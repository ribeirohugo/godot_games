extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. Weapon names are the same in every language (weapons.gd).

const LANGUAGES := [["en", "English"], ["pt", "Português"]]

const TEXT := {
	# Menu.
	"tagline": ["Plant the bomb or stop it. Five against five, one life per round.",
			"Planta a bomba ou trava-a. Cinco contra cinco, uma vida por ronda."],
	"play": ["Play", "Jogar"],
	"how_to_play": ["How to Play", "Como Jogar"],
	"settings": ["Settings", "Definições"],
	"quit": ["Quit", "Sair"],
	"back": ["Back", "Voltar"],
	"record": ["Matches won %d · lost %d · drawn %d", "Partidas ganhas %d · perdidas %d · empatadas %d"],
	"hint_keys": ["Arrows move · Enter selects · Esc goes back", "Setas movem · Enter escolhe · Esc volta atrás"],
	"hint_pad": ["D-pad moves · A selects · B goes back", "D-pad move · A escolhe · B volta atrás"],

	# Match setup.
	"match_setup": ["New Match", "Nova Partida"],
	"map": ["Map", "Mapa"],
	"map_dunes": ["Dunes", "Dunas"],
	"map_depot": ["Depot", "Armazém"],
	"side": ["Your side", "O teu lado"],
	"side_att": ["Attackers", "Atacantes"],
	"side_def": ["Defenders", "Defensores"],
	"side_auto": ["Random", "Aleatório"],
	"team_size": ["Teams", "Equipas"],
	"size_n": ["%d vs %d", "%d contra %d"],
	"bot_skill": ["Bot skill", "Nível dos bots"],
	"skill_0": ["Easy", "Fácil"],
	"skill_1": ["Normal", "Normal"],
	"skill_2": ["Hard", "Difícil"],
	"skill_3": ["Expert", "Perito"],
	"match_length": ["Match length", "Duração"],
	"length_0": ["Short: first to 9 of 16 rounds", "Curta: primeiro a 9 de 16 rondas"],
	"length_1": ["Long: first to 16 of 30 rounds", "Longa: primeiro a 16 de 30 rondas"],
	"start_match": ["Start Match", "Começar Partida"],

	# Pause and match end.
	"paused": ["Paused", "Pausa"],
	"resume": ["Resume", "Continuar"],
	"quit_to_menu": ["Leave Match", "Abandonar Partida"],
	"victory": ["Victory", "Vitória"],
	"defeat": ["Defeat", "Derrota"],
	"draw": ["Draw", "Empate"],
	"your_stats": ["Your kills %d · deaths %d", "Os teus abates %d · mortes %d"],
	"play_again": ["Play Again", "Jogar Outra Vez"],
	"main_menu": ["Main Menu", "Menu Principal"],
	"click_to_play": ["Click to play", "Clica para jogar"],

	# Rounds.
	"you": ["You", "Tu"],
	"round_n": ["Round %d", "Ronda %d"],
	"round_short": ["Round %d / %d", "Ronda %d / %d"],
	"last_round": ["Last round", "Última ronda"],
	"last_round_half": ["Last round of the half", "Última ronda da primeira parte"],
	"match_point": ["Round %d · Match point", "Ronda %d · Ponto de partida"],
	"buy_hint": ["Buy your gear", "Compra o teu equipamento"],
	"go": ["Go, go, go!", "Vamos, vamos!"],
	"att_win": ["Attackers win", "Os atacantes ganham"],
	"def_win": ["Defenders win", "Os defensores ganham"],
	"reason_elimination": ["Every enemy is down", "Todos os inimigos foram abatidos"],
	"reason_bomb": ["The target was destroyed", "O alvo foi destruído"],
	"reason_defuse": ["The bomb was defused", "A bomba foi desativada"],
	"reason_time": ["Time ran out", "O tempo acabou"],
	"bomb_planted": ["Bomb planted", "Bomba plantada"],
	"site_n": ["Site %s", "Local %s"],
	"halftime": ["Half time: the teams switch sides.", "Intervalo: as equipas trocam de lado."],
	"got_bomb": ["You picked up the bomb.", "Apanhaste a bomba."],
	"plant_on_site": ["The bomb can only be planted on a bomb site (A or B).", "A bomba só pode ser plantada num local de bomba (A ou B)."],

	# HUD.
	"hud_bomb": ["BOMB", "BOMBA"],
	"hud_buy": ["%s  buy menu", "%s  menu de compras"],
	"planting": ["Planting the bomb", "A plantar a bomba"],
	"defusing": ["Defusing", "A desativar"],
	"no_time": ["Not enough time!", "Não há tempo suficiente!"],
	"hint_defuse": ["Hold %s to defuse the bomb", "Mantém %s para desativar a bomba"],
	"hint_take_bomb": ["You are on a bomb site: press %s for the bomb", "Estás num local de bomba: carrega %s para a bomba"],
	"hint_plant": ["Hold fire to plant the bomb", "Mantém o disparo para plantar a bomba"],
	"hint_pickup": ["%s  pick up %s", "%s  apanhar %s"],
	"hint_next": ["click for the next player", "clica para o jogador seguinte"],
	"you_died": ["You died", "Morreste"],
	"killed_by": ["Killed by %s (%d HP left)", "Abatido por %s (ficou com %d de vida)"],
	"spectating": ["Watching %s", "A ver %s"],
	"col_kills": ["K", "A"],
	"col_deaths": ["D", "M"],
	"col_money": ["Money", "Dinheiro"],

	# Buy menu.
	"buy_title": ["Buy", "Comprar"],
	"buy_pistols": ["Pistols", "Pistolas"],
	"buy_heavy": ["SMGs and shotgun", "Submetralhadoras e caçadeira"],
	"buy_rifles": ["Rifles", "Espingardas"],
	"buy_gear": ["Gear and grenades", "Equipamento e granadas"],
	"buy_close_hint": ["B or Esc closes · buying is open during freeze time and the first 20 seconds, in your spawn",
			"B ou Esc fecha · as compras estão abertas no início da ronda e nos primeiros 20 segundos, na tua base"],
	"owned": ["owned", "já tens"],

	# How to play.
	"help_goal": ["Goal", "Objetivo"],
	"help_goal_text": ["Two teams play a series of rounds, and you have one life per round. Attackers win a round by planting the bomb on site A or B and keeping it safe until it explodes, or by taking out every defender. Defenders win by defusing a planted bomb, by taking out every attacker before the bomb is down, or when the round clock runs out. At half time the teams switch sides.",
			"Duas equipas jogam uma série de rondas e tens uma vida por ronda. Os atacantes ganham a ronda plantando a bomba no local A ou B e protegendo-a até explodir, ou abatendo todos os defensores. Os defensores ganham desativando a bomba plantada, abatendo todos os atacantes antes de a bomba ser plantada, ou quando o relógio da ronda chega ao fim. No intervalo as equipas trocam de lado."],
	"help_money": ["Money", "Dinheiro"],
	"help_money_text": ["Buy weapons, armor and grenades at the start of each round, in your spawn. Kills pay (SMGs and the shotgun pay more, the sniper rifle less), winning pays best, and losing rounds in a row pays more each time. Survivors keep their weapons for the next round; if you die you start with a pistol again.",
			"Compra armas, colete e granadas no início de cada ronda, na tua base. Os abates dão dinheiro (as submetralhadoras e a caçadeira dão mais, a espingarda de precisão menos), ganhar dá mais ainda, e perder rondas seguidas dá cada vez mais. Quem sobrevive mantém as armas para a ronda seguinte; se morreres começas outra vez só com a pistola."],
	"help_shooting": ["Shooting", "Disparar"],
	"help_shooting_text": ["Stand still, walk or crouch to shoot straight: running and jumping throw your shots off. Guns climb as you spray, so fire short bursts or pull down against the recoil. A headshot does four times the damage, and a helmet only softens it. Walking is silent; running footsteps give you away.",
			"Fica parado, anda devagar ou agacha-te para disparar certeiro: correr e saltar desviam os tiros. As armas sobem enquanto disparas em rajada, por isso dispara rajadas curtas ou puxa para baixo contra o recuo. Um tiro na cabeça faz quatro vezes o dano, e o capacete só o atenua. Andar devagar é silencioso; os passos a correr denunciam-te."],
	"controls": ["Controls", "Controlos"],
	"help_keyboard": ["Keyboard and mouse: WASD to move, mouse to aim, left click to fire, right click to zoom, R to reload, Space to jump, Ctrl to crouch, Shift to walk quietly, 1–5 or the mouse wheel to change weapon (5 is the bomb), Q for the last weapon, G to drop your weapon, E to pick up or to defuse (hold), B for the buy menu, Tab for the scores, Esc to pause.",
			"Teclado e rato: WASD para andar, rato para apontar, clique esquerdo para disparar, clique direito para o zoom, R para recarregar, Espaço para saltar, Ctrl para agachar, Shift para andar em silêncio, 1–5 ou a roda do rato para trocar de arma (5 é a bomba), Q para a arma anterior, G para largar a arma, E para apanhar ou desativar (manter), B para o menu de compras, Tab para a pontuação, Esc para pausa."],
	"help_pad": ["Controller: left stick to move, right stick to aim, RT to fire, LT to zoom, X to reload, A to jump, B to crouch, click the left stick to walk, LB / RB or Y to change weapon, D-pad up to pick up or defuse, D-pad down for the scores, View for the buy menu, Start to pause.",
			"Comando: manípulo esquerdo para andar, manípulo direito para apontar, RT para disparar, LT para o zoom, X para recarregar, A para saltar, B para agachar, clicar no manípulo esquerdo para andar devagar, LB / RB ou Y para trocar de arma, D-pad para cima para apanhar ou desativar, D-pad para baixo para a pontuação, View para o menu de compras, Start para pausa."],

	# Settings.
	"language": ["Language", "Idioma"],
	"sound": ["Sound effects", "Efeitos sonoros"],
	"mouse_sensitivity": ["Mouse sensitivity", "Sensibilidade do rato"],
	"stick_sensitivity": ["Stick sensitivity", "Sensibilidade do manípulo"],
	"invert_y": ["Invert aim", "Inverter mira"],
	"fullscreen": ["Fullscreen", "Ecrã inteiro"],
	"on": ["On", "Ligado"],
	"off": ["Off", "Desligado"],
	"about_text": ["Dead Sector is a round-based tactical shooter: attackers plant the bomb, defenders stop them.",
			"Dead Sector é um jogo de tiros tático por rondas: os atacantes plantam a bomba, os defensores impedem-nos."],
	"developed_by": ["Developed by Web Platinum.", "Desenvolvido por Web Platinum."],
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
