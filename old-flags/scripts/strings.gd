extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. Flag names live in flags.gd.

const LANGUAGES := [["en", "English"], ["pt", "Português"]]

const TEXT := {
	# Menu.
	"title": ["Old Flags", "Bandeiras Antigas"],
	"tagline": ["Test your knowledge of history's defunct and forgotten flags: empires, kingdoms and states that no longer exist.",
			"Testa o teu conhecimento sobre bandeiras extintas e esquecidas da história: impérios, reinos e estados que já não existem."],
	"choose_game": ["Choose a game", "Escolhe um jogo"],
	"type_old": ["Old", "Antigas"],
	"type_classic": ["Classic", "Clássico"],
	"type_old_detail": ["Historical and defunct state flags, the original quiz.", "Bandeiras de estados históricos e extintos, o questionário original."],
	"type_classic_detail": ["Current national flags of all 195 of the world's countries.", "Bandeiras nacionais atuais dos 195 países do mundo."],
	"choose_mode": ["Choose a mode", "Escolhe um modo"],
	"mode_name": ["Guess the Name", "Adivinha o Nome"],
	"mode_flag": ["Guess the Flag", "Adivinha a Bandeira"],
	"mode_name_detail": ["See the flag, pick the matching state.", "Vês a bandeira, escolhes o estado correspondente."],
	"mode_flag_detail": ["See the name, pick the matching flag.", "Vês o nome, escolhes a bandeira correspondente."],
	"choose_difficulty": ["Choose a difficulty", "Escolhe a dificuldade"],
	"diff_all": ["All", "Todas"],
	"diff_easy": ["Easy", "Fácil"],
	"diff_medium": ["Medium", "Médio"],
	"diff_hard": ["Hard", "Difícil"],
	"pool_size": ["%d flags in the pool", "%d bandeiras disponíveis"],
	"rules_old": ["%d rounds · %d choices each round, drawn from a pool of historical flags.",
			"%d perguntas · %d opções por pergunta, de um conjunto de bandeiras históricas."],
	"rules_classic": ["%d rounds · %d choices each round, drawn from the current flags of every country in the world.",
			"%d perguntas · %d opções por pergunta, com as bandeiras atuais de todos os países do mundo."],
	"how_to_play": ["How to Play", "Como Jogar"],
	"stats": ["Stats", "Estatísticas"],
	"settings": ["Settings", "Definições"],
	"home": ["Home", "Início"],
	"back": ["Back", "Voltar"],
	"play": ["Play", "Jogar"],
	"menu": ["Menu", "Menu"],
	"hint_keys": ["Arrows move · Enter selects · Esc goes back", "Setas movem · Enter escolhe · Esc volta atrás"],
	"hint_pad": ["D-pad moves · A selects · B goes back", "D-pad move · A escolhe · B volta atrás"],

	# Game.
	"status": ["Question %d of %d · Score: %d", "Pergunta %d de %d · Pontuação: %d"],
	"correct": ["Correct!", "Correto!"],
	"wrong_name": ["Wrong: this flag belonged to %s.", "Errado: esta bandeira pertenceu a %s."],
	"wrong_flag": ["Wrong: that's not the flag of %s.", "Errado: essa não é a bandeira de %s."],
	"next": ["Next", "Seguinte"],
	"leave_title": ["Leave this quiz?", "Sair deste questionário?"],
	"leave_text": ["Your answers so far will be lost.", "As respostas que já deste vão perder-se."],
	"keep_playing": ["Keep playing", "Continuar a jogar"],
	"leave": ["Leave", "Sair"],
	"see_result": ["See Result", "Ver Resultado"],

	# Result.
	"scored": ["You scored %d out of %d!", "Acertaste %d de %d!"],
	"passed": ["Passed", "Aprovado"],
	"failed": ["Failed", "Reprovado"],
	"pass_note": ["Get %d or more right to pass.", "Acerta %d ou mais para passar."],
	"play_again": ["Play Again", "Jogar Novamente"],
	"your_answers": ["Your answers", "As tuas respostas"],
	"you_picked": ["You picked: %s", "Escolheste: %s"],

	# How to play.
	"help_intro": ["Each round shows a flag. Pick which country or state it belonged to from %d choices. Play %d rounds per game.",
			"Em cada pergunta, aparece uma bandeira. Escolhe a que país ou estado pertenceu entre %d opções. Cada jogo tem %d perguntas."],
	"game_types": ["Game Types", "Tipos de Jogo"],
	"modes": ["Modes", "Modos"],
	"difficulty": ["Difficulty", "Dificuldade"],
	"help_difficulty": ["Old mode lets you narrow the pool of flags before you start (Classic mode always draws from all 195 current flags). Easy sticks to flags that still resemble their modern counterpart, or are simply too iconic to confuse with anything else. Hard leans on repetitive families that blur together: British colonial ensigns, Soviet and Yugoslav constituent republics, and minor 19th-century German and Italian states. Medium is everything in between, and All draws from the whole pool regardless of difficulty.",
			"No modo Antigas, podes limitar o conjunto de bandeiras antes de começares (o modo Clássico usa sempre as 195 bandeiras atuais). O Fácil fica-se pelas bandeiras que ainda se parecem com a versão atual do seu país, ou que são demasiado icónicas para se confundirem com outra qualquer. O Difícil apoia-se em famílias repetitivas que se confundem facilmente entre si: pavilhões coloniais britânicos, repúblicas constituintes soviéticas e jugoslavas, e pequenos estados alemães e italianos do séc. XIX. O Médio é tudo o que fica pelo meio, e o Todas usa o conjunto inteiro, sem filtrar por dificuldade."],
	"controls": ["Controls", "Controlos"],
	"help_touch": ["Mouse or touch: pick a game, a mode and (in Old) a difficulty, then tap a choice and Next.", "Rato ou toque: escolhe um jogo, um modo e (em Antigas) a dificuldade, depois toca numa opção e em Seguinte."],
	"help_keyboard": ["Keyboard: arrows or Tab to move, Enter or Space to choose, 1–4 to answer at once, Esc to go back.",
			"Teclado: setas ou Tab para mover, Enter ou Espaço para escolher, 1–4 para responder logo, Esc para voltar atrás."],
	"help_pad": ["Controller: D-pad or left stick to move, LB / RB to step through buttons, A to choose, B to go back, Start for Next or Play Again, right stick to scroll.",
			"Comando: D-pad ou manípulo esquerdo para mover, LB / RB para saltar entre botões, A para escolher, B para voltar atrás, Start para Seguinte ou Jogar Novamente, manípulo direito para deslizar."],

	# Stats.
	"games_played": ["Quizzes Played", "Questionários Jogados"],
	"average_score": ["Average Score", "Pontuação Média"],
	"best_score": ["Best Score", "Melhor Pontuação"],
	"pass_rate": ["Pass Rate", "Taxa de Sucesso"],
	"by_game": ["By Game", "Por Jogo"],
	"by_mode": ["By Mode", "Por Modo"],
	"by_difficulty": ["By Difficulty (Old)", "Por Dificuldade (Antigas)"],
	"bucket": ["%d played · avg %s · best %s", "%d jogados · média %s · melhor %s"],
	"recent": ["Recent History", "Histórico Recente"],
	"no_games": ["No quizzes played yet.", "Ainda não jogaste nenhum questionário."],
	"clear_stats": ["Clear Stats", "Limpar Estatísticas"],
	"confirm_clear": ["Press again to clear", "Carrega outra vez para limpar"],

	# Settings.
	"language": ["Language", "Idioma"],
	"sound": ["Sound effects", "Efeitos sonoros"],
	"vibration": ["Vibration", "Vibração"],
	"on": ["On", "Ligado"],
	"off": ["Off", "Desligado"],
	"about": ["About", "Sobre"],
	"about_text": ["Old Flags is a quiz about historical and defunct state flags: empires, kingdoms, colonies and short-lived republics that no longer exist.",
			"Bandeiras Antigas é um questionário sobre bandeiras de estados históricos e extintos: impérios, reinos, colónias e repúblicas de vida curta que já não existem."],
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
