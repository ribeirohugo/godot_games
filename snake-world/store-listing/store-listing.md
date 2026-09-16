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
| `AppTile.300x300.png`, `AppTile.150x150.png`, `AppTile.71x71.png` | 1:1 | Store logos (made from `icon.png`, like the package logos); shared by every language |
| `screenshot*.png` | 2000x1520 | Desktop screenshots |

English screenshots, in listing order: `screenshot.png` 3-3 Scorpion Run (Badlands: blades and poison), `screenshot-2.png` Classic mode with a golden apple, `screenshot-3.png` the campaign level select, `screenshot-4.png` 5-2 Hellmouth (Inferno: timed golden hunt, portals, blades), `screenshot-5.png` 4-2 Emberways (Ashlands: portals and blades), `screenshot-6.png` the main menu, `screenshot-7.png` the language settings.

Each other language has three localized screenshots: a campaign level (`screenshot.png`), the main menu (`screenshot-2.png`) and the level select (`screenshot-3.png`). Level names and level hints are English-only in the game for now, so they appear in English in those shots too.

## English (en-us) — Snake World

### Short description (recommended, up to 1,000 characters; keep under 270 for best display)

The classic snake game, with a campaign. Eat apples and grow across 20 hand-built levels in five worlds, from a gentle meadow to the inferno — or play Classic and chase your best score.

(185 characters)

### Description (required, up to 10,000 characters)

Snake World is the classic snake game, rebuilt with a campaign. Steer your snake around the board, eat apples to grow longer, and don't run into the walls or bite your own tail.

Campaign takes you through five worlds of four levels each: the Meadow, the Dustfields, the Badlands, the Ashlands and finally the Inferno. Every world repaints the board and brings a new hazard — stone walls, spinning blades that sweep the board, poison apples that cost you three segments, and linked portals that carry you across. Each level sets its own goal: eat a number of apples, catch golden apples before the clock runs out, grow to a set length, or simply survive. Clearing a level opens the next, and levels you haven't reached stay hidden until you get there.

Classic is the endless original: one open field, apples that speed you up as you go, golden apples worth 50 points that don't wait around, and your best score saved.

Steer with the arrow keys, WASD or an Xbox controller; the menus work with the mouse too. Play in English, Portuguese, Spanish, French, Italian, German, Swedish, Arabic or Chinese.

(1100 characters)

### Product features (200 characters per feature, 20 max — Store adds bullets automatically, do not add your own)

1. Classic mode: the endless original — eat, grow, speed up and chase your best score
2. Campaign: 20 hand-built levels across five worlds, from a gentle meadow to the inferno
3. New hazards as you go: stone walls, spinning blades, poison apples and linked portals
4. Varied goals: eat apples, catch golden apples against the clock, grow to a length, or survive
5. Levels unlock one by one and stay hidden until you reach them
6. Keyboard, mouse and Xbox controller support, in 10 languages

## Portuguese (Portugal) (pt-pt) — Jogo da Cobra

### Descrição curta (recomendado, até 1000 carateres; manter abaixo de 270 para melhor exibição)

O clássico jogo da cobra, agora com campanha. Come maçãs e cresce ao longo de 20 níveis em cinco mundos, de um prado tranquilo até ao inferno — ou joga no modo Clássico e bate o teu recorde.

(190 carateres)

### Descrição (obrigatório, até 10 000 carateres)

Jogo da Cobra é o clássico de sempre, reconstruído com uma campanha. Conduz a cobra pelo tabuleiro, come maçãs para crescer e não batas nas paredes nem mordas a tua própria cauda.

A Campanha leva-te por cinco mundos com quatro níveis cada: o Prado, as Terras Secas, os Ermos, as Terras de Cinza e, por fim, o Inferno. Cada mundo muda o aspeto do tabuleiro e traz um novo perigo — paredes de pedra, lâminas giratórias que varrem o tabuleiro, maçãs envenenadas que te custam três segmentos e portais ligados que te levam de um lado ao outro. Cada nível tem o seu objetivo: comer um certo número de maçãs, apanhar maçãs douradas antes que o tempo acabe, crescer até um certo tamanho, ou simplesmente sobreviver. Concluir um nível abre o seguinte, e os níveis a que ainda não chegaste ficam escondidos até lá chegares.

O modo Clássico é o original sem fim: um campo aberto, maçãs que te tornam mais rápido, maçãs douradas que valem 50 pontos e não esperam por ti, e o teu recorde guardado.

Conduz a cobra com as setas, WASD ou um comando Xbox; os menus também funcionam com o rato. Joga em inglês, português, espanhol, francês, italiano, alemão, sueco, árabe ou chinês.

(1168 carateres)

### Funcionalidades do produto (200 carateres por funcionalidade, 20 no máximo — a Store adiciona os marcadores automaticamente, não acrescentes os teus)

1. Modo Clássico: o original sem fim — come, cresce, acelera e bate o teu recorde
2. Campanha: 20 níveis feitos à mão em cinco mundos, de um prado tranquilo até ao inferno
3. Novos perigos pelo caminho: paredes de pedra, lâminas giratórias, maçãs envenenadas e portais
4. Objetivos variados: comer maçãs, apanhar maçãs douradas contra o relógio, crescer ou sobreviver
5. Os níveis desbloqueiam-se um a um e ficam escondidos até lá chegares
6. Teclado, rato e comando Xbox, em 10 idiomas

## Spanish (es-es) — Snake World

### Descripción breve (recomendado, hasta 1000 caracteres; mantener por debajo de 270 para una mejor visualización)

El clásico juego de la serpiente, ahora con campaña. Come manzanas y crece a lo largo de 20 niveles en cinco mundos, de una pradera tranquila al infierno — o juega en modo Clásico y supera tu récord.

(199 caracteres)

### Descripción (obligatorio, hasta 10 000 caracteres)

Snake World es el clásico juego de la serpiente, reconstruido con una campaña. Guía a tu serpiente por el tablero, come manzanas para crecer y no choques contra las paredes ni te muerdas la cola.

La Campaña te lleva por cinco mundos de cuatro niveles cada uno: la Pradera, las Tierras Polvorientas, las Tierras Baldías, las Tierras de Ceniza y, por último, el Infierno. Cada mundo cambia el aspecto del tablero y trae un nuevo peligro — muros de piedra, cuchillas giratorias que barren el tablero, manzanas envenenadas que te cuestan tres segmentos y portales enlazados que te llevan de un lado a otro. Cada nivel tiene su propio objetivo: comer cierto número de manzanas, atrapar manzanas doradas antes de que se acabe el tiempo, crecer hasta cierta longitud o simplemente sobrevivir. Superar un nivel abre el siguiente, y los niveles a los que aún no has llegado permanecen ocultos hasta que llegues.

El modo Clásico es el original sin fin: un campo abierto, manzanas que te hacen más rápido, manzanas doradas que valen 50 puntos y no esperan, y tu récord guardado.

Guía a la serpiente con las flechas, WASD o un mando de Xbox; los menús también funcionan con el ratón. Juega en inglés, portugués, español, francés, italiano, alemán, sueco, árabe o chino.

(1260 caracteres)

### Características del producto (200 caracteres por característica, 20 como máximo — la Store añade las viñetas automáticamente, no incluyas las tuyas)

1. Modo Clásico: el original sin fin — come, crece, acelera y supera tu récord
2. Campaña: 20 niveles hechos a mano en cinco mundos, de una pradera tranquila al infierno
3. Nuevos peligros por el camino: muros de piedra, cuchillas giratorias, manzanas envenenadas y portales
4. Objetivos variados: comer manzanas, atrapar doradas contra reloj, crecer o sobrevivir
5. Los niveles se desbloquean uno a uno y permanecen ocultos hasta que llegas a ellos
6. Teclado, ratón y mando de Xbox, en 10 idiomas

## Portuguese (Brazil) (pt-br) — Jogo da Cobrinha

### Descrição curta (recomendado, até 1.000 caracteres; manter abaixo de 270 para melhor exibição)

O clássico jogo da cobrinha, agora com campanha. Coma maçãs e cresça ao longo de 20 níveis em cinco mundos, de uma campina tranquila até o inferno — ou jogue no modo Clássico e bata o seu recorde.

(196 caracteres)

### Descrição (obrigatório, até 10.000 caracteres)

Jogo da Cobrinha é o clássico de sempre, reconstruído com uma campanha. Guie a cobrinha pelo tabuleiro, coma maçãs para crescer e não bata nas paredes nem morda o próprio rabo.

A Campanha leva você por cinco mundos com quatro níveis cada: a Campina, as Terras Secas, as Terras Áridas, as Terras de Cinzas e, por fim, o Inferno. Cada mundo muda a cara do tabuleiro e traz um novo perigo — paredes de pedra, lâminas giratórias que varrem o tabuleiro, maçãs envenenadas que custam três segmentos e portais conectados que levam você de um lado ao outro. Cada nível tem seu próprio objetivo: comer um certo número de maçãs, pegar maçãs douradas antes que o tempo acabe, crescer até um certo tamanho, ou simplesmente sobreviver. Concluir um nível abre o próximo, e os níveis que você ainda não alcançou ficam escondidos até você chegar lá.

O modo Clássico é o original sem fim: um campo aberto, maçãs que deixam você mais rápido, maçãs douradas que valem 50 pontos e não esperam, e o seu recorde salvo.

Guie a cobrinha com as setas, WASD ou um controle Xbox; os menus também funcionam com o mouse. Jogue em inglês, português, espanhol, francês, italiano, alemão, sueco, árabe ou chinês.

(1183 caracteres)

### Recursos do produto (200 caracteres por recurso, 20 no máximo — a Store adiciona os marcadores automaticamente, não adicione os seus)

1. Modo Clássico: o original sem fim — coma, cresça, acelere e bata o seu recorde
2. Campanha: 20 níveis feitos à mão em cinco mundos, de uma campina tranquila até o inferno
3. Novos perigos pelo caminho: paredes de pedra, lâminas giratórias, maçãs envenenadas e portais
4. Objetivos variados: comer maçãs, pegar maçãs douradas contra o relógio, crescer ou sobreviver
5. Os níveis são desbloqueados um a um e ficam escondidos até você chegar lá
6. Teclado, mouse e controle Xbox, em 10 idiomas

## French (fr-fr) — Snake World

### Description courte (recommandé, jusqu'à 1000 caractères ; rester sous 270 pour un meilleur affichage)

Le jeu du serpent classique, avec une campagne. Mangez des pommes et grandissez au fil de 20 niveaux sur cinq mondes, d'une prairie paisible jusqu'à l'enfer — ou jouez en mode Classique et battez votre record.

(209 caractères)

### Description (obligatoire, jusqu'à 10 000 caractères)

Snake World, c'est le jeu du serpent classique, repensé avec une campagne. Dirigez votre serpent sur le plateau, mangez des pommes pour grandir, et évitez les murs comme votre propre queue.

La Campagne vous emmène à travers cinq mondes de quatre niveaux chacun : la Prairie, les Terres Arides, les Terres Désolées, les Terres de Cendres et enfin l'Enfer. Chaque monde change le décor du plateau et apporte un nouveau danger — murs de pierre, lames tournoyantes qui balaient le plateau, pommes empoisonnées qui vous coûtent trois segments et portails reliés qui vous font traverser d'un côté à l'autre. Chaque niveau a son propre objectif : manger un certain nombre de pommes, attraper des pommes dorées avant la fin du chrono, atteindre une certaine longueur ou simplement survivre. Terminer un niveau débloque le suivant, et les niveaux que vous n'avez pas encore atteints restent cachés jusqu'à ce que vous y arriviez.

Le mode Classique, c'est l'original sans fin : un terrain ouvert, des pommes qui vous accélèrent, des pommes dorées qui valent 50 points et ne restent pas longtemps, et votre record sauvegardé.

Dirigez le serpent avec les flèches, WASD ou une manette Xbox ; les menus fonctionnent aussi à la souris. Jouez en anglais, portugais, espagnol, français, italien, allemand, suédois, arabe ou chinois.

(1318 caractères)

### Fonctionnalités du produit (200 caractères par fonctionnalité, 20 maximum — la Store ajoute les puces automatiquement, n'ajoutez pas les vôtres)

1. Mode Classique : l'original sans fin — mangez, grandissez, accélérez et battez votre record
2. Campagne : 20 niveaux conçus à la main sur cinq mondes, d'une prairie paisible jusqu'à l'enfer
3. De nouveaux dangers en chemin : murs de pierre, lames tournoyantes, pommes empoisonnées et portails
4. Des objectifs variés : manger des pommes, attraper des pommes dorées contre la montre, grandir ou survivre
5. Les niveaux se débloquent un par un et restent cachés jusqu'à ce que vous les atteigniez
6. Clavier, souris et manette Xbox, en 10 langues

## Italian (it-it) — Snake World

### Descrizione breve (consigliata, fino a 1000 caratteri; restare sotto i 270 per una migliore visualizzazione)

Il classico gioco del serpente, ora con una campagna. Mangia mele e cresci attraverso 20 livelli in cinque mondi, da un prato tranquillo fino all'inferno — oppure gioca in modalità Classica e batti il tuo record.

(212 caratteri)

### Descrizione (obbligatoria, fino a 10.000 caratteri)

Snake World è il classico gioco del serpente, ripensato con una campagna. Guida il serpente sul tabellone, mangia mele per crescere e non sbattere contro i muri né morderti la coda.

La Campagna ti porta attraverso cinque mondi da quattro livelli ciascuno: il Prato, le Terre Polverose, le Terre Desolate, le Terre di Cenere e infine l'Inferno. Ogni mondo cambia l'aspetto del tabellone e porta un nuovo pericolo — muri di pietra, lame rotanti che spazzano il tabellone, mele avvelenate che ti costano tre segmenti e portali collegati che ti trasportano da una parte all'altra. Ogni livello ha il suo obiettivo: mangiare un certo numero di mele, prendere le mele dorate prima che scada il tempo, crescere fino a una certa lunghezza o semplicemente sopravvivere. Completare un livello sblocca il successivo, e i livelli che non hai ancora raggiunto restano nascosti finché non ci arrivi.

La modalità Classica è l'originale infinito: un campo aperto, mele che ti rendono più veloce, mele dorate che valgono 50 punti e non aspettano, e il tuo record salvato.

Guida il serpente con le frecce, WASD o un controller Xbox; i menu funzionano anche con il mouse. Gioca in inglese, portoghese, spagnolo, francese, italiano, tedesco, svedese, arabo o cinese.

(1249 caratteri)

### Funzionalità del prodotto (200 caratteri per funzionalità, massimo 20 — lo Store aggiunge i punti elenco automaticamente, non aggiungere i tuoi)

1. Modalità Classica: l'originale infinito — mangia, cresci, accelera e batti il tuo record
2. Campagna: 20 livelli creati a mano in cinque mondi, da un prato tranquillo fino all'inferno
3. Nuovi pericoli lungo la strada: muri di pietra, lame rotanti, mele avvelenate e portali
4. Obiettivi diversi: mangiare mele, prendere mele dorate contro il tempo, crescere o sopravvivere
5. I livelli si sbloccano uno alla volta e restano nascosti finché non li raggiungi
6. Tastiera, mouse e controller Xbox, in 10 lingue

## German (de-de) — Snake World

### Kurzbeschreibung (empfohlen, bis zu 1000 Zeichen; für die beste Darstellung unter 270 bleiben)

Das klassische Schlangenspiel, jetzt mit Kampagne. Iss Äpfel und wachse durch 20 Level in fünf Welten, von einer friedlichen Wiese bis ins Inferno — oder spiel den klassischen Modus und jage deinen Bestwert.

(207 Zeichen)

### Beschreibung (erforderlich, bis zu 10 000 Zeichen)

Snake World ist das klassische Schlangenspiel, neu gebaut mit einer Kampagne. Steuere deine Schlange über das Spielfeld, iss Äpfel, um länger zu werden, und stoß weder gegen Wände, noch beiß dir in den eigenen Schwanz.

Die Kampagne führt dich durch fünf Welten mit je vier Levels: die Wiese, die Staubfelder, das Ödland, das Aschland und schließlich das Inferno. Jede Welt gibt dem Spielfeld ein neues Gesicht und bringt eine neue Gefahr — Steinmauern, rotierende Klingen, die über das Feld fegen, giftige Äpfel, die dich drei Glieder kosten, und verbundene Portale, die dich quer über das Feld bringen. Jedes Level hat sein eigenes Ziel: eine bestimmte Zahl Äpfel essen, goldene Äpfel vor Ablauf der Zeit schnappen, eine bestimmte Länge erreichen oder einfach überleben. Wer ein Level schafft, schaltet das nächste frei, und Levels, die du noch nicht erreicht hast, bleiben verborgen, bis du dort ankommst.

Der klassische Modus ist das endlose Original: ein offenes Feld, Äpfel, die dich schneller machen, goldene Äpfel, die 50 Punkte wert sind und nicht lange warten, und dein gespeicherter Bestwert.

Steuere die Schlange mit den Pfeiltasten, WASD oder einem Xbox-Controller; die Menüs lassen sich auch mit der Maus bedienen. Spiele auf Englisch, Portugiesisch, Spanisch, Französisch, Italienisch, Deutsch, Schwedisch, Arabisch oder Chinesisch.

(1349 Zeichen)

### Produktfunktionen (200 Zeichen pro Funktion, maximal 20 — die Store fügt die Aufzählungszeichen automatisch hinzu, füge deine eigenen nicht hinzu)

1. Klassischer Modus: das endlose Original — essen, wachsen, schneller werden und den Bestwert jagen
2. Kampagne: 20 handgebaute Level in fünf Welten, von einer friedlichen Wiese bis ins Inferno
3. Neue Gefahren unterwegs: Steinmauern, rotierende Klingen, giftige Äpfel und Portale
4. Abwechslungsreiche Ziele: Äpfel essen, goldene Äpfel gegen die Zeit fangen, wachsen oder überleben
5. Level werden nacheinander freigeschaltet und bleiben verborgen, bis du sie erreichst
6. Tastatur, Maus und Xbox-Controller, in 10 Sprachen

## Swedish (sv-se) — Snake World

### Kort beskrivning (rekommenderas, upp till 1 000 tecken; håll under 270 för bästa visning)

Det klassiska ormspelet, nu med kampanj. Ät äpplen och väx genom 20 banor i fem världar, från en lugn äng ända till infernot — eller spela klassiskt läge och slå ditt rekord.

(174 tecken)

### Beskrivning (obligatorisk, upp till 10 000 tecken)

Snake World är det klassiska ormspelet, ombyggt med en kampanj. Styr din orm över spelplanen, ät äpplen för att växa och kör inte in i väggarna eller bit dig själv i svansen.

Kampanjen tar dig genom fem världar med fyra banor var: Ängen, Dammfälten, Ödemarken, Askmarkerna och till sist Infernot. Varje värld ger spelplanen ett nytt utseende och en ny fara — stenväggar, snurrande blad som sveper över planen, giftiga äpplen som kostar dig tre segment och sammankopplade portaler som för dig tvärs över planen. Varje bana har sitt eget mål: ät ett visst antal äpplen, fånga gyllene äpplen innan tiden tar slut, väx till en viss längd eller överlev helt enkelt. Klarar du en bana låses nästa upp, och banor du inte har nått ännu förblir dolda tills du kommer dit.

Klassiskt läge är det oändliga originalet: ett öppet fält, äpplen som gör dig snabbare, gyllene äpplen värda 50 poäng som inte väntar, och ditt rekord sparat.

Styr ormen med piltangenterna, WASD eller en Xbox-handkontroll; menyerna fungerar även med musen. Spela på engelska, portugisiska, spanska, franska, italienska, tyska, svenska, arabiska eller kinesiska.

(1127 tecken)

### Produktfunktioner (200 tecken per funktion, högst 20 — Store lägger till punkter automatiskt, lägg inte till egna)

1. Klassiskt läge: det oändliga originalet — ät, väx, bli snabbare och slå ditt rekord
2. Kampanj: 20 handbyggda banor i fem världar, från en lugn äng ända till infernot
3. Nya faror längs vägen: stenväggar, snurrande blad, giftiga äpplen och portaler
4. Varierade mål: ät äpplen, fånga gyllene äpplen mot klockan, väx eller överlev
5. Banorna låses upp en i taget och förblir dolda tills du når dem
6. Tangentbord, mus och Xbox-handkontroll, på 10 språk

## Arabic (ar-sa) — Snake World

### وصف قصير (موصى به، حتى 1000 حرف؛ يُفضّل أقل من 270 لأفضل عرض)

لعبة الثعبان الكلاسيكية، الآن مع حملة. كُل التفاح وانمُ عبر 20 مستوى في خمسة عوالم، من مرجٍ هادئ حتى الجحيم — أو العب الوضع الكلاسيكي وحطّم أفضل نتيجة لك.

(154 حرفًا)

### الوصف (مطلوب، حتى 10000 حرف)

Snake World هي لعبة الثعبان الكلاسيكية، أُعيد بناؤها مع حملة. وجّه ثعبانك عبر اللوحة، وكُل التفاح لتزداد طولًا، ولا تصطدم بالجدران ولا تعضّ ذيلك.

تأخذك الحملة عبر خمسة عوالم في كل منها أربعة مستويات: المرج، وأراضي الغبار، والأراضي الوعرة، وأراضي الرماد، وأخيرًا الجحيم. كل عالم يغيّر شكل اللوحة ويجلب خطرًا جديدًا — جدران حجرية، وشفرات دوّارة تكتسح اللوحة، وتفاح مسموم يكلّفك ثلاثة أجزاء، وبوابات مترابطة تنقلك من جهة إلى أخرى. لكل مستوى هدفه الخاص: أكل عدد معيّن من التفاح، أو التقاط التفاح الذهبي قبل نفاد الوقت، أو الوصول إلى طول معيّن، أو ببساطة البقاء على قيد الحياة. إكمال مستوى يفتح المستوى التالي، وتبقى المستويات التي لم تصل إليها بعد مخفية حتى تبلغها.

الوضع الكلاسيكي هو الأصل الذي لا ينتهي: حقل مفتوح، وتفاح يزيد من سرعتك، وتفاح ذهبي يساوي 50 نقطة ولا ينتظر طويلًا، وأفضل نتيجة لك محفوظة.

وجّه الثعبان بمفاتيح الأسهم أو WASD أو يد تحكم Xbox، وتعمل القوائم بالفأرة أيضًا. العب بالإنجليزية أو البرتغالية أو الإسبانية أو الفرنسية أو الإيطالية أو الألمانية أو السويدية أو العربية أو الصينية.

(1001 حرفًا)

### ميزات المنتج (200 حرف لكل ميزة، 20 كحد أقصى — يضيف المتجر النقاط تلقائيًا، لا تضف نقاطك الخاصة)

1. الوضع الكلاسيكي: الأصل الذي لا ينتهي — كُل وانمُ وتسارع وحطّم رقمك القياسي
2. الحملة: 20 مستوى مصممًا يدويًا في خمسة عوالم، من مرج هادئ حتى الجحيم
3. مخاطر جديدة على الطريق: جدران حجرية وشفرات دوّارة وتفاح مسموم وبوابات
4. أهداف متنوعة: أكل التفاح، التقاط التفاح الذهبي ضد الوقت، النمو أو البقاء على قيد الحياة
5. تُفتح المستويات واحدًا تلو الآخر وتبقى مخفية حتى تصل إليها
6. لوحة المفاتيح والفأرة ويد تحكم Xbox، بـ 10 لغات

## Chinese (Simplified) (zh-cn) — Snake World

### 简短描述（建议填写，最多 1000 个字符；为获得最佳显示效果请保持在 270 个字符以内）

经典贪吃蛇，如今加入了战役模式。吃苹果、变长，闯过五个世界的 20 个关卡，从宁静的草甸一路到炼狱——或者在经典模式中挑战你的最高分。

(67 个字符)

### 描述（必填，最多 10000 个字符）

Snake World 是经典的贪吃蛇游戏，并重新打造了战役模式。操控你的蛇在棋盘上移动，吃苹果让自己变长，别撞墙，也别咬到自己的尾巴。

战役模式将带你穿越五个世界，每个世界有四个关卡：草甸、尘土荒原、荒漠、灰烬之地，最后是炼狱。每个世界都会改变棋盘的样貌，并带来新的危险——石墙、横扫棋盘的旋转刀刃、会让你失去三节身体的毒苹果，以及把你传送到另一侧的相连传送门。每个关卡都有自己的目标：吃掉一定数量的苹果、在时间耗尽前抓住金苹果、长到指定长度，或者单纯地活下来。通关一关即可解锁下一关，尚未到达的关卡会一直隐藏，直到你抵达为止。

经典模式是永无止境的原版玩法：开阔的场地、越吃越快的节奏、价值 50 分但转瞬即逝的金苹果，还会保存你的最高分。

使用方向键、WASD 或 Xbox 手柄操控蛇，菜单也支持鼠标操作。支持英语、葡萄牙语、西班牙语、法语、意大利语、德语、瑞典语、阿拉伯语和中文。

(398 个字符)

### 产品功能（每项最多 200 个字符，最多 20 项——应用商店会自动添加项目符号，请勿自行添加）

1. 经典模式：永无止境的原版玩法——吃、变长、加速，挑战最高分
2. 战役模式：五个世界共 20 个精心设计的关卡，从宁静的草甸到炼狱
3. 一路上的新危险：石墙、旋转刀刃、毒苹果和传送门
4. 多样的目标：吃苹果、限时抓金苹果、长到指定长度或坚持生存
5. 关卡逐一解锁，未到达的关卡始终保持隐藏
6. 支持键盘、鼠标和 Xbox 手柄，提供 10 种语言
