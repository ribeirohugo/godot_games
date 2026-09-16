extends RefCounted
## Every text in the game, in each language. The game shows them with tr("key").
## Values follow the order of LANGUAGES. "Snake" and individual level names are not translated -
## there are 20 of them, in English only for now.

const LANGUAGES := [["en", "English"], ["pt_PT", "Português (PT)"], ["es", "Español"], ["pt_BR", "Português (BR)"], ["fr", "Français"], ["it", "Italiano"], ["de", "Deutsch"], ["sv", "Svenska"], ["ar", "العربية"], ["zh_CN", "中文"]]

const TEXT := {
	# Modes.
	"campaign": ["Campaign", "Campanha", "Campaña", "Campanha", "Campagne",
			"Campagna", "Kampagne", "Kampanj", "الحملة", "战役"],
	"classic": ["Classic", "Clássico", "Clásico", "Clássico", "Classique",
			"Classica", "Klassisch", "Klassiskt", "كلاسيكي", "经典模式"],
	"settings": ["Settings", "Definições", "Ajustes", "Configurações", "Paramètres",
			"Impostazioni", "Einstellungen", "Inställningar", "الإعدادات", "设置"],

	# Menu / pause / game-over / cleared options.
	"resume": ["Resume", "Continuar", "Continuar", "Continuar", "Reprendre",
			"Riprendi", "Fortsetzen", "Fortsätt", "استئناف", "继续"],
	"restart": ["Restart", "Reiniciar", "Reiniciar", "Reiniciar", "Recommencer",
			"Ricomincia", "Neu starten", "Starta om", "إعادة البدء", "重新开始"],
	"level_select": ["Level select", "Selecionar nível", "Elegir nivel", "Selecionar nível", "Choisir un niveau",
			"Scegli livello", "Level auswählen", "Välj bana", "اختيار المستوى", "选择关卡"],
	"exit_menu": ["Exit to menu", "Sair para o menu", "Salir al menú", "Sair para o menu", "Retour au menu",
			"Torna al menu", "Zum Menü", "Till menyn", "العودة إلى القائمة", "返回菜单"],
	"retry_level": ["Retry level", "Tentar de novo", "Reintentar nivel", "Tentar de novo", "Réessayer le niveau",
			"Riprova livello", "Nochmal versuchen", "Försök igen", "إعادة المحاولة", "重试关卡"],
	"play_again": ["Play again", "Jogar novamente", "Jugar de nuevo", "Jogar novamente", "Rejouer",
			"Rigioca", "Nochmal spielen", "Spela igen", "العب مرة أخرى", "再玩一次"],
	"next_level": ["Next level", "Nível seguinte", "Siguiente nivel", "Próximo nível", "Niveau suivant",
			"Livello successivo", "Nächstes Level", "Nästa bana", "المستوى التالي", "下一关"],
	"replay_level": ["Replay level", "Repetir nível", "Repetir nivel", "Repetir nível", "Refaire le niveau",
			"Rigioca livello", "Level wiederholen", "Spela om nivån", "إعادة تشغيل المستوى", "重玩关卡"],

	# Control hints: gamepad and mouse/keyboard variants.
	"help_pad_choose": ["D-pad or stick to choose, A to select", "Cruzeta ou stick para escolher, A para selecionar", "Cruceta o stick para elegir, A para seleccionar", "Direcional ou analógico para escolher, A para selecionar", "Croix ou stick pour choisir, A pour valider",
			"Croce direzionale o stick per scegliere, A per selezionare", "Steuerkreuz oder Stick zum Wählen, A zum Bestätigen", "Styrkors eller spak för att välja, A för att bekräfta", "استخدم الاتجاهات أو العصا للاختيار، ثم A للتأكيد", "方向键或摇杆选择，A 键确认"],
	"help_kb_choose": ["W / S or arrows to choose, Enter or click to select", "W / S ou setas para escolher, Enter ou clique para selecionar", "W / S o flechas para elegir, Intro o clic para seleccionar", "W / S ou setas para escolher, Enter ou clique para selecionar", "W / S ou flèches pour choisir, Entrée ou clic pour valider",
			"W / S o frecce per scegliere, Invio o clic per selezionare", "W / S oder Pfeiltasten zum Wählen, Enter oder Klick zum Bestätigen", "W / S eller piltangenter för att välja, Enter eller klick för att bekräfta", "W / S أو الأسهم للاختيار، Enter أو النقر للتأكيد", "W / S 或方向键选择，回车或点击确认"],
	"help_pad_levels": ["D-pad to choose, A to play, B to go back", "Cruzeta para escolher, A para jogar, B para voltar", "Cruceta para elegir, A para jugar, B para volver", "Direcional para escolher, A para jogar, B para voltar", "Croix pour choisir, A pour jouer, B pour revenir",
			"Croce direzionale per scegliere, A per giocare, B per tornare indietro", "Steuerkreuz zum Wählen, A zum Spielen, B zum Zurückgehen", "Styrkors för att välja, A för att spela, B för att gå tillbaka", "استخدم الاتجاهات للاختيار، A للعب، B للرجوع", "方向键选择，A 键开始，B 键返回"],
	"help_kb_levels": ["Arrows or WASD to choose, Enter or click to play, Esc to go back", "Setas ou WASD para escolher, Enter ou clique para jogar, Esc para voltar", "Flechas o WASD para elegir, Intro o clic para jugar, Esc para volver", "Setas ou WASD para escolher, Enter ou clique para jogar, Esc para voltar", "Flèches ou WASD pour choisir, Entrée ou clic pour jouer, Échap pour revenir",
			"Frecce o WASD per scegliere, Invio o clic per giocare, Esc per tornare indietro", "Pfeiltasten oder WASD zum Wählen, Enter oder Klick zum Spielen, Esc zum Zurückgehen", "Piltangenter eller WASD för att välja, Enter eller klick för att spela, Esc för att gå tillbaka", "الأسهم أو WASD للاختيار، Enter أو النقر للعب، Esc للرجوع", "方向键或 WASD 选择，回车或点击开始，Esc 返回"],
	"help_pad_steer": ["D-pad / stick: steer      Start: pause", "Cruzeta / stick: mover      Start: pausa", "Cruceta / stick: mover      Start: pausa", "Direcional / analógico: mover      Start: pausa", "Croix / stick : diriger      Start : pause",
			"Croce / stick: muovi      Start: pausa", "Steuerkreuz / Stick: lenken      Start: Pause", "Styrkors / spak: styr      Start: paus", "الاتجاهات / العصا: تحكم      Start: إيقاف مؤقت", "方向键 / 摇杆：移动      Start：暂停"],
	"help_kb_steer": ["Arrows / WASD: steer      P / Esc: pause", "Setas / WASD: mover      P / Esc: pausa", "Flechas / WASD: mover      P / Esc: pausa", "Setas / WASD: mover      P / Esc: pausa", "Flèches / WASD : diriger      P / Échap : pause",
			"Frecce / WASD: muovi      P / Esc: pausa", "Pfeiltasten / WASD: lenken      P / Esc: Pause", "Piltangenter / WASD: styr      P / Esc: paus", "الأسهم / WASD: تحكم      P / Esc: إيقاف مؤقت", "方向键 / WASD：移动      P / Esc：暂停"],

	# HUD.
	"hud_score": ["SCORE", "PONTOS", "PUNTOS", "PONTOS", "SCORE", "PUNTI", "PUNKTE", "POÄNG", "النتيجة", "分数"],
	"hud_tagline": ["Eat apples, grow long, and don't bite yourself!", "Come maçãs, cresce e não te mordas a ti próprio!", "¡Come manzanas, crece y no te muerdas a ti mismo!", "Coma maçãs, cresça e não morda você mesmo!", "Mange des pommes, deviens long et ne te mords pas toi-même !",
			"Mangia le mele, cresci e non morderti da solo!", "Iss Äpfel, werde lang und beiß dich nicht selbst!", "Ät äpplen, väx dig lång och bit inte dig själv!", "كل التفاح، اطُل، ولا تعضّ نفسك!", "吃苹果，越长越长，千万别咬到自己！"],
	"hud_campaign_progress": ["Campaign: %d of %d levels cleared", "Campanha: %d de %d níveis concluídos", "Campaña: %d de %d niveles superados", "Campanha: %d de %d níveis concluídos", "Campagne : %d niveaux sur %d terminés",
			"Campagna: %d livelli su %d completati", "Kampagne: %d von %d Levels geschafft", "Kampanj: %d av %d banor klarade", "الحملة: %d من %d مستوى مكتمل", "战役：已通关 %d / %d 关"],
	"hud_golden_worth": ["Golden apples: +%d", "Maçãs douradas: +%d", "Manzanas doradas: +%d", "Maçãs douradas: +%d", "Pommes dorées : +%d",
			"Mele dorate: +%d", "Goldene Äpfel: +%d", "Gyllene äpplen: +%d", "التفاح الذهبي: +%d", "金苹果：+%d"],
	"hud_score_apples": ["Score %d      Apples %d", "Pontos %d      Maçãs %d", "Puntos %d      Manzanas %d", "Pontos %d      Maçãs %d", "Score %d      Pommes %d",
			"Punti %d      Mele %d", "Punkte %d      Äpfel %d", "Poäng %d      Äpplen %d", "النتيجة %d      التفاح %d", "分数 %d      苹果 %d"],

	# Campaign and level select.
	"campaign_title": ["CAMPAIGN", "CAMPANHA", "CAMPAÑA", "CAMPANHA", "CAMPAGNE",
			"CAMPAGNA", "KAMPAGNE", "KAMPANJ", "الحملة", "战役"],
	"campaign_progress": ["%d of %d levels cleared  ·  clear one to open the next", "%d de %d níveis concluídos  ·  conclui um para abrir o seguinte", "%d de %d niveles superados  ·  supera uno para abrir el siguiente", "%d de %d níveis concluídos  ·  conclua um para abrir o próximo", "%d niveaux sur %d terminés  ·  termine-en un pour débloquer le suivant",
			"%d livelli su %d completati  ·  completane uno per sbloccare il successivo", "%d von %d Levels geschafft  ·  eins schaffen, um das nächste freizuschalten", "%d av %d banor klarade  ·  klara en för att låsa upp nästa", "%d من %d مستوى مكتمل  ·  أكمل واحدًا لفتح التالي", "已通关 %d / %d 关  ·  通关一关即可解锁下一关"],
	"campaign_locked_hint": ["Locked. Clear %s to carry on.", "Bloqueado. Conclui %s para continuar.", "Bloqueado. Supera %s para continuar.", "Bloqueado. Conclua %s para continuar.", "Verrouillé. Termine %s pour continuer.",
			"Bloccato. Completa %s per continuare.", "Gesperrt. Schließe %s ab, um weiterzumachen.", "Låst. Klara %s för att fortsätta.", "مقفل. أكمل %s للمتابعة.", "已锁定。通关 %s 即可继续。"],
	"world_label": ["WORLD %d", "MUNDO %d", "MUNDO %d", "MUNDO %d", "MONDE %d",
			"MONDO %d", "WELT %d", "VÄRLD %d", "العالم %d", "第 %d 世界"],
	"world_unknown": ["? ? ?", "? ? ?", "? ? ?", "? ? ?", "? ? ?", "? ? ?", "? ? ?", "? ? ?", "? ? ?", "? ? ?"],
	"level_locked": ["Locked", "Bloqueado", "Bloqueado", "Bloqueado", "Verrouillé",
			"Bloccato", "Gesperrt", "Låst", "مقفل", "已锁定"],
	"best_value": ["Best %d", "Melhor %d", "Mejor %d", "Melhor %d", "Record %d",
			"Record %d", "Bestwert %d", "Bäst %d", "الأفضل %d", "最佳 %d"],

	# Pause / game over / level cleared.
	"paused_title": ["PAUSED", "PAUSA", "PAUSA", "PAUSADO", "PAUSE", "PAUSA", "PAUSE", "PAUS", "إيقاف مؤقت", "已暂停"],
	"game_over_title": ["GAME OVER", "FIM DE JOGO", "FIN DE LA PARTIDA", "FIM DE JOGO", "PARTIE TERMINÉE",
			"PARTITA FINITA", "SPIEL VORBEI", "SPELET SLUT", "انتهت اللعبة", "游戏结束"],
	"new_best": ["New best!", "Novo recorde!", "¡Nuevo récord!", "Novo recorde!", "Nouveau record !",
			"Nuovo record!", "Neuer Bestwert!", "Nytt rekord!", "رقم قياسي جديد!", "创造新纪录！"],
	"campaign_complete": ["CAMPAIGN COMPLETE", "CAMPANHA CONCLUÍDA", "CAMPAÑA COMPLETADA", "CAMPANHA CONCLUÍDA", "CAMPAGNE TERMINÉE",
			"CAMPAGNA COMPLETATA", "KAMPAGNE ABGESCHLOSSEN", "KAMPANJ KLAR", "اكتملت الحملة", "战役通关"],
	"level_clear": ["LEVEL CLEAR", "NÍVEL CONCLUÍDO", "NIVEL SUPERADO", "NÍVEL CONCLUÍDO", "NIVEAU TERMINÉ",
			"LIVELLO COMPLETATO", "LEVEL GESCHAFFT", "BANA KLARAD", "اكتمل المستوى", "关卡通关"],
	"best_on_level": ["Best on this level!", "Melhor pontuação neste nível!", "¡Mejor puntuación en este nivel!", "Melhor pontuação neste nível!", "Meilleur score sur ce niveau !",
			"Miglior punteggio su questo livello!", "Bestwert auf diesem Level!", "Bästa resultatet på den här banan!", "أفضل نتيجة في هذا المستوى!", "本关最佳成绩！"],

	# Level goals.
	"goal_apples": ["Apples", "Maçãs", "Manzanas", "Maçãs", "Pommes", "Mele", "Äpfel", "Äpplen", "التفاح", "苹果"],
	"goal_golden": ["Golden", "Douradas", "Doradas", "Douradas", "Dorées",
			"Dorate", "Golden", "Gyllene", "الذهبي", "金苹果"],
	"goal_length": ["Length", "Tamanho", "Longitud", "Tamanho", "Longueur",
			"Lunghezza", "Länge", "Längd", "الطول", "长度"],
	"goal_seconds": ["Seconds", "Segundos", "Segundos", "Segundos", "Secondes",
			"Secondi", "Sekunden", "Sekunder", "الثواني", "秒数"],
	"goal_default": ["Goal", "Objetivo", "Objetivo", "Objetivo", "Objectif", "Obiettivo", "Ziel", "Mål", "الهدف", "目标"],
	"goal_short_apples": ["Eat %d apples", "Come %d maçãs", "Come %d manzanas", "Coma %d maçãs", "Mange %d pommes",
			"Mangia %d mele", "Iss %d Äpfel", "Ät %d äpplen", "كل %d تفاحة", "吃 %d 个苹果"],
	"goal_short_golden": ["Eat %d golden", "Come %d douradas", "Come %d doradas", "Coma %d douradas", "Mange %d dorées",
			"Mangia %d dorate", "Iss %d goldene", "Ät %d gyllene", "كل %d تفاحة ذهبية", "吃 %d 个金苹果"],
	"goal_short_length": ["Grow to %d", "Cresce até %d", "Crece hasta %d", "Cresça até %d", "Atteins %d de long",
			"Cresci fino a %d", "Wachse auf %d", "Väx till %d", "انمُ حتى %d", "长到 %d 节"],
	"goal_short_survive": ["Survive %ds", "Sobrevive %ds", "Sobrevive %ds", "Sobreviva %ds", "Survis %ds",
			"Sopravvivi %ds", "Überlebe %ds", "Överlev %ds", "اصمد %d ث", "坚持 %d 秒"],
	"goal_progress_line": ["%s: %d of %d", "%s: %d de %d", "%s: %d de %d", "%s: %d de %d", "%s : %d sur %d",
			"%s: %d su %d", "%s: %d von %d", "%s: %d av %d", "%s: %d من %d", "%s：%d / %d"],

	# Death causes.
	"death_poison": ["Rotten to the core.", "Podre até ao caroço.", "Podrido hasta el fondo.", "Podre até o caroço.", "Pourri jusqu'au trognon.",
			"Marcio fino al torsolo.", "Verfault bis zum Kern.", "Ruttet in i märgen.", "تعفّنت حتى النخاع.", "烂到骨子里了。"],
	"death_blade": ["Cut down by a blade.", "Cortado por uma lâmina.", "Cortado por una cuchilla.", "Cortado por uma lâmina.", "Fauché par une lame.",
			"Falciato da una lama.", "Von einer Klinge erwischt.", "Nedhuggen av ett blad.", "قطعتك شفرة.", "被刀刃斩断了。"],
	"death_time": ["Out of time.", "Tempo esgotado.", "Se acabó el tiempo.", "Tempo esgotado.", "Temps écoulé.",
			"Tempo scaduto.", "Zeit abgelaufen.", "Tiden är ute.", "انتهى الوقت.", "时间到了。"],
	"death_default": ["You hit something.", "Bateste em qualquer coisa.", "Has chocado contra algo.", "Você bateu em alguma coisa.", "Tu as heurté quelque chose.",
			"Hai colpito qualcosa.", "Du bist gegen etwas geprallt.", "Du körde in i något.", "اصطدمت بشيء ما.", "你撞到东西了。"],

	# Settings.
	"settings_title": ["SETTINGS", "DEFINIÇÕES", "AJUSTES", "CONFIGURAÇÕES", "PARAMÈTRES",
			"IMPOSTAZIONI", "EINSTELLUNGEN", "INSTÄLLNINGAR", "الإعدادات", "设置"],
	"settings_language": ["Language", "Idioma", "Idioma", "Idioma", "Langue",
			"Lingua", "Sprache", "Språk", "اللغة", "语言"],
	"settings_back": ["Back", "Voltar", "Volver", "Voltar", "Retour", "Indietro", "Zurück", "Tillbaka", "رجوع", "返回"],
	"settings_hint_pad": ["D-pad to choose, A to select, B to go back", "Cruzeta para escolher, A para selecionar, B para voltar", "Cruceta para elegir, A para seleccionar, B para volver", "Direcional para escolher, A para selecionar, B para voltar", "Croix pour choisir, A pour valider, B pour revenir",
			"Croce direzionale per scegliere, A per selezionare, B per tornare indietro", "Steuerkreuz zum Wählen, A zum Bestätigen, B zum Zurückgehen", "Styrkors för att välja, A för att bekräfta, B för att gå tillbaka", "استخدم الاتجاهات للاختيار، A للتأكيد، B للرجوع", "方向键选择，A 键确认，B 键返回"],
	"settings_hint_kb": ["Arrows to choose, Enter or click to select, Esc to go back", "Setas para escolher, Enter ou clique para selecionar, Esc para voltar", "Flechas para elegir, Intro o clic para seleccionar, Esc para volver", "Setas para escolher, Enter ou clique para selecionar, Esc para voltar", "Flèches pour choisir, Entrée ou clic pour valider, Échap pour revenir",
			"Frecce per scegliere, Invio o clic per selezionare, Esc per tornare indietro", "Pfeiltasten zum Wählen, Enter oder Klick zum Bestätigen, Esc zum Zurückgehen", "Piltangenter för att välja, Enter eller klick för att bekräfta, Esc för att gå tillbaka", "الأسهم للاختيار، Enter أو النقر للتأكيد، Esc للرجوع", "方向键选择，回车或点击确认，Esc 返回"],

	# World names.
	"world_1": ["Meadow", "Prado", "Pradera", "Campina", "Prairie", "Prato", "Wiese", "Äng", "المرج", "草甸"],
	"world_2": ["Dustfields", "Terras Secas", "Tierras Polvorientas", "Terras Secas", "Terres Arides",
			"Terre Polverose", "Staubfelder", "Dammfälten", "أراضي الغبار", "尘土荒原"],
	"world_3": ["Badlands", "Ermos", "Tierras Baldías", "Terras Áridas", "Terres Désolées",
			"Terre Desolate", "Ödland", "Ödemarken", "الأراضي الوعرة", "荒漠"],
	"world_4": ["Ashlands", "Terras de Cinza", "Tierras de Ceniza", "Terras de Cinzas", "Terres de Cendres",
			"Terre di Cenere", "Aschland", "Askmarkerna", "أراضي الرماد", "灰烬之地"],
	"world_5": ["Inferno", "Inferno", "Infierno", "Inferno", "Enfer", "Inferno", "Inferno", "Inferno", "الجحيم", "炼狱"],
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
	var full := OS.get_locale()  # e.g. "pt_BR", "en_US", "zh_Hans_CN"
	for entry in LANGUAGES:
		if full.begins_with(entry[0]):
			return entry[0]
	var lang := OS.get_locale_language()  # e.g. "pt", "zh", "en"
	for entry in LANGUAGES:
		if entry[0] == lang or entry[0].begins_with(lang + "_"):
			return entry[0]
	return "en"
