# Microsoft Store listing — Par ou Ímpar

Written to Microsoft's Store listing rules (character limits, no HTML/code/URLs in the description, no manually-added bullets in Product features): https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/add-and-edit-store-listing-info (same field rules apply to MSIX apps).

The game is translated into 12 languages (see `scripts/strings.gd`). `msix.env` declares 13 listing languages in the package manifest (`en-us,en-gb,pt,es,fr,de,it,nl,ro,sv,nb,pl,tr`): English is split into US and UK, and every other language uses its main language code. Partner Center will ask for a listing in each, so one is provided below for every language, headed with that code.

## Product identity

From Partner Center > Product management > Product identity. The first three are in `msix.env`.

| Field | Value |
| --- | --- |
| Package/Identity/Name | `WebPlatinum.Paroumpar` |
| Package/Identity/Publisher | `CN=33F06A6D-7BDD-48EE-AC03-85FC626020AD` |
| Package/Properties/PublisherDisplayName | `Web Platinum` |
| Package Family Name (PFN) | `WebPlatinum.Paroumpar_65qvk9hs8s2gj` |
| Package SID | `S-1-15-2-150067807-2342723484-2296540802-1427363294-4012175815-1045055738-3114301675` |
| Store ID | `9MXMB9KCH2DR` |
| Store deep link, Web Store URL | Available after the product is live |

## Product name

The name is localized: each listing uses the name reserved for it in Partner Center, and the game shows the same name as its title in that language. The manifest's `DISPLAY_NAME` stays "Par ou Ímpar" (the dashboard name).

| Listing | Product name |
| --- | --- |
| en-us | Odds or Evens |
| en-gb | Odd or Even (the game itself shows "Odds or Evens" for all English) |
| pt | Par ou Ímpar |
| es | Pares o Nones |
| fr | Pair ou Impair |
| de | Gerade oder ungerade |
| it | Parí o Dispari |
| nl | Even of oneven |
| ro | Par sau impar |
| sv | Udda eller jämnt |
| nb | Partall eller oddetall |
| pl | Parzyste czy nieparzyste |
| tr | Tek mi çift mi? |

## Images

Rendered in-engine from the game's own drawing code, icon and fonts — no external image editor involved. The App tiles are `icon.png` scaled down. The top level holds the en-us images; each language folder holds that language's images, with its product name on the art and the game running in that language in the screenshots. `en-gb/` has only its own art (with "Odd or Even"): use the top-level screenshots for en-gb.

| File | Where it goes |
| --- | --- |
| `BoxArt.1080x1080.png`, `BoxArt.2160x2160.png` | Store display images: 1:1 box art |
| `PosterArt.720x1080.png`, `PosterArt.1440x2160.png` | Store display images: 2:3 poster art |
| `HeroArt.1920x1080.png`, `HeroArt.3840x2160.png` | Store display images: 16:9 Super hero art (optional) |
| `AppTile.300x300.png`, `AppTile.150x150.png`, `AppTile.71x71.png` | Store logos: 1:1 app tile icon (optional; top level only, same for every language) |
| `screenshot.png` | Desktop screenshot: a round against the CPU just won, 3 + 2 = 5 ODD, the fingers counted, with confetti |
| `screenshot-2.png` | Desktop screenshot: the main menu with the vs CPU and 2 Players modes |
| `screenshot-3.png` | Desktop screenshot: 2 Players mode, player 1 has picked and it is player 2's turn |
| `screenshot-4.png` | Desktop screenshot: the hands shaking on the last word of the chant |
| `screenshot-5.png` | Desktop screenshot: a match won, with the New match and Main menu buttons |

All screenshots are real gameplay at 1920x1080.

## English (en-us) — Odds or Evens

### Short description (recommended, up to 1,000 characters; keep under 270 for best display)

Play Odds or Evens, the classic hand game. Call EVEN or ODD, show 0 to 5 fingers and watch both hands open on the chant. Play against the computer or take turns with a friend on the same device.

(194 characters)

### Description (required, up to 10,000 characters)

Odds or Evens brings the classic hand game to your computer. It is the quick way to decide who goes first, who picks the team or who gets the last slice: both players show some fingers at the same time, and the sum decides the winner.

Call EVEN or ODD, then show 0 to 5 fingers. Both hands shake three times to the chant and open together. The fingers are counted one by one: if the sum is even, EVEN wins the round, and if it is odd, ODD wins. The first to win 3, 5 or 7 rounds wins the match.

Pick the play mode on the main menu. Against the CPU you can face a random opponent or a clever one that remembers which numbers you like to show and tries to outguess you. In 2 Players mode you and a friend take turns on the same device: player 1 picks first, player 2 picks next, and neither choice is shown until the hands open.

Cartoon hands, animated counting, sound effects and confetti when you win. Statistics keep your rounds, matches and longest winning streak against the CPU. Play with the mouse or the keyboard, and go back to the main menu at any time. The game is available in 12 languages.

(1103 characters)

### Product features (200 characters per feature, 20 max — Store adds bullets automatically, do not add your own)

1. The classic hand game: call EVEN or ODD and show 0 to 5 fingers
2. Play against the CPU or with a friend, taking turns on the same device
3. Two CPU opponents: a random one and a clever one that learns your habits
4. Matches to 3, 5 or 7 rounds
5. Hands that shake to the chant, open together and count every finger
6. Statistics for rounds, matches and your longest winning streak
7. Mouse and keyboard controls
8. Available in 12 languages

## English (en-gb) — Odd or Even

### Short description (recommended, up to 1,000 characters; keep under 270 for best display)

Play Odd or Even, the classic hand game. Call EVEN or ODD, show 0 to 5 fingers and watch both hands open on the chant. Play against the computer or take turns with a friend on the same device.

(192 characters)

### Description (required, up to 10,000 characters)

Odd or Even brings the classic hand game to your computer. It is the quick way to decide who goes first, who picks the team or who gets the last slice: both players show some fingers at the same time, and the sum decides the winner.

Call EVEN or ODD, then show 0 to 5 fingers. Both hands shake three times to the chant and open together. The fingers are counted one by one: if the sum is even, EVEN wins the round, and if it is odd, ODD wins. The first to win 3, 5 or 7 rounds wins the match.

Pick the play mode on the main menu. Against the CPU you can face a random opponent or a clever one that remembers which numbers you like to show and tries to outguess you. In 2 Players mode you and a friend take turns on the same device: player 1 picks first, player 2 picks next, and neither choice is shown until the hands open.

Cartoon hands, animated counting, sound effects and confetti when you win. Statistics keep your rounds, matches and longest winning streak against the CPU. Play with the mouse or the keyboard, and go back to the main menu at any time. The game is available in 12 languages.

(1101 characters)

### Product features (200 characters per feature, 20 max — Store adds bullets automatically, do not add your own)

1. The classic hand game: call EVEN or ODD and show 0 to 5 fingers
2. Play against the CPU or with a friend, taking turns on the same device
3. Two CPU opponents: a random one and a clever one that learns your habits
4. Matches to 3, 5 or 7 rounds
5. Hands that shake to the chant, open together and count every finger
6. Statistics for rounds, matches and your longest winning streak
7. Mouse and keyboard controls
8. Available in 12 languages

## Portuguese (pt) — Par ou Ímpar

### Descrição curta (recomendado, até 1000 carateres; manter abaixo de 270 para melhor exibição)

Joga ao Par ou Ímpar, o clássico jogo de mãos. Escolhe PAR ou ÍMPAR, mostra de 0 a 5 dedos e vê as duas mãos abrirem ao som da lengalenga. Joga contra o computador ou à vez com um amigo no mesmo dispositivo.

(207 carateres)

### Descrição (obrigatório, até 10 000 carateres)

Par ou Ímpar traz para o teu computador o clássico jogo de mãos. É a forma rápida de decidir quem começa, quem escolhe a equipa ou quem fica com a última fatia: os dois jogadores mostram os dedos ao mesmo tempo e a soma decide quem ganha.

Escolhe PAR ou ÍMPAR e mostra de 0 a 5 dedos. As duas mãos abanam três vezes ao som da lengalenga e abrem ao mesmo tempo. Os dedos são contados um a um: se a soma for par, ganha o PAR, e se for ímpar, ganha o ÍMPAR. Quem ganhar primeiro 3, 5 ou 7 rondas ganha a partida.

Escolhe o modo de jogo no menu principal. Contra o CPU podes defrontar um adversário aleatório ou um esperto, que se lembra dos números que gostas de mostrar e tenta adivinhar a tua jogada. No modo 2 Jogadores, tu e um amigo jogam à vez no mesmo dispositivo: o jogador 1 escolhe primeiro, o jogador 2 a seguir, e nenhuma escolha aparece antes de as mãos abrirem.

Mãos desenhadas, contagem animada, efeitos sonoros e confetes quando ganhas. As estatísticas guardam as rondas, as partidas e a tua maior série de vitórias contra o CPU. Joga com o rato ou com o teclado e volta ao menu principal a qualquer momento. O jogo está disponível em 12 idiomas.

(1162 carateres)

### Funcionalidades do produto (200 carateres por funcionalidade, 20 no máximo — a Store adiciona os marcadores automaticamente, não acrescentes os teus)

1. O clássico jogo de mãos: escolhe PAR ou ÍMPAR e mostra de 0 a 5 dedos
2. Joga contra o CPU ou com um amigo, à vez, no mesmo dispositivo
3. Dois adversários CPU: um aleatório e um esperto que aprende os teus hábitos
4. Partidas a 3, 5 ou 7 rondas
5. Mãos que abanam ao som da lengalenga, abrem ao mesmo tempo e contam cada dedo
6. Estatísticas de rondas, partidas e da tua maior série de vitórias
7. Controlo com o rato e com o teclado
8. Disponível em 12 idiomas

## Spanish (es) — Pares o Nones

### Descripción breve (recomendado, hasta 1000 caracteres; mantener por debajo de 270 para una mejor visualización)

Juega a Pares o Nones, el clásico juego de manos. Elige PAR o IMPAR, saca de 0 a 5 dedos y mira cómo se abren las dos manos al ritmo de la cantinela. Juega contra el ordenador o por turnos con un amigo en el mismo dispositivo.

(226 caracteres)

### Descripción (obligatorio, hasta 10 000 caracteres)

Pares o Nones lleva a tu ordenador el clásico juego de manos. Es la forma rápida de decidir quién empieza, quién elige equipo o quién se queda el último trozo: los dos jugadores sacan los dedos a la vez y la suma decide quién gana.

Elige PAR o IMPAR y saca de 0 a 5 dedos. Las dos manos se agitan tres veces al ritmo de la cantinela y se abren a la vez. Los dedos se cuentan uno a uno: si la suma es par, gana PAR, y si es impar, gana IMPAR. Quien gane primero 3, 5 o 7 rondas gana la partida.

Elige el modo de juego en el menú principal. Contra la CPU puedes enfrentarte a un rival aleatorio o a uno listo, que recuerda los números que te gusta sacar e intenta adivinar tu jugada. En el modo 2 Jugadores, tú y un amigo jugáis por turnos en el mismo dispositivo: el jugador 1 elige primero, el jugador 2 después, y ninguna elección se ve hasta que se abren las manos.

Manos dibujadas, recuento animado, efectos de sonido y confeti cuando ganas. Las estadísticas guardan tus rondas, tus partidas y tu mejor racha de victorias contra la CPU. Juega con el ratón o con el teclado y vuelve al menú principal cuando quieras. El juego está disponible en 12 idiomas.

(1161 caracteres)

### Características del producto (200 caracteres por característica, 20 como máximo — la Store añade las viñetas automáticamente, no incluyas las tuyas)

1. El clásico juego de manos: elige PAR o IMPAR y saca de 0 a 5 dedos
2. Juega contra la CPU o con un amigo, por turnos, en el mismo dispositivo
3. Dos rivales CPU: uno aleatorio y uno listo que aprende tus costumbres
4. Partidas a 3, 5 o 7 rondas
5. Manos que se agitan al ritmo de la cantinela, se abren a la vez y cuentan cada dedo
6. Estadísticas de rondas, partidas y tu mejor racha de victorias
7. Control con el ratón y con el teclado
8. Disponible en 12 idiomas

## French (fr) — Pair ou Impair

### Description courte (recommandé, jusqu'à 1000 caractères ; rester sous 270 pour un meilleur affichage)

Joue à Pair ou Impair, le jeu de mains classique. Choisis PAIR ou IMPAIR, montre de 0 à 5 doigts et regarde les deux mains s'ouvrir en rythme. Joue contre l'ordinateur ou chacun son tour avec un ami sur le même appareil.

(220 caractères)

### Description (obligatoire, jusqu'à 10 000 caractères)

Pair ou Impair apporte sur ton ordinateur le jeu de mains classique. C'est la façon rapide de décider qui commence, qui choisit l'équipe ou qui prend la dernière part : les deux joueurs montrent leurs doigts en même temps et la somme désigne le gagnant.

Choisis PAIR ou IMPAIR, puis montre de 0 à 5 doigts. Les deux mains se balancent trois fois en rythme et s'ouvrent ensemble. Les doigts sont comptés un par un : si la somme est paire, PAIR gagne la manche, et si elle est impaire, IMPAIR gagne. Le premier à gagner 3, 5 ou 7 manches remporte la partie.

Choisis le mode de jeu dans le menu principal. Contre le CPU, tu peux affronter un adversaire aléatoire ou un adversaire malin, qui retient les nombres que tu aimes montrer et essaie de deviner ton coup. En mode 2 Joueurs, toi et un ami jouez chacun votre tour sur le même appareil : le joueur 1 choisit d'abord, le joueur 2 ensuite, et aucun choix n'est visible avant l'ouverture des mains.

Des mains dessinées, un comptage animé, des effets sonores et des confettis quand tu gagnes. Les statistiques gardent tes manches, tes parties et ta plus longue série de victoires contre le CPU. Joue à la souris ou au clavier, et reviens au menu principal à tout moment. Le jeu est disponible en 12 langues.

(1258 caractères)

### Fonctionnalités du produit (200 caractères par fonctionnalité, 20 maximum — la Store ajoute les puces automatiquement, n'ajoutez pas les vôtres)

1. Le jeu de mains classique : choisis PAIR ou IMPAIR et montre de 0 à 5 doigts
2. Joue contre le CPU ou avec un ami, chacun son tour, sur le même appareil
3. Deux adversaires CPU : un aléatoire et un malin qui apprend tes habitudes
4. Parties en 3, 5 ou 7 manches
5. Des mains qui se balancent en rythme, s'ouvrent ensemble et comptent chaque doigt
6. Statistiques des manches, des parties et de ta plus longue série de victoires
7. Contrôle à la souris et au clavier
8. Disponible en 12 langues

## German (de) — Gerade oder ungerade

### Kurzbeschreibung (empfohlen, bis zu 1000 Zeichen; für die beste Darstellung unter 270 bleiben)

Spiele Gerade oder ungerade, das klassische Handspiel. Wähle GERADE oder UNGERADE, zeig 0 bis 5 Finger und sieh zu, wie sich beide Hände im Takt öffnen. Spiel gegen den Computer oder abwechselnd mit einem Freund auf demselben Gerät.

(232 Zeichen)

### Beschreibung (erforderlich, bis zu 10 000 Zeichen)

Gerade oder ungerade bringt das klassische Handspiel auf deinen Computer. So lässt sich schnell entscheiden, wer anfängt, wer das Team wählt oder wer das letzte Stück bekommt: Beide Spieler zeigen gleichzeitig ihre Finger, und die Summe entscheidet.

Wähle GERADE oder UNGERADE und zeig 0 bis 5 Finger. Beide Hände schwingen dreimal im Takt und öffnen sich gleichzeitig. Die Finger werden einzeln gezählt: Ist die Summe gerade, gewinnt GERADE die Runde, ist sie ungerade, gewinnt UNGERADE. Wer zuerst 3, 5 oder 7 Runden gewinnt, gewinnt das Spiel.

Wähle den Spielmodus im Hauptmenü. Gegen die CPU spielst du gegen einen zufälligen Gegner oder einen schlauen, der sich merkt, welche Zahlen du gern zeigst, und deinen Zug zu erraten versucht. Im Modus 2 Spieler spielt ihr abwechselnd auf demselben Gerät: Spieler 1 wählt zuerst, dann Spieler 2, und keine Wahl ist zu sehen, bevor sich die Hände öffnen.

Gezeichnete Hände, animiertes Zählen, Soundeffekte und Konfetti, wenn du gewinnst. Die Statistik speichert deine Runden, Spiele und deine längste Siegesserie gegen die CPU. Spiel mit Maus oder Tastatur und kehr jederzeit ins Hauptmenü zurück. Das Spiel ist in 12 Sprachen verfügbar.

(1186 Zeichen)

### Produktfunktionen (200 Zeichen pro Funktion, maximal 20 — die Store fügt die Aufzählungszeichen automatisch hinzu, füge deine eigenen nicht hinzu)

1. Das klassische Handspiel: Wähle GERADE oder UNGERADE und zeig 0 bis 5 Finger
2. Spiel gegen die CPU oder abwechselnd mit einem Freund auf demselben Gerät
3. Zwei CPU-Gegner: ein zufälliger und ein schlauer, der deine Gewohnheiten lernt
4. Spiele bis 3, 5 oder 7 Runden
5. Hände, die im Takt schwingen, sich gleichzeitig öffnen und jeden Finger zählen
6. Statistik zu Runden, Spielen und deiner längsten Siegesserie
7. Steuerung mit Maus und Tastatur
8. In 12 Sprachen verfügbar

## Italian (it) — Parí o Dispari

### Descrizione breve (consigliata, fino a 1000 caratteri; restare sotto i 270 per una migliore visualizzazione)

Gioca a Parí o Dispari, il classico gioco con le mani. Scegli PARI o DISPARI, mostra da 0 a 5 dita e guarda le due mani aprirsi a ritmo. Gioca contro il computer o a turno con un amico sullo stesso dispositivo.

(210 caratteri)

### Descrizione (obbligatoria, fino a 10.000 caratteri)

Parí o Dispari porta sul tuo computer il classico gioco con le mani. È il modo più veloce per decidere chi comincia, chi sceglie la squadra o chi prende l'ultima fetta: i due giocatori mostrano le dita nello stesso momento e la somma decide chi vince.

Scegli PARI o DISPARI e mostra da 0 a 5 dita. Le due mani oscillano tre volte a ritmo e si aprono insieme. Le dita vengono contate una per una: se la somma è pari vince PARI, se è dispari vince DISPARI. Chi vince per primo 3, 5 o 7 round vince la partita.

Scegli la modalità di gioco nel menu principale. Contro la CPU puoi affrontare un avversario casuale o uno furbo, che ricorda i numeri che ti piace mostrare e cerca di anticipare la tua mossa. Nella modalità 2 Giocatori tu e un amico giocate a turno sullo stesso dispositivo: il giocatore 1 sceglie per primo, poi il giocatore 2, e nessuna scelta si vede prima che le mani si aprano.

Mani disegnate, conteggio animato, effetti sonori e coriandoli quando vinci. Le statistiche conservano i round, le partite e la tua serie di vittorie più lunga contro la CPU. Gioca con il mouse o con la tastiera e torna al menu principale in qualsiasi momento. Il gioco è disponibile in 12 lingue.

(1192 caratteri)

### Funzionalità del prodotto (200 caratteri per funzionalità, massimo 20 — lo Store aggiunge i punti elenco automaticamente, non aggiungere i tuoi)

1. Il classico gioco con le mani: scegli PARI o DISPARI e mostra da 0 a 5 dita
2. Gioca contro la CPU o con un amico, a turno, sullo stesso dispositivo
3. Due avversari CPU: uno casuale e uno furbo che impara le tue abitudini
4. Partite a 3, 5 o 7 round
5. Mani che oscillano a ritmo, si aprono insieme e contano ogni dito
6. Statistiche di round, partite e della tua serie di vittorie più lunga
7. Controlli con mouse e tastiera
8. Disponibile in 12 lingue

## Dutch (nl) — Even of oneven

### Korte beschrijving (aanbevolen, tot 1000 tekens; blijf onder 270 voor de beste weergave)

Speel Even of oneven, het klassieke handspel. Kies EVEN of ONEVEN, laat 0 tot 5 vingers zien en kijk hoe beide handen op het ritme opengaan. Speel tegen de computer of om de beurt met een vriend op hetzelfde apparaat.

(217 tekens)

### Beschrijving (verplicht, tot 10.000 tekens)

Even of oneven brengt het klassieke handspel naar je computer. Het is de snelle manier om te beslissen wie begint, wie het team kiest of wie het laatste stuk krijgt: beide spelers laten tegelijk hun vingers zien en de som bepaalt wie wint.

Kies EVEN of ONEVEN en laat 0 tot 5 vingers zien. Beide handen zwaaien drie keer op het ritme en gaan tegelijk open. De vingers worden één voor één geteld: is de som even, dan wint EVEN de ronde, is ze oneven, dan wint ONEVEN. Wie als eerste 3, 5 of 7 rondes wint, wint de wedstrijd.

Kies de spelmodus in het hoofdmenu. Tegen de CPU speel je tegen een willekeurige tegenstander of een slimme, die onthoudt welke getallen je graag laat zien en je zet probeert te raden. In de modus 2 Spelers spelen jij en een vriend om de beurt op hetzelfde apparaat: speler 1 kiest eerst, daarna speler 2, en geen enkele keuze is te zien voordat de handen opengaan.

Getekende handen, geanimeerd tellen, geluidseffecten en confetti als je wint. De statistieken houden je rondes, wedstrijden en langste winstreeks tegen de CPU bij. Speel met de muis of het toetsenbord en ga op elk moment terug naar het hoofdmenu. Het spel is beschikbaar in 12 talen.

(1176 tekens)

### Productkenmerken (200 tekens per kenmerk, maximaal 20 — de Store voegt de opsommingstekens automatisch toe, voeg ze niet zelf toe)

1. Het klassieke handspel: kies EVEN of ONEVEN en laat 0 tot 5 vingers zien
2. Speel tegen de CPU of om de beurt met een vriend op hetzelfde apparaat
3. Twee CPU-tegenstanders: een willekeurige en een slimme die je gewoontes leert
4. Wedstrijden tot 3, 5 of 7 rondes
5. Handen die op het ritme zwaaien, tegelijk opengaan en elke vinger tellen
6. Statistieken van rondes, wedstrijden en je langste winstreeks
7. Besturing met muis en toetsenbord
8. Beschikbaar in 12 talen

## Romanian (ro) — Par sau impar

### Descriere scurtă (recomandat, până la 1000 de caractere; sub 270 pentru o afișare optimă)

Joacă Par sau impar, clasicul joc cu mâinile. Alege PAR sau IMPAR, arată de la 0 la 5 degete și privește cum se deschid ambele mâini în ritm. Joacă împotriva computerului sau pe rând cu un prieten, pe același dispozitiv.

(220 caractere)

### Descriere (obligatoriu, până la 10.000 de caractere)

Par sau impar aduce pe computerul tău clasicul joc cu mâinile. Este cea mai rapidă cale de a decide cine începe, cine alege echipa sau cine ia ultima felie: ambii jucători arată degetele în același timp, iar suma decide câștigătorul.

Alege PAR sau IMPAR și arată de la 0 la 5 degete. Cele două mâini se leagănă de trei ori în ritm și se deschid împreună. Degetele sunt numărate unul câte unul: dacă suma este pară, câștigă PAR, iar dacă este impară, câștigă IMPAR. Cine câștigă primul 3, 5 sau 7 runde câștigă meciul.

Alege modul de joc din meniul principal. Împotriva CPU-ului poți juca cu un adversar aleatoriu sau cu unul isteț, care ține minte ce numere îți place să arăți și încearcă să-ți ghicească mutarea. În modul 2 Jucători, tu și un prieten jucați pe rând pe același dispozitiv: jucătorul 1 alege primul, apoi jucătorul 2, iar nicio alegere nu se vede până nu se deschid mâinile.

Mâini desenate, numărătoare animată, efecte sonore și confetti când câștigi. Statisticile păstrează rundele, meciurile și cea mai lungă serie de victorii împotriva CPU-ului. Joacă cu mouse-ul sau cu tastatura și revino oricând la meniul principal. Jocul este disponibil în 12 limbi.

(1176 caractere)

### Caracteristicile produsului (200 de caractere pe caracteristică, maximum 20 — Store adaugă automat marcajele, nu le adăuga pe ale tale)

1. Clasicul joc cu mâinile: alege PAR sau IMPAR și arată de la 0 la 5 degete
2. Joacă împotriva CPU-ului sau pe rând cu un prieten, pe același dispozitiv
3. Doi adversari CPU: unul aleatoriu și unul isteț, care îți învață obiceiurile
4. Meciuri până la 3, 5 sau 7 runde
5. Mâini care se leagănă în ritm, se deschid împreună și numără fiecare deget
6. Statistici pentru runde, meciuri și cea mai lungă serie de victorii
7. Control cu mouse-ul și tastatura
8. Disponibil în 12 limbi

## Swedish (sv) — Udda eller jämnt

### Kort beskrivning (rekommenderas, upp till 1 000 tecken; håll under 270 för bästa visning)

Spela Udda eller jämnt, det klassiska handspelet. Välj JÄMNT eller UDDA, visa 0 till 5 fingrar och se båda händerna öppnas i takt. Spela mot datorn eller turas om med en vän på samma enhet.

(189 tecken)

### Beskrivning (obligatorisk, upp till 10 000 tecken)

Udda eller jämnt tar det klassiska handspelet till din dator. Det är det snabba sättet att avgöra vem som börjar, vem som väljer lag eller vem som får sista biten: båda spelarna visar fingrar samtidigt och summan avgör vem som vinner.

Välj JÄMNT eller UDDA och visa 0 till 5 fingrar. Båda händerna svänger tre gånger i takt och öppnas samtidigt. Fingrarna räknas ett i taget: är summan jämn vinner JÄMNT rundan, är den udda vinner UDDA. Den som först vinner 3, 5 eller 7 rundor vinner matchen.

Välj spelläge i huvudmenyn. Mot datorn kan du möta en slumpmässig motståndare eller en smart som minns vilka tal du gärna visar och försöker gissa ditt drag. I läget 2 Spelare turas du och en vän om på samma enhet: spelare 1 väljer först, sedan spelare 2, och inget val syns förrän händerna öppnas.

Tecknade händer, animerad räkning, ljudeffekter och konfetti när du vinner. Statistiken sparar dina rundor, matcher och din längsta vinstsvit mot datorn. Spela med mus eller tangentbord och gå tillbaka till huvudmenyn när du vill. Spelet finns på 12 språk.

(1052 tecken)

### Produktfunktioner (200 tecken per funktion, högst 20 — Store lägger till punkter automatiskt, lägg inte till egna)

1. Det klassiska handspelet: välj JÄMNT eller UDDA och visa 0 till 5 fingrar
2. Spela mot datorn eller turas om med en vän på samma enhet
3. Två datormotståndare: en slumpmässig och en smart som lär sig dina vanor
4. Matcher till 3, 5 eller 7 rundor
5. Händer som svänger i takt, öppnas samtidigt och räknar varje finger
6. Statistik över rundor, matcher och din längsta vinstsvit
7. Styrning med mus och tangentbord
8. Finns på 12 språk

## Norwegian (nb) — Partall eller oddetall

### Kort beskrivelse (anbefalt, opptil 1000 tegn; hold deg under 270 for best visning)

Spill Partall eller oddetall, det klassiske håndspillet. Velg PARTALL eller ODDETALL, vis 0 til 5 fingre og se begge hendene åpne seg i takt. Spill mot datamaskinen eller bytt på med en venn på samme enhet.

(206 tegn)

### Beskrivelse (påkrevd, opptil 10 000 tegn)

Partall eller oddetall bringer det klassiske håndspillet til datamaskinen din. Det er den raske måten å avgjøre hvem som begynner, hvem som velger lag eller hvem som får det siste stykket: begge spillerne viser fingre samtidig, og summen avgjør hvem som vinner.

Velg PARTALL eller ODDETALL og vis 0 til 5 fingre. Begge hendene svinger tre ganger i takt og åpner seg samtidig. Fingrene telles én etter én: er summen et partall, vinner PARTALL runden, er den et oddetall, vinner ODDETALL. Den som først vinner 3, 5 eller 7 runder, vinner kampen.

Velg spillmodus i hovedmenyen. Mot CPU-en kan du møte en tilfeldig motstander eller en lur en, som husker hvilke tall du liker å vise og prøver å gjette trekket ditt. I modusen 2 Spillere bytter du og en venn på på samme enhet: spiller 1 velger først, deretter spiller 2, og ingen valg vises før hendene åpner seg.

Tegnede hender, animert telling, lydeffekter og konfetti når du vinner. Statistikken tar vare på rundene, kampene og den lengste seiersrekken din mot CPU-en. Spill med mus eller tastatur, og gå tilbake til hovedmenyen når som helst. Spillet er tilgjengelig på 12 språk.

(1131 tegn)

### Produktfunksjoner (200 tegn per funksjon, maks 20 — Store legger til punkttegn automatisk, ikke legg til dine egne)

1. Det klassiske håndspillet: velg PARTALL eller ODDETALL og vis 0 til 5 fingre
2. Spill mot CPU-en eller bytt på med en venn på samme enhet
3. To CPU-motstandere: en tilfeldig og en lur som lærer vanene dine
4. Kamper til 3, 5 eller 7 runder
5. Hender som svinger i takt, åpner seg samtidig og teller hver finger
6. Statistikk over runder, kamper og din lengste seiersrekke
7. Styring med mus og tastatur
8. Tilgjengelig på 12 språk

## Polish (pl) — Parzyste czy nieparzyste

### Krótki opis (zalecany, do 1000 znaków; dla najlepszego wyświetlania poniżej 270)

Zagraj w Parzyste czy nieparzyste, klasyczną grę na palce. Wybierz PARZYSTE lub NIEPARZYSTE, pokaż od 0 do 5 palców i patrz, jak obie dłonie otwierają się w rytm. Graj z komputerem albo na zmianę z przyjacielem na jednym urządzeniu.

(232 znaków)

### Opis (wymagany, do 10 000 znaków)

Parzyste czy nieparzyste przenosi klasyczną grę na palce na twój komputer. To szybki sposób, żeby zdecydować, kto zaczyna, kto wybiera drużynę albo kto dostaje ostatni kawałek: obaj gracze pokazują palce w tej samej chwili, a suma decyduje o zwycięzcy.

Wybierz PARZYSTE lub NIEPARZYSTE i pokaż od 0 do 5 palców. Obie dłonie trzy razy kołyszą się w rytm i otwierają się jednocześnie. Palce są liczone jeden po drugim: jeśli suma jest parzysta, rundę wygrywa PARZYSTE, a jeśli nieparzysta, wygrywa NIEPARZYSTE. Kto pierwszy wygra 3, 5 lub 7 rund, wygrywa mecz.

Wybierz tryb gry w menu głównym. Z komputerem możesz zmierzyć się z losowym przeciwnikiem albo ze sprytnym, który zapamiętuje, jakie liczby lubisz pokazywać, i próbuje odgadnąć twój ruch. W trybie 2 Graczy ty i przyjaciel gracie na zmianę na jednym urządzeniu: gracz 1 wybiera pierwszy, potem gracz 2, a żaden wybór nie jest widoczny, dopóki dłonie się nie otworzą.

Rysowane dłonie, animowane liczenie, efekty dźwiękowe i konfetti, kiedy wygrywasz. Statystyki zapisują twoje rundy, mecze i najdłuższą serię zwycięstw z komputerem. Graj myszą lub klawiaturą i w każdej chwili wróć do menu głównego. Gra jest dostępna w 12 językach.

(1192 znaków)

### Funkcje produktu (200 znaków na funkcję, maksymalnie 20 — Store dodaje punktory automatycznie, nie dodawaj własnych)

1. Klasyczna gra na palce: wybierz PARZYSTE lub NIEPARZYSTE i pokaż od 0 do 5 palców
2. Graj z komputerem albo na zmianę z przyjacielem na jednym urządzeniu
3. Dwóch przeciwników komputerowych: losowy i sprytny, który uczy się twoich nawyków
4. Mecze do 3, 5 lub 7 rund
5. Dłonie, które kołyszą się w rytm, otwierają się razem i liczą każdy palec
6. Statystyki rund, meczów i najdłuższej serii zwycięstw
7. Sterowanie myszą i klawiaturą
8. Dostępna w 12 językach

## Turkish (tr) — Tek mi çift mi?

### Kısa açıklama (önerilir, en fazla 1000 karakter; en iyi görünüm için 270'in altında tutun)

Klasik el oyunu Tek mi çift mi? ile oyna. TEK ya da ÇİFT seç, 0 ile 5 arası parmak göster ve iki elin ritimle açılışını izle. Bilgisayara karşı oyna ya da aynı cihazda bir arkadaşınla sırayla oyna.

(197 karakter)

### Açıklama (zorunlu, en fazla 10.000 karakter)

Tek mi çift mi? klasik el oyununu bilgisayarına getiriyor. Kimin başlayacağına, takımı kimin seçeceğine ya da son dilimi kimin alacağına karar vermenin en hızlı yolu: iki oyuncu aynı anda parmaklarını gösterir ve toplam kazananı belirler.

TEK ya da ÇİFT seç ve 0 ile 5 arası parmak göster. İki el ritimle üç kez sallanır ve birlikte açılır. Parmaklar tek tek sayılır: toplam çiftse turu ÇİFT, tekse TEK kazanır. 3, 5 ya da 7 turu ilk kazanan maçı kazanır.

Oyun modunu ana menüden seç. CPU'ya karşı rastgele bir rakiple ya da göstermeyi sevdiğin sayıları hatırlayıp hamleni tahmin etmeye çalışan akıllı bir rakiple oynayabilirsin. 2 Oyuncu modunda sen ve bir arkadaşın aynı cihazda sırayla oynarsınız: önce 1. oyuncu seçer, sonra 2. oyuncu, ve eller açılana kadar hiçbir seçim görünmez.

Çizilmiş eller, animasyonlu sayım, ses efektleri ve kazandığında konfeti. İstatistikler CPU'ya karşı turlarını, maçlarını ve en uzun galibiyet serini kaydeder. Fare ya da klavyeyle oyna ve istediğin an ana menüye dön. Oyun 12 dilde mevcut.

(1028 karakter)

### Ürün özellikleri (özellik başına 200 karakter, en fazla 20 — Store madde işaretlerini otomatik ekler, kendiniz eklemeyin)

1. Klasik el oyunu: TEK ya da ÇİFT seç ve 0 ile 5 arası parmak göster
2. CPU'ya karşı ya da aynı cihazda bir arkadaşınla sırayla oyna
3. İki CPU rakibi: rastgele olan ve alışkanlıklarını öğrenen akıllı olan
4. 3, 5 ya da 7 turluk maçlar
5. Ritimle sallanan, birlikte açılan ve her parmağı sayan eller
6. Turlar, maçlar ve en uzun galibiyet serisi için istatistikler
7. Fare ve klavye kontrolleri
8. 12 dilde mevcut
