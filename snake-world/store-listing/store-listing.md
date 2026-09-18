# Microsoft Store listing — Snake World

Written to Microsoft's Store listing rules (character limits, no HTML/code/URLs in the description, no manually-added bullets in Product features): https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/add-and-edit-store-listing-info (same field rules apply to MSIX apps).

The game is translated into 10 languages (see `scripts/strings.gd`), and `msix.env` declares all 10 in the package manifest, so Partner Center will ask for a listing in each. One is provided below for every language, headed with the Partner Center language code.

## Product name

Unlike this developer's other games, the name **is** localized in Portuguese, matching the in-game title: **Jogo da Cobra** (pt-pt) and **Jogo da Cobrinha** (pt-br). Every other language uses **Snake World**. Reserve all three names in Partner Center (Product management > Product identity) before submitting; the manifest's `DISPLAY_NAME` stays "Snake World".

## Images

Rendered in-engine from the game's own drawing code and fonts. The English (en-us) set sits at the top of `store-listing/`; every other language has its own folder named after its Partner Center code (`pt-pt/`, `pt-br/`, `es-es/`, ...), whose box and poster art carry that language's title and tagline.

| File | Size | Where it goes |
| --- | --- | --- |
| `BoxArt.2160x2160.png`, `BoxArt.1080x1080.png` | 1:1 | Store display images: 1:1 box art |
| `PosterArt.1440x2160.png`, `PosterArt.720x1080.png` | 2:3 | Store display images: 9:16 poster art |
| `HeroArt.3840x2160.png`, `HeroArt.1920x1080.png` | 16:9 | Store display images: 16:9 Super hero art |
| `AppTile.300x300.png`, `AppTile.150x150.png`, `AppTile.71x71.png` | 1:1 | Store logos (made from `icon.png`, like the package logos); shared by every language |
| `screenshot*.png` | 2000x1520 | Desktop screenshots |

The hero art is English-only (title "Snake World", tagline "Eat apples. Grow long. Survive five worlds."), built from a live capture of the menu's self-playing demo — the same snake that plays behind the main menu — with the menu text hidden and the title card drawn on top.

English screenshots, in listing order: `screenshot.png` 3-3 Scorpion Run (Badlands: blades and poison), `screenshot-2.png` Classic mode with a golden apple, `screenshot-3.png` the campaign level select, `screenshot-4.png` 5-2 Hellmouth (Inferno: timed golden hunt, portals, blades), `screenshot-5.png` 4-2 Emberways (Ashlands: portals and blades), `screenshot-6.png` the main menu, `screenshot-7.png` the language settings.

Each other language has three localized screenshots: a campaign level (`screenshot.png`), the main menu (`screenshot-2.png`) and the level select (`screenshot-3.png`). Level names and level hints are English-only in the game for now, so they appear in English in those shots too.

## English (en-us) — Snake World

### Short description (recommended, up to 1,000 characters; keep under 270 for best display)

Five untamed worlds stand between your snake and the Inferno. Dodge spinning blades, poison apples and portals across 20 hand-built levels — or slither forever in Classic mode and chase your best score.

(202 characters)

### Description (required, up to 10,000 characters)

Your snake's real test is the campaign. Twenty hand-built levels lead you through five worlds that grow more hostile the further you go — starting in a quiet meadow and ending in the Inferno itself. Every world throws something new at you: crumbling stone walls, blades that sweep across the board, poison apples that cost you dearly, and portals that fling you to the other side without warning. No two levels ask the same thing of you — some want speed, some want patience, some just want you to survive. Clear one and the next opens up; everything beyond stays hidden until you've earned the right to see it.

Need a breather? Classic mode is the endless original: one open field, apples that speed you up, golden apples worth 50 points if you're quick enough to catch them, and your best score always within reach.

Steer with arrow keys, WASD or an Xbox controller — the menus work with a mouse too. Play in English, Portuguese, Spanish, French, Italian, German, Swedish, Arabic or Chinese.

(995 characters)

### Product features (200 characters per feature, 20 max — Store adds bullets automatically, do not add your own)

1. Classic mode: the endless original — eat, grow, speed up and chase your best score
2. Campaign: 20 hand-built levels across five worlds, from a gentle meadow to the inferno
3. New hazards as you go: stone walls, spinning blades, poison apples and linked portals
4. Varied goals: eat apples, catch golden apples against the clock, grow to a length, or survive
5. Levels unlock one by one and stay hidden until you reach them
6. Keyboard, mouse and Xbox controller support, in 10 languages

## Portuguese (Portugal) (pt-pt) — Jogo da Cobra

### Descrição curta (recomendado, até 1000 carateres; manter abaixo de 270 para melhor exibição)

Cinco mundos hostis separam a tua cobra do Inferno. Evita lâminas giratórias, maçãs envenenadas e portais ao longo de 20 níveis feitos à mão — ou desliza sem fim no modo Clássico e bate o teu recorde.

(200 carateres)

### Descrição (obrigatório, até 10 000 carateres)

O verdadeiro desafio da tua cobra é a Campanha. Vinte níveis feitos à mão levam-te por cinco mundos que se tornam mais hostis a cada passo — começando num prado tranquilo e terminando no próprio Inferno. Cada mundo traz algo novo: paredes de pedra que se desfazem, lâminas que varrem o tabuleiro, maçãs envenenadas que te custam caro e portais que te atiram para o outro lado sem aviso. Nenhum nível te pede a mesma coisa — alguns querem velocidade, outros paciência, outros só que sobrevivas. Vence um e o seguinte abre-se; tudo o que vem depois fica escondido até teres ganho o direito de o ver.

Precisas de uma pausa? O modo Clássico é o original sem fim: um campo aberto, maçãs que te tornam mais rápido, maçãs douradas que valem 50 pontos se fores rápido o suficiente para as apanhar, e o teu recorde sempre à mão.

Conduz a cobra com as setas, WASD ou um comando Xbox — os menus também funcionam com o rato. Joga em inglês, português, espanhol, francês, italiano, alemão, sueco, árabe ou chinês.

(1002 carateres)

### Funcionalidades do produto (200 carateres por funcionalidade, 20 no máximo — a Store adiciona os marcadores automaticamente, não acrescentes os teus)

1. Modo Clássico: o original sem fim — come, cresce, acelera e bate o teu recorde
2. Campanha: 20 níveis feitos à mão em cinco mundos, de um prado tranquilo até ao inferno
3. Novos perigos pelo caminho: paredes de pedra, lâminas giratórias, maçãs envenenadas e portais
4. Objetivos variados: comer maçãs, apanhar maçãs douradas contra o relógio, crescer ou sobreviver
5. Os níveis desbloqueiam-se um a um e ficam escondidos até lá chegares
6. Teclado, rato e comando Xbox, em 10 idiomas

## Spanish (es-es) — Snake World

### Descripción breve (recomendado, hasta 1000 caracteres; mantener por debajo de 270 para una mejor visualización)

Cinco mundos hostiles separan a tu serpiente del Infierno. Evita cuchillas giratorias, manzanas envenenadas y portales a lo largo de 20 niveles hechos a mano — o desliza sin fin en modo Clásico y supera tu récord.

(213 caracteres)

### Descripción (obligatorio, hasta 10 000 caracteres)

El verdadero desafío de tu serpiente es la Campaña. Veinte niveles hechos a mano te llevan por cinco mundos que se vuelven más hostiles a cada paso — empezando en una pradera tranquila y terminando en el propio Infierno. Cada mundo trae algo nuevo: muros de piedra que se desmoronan, cuchillas que barren el tablero, manzanas envenenadas que te cuestan caro y portales que te lanzan al otro lado sin aviso. Ningún nivel te pide lo mismo — algunos quieren velocidad, otros paciencia, otros solo que sobrevivas. Supera uno y se abre el siguiente; todo lo que hay más allá permanece oculto hasta que te has ganado el derecho a verlo.

¿Necesitas un respiro? El modo Clásico es el original sin fin: un campo abierto, manzanas que te hacen más rápido, manzanas doradas que valen 50 puntos si eres lo bastante rápido para atraparlas, y tu récord siempre a tu alcance.

Guía a la serpiente con las flechas, WASD o un mando de Xbox — los menús también funcionan con el ratón. Juega en inglés, portugués, español, francés, italiano, alemán, sueco, árabe o chino.

(1053 caracteres)

### Características del producto (200 caracteres por característica, 20 como máximo — la Store añade las viñetas automáticamente, no incluyas las tuyas)

1. Modo Clásico: el original sin fin — come, crece, acelera y supera tu récord
2. Campaña: 20 niveles hechos a mano en cinco mundos, de una pradera tranquila al infierno
3. Nuevos peligros por el camino: muros de piedra, cuchillas giratorias, manzanas envenenadas y portales
4. Objetivos variados: comer manzanas, atrapar doradas contra reloj, crecer o sobrevivir
5. Los niveles se desbloquean uno a uno y permanecen ocultos hasta que llegas a ellos
6. Teclado, ratón y mando de Xbox, en 10 idiomas

## Portuguese (Brazil) (pt-br) — Jogo da Cobrinha

### Descrição curta (recomendado, até 1.000 caracteres; manter abaixo de 270 para melhor exibição)

Cinco mundos hostis separam sua cobrinha do Inferno. Evite lâminas giratórias, maçãs envenenadas e portais ao longo de 20 níveis feitos à mão — ou deslize sem fim no modo Clássico e bata o seu recorde.

(201 caracteres)

### Descrição (obrigatório, até 10.000 caracteres)

O verdadeiro desafio da sua cobrinha é a Campanha. Vinte níveis feitos à mão levam você por cinco mundos que ficam mais hostis a cada passo — começando numa campina tranquila e terminando no próprio Inferno. Cada mundo traz algo novo: paredes de pedra que se desmancham, lâminas que varrem o tabuleiro, maçãs envenenadas que custam caro e portais que jogam você para o outro lado sem aviso. Nenhum nível pede a mesma coisa — alguns querem velocidade, outros paciência, outros só que você sobreviva. Vença um e o próximo se abre; tudo o que vem depois fica escondido até você merecer ver.

Precisa de uma pausa? O modo Clássico é o original sem fim: um campo aberto, maçãs que deixam você mais rápido, maçãs douradas que valem 50 pontos se você for rápido o bastante para pegá-las, e o seu recorde sempre à mão.

Guie a cobrinha com as setas, WASD ou um controle Xbox — os menus também funcionam com o mouse. Jogue em inglês, português, espanhol, francês, italiano, alemão, sueco, árabe ou chinês.

(996 caracteres)

### Recursos do produto (200 caracteres por recurso, 20 no máximo — a Store adiciona os marcadores automaticamente, não adicione os seus)

1. Modo Clássico: o original sem fim — coma, cresça, acelere e bata o seu recorde
2. Campanha: 20 níveis feitos à mão em cinco mundos, de uma campina tranquila até o inferno
3. Novos perigos pelo caminho: paredes de pedra, lâminas giratórias, maçãs envenenadas e portais
4. Objetivos variados: comer maçãs, pegar maçãs douradas contra o relógio, crescer ou sobreviver
5. Os níveis são desbloqueados um a um e ficam escondidos até você chegar lá
6. Teclado, mouse e controle Xbox, em 10 idiomas

## French (fr-fr) — Snake World

### Description courte (recommandé, jusqu'à 1000 caractères ; rester sous 270 pour un meilleur affichage)

Cinq mondes hostiles séparent votre serpent de l'Enfer. Évitez les lames tournoyantes, les pommes empoisonnées et les portails à travers 20 niveaux conçus à la main — ou glissez sans fin en mode Classique et battez votre record.

(228 caractères)

### Description (obligatoire, jusqu'à 10 000 caractères)

Le vrai défi de votre serpent, c'est la Campagne. Vingt niveaux conçus à la main vous mènent à travers cinq mondes de plus en plus hostiles — d'une prairie paisible jusqu'à l'Enfer lui-même. Chaque monde apporte son lot de nouveautés : des murs de pierre qui s'effondrent, des lames qui balaient le plateau, des pommes empoisonnées qui vous coûtent cher, et des portails qui vous projettent de l'autre côté sans prévenir. Aucun niveau ne vous demande la même chose — certains veulent de la vitesse, d'autres de la patience, d'autres juste que vous surviviez. Terminez-en un et le suivant s'ouvre ; tout ce qui suit reste caché jusqu'à ce que vous ayez gagné le droit de le voir.

Besoin d'une pause ? Le mode Classique, c'est l'original sans fin : un terrain ouvert, des pommes qui vous accélèrent, des pommes dorées qui valent 50 points si vous êtes assez rapide pour les attraper, et votre record toujours à portée.

Dirigez le serpent avec les flèches, WASD ou une manette Xbox — les menus fonctionnent aussi à la souris. Jouez en anglais, portugais, espagnol, français, italien, allemand, suédois, arabe ou chinois.

(1119 caractères)

### Fonctionnalités du produit (200 caractères par fonctionnalité, 20 maximum — la Store ajoute les puces automatiquement, n'ajoutez pas les vôtres)

1. Mode Classique : l'original sans fin — mangez, grandissez, accélérez et battez votre record
2. Campagne : 20 niveaux conçus à la main sur cinq mondes, d'une prairie paisible jusqu'à l'enfer
3. De nouveaux dangers en chemin : murs de pierre, lames tournoyantes, pommes empoisonnées et portails
4. Des objectifs variés : manger des pommes, attraper des pommes dorées contre la montre, grandir ou survivre
5. Les niveaux se débloquent un par un et restent cachés jusqu'à ce que vous les atteigniez
6. Clavier, souris et manette Xbox, en 10 langues

## Italian (it-it) — Snake World

### Descrizione breve (consigliata, fino a 1000 caratteri; restare sotto i 270 per una migliore visualizzazione)

Cinque mondi ostili separano il tuo serpente dall'Inferno. Evita lame rotanti, mele avvelenate e portali attraverso 20 livelli creati a mano — oppure scivola all'infinito in modalità Classica e batti il tuo record.

(214 caratteri)

### Descrizione (obbligatoria, fino a 10.000 caratteri)

La vera prova per il tuo serpente è la Campagna. Venti livelli creati a mano ti portano attraverso cinque mondi sempre più ostili — da un prato tranquillo fino all'Inferno stesso. Ogni mondo porta qualcosa di nuovo: muri di pietra che crollano, lame che spazzano il tabellone, mele avvelenate che ti costano caro e portali che ti scaraventano dall'altra parte senza preavviso. Nessun livello ti chiede la stessa cosa — alcuni vogliono velocità, altri pazienza, altri solo che tu sopravviva. Superane uno e si apre il successivo; tutto ciò che viene dopo resta nascosto finché non ti sei guadagnato il diritto di vederlo.

Hai bisogno di una pausa? La modalità Classica è l'originale infinito: un campo aperto, mele che ti rendono più veloce, mele dorate che valgono 50 punti se sei abbastanza rapido da prenderle, e il tuo record sempre a portata di mano.

Guida il serpente con le frecce, WASD o un controller Xbox — i menu funzionano anche con il mouse. Gioca in inglese, portoghese, spagnolo, francese, italiano, tedesco, svedese, arabo o cinese.

(1049 caratteri)

### Funzionalità del prodotto (200 caratteri per funzionalità, massimo 20 — lo Store aggiunge i punti elenco automaticamente, non aggiungere i tuoi)

1. Modalità Classica: l'originale infinito — mangia, cresci, accelera e batti il tuo record
2. Campagna: 20 livelli creati a mano in cinque mondi, da un prato tranquillo fino all'inferno
3. Nuovi pericoli lungo la strada: muri di pietra, lame rotanti, mele avvelenate e portali
4. Obiettivi diversi: mangiare mele, prendere mele dorate contro il tempo, crescere o sopravvivere
5. I livelli si sbloccano uno alla volta e restano nascosti finché non li raggiungi
6. Tastiera, mouse e controller Xbox, in 10 lingue

## German (de-de) — Snake World

### Kurzbeschreibung (empfohlen, bis zu 1000 Zeichen; für die beste Darstellung unter 270 bleiben)

Fünf feindliche Welten trennen deine Schlange vom Inferno. Weiche rotierenden Klingen, giftigen Äpfeln und Portalen in 20 handgebauten Levels aus — oder gleite endlos im klassischen Modus und jage deinen Bestwert.

(213 Zeichen)

### Beschreibung (erforderlich, bis zu 10 000 Zeichen)

Die wahre Prüfung für deine Schlange ist die Kampagne. Zwanzig handgebaute Levels führen dich durch fünf Welten, die mit jedem Schritt feindlicher werden — von einer ruhigen Wiese bis ins Inferno selbst. Jede Welt bringt etwas Neues: bröckelnde Steinmauern, Klingen, die über das Feld fegen, giftige Äpfel, die dich teuer zu stehen kommen, und Portale, die dich ohne Vorwarnung auf die andere Seite schleudern. Kein Level verlangt dasselbe von dir — manche wollen Tempo, manche Geduld, manche nur, dass du überlebst. Schaffst du eines, öffnet sich das nächste; alles danach bleibt verborgen, bis du dir das Recht verdient hast, es zu sehen.

Brauchst du eine Pause? Der klassische Modus ist das endlose Original: ein offenes Feld, Äpfel, die dich schneller machen, goldene Äpfel im Wert von 50 Punkten, wenn du schnell genug bist, sie zu fangen, und dein Bestwert immer in Reichweite.

Steuere die Schlange mit den Pfeiltasten, WASD oder einem Xbox-Controller — die Menüs lassen sich auch mit der Maus bedienen. Spiele auf Englisch, Portugiesisch, Spanisch, Französisch, Italienisch, Deutsch, Schwedisch, Arabisch oder Chinesisch.

(1130 Zeichen)

### Produktfunktionen (200 Zeichen pro Funktion, maximal 20 — die Store fügt die Aufzählungszeichen automatisch hinzu, füge deine eigenen nicht hinzu)

1. Klassischer Modus: das endlose Original — essen, wachsen, schneller werden und den Bestwert jagen
2. Kampagne: 20 handgebaute Level in fünf Welten, von einer friedlichen Wiese bis ins Inferno
3. Neue Gefahren unterwegs: Steinmauern, rotierende Klingen, giftige Äpfel und Portale
4. Abwechslungsreiche Ziele: Äpfel essen, goldene Äpfel gegen die Zeit fangen, wachsen oder überleben
5. Level werden nacheinander freigeschaltet und bleiben verborgen, bis du sie erreichst
6. Tastatur, Maus und Xbox-Controller, in 10 Sprachen

## Swedish (sv-se) — Snake World

### Kort beskrivning (rekommenderas, upp till 1 000 tecken; håll under 270 för bästa visning)

Fem fientliga världar skiljer din orm från Infernot. Undvik snurrande blad, giftiga äpplen och portaler genom 20 handbyggda banor — eller glid i evighet i klassiskt läge och slå ditt rekord.

(190 tecken)

### Beskrivning (obligatorisk, upp till 10 000 tecken)

Din orms verkliga prövning är Kampanjen. Tjugo handbyggda banor tar dig genom fem världar som blir farligare för varje steg — från en lugn äng till Infernot självt. Varje värld för med sig något nytt: stenväggar som rasar, blad som sveper över planen, giftiga äpplen som kostar dig dyrt och portaler som slungar dig till andra sidan utan förvarning. Ingen bana kräver samma sak av dig — några vill ha snabbhet, några tålamod, några bara att du överlever. Klarar du en öppnas nästa; allt som väntar bortom förblir dolt tills du förtjänat rätten att se det.

Behöver du en paus? Klassiskt läge är det oändliga originalet: ett öppet fält, äpplen som gör dig snabbare, gyllene äpplen värda 50 poäng om du är snabb nog att fånga dem, och ditt rekord alltid inom räckhåll.

Styr ormen med piltangenterna, WASD eller en Xbox-handkontroll — menyerna fungerar även med musen. Spela på engelska, portugisiska, spanska, franska, italienska, tyska, svenska, arabiska eller kinesiska.

(971 tecken)

### Produktfunktioner (200 tecken per funktion, högst 20 — Store lägger till punkter automatiskt, lägg inte till egna)

1. Klassiskt läge: det oändliga originalet — ät, väx, bli snabbare och slå ditt rekord
2. Kampanj: 20 handbyggda banor i fem världar, från en lugn äng ända till infernot
3. Nya faror längs vägen: stenväggar, snurrande blad, giftiga äpplen och portaler
4. Varierade mål: ät äpplen, fånga gyllene äpplen mot klockan, väx eller överlev
5. Banorna låses upp en i taget och förblir dolda tills du når dem
6. Tangentbord, mus och Xbox-handkontroll, på 10 språk

## Arabic (ar-sa) — Snake World

### وصف قصير (موصى به، حتى 1000 حرف؛ يُفضّل أقل من 270 لأفضل عرض)

خمسة عوالم عدائية تفصل ثعبانك عن الجحيم. تجنّب الشفرات الدوّارة والتفاح المسموم والبوابات عبر 20 مستوى مصممًا يدويًا — أو انزلق إلى ما لا نهاية في الوضع الكلاسيكي وحطّم رقمك القياسي.

(182 حرفًا)

### الوصف (مطلوب، حتى 10000 حرف)

التحدي الحقيقي لثعبانك هو الحملة. عشرون مستوى مصممًا يدويًا تأخذك عبر خمسة عوالم تزداد عدائية مع كل خطوة — من مرجٍ هادئ إلى الجحيم نفسه. كل عالم يحمل شيئًا جديدًا: جدران حجرية تتصدّع، وشفرات تكتسح اللوحة، وتفاح مسموم يكلّفك الكثير، وبوابات تقذف بك إلى الجانب الآخر دون إنذار. لا يطلب منك مستويان الشيء نفسه — بعضها يريد السرعة، وبعضها الصبر، وبعضها فقط أن تنجو. تجاوز مستوى ويُفتح التالي؛ وكل ما بعده يبقى مخفيًا حتى تكسب حق رؤيته.

تحتاج إلى استراحة؟ الوضع الكلاسيكي هو الأصل الذي لا ينتهي: حقل مفتوح، وتفاح يزيد من سرعتك، وتفاح ذهبي يساوي 50 نقطة إن كنت سريعًا كافيًا لالتقاطه، وأفضل نتيجة لك في متناول يدك دائمًا.

وجّه الثعبان بمفاتيح الأسهم أو WASD أو يد تحكم Xbox — وتعمل القوائم بالفأرة أيضًا. العب بالإنجليزية أو البرتغالية أو الإسبانية أو الفرنسية أو الإيطالية أو الألمانية أو السويدية أو العربية أو الصينية.

(817 حرفًا)

### ميزات المنتج (200 حرف لكل ميزة، 20 كحد أقصى — يضيف المتجر النقاط تلقائيًا، لا تضف نقاطك الخاصة)

1. الوضع الكلاسيكي: الأصل الذي لا ينتهي — كُل وانمُ وتسارع وحطّم رقمك القياسي
2. الحملة: 20 مستوى مصممًا يدويًا في خمسة عوالم، من مرج هادئ حتى الجحيم
3. مخاطر جديدة على الطريق: جدران حجرية وشفرات دوّارة وتفاح مسموم وبوابات
4. أهداف متنوعة: أكل التفاح، التقاط التفاح الذهبي ضد الوقت، النمو أو البقاء على قيد الحياة
5. تُفتح المستويات واحدًا تلو الآخر وتبقى مخفية حتى تصل إليها
6. لوحة المفاتيح والفأرة ويد تحكم Xbox، بـ 10 لغات

## Chinese (Simplified) (zh-cn) — Snake World

### 简短描述（建议填写，最多 1000 个字符；为获得最佳显示效果请保持在 270 个字符以内）

五个充满敌意的世界横在你的蛇和炼狱之间。在 20 个精心设计的关卡中躲避旋转刀刃、毒苹果和传送门——或者在经典模式中永无止境地滑行，挑战你的最高分。

(74 个字符)

### 描述（必填，最多 10000 个字符）

你的蛇真正的考验是战役模式。20 个精心设计的关卡带你穿越五个越来越危险的世界——从宁静的草甸，直到炼狱本身。每个世界都会带来新的东西：会崩塌的石墙、横扫棋盘的刀刃、代价高昂的毒苹果，还有毫无预警就把你甩到另一侧的传送门。没有两个关卡的要求是一样的——有些考验速度，有些考验耐心，有些只求你活下来。闯过一关，下一关便会开启；之后的一切都保持隐藏，直到你赢得了看见它的资格。

想休息一下？经典模式是永无止境的原版玩法：开阔的场地、越吃越快的节奏、价值 50 分但需要眼疾手快才能抓住的金苹果，还会一直保存你的最高分。

使用方向键、WASD 或 Xbox 手柄操控蛇，菜单也支持鼠标操作。支持英语、葡萄牙语、西班牙语、法语、意大利语、德语、瑞典语、阿拉伯语和中文。

(332 个字符)

### 产品功能（每项最多 200 个字符，最多 20 项——应用商店会自动添加项目符号，请勿自行添加）

1. 经典模式：永无止境的原版玩法——吃、变长、加速，挑战最高分
2. 战役模式：五个世界共 20 个精心设计的关卡，从宁静的草甸到炼狱
3. 一路上的新危险：石墙、旋转刀刃、毒苹果和传送门
4. 多样的目标：吃苹果、限时抓金苹果、长到指定长度或坚持生存
5. 关卡逐一解锁，未到达的关卡始终保持隐藏
6. 支持键盘、鼠标和 Xbox 手柄，提供 10 种语言
