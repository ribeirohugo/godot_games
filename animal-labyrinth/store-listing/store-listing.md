# Microsoft Store listing — Animal Labyrinth

Written to Microsoft's Store listing rules (character limits, no HTML/code/URLs in the description, no manually-added bullets in Product features): https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/add-and-edit-store-listing-info (same field rules apply to MSIX apps).

The game supports `en`, `pt`, `es`, `fr`, `de`, `it`, `ro` and `pl` (see `scripts/strings.gd`), chosen from the settings (gear) menu, and `msix.env` declares the same base language codes (no regions: `pt`, not `pt-pt`), so a listing is provided below for each — add each under its matching language in Partner Center.

## Product name

Unlike this developer's other games, the name **is** localized, matching the in-game title (`game_name` in `scripts/strings.gd`). All eight names are reserved in Partner Center (Product management > Product identity); the manifest's `DISPLAY_NAME` stays "Animal Labyrinth".

| Language | Name |
| --- | --- |
| English (en) | Animal Labyrinth |
| Portuguese (pt) | Labirinto Animal |
| Spanish (es) | Laberinto Animal |
| French (fr) | Labyrinthe Animal |
| German (de) | Tierlabyrinth |
| Italian (it) | Labirinto Animale |
| Romanian (ro) | Labirint Animal |
| Polish (pl) | Zwierzęcy Labirynt |

## Images

Rendered in-engine from the game's own drawing code (board, tiles, island and animals) and font — no external image editor involved. The box, poster and hero art come from `scripts/store_art.gd`: play the game with `-- --render-store` to make them again for every language.

The English (en) set sits at the top of `store-listing/`. Every other language has its own folder named after its code in `msix.env` (`pt/`, `es/`, `fr/`, `de/`, `it/`, `ro/`, `pl/`), with the same three images carrying that language's title, tagline and badge.

| File | Where it goes |
| --- | --- |
| `AppTile.300x300.png`, `AppTile.150x150.png`, `AppTile.71x71.png` | Store logos: 1:1 app tile icon (optional), made from `icon.png`; shared by every language |
| `BoxArt.1080x1080.png`, `BoxArt.2160x2160.png` | Store display images: 1:1 box art |
| `PosterArt.720x1080.png`, `PosterArt.1440x2160.png` | Store display images: 9:16 poster art |
| `HeroArt.1920x1080.png`, `HeroArt.3840x2160.png` | Store display images: 16:9 Super hero art |
| `screenshot.png` | Desktop screenshot: mid-round, several tiles placed, the monkey waiting at the start |
| `screenshot-2.png` | Desktop screenshot: the title screen, with the animal and difficulty pickers |
| `screenshot-3.png` | Desktop screenshot: the round-win overlay, animal cheering on its island |

The screenshots show the game in Portuguese and sit only at the top level, so the same three are used for every language.

## English (en) — Animal Labyrinth

### Short description (recommended, up to 1,000 characters; keep under 270 for best display)

Place tiles in the sea to build a path to your animal's food, then watch it walk on its own, always turning left. Pick Easy, Medium or Hard and try to beat your best score.

(172 characters)

### Description (required, up to 10,000 characters)

Animal Labyrinth is a path-building puzzle: each round, you place land tiles on a 4x4 board to connect the starting point to an island where food is waiting. When the tiles run out, your chosen animal walks on its own, always turning left when it can, until it reaches its food — or falls into the water, or wanders back to the start empty-handed.

Choose the monkey, the horse, the cat or the dog, each with its own food waiting: bananas, carrots, fish or a bone.

Choose the difficulty too. Easy uses only simple tiles — straights, bends and dead ends — and gives you more tiles per round to fit them in. Medium adds crossings, a loop and stairs. Hard adds zigzags and a tricky tile whose two patches of land sit too far apart to walk between, with fewer tiles per round and a longer path to the island.

Each tile is worth different points depending on its shape, and reaching the island earns a bonus that grows every round, and your best score is saved. The island and the sea are drawn in isometric view by the game itself, with waves, sand and a palm tree that change every round.

Play with the mouse: pick your animal and difficulty, place the tiles, and see whether your animal makes it safely across. Play in English, Portuguese, Spanish, French, German, Italian, Romanian or Polish, and turn the sound on or off from the settings.

(1342 characters)

### Product features (200 characters per feature, 20 max — Store adds bullets automatically, do not add your own)

1. Place tiles on a 4x4 board to build a path to your animal's food
2. Choose the monkey, horse, cat or dog — each with its own food waiting
3. Three difficulty levels, each with its own set of tiles and pace
4. The animal walks on its own, always turning left when it can, until it arrives or falls in the water
5. Points for every tile and a bonus for every round cleared, with your best score saved
6. Islands and sea drawn in isometric view by the game itself, no images
7. Play in English, Portuguese, Spanish, French, German, Italian, Romanian or Polish

## Portuguese (pt) — Labirinto Animal

### Descrição curta (recomendado, até 1000 carateres; manter abaixo de 270 para melhor exibição)

Coloca peças no mar para abrires um caminho até à comida do teu animal, que depois anda sozinho e vira sempre para a esquerda. Escolhe Fácil, Médio ou Difícil, e tenta bater o teu recorde.

(188 carateres)

### Descrição (obrigatório, até 10 000 carateres)

Labirinto Animal é um puzzle de construir caminhos: em cada ronda, colocas peças de terreno num tabuleiro 4x4 para ligares o ponto de partida a uma ilha com comida à espera. Quando as peças acabam, o animal escolhido anda sozinho, virando sempre que pode para a esquerda, até chegar à comida — ou até cair à água ou voltar ao início de mãos a abanar.

Escolhe entre o macaco, o cavalo, o gato ou o cão, cada um com a sua comida à espera: bananas, cenouras, peixe ou um osso.

Escolhe também a dificuldade. Fácil usa só peças simples — retas, curvas e becos sem saída — e dá mais peças por ronda para as encaixares. Médio junta cruzamentos, uma argola e escadas. Difícil acrescenta ziguezagues e uma peça traiçoeira cujos dois pedaços de terra ficam longe demais um do outro para se andar entre eles, com menos peças por ronda e um caminho mais comprido até à ilha.

Cada peça vale pontos diferentes consoante a sua forma, e chegar à ilha dá um bónus que cresce a cada ronda, além do teu recorde guardado. A ilha e o mar são desenhados em isométrico diretamente pelo jogo, com ondas, areia e uma palmeira que mudam a cada ronda.

Joga com o rato: escolhe o animal e a dificuldade, coloca as peças, e vê se o teu animal chega a bom porto. Joga em inglês, português, espanhol, francês, alemão, italiano, romeno ou polaco, e liga ou desliga o som nas definições.

(1358 carateres)

### Funcionalidades do produto (200 carateres por funcionalidade, 20 no máximo — a Store adiciona os marcadores automaticamente, não acrescentes os teus)

1. Coloca peças num tabuleiro 4x4 para abrires caminho até à comida do teu animal
2. Escolhe entre macaco, cavalo, gato ou cão — cada um com a sua comida à espera
3. Três níveis de dificuldade, cada um com o seu conjunto de peças e o seu ritmo
4. O animal anda sozinho, virando sempre para a esquerda quando pode, até chegar ou cair à água
5. Pontuação por peça e bónus a cada ronda concluída, com recorde guardado
6. Ilhas e mar desenhados em isométrico diretamente pelo jogo, sem imagens
7. Joga em inglês, português, espanhol, francês, alemão, italiano, romeno ou polaco

## Spanish (es) — Laberinto Animal

### Descripción breve (recomendado, hasta 1000 caracteres; mantener por debajo de 270 para una mejor visualización)

Coloca piezas en el mar para abrir un camino hasta la comida de tu animal, que después camina solo y siempre gira a la izquierda. Elige Fácil, Medio o Difícil, e intenta superar tu récord.

(188 caracteres)

### Descripción (obligatorio, hasta 10 000 caracteres)

Laberinto Animal es un puzle de construir caminos: en cada ronda, colocas piezas de terreno en un tablero de 4x4 para unir el punto de partida con una isla donde espera la comida. Cuando se acaban las piezas, el animal elegido camina solo, girando a la izquierda siempre que puede, hasta llegar a la comida — o hasta caer al agua o volver al principio con las manos vacías.

Elige entre el mono, el caballo, el gato o el perro, cada uno con su comida esperando: plátanos, zanahorias, pescado o un hueso.

Elige también la dificultad. Fácil usa solo piezas sencillas — rectas, curvas y callejones sin salida — y da más piezas por ronda para encajarlas. Medio añade cruces, un bucle y escaleras. Difícil suma zigzags y una pieza traicionera cuyos dos trozos de tierra quedan demasiado lejos para caminar entre ellos, con menos piezas por ronda y un camino más largo hasta la isla.

Cada pieza vale puntos distintos según su forma, y llegar a la isla da una bonificación que crece en cada ronda, además de guardar tu récord. La isla y el mar los dibuja el propio juego en vista isométrica, con olas, arena y una palmera que cambian en cada ronda.

Juega con el ratón: elige el animal y la dificultad, coloca las piezas, y comprueba si tu animal llega a buen puerto. Juega en inglés, portugués, español, francés, alemán, italiano, rumano o polaco, y activa o desactiva el sonido en los ajustes.

(1390 caracteres)

### Características del producto (200 caracteres por característica, 20 como máximo — la Store añade las viñetas automáticamente, no incluyas las tuyas)

1. Coloca piezas en un tablero de 4x4 para abrir un camino hasta la comida de tu animal
2. Elige entre mono, caballo, gato o perro — cada uno con su comida esperando
3. Tres niveles de dificultad, cada uno con su propio conjunto de piezas y su ritmo
4. El animal camina solo, girando siempre a la izquierda cuando puede, hasta llegar o caer al agua
5. Puntos por cada pieza y bonificación por cada ronda superada, con tu récord guardado
6. Islas y mar dibujados en vista isométrica por el propio juego, sin imágenes
7. Juega en inglés, portugués, español, francés, alemán, italiano, rumano o polaco

## French (fr) — Labyrinthe Animal

### Description courte (recommandé, jusqu'à 1000 caractères ; rester sous 270 pour un meilleur affichage)

Posez des pièces dans la mer pour tracer un chemin jusqu'à la nourriture de votre animal, qui avance ensuite seul en tournant toujours à gauche. Choisissez Facile, Moyen ou Difficile, et tentez de battre votre record.

(217 caractères)

### Description (obligatoire, jusqu'à 10 000 caractères)

Labyrinthe Animal est un puzzle de construction de chemins : à chaque manche, vous posez des pièces de terrain sur un plateau de 4x4 pour relier le point de départ à une île où la nourriture attend. Quand les pièces sont épuisées, l'animal choisi avance seul, en tournant à gauche dès qu'il le peut, jusqu'à atteindre sa nourriture — ou jusqu'à tomber à l'eau ou revenir au départ bredouille.

Choisissez le singe, le cheval, le chat ou le chien, chacun avec sa nourriture qui l'attend : des bananes, des carottes, du poisson ou un os.

Choisissez aussi la difficulté. Facile n'utilise que des pièces simples — lignes droites, virages et culs-de-sac — et donne plus de pièces par manche pour les placer. Moyen ajoute des croisements, une boucle et des escaliers. Difficile ajoute des zigzags et une pièce piège dont les deux morceaux de terre sont trop éloignés pour passer de l'un à l'autre, avec moins de pièces par manche et un chemin plus long jusqu'à l'île.

Chaque pièce rapporte des points selon sa forme, et atteindre l'île donne un bonus qui augmente à chaque manche, et votre record est sauvegardé. L'île et la mer sont dessinées en vue isométrique par le jeu lui-même, avec des vagues, du sable et un palmier qui changent à chaque manche.

Jouez à la souris : choisissez l'animal et la difficulté, posez les pièces, et voyez si votre animal arrive à bon port. Jouez en anglais, portugais, espagnol, français, allemand, italien, roumain ou polonais, et activez ou coupez le son dans les paramètres.

(1508 caractères)

### Fonctionnalités du produit (200 caractères par fonctionnalité, 20 maximum — la Store ajoute les puces automatiquement, n'ajoutez pas les vôtres)

1. Posez des pièces sur un plateau de 4x4 pour tracer un chemin jusqu'à la nourriture de votre animal
2. Choisissez le singe, le cheval, le chat ou le chien — chacun avec sa nourriture qui l'attend
3. Trois niveaux de difficulté, chacun avec ses propres pièces et son rythme
4. L'animal avance seul, en tournant toujours à gauche quand il peut, jusqu'à arriver ou tomber à l'eau
5. Des points pour chaque pièce et un bonus pour chaque manche réussie, avec votre record sauvegardé
6. Îles et mer dessinées en vue isométrique par le jeu lui-même, sans images
7. Jouez en anglais, portugais, espagnol, français, allemand, italien, roumain ou polonais

## German (de) — Tierlabyrinth

### Kurzbeschreibung (empfohlen, bis zu 1000 Zeichen; für die beste Darstellung unter 270 bleiben)

Lege Teile ins Meer, um deinem Tier einen Weg zu seinem Futter zu bauen — danach läuft es von selbst und biegt immer links ab. Wähle Leicht, Mittel oder Schwer und versuche, deinen Bestwert zu schlagen.

(202 Zeichen)

### Beschreibung (erforderlich, bis zu 10 000 Zeichen)

Tierlabyrinth ist ein Rätsel, in dem du Wege baust: In jeder Runde legst du Landteile auf ein 4x4-Spielfeld, um den Startpunkt mit einer Insel zu verbinden, auf der Futter wartet. Sind die Teile verbraucht, läuft dein gewähltes Tier von selbst los und biegt links ab, wann immer es kann — bis es sein Futter erreicht, ins Wasser fällt oder mit leeren Händen zum Start zurückkehrt.

Wähle den Affen, das Pferd, die Katze oder den Hund, jedes Tier mit seinem eigenen Futter: Bananen, Karotten, Fisch oder ein Knochen.

Wähle auch den Schwierigkeitsgrad. Leicht verwendet nur einfache Teile — Geraden, Kurven und Sackgassen — und gibt dir mehr Teile pro Runde. Mittel bringt Kreuzungen, eine Schleife und Treppen dazu. Schwer ergänzt Zickzacks und ein kniffliges Teil, dessen zwei Landstücke zu weit auseinanderliegen, um von einem zum anderen zu gehen, mit weniger Teilen pro Runde und einem längeren Weg zur Insel.

Jedes Teil bringt je nach Form unterschiedlich viele Punkte, das Erreichen der Insel gibt einen Bonus, der mit jeder Runde wächst, und dein Bestwert wird gespeichert. Insel und Meer zeichnet das Spiel selbst in isometrischer Ansicht, mit Wellen, Sand und einer Palme, die sich jede Runde ändern.

Gespielt wird mit der Maus: Wähle Tier und Schwierigkeitsgrad, lege die Teile und sieh zu, ob dein Tier sicher ankommt. Spiele auf Englisch, Portugiesisch, Spanisch, Französisch, Deutsch, Italienisch, Rumänisch oder Polnisch, und schalte den Ton in den Einstellungen ein oder aus.

(1492 Zeichen)

### Produktfunktionen (200 Zeichen pro Funktion, maximal 20 — die Store fügt die Aufzählungszeichen automatisch hinzu, füge deine eigenen nicht hinzu)

1. Lege Teile auf ein 4x4-Spielfeld, um deinem Tier einen Weg zu seinem Futter zu bauen
2. Wähle Affe, Pferd, Katze oder Hund — jedes Tier mit seinem eigenen Futter
3. Drei Schwierigkeitsgrade, jeder mit eigenen Teilen und eigenem Tempo
4. Das Tier läuft von selbst und biegt immer links ab, wenn es kann, bis es ankommt oder ins Wasser fällt
5. Punkte für jedes Teil und ein Bonus für jede geschaffte Runde, mit gespeichertem Bestwert
6. Inseln und Meer zeichnet das Spiel selbst in isometrischer Ansicht, ganz ohne Bilder
7. Spiele auf Englisch, Portugiesisch, Spanisch, Französisch, Deutsch, Italienisch, Rumänisch oder Polnisch

## Italian (it) — Labirinto Animale

### Descrizione breve (consigliato, fino a 1000 caratteri; resta sotto i 270 per una visualizzazione migliore)

Metti i pezzi nel mare per costruire un percorso fino al cibo del tuo animale, che poi cammina da solo girando sempre a sinistra. Scegli Facile, Medio o Difficile e prova a battere il tuo record.

(195 caratteri)

### Descrizione (obbligatorio, fino a 10.000 caratteri)

Labirinto Animale è un puzzle in cui costruisci percorsi: a ogni turno metti pezzi di terra su una plancia 4x4 per collegare il punto di partenza a un'isola dove il cibo è in attesa. Quando i pezzi finiscono, l'animale scelto cammina da solo, girando a sinistra ogni volta che può, finché non raggiunge il cibo — oppure cade in acqua o torna alla partenza a mani vuote.

Scegli la scimmia, il cavallo, il gatto o il cane, ognuno con il suo cibo che lo aspetta: banane, carote, pesce o un osso.

Scegli anche la difficoltà. Facile usa solo pezzi semplici — rettilinei, curve e vicoli ciechi — e ti dà più pezzi a ogni turno per sistemarli. Medio aggiunge incroci, un anello e delle scale. Difficile aggiunge zigzag e un pezzo insidioso i cui due tratti di terra sono troppo lontani per passare dall'uno all'altro, con meno pezzi a ogni turno e un percorso più lungo fino all'isola.

Ogni pezzo vale punti diversi in base alla sua forma, raggiungere l'isola dà un bonus che cresce a ogni turno e il tuo record viene salvato. L'isola e il mare sono disegnati in vista isometrica dal gioco stesso, con onde, sabbia e una palma che cambiano a ogni turno.

Si gioca con il mouse: scegli l'animale e la difficoltà, metti i pezzi e guarda se il tuo animale arriva sano e salvo. Gioca in inglese, portoghese, spagnolo, francese, tedesco, italiano, rumeno o polacco, e attiva o disattiva il suono nelle impostazioni.

(1406 caratteri)

### Caratteristiche del prodotto (200 caratteri per caratteristica, 20 al massimo — lo Store aggiunge i punti elenco automaticamente, non aggiungere i tuoi)

1. Metti i pezzi su una plancia 4x4 per costruire un percorso fino al cibo del tuo animale
2. Scegli scimmia, cavallo, gatto o cane — ognuno con il suo cibo che lo aspetta
3. Tre livelli di difficoltà, ognuno con i suoi pezzi e il suo ritmo
4. L'animale cammina da solo, girando sempre a sinistra quando può, finché arriva o cade in acqua
5. Punti per ogni pezzo e un bonus per ogni turno superato, con il tuo record salvato
6. Isole e mare disegnati in vista isometrica dal gioco stesso, senza immagini
7. Gioca in inglese, portoghese, spagnolo, francese, tedesco, italiano, rumeno o polacco

## Romanian (ro) — Labirint Animal

### Descriere scurtă (recomandat, până la 1.000 de caractere; sub 270 pentru o afișare optimă)

Pune piese în mare ca să construiești un drum până la mâncarea animalului tău, care apoi merge singur și o ia mereu la stânga. Alege Ușor, Mediu sau Greu și încearcă să-ți bați recordul.

(186 de caractere)

### Descriere (obligatoriu, până la 10.000 de caractere)

Labirint Animal este un puzzle în care construiești drumuri: în fiecare rundă pui piese de uscat pe o tablă de 4x4 ca să legi punctul de plecare de o insulă unde te așteaptă mâncarea. Când se termină piesele, animalul ales merge singur, luând-o la stânga ori de câte ori poate, până ajunge la mâncare — sau cade în apă, sau se întoarce la start cu mâna goală.

Alege maimuța, calul, pisica sau câinele, fiecare cu mâncarea lui care îl așteaptă: banane, morcovi, pește sau un os.

Alege și dificultatea. Ușor folosește doar piese simple — drepte, curbe și fundături — și îți dă mai multe piese pe rundă ca să le potrivești. Mediu adaugă intersecții, o buclă și scări. Greu adaugă zigzaguri și o piesă înșelătoare ale cărei două bucăți de uscat sunt prea departe una de alta ca să treci dintr-una în alta, cu mai puține piese pe rundă și un drum mai lung până la insulă.

Fiecare piesă valorează un număr diferit de puncte după forma ei, ajungerea pe insulă aduce un bonus care crește cu fiecare rundă, iar recordul tău este salvat. Insula și marea sunt desenate în vedere izometrică chiar de joc, cu valuri, nisip și un palmier care se schimbă în fiecare rundă.

Se joacă cu mouse-ul: alege animalul și dificultatea, pune piesele și vezi dacă animalul tău ajunge cu bine. Joacă în engleză, portugheză, spaniolă, franceză, germană, italiană, română sau poloneză, și pornește sau oprește sunetul din setări.

(1404 de caractere)

### Caracteristici ale produsului (200 de caractere per caracteristică, maximum 20 — Store adaugă automat marcatorii, nu-i adăuga pe ai tăi)

1. Pune piese pe o tablă de 4x4 ca să construiești un drum până la mâncarea animalului tău
2. Alege maimuța, calul, pisica sau câinele — fiecare cu mâncarea lui care îl așteaptă
3. Trei niveluri de dificultate, fiecare cu piesele și ritmul lui
4. Animalul merge singur, luând-o mereu la stânga când poate, până ajunge sau cade în apă
5. Puncte pentru fiecare piesă și un bonus pentru fiecare rundă câștigată, cu recordul salvat
6. Insule și mare desenate în vedere izometrică chiar de joc, fără imagini
7. Joacă în engleză, portugheză, spaniolă, franceză, germană, italiană, română sau poloneză

## Polish (pl) — Zwierzęcy Labirynt

### Krótki opis (zalecany, do 1000 znaków; najlepiej poniżej 270, by dobrze się wyświetlał)

Układaj elementy na morzu, aby zbudować drogę do jedzenia twojego zwierzaka, który potem idzie sam i zawsze skręca w lewo. Wybierz poziom Łatwy, Średni lub Trudny i spróbuj pobić swój rekord.

(191 znaków)

### Opis (wymagany, do 10 000 znaków)

Zwierzęcy Labirynt to łamigłówka o budowaniu dróg: w każdej rundzie układasz elementy lądu na planszy 4x4, aby połączyć punkt startowy z wyspą, na której czeka jedzenie. Gdy elementy się skończą, wybrane zwierzę rusza samo i skręca w lewo, kiedy tylko może, aż dotrze do jedzenia — albo wpadnie do wody, albo wróci na start z pustymi rękami.

Wybierz małpę, konia, kota lub psa — każde zwierzę ma czekające na nie jedzenie: banany, marchewki, rybę albo kość.

Wybierz też poziom trudności. Łatwy używa tylko prostych elementów — prostych odcinków, zakrętów i ślepych zaułków — i daje więcej elementów na rundę. Średni dodaje skrzyżowania, pętlę i schody. Trudny dodaje zygzaki oraz podchwytliwy element, którego dwa kawałki lądu leżą za daleko od siebie, by przejść z jednego na drugi, a do tego mniej elementów na rundę i dłuższą drogę do wyspy.

Każdy element jest wart inną liczbę punktów zależnie od kształtu, dotarcie do wyspy daje premię, która rośnie z każdą rundą, a twój rekord zostaje zapisany. Wyspę i morze rysuje sama gra w widoku izometrycznym, z falami, piaskiem i palmą, które zmieniają się w każdej rundzie.

Grasz myszką: wybierz zwierzę i poziom trudności, ułóż elementy i sprawdź, czy twój zwierzak bezpiecznie dotrze na miejsce. Graj po angielsku, portugalsku, hiszpańsku, francusku, niemiecku, włosku, rumuńsku lub polsku, a dźwięk włączysz lub wyłączysz w ustawieniach.

(1392 znaków)

### Funkcje produktu (200 znaków na funkcję, maksymalnie 20 — Store sam dodaje punktory, nie dodawaj własnych)

1. Układaj elementy na planszy 4x4, aby zbudować drogę do jedzenia twojego zwierzaka
2. Wybierz małpę, konia, kota lub psa — każde zwierzę ma czekające na nie jedzenie
3. Trzy poziomy trudności, każdy z własnym zestawem elementów i tempem
4. Zwierzę idzie samo i zawsze skręca w lewo, gdy może, aż dotrze do celu albo wpadnie do wody
5. Punkty za każdy element i premia za każdą ukończoną rundę, z zapisanym rekordem
6. Wyspy i morze rysowane przez samą grę w widoku izometrycznym, bez obrazków
7. Graj po angielsku, portugalsku, hiszpańsku, francusku, niemiecku, włosku, rumuńsku lub polsku
