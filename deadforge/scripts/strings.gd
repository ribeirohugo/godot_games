extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES.

const LANGUAGES := [["en", "English"], ["pt", "Português"]]

const TEXT := {
	# Menu.
	"tagline": ["The furnaces never went out. Neither did the things inside them.",
			"As fornalhas nunca se apagaram. Nem as criaturas lá dentro."],
	"new_game": ["New Game", "Novo Jogo"],
	"continue": ["Continue: %s", "Continuar: %s"],
	"level_select": ["Level Select", "Escolher Nível"],
	"how_to_play": ["How to Play", "Como Jogar"],
	"settings": ["Settings", "Definições"],
	"quit": ["Quit", "Sair"],
	"back": ["Back", "Voltar"],
	"choose_difficulty": ["Choose a difficulty", "Escolhe a dificuldade"],
	"diff_easy": ["Apprentice", "Aprendiz"],
	"diff_normal": ["Smith", "Ferreiro"],
	"diff_hard": ["Forgemaster", "Mestre da Forja"],
	"diff_easy_detail": ["Demons hit softly and fall quickly.", "Os demónios batem com pouca força e caem depressa."],
	"diff_normal_detail": ["The foundry as it was meant to be.", "A fundição tal como foi pensada."],
	"diff_hard_detail": ["Tougher demons that hit much harder.", "Demónios mais resistentes que batem com muito mais força."],
	"choose_level": ["Choose a level", "Escolhe um nível"],
	"level_n": ["Level %d: %s", "Nível %d: %s"],
	"best_time": ["Best time %s", "Melhor tempo %s"],
	"locked_level": ["Locked", "Bloqueado"],
	"hint_keys": ["Arrows move · Enter selects · Esc goes back", "Setas movem · Enter escolhe · Esc volta atrás"],
	"hint_pad": ["D-pad moves · A selects · B goes back", "D-pad move · A escolhe · B volta atrás"],

	# Levels.
	"level_slag_pits": ["The Slag Pits", "Os Poços de Escória"],
	"level_anvil_halls": ["Anvil Halls", "Salões da Bigorna"],
	"level_core": ["The Deadforge Core", "O Coração de Deadforge"],

	# Pause, death, level end.
	"paused": ["Paused", "Pausa"],
	"resume": ["Resume", "Continuar"],
	"restart_level": ["Restart Level", "Recomeçar Nível"],
	"quit_to_menu": ["Quit to Menu", "Sair para o Menu"],
	"you_died": ["You Died", "Morreste"],
	"died_text": ["The forge claims another soul.", "A forja reclama mais uma alma."],
	"try_again": ["Try Again", "Tentar Novamente"],
	"level_complete": ["Level Complete", "Nível Concluído"],
	"kills": ["Kills", "Abates"],
	"items": ["Items", "Objetos"],
	"time": ["Time", "Tempo"],
	"next_level": ["Next Level", "Nível Seguinte"],
	"victory": ["The Forge Is Cold", "A Forja Arrefeceu"],
	"victory_text": ["The Forgelord is dead and the furnaces of Deadforge fall silent. For now.",
			"O Senhor da Forja está morto e as fornalhas de Deadforge silenciam-se. Por agora."],
	"click_to_play": ["Click to play", "Clica para jogar"],

	# HUD.
	"hud_health": ["HEALTH", "VIDA"],
	"hud_armor": ["ARMOR", "ARMADURA"],
	"hud_ammo": ["AMMO", "MUNIÇÃO"],
	"hud_arms": ["ARMS", "ARMAS"],
	"hud_keys": ["KEYS", "CHAVES"],
	"hud_kills": ["KILLS", "ABATES"],

	# Weapons and pickups.
	"weapon_hammer": ["Forge Hammer", "Martelo de Forja"],
	"weapon_rivet": ["Rivet Gun", "Pistola de Rebites"],
	"weapon_scatter": ["Scattergun", "Caçadeira"],
	"weapon_slag": ["Slag Cannon", "Canhão de Escória"],
	"got_weapon": ["You got the %s!", "Apanhaste a %s!"],
	"got_medkit": ["Picked up a medkit.", "Apanhaste um kit médico."],
	"got_armor": ["Picked up forge plate armor.", "Apanhaste uma armadura de forja."],
	"got_rivets": ["Picked up a box of rivets.", "Apanhaste uma caixa de rebites."],
	"got_shells": ["Picked up some shells.", "Apanhaste alguns cartuchos."],
	"got_slag": ["Picked up a slag canister.", "Apanhaste um cilindro de escória."],
	"got_red_key": ["Picked up the red key.", "Apanhaste a chave vermelha."],
	"got_blue_key": ["Picked up the blue key.", "Apanhaste a chave azul."],
	"need_red_key": ["You need the red key to open this door.", "Precisas da chave vermelha para abrir esta porta."],
	"need_blue_key": ["You need the blue key to open this door.", "Precisas da chave azul para abrir esta porta."],
	"exit_sealed": ["The exit is sealed while the Forgelord lives.", "A saída está selada enquanto o Senhor da Forja viver."],
	"boss_dead": ["The Forgelord falls! The exit is open.", "O Senhor da Forja caiu! A saída está aberta."],
	"all_killed": ["Every demon on this level is dead.", "Todos os demónios deste nível estão mortos."],

	# How to play.
	"help_goal": ["Goal", "Objetivo"],
	"help_goal_text": ["Fight through each level of the foundry and step onto the green exit pad. Colored doors need the key of the same color. On the last level the exit only opens once the Forgelord is dead. Your health, armor, weapons and ammo carry over to the next level.",
			"Abre caminho por cada nível da fundição e pisa a plataforma verde de saída. As portas coloridas precisam da chave da mesma cor. No último nível, a saída só abre quando o Senhor da Forja estiver morto. A vida, a armadura, as armas e as munições passam para o nível seguinte."],
	"help_weapons": ["Weapons", "Armas"],
	"help_weapons_text": ["1 Forge Hammer: melee, never runs out. 2 Rivet Gun: fast and accurate. 3 Scattergun: a wide blast of shells, deadly up close. 4 Slag Cannon: molten slag that bursts on impact, keep your distance.",
			"1 Martelo de Forja: corpo a corpo, nunca se esgota. 2 Pistola de Rebites: rápida e certeira. 3 Caçadeira: uma rajada larga de cartuchos, mortal de perto. 4 Canhão de Escória: escória derretida que rebenta ao impacto, mantém a distância."],
	"help_enemies": ["Enemies", "Inimigos"],
	"help_enemies_text": ["Husks shamble up and claw. Cinders float and hurl fireballs, so sidestep them. Brutes are slow to die and charge hard. Lava hurts while you stand in it.",
			"Os Cascos arrastam-se e arranham. As Brasas flutuam e lançam bolas de fogo, por isso desvia-te para o lado. Os Brutos custam a morrer e carregam com força. A lava magoa enquanto estiveres em cima dela."],
	"controls": ["Controls", "Controlos"],
	"help_keyboard": ["Keyboard and mouse: WASD or arrows to move, mouse to look, left click or Ctrl to fire, 1–4 or the mouse wheel to change weapon, Esc to pause. Doors open when you walk up to them.",
			"Teclado e rato: WASD ou setas para andar, rato para olhar, clique esquerdo ou Ctrl para disparar, 1–4 ou a roda do rato para trocar de arma, Esc para pausa. As portas abrem quando te aproximas."],
	"help_pad": ["Controller: left stick to move, right stick to look, RT or A to fire, LB / RB or Y to change weapon, Start to pause.",
			"Comando: manípulo esquerdo para andar, manípulo direito para olhar, RT ou A para disparar, LB / RB ou Y para trocar de arma, Start para pausa."],

	# Settings.
	"language": ["Language", "Idioma"],
	"sound": ["Sound effects", "Efeitos sonoros"],
	"music": ["Music", "Música"],
	"mouse_sensitivity": ["Mouse sensitivity", "Sensibilidade do rato"],
	"stick_sensitivity": ["Stick sensitivity", "Sensibilidade do manípulo"],
	"invert_y": ["Invert look", "Inverter olhar"],
	"fullscreen": ["Fullscreen", "Ecrã inteiro"],
	"on": ["On", "Ligado"],
	"off": ["Off", "Desligado"],
	"about_text": ["Deadforge is a fast retro first-person shooter set in a demon-infested foundry.",
			"Deadforge é um jogo de tiros retro na primeira pessoa, passado numa fundição infestada de demónios."],
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
