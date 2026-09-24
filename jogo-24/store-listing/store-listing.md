# Microsoft Store listing — 24 Game Pro (Jogo do 24 Pro)

Written to Microsoft's Store listing rules (character limits, no HTML/code/URLs in the description, no manually-added bullets in Product features): https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/add-and-edit-store-listing-info (same field rules apply to MSIX apps).

The game itself is translated into 10 languages (see `scripts/strings.gd`), but `msix.env` declares only `en` and `pt` in the package manifest, so the Store listing is provided in those two languages only. Add each under its matching language in Partner Center.

## Product identity

From Partner Center > Product management > Product identity. The first three are in `msix.env`.

| Field | Value |
| --- | --- |
| Package/Identity/Name | `WebPlatinum.Jogodo24Pro` |
| Package/Identity/Publisher | `CN=33F06A6D-7BDD-48EE-AC03-85FC626020AD` |
| Package/Properties/PublisherDisplayName | `Web Platinum` |
| Package Family Name (PFN) | `WebPlatinum.Jogodo24Pro_65qvk9hs8s2gj` |
| Package SID | `S-1-15-2-3120154550-2824893067-321661699-1191861214-149194376-2537591908-3230735839` |
| Store ID | `9NX79GV07Q2T` |
| Store deep link, Web Store URL | Available after the product is live |

## Product name

The name is localized: each listing uses its own name, and the game shows the same name as its title in that language. The manifest's `DISPLAY_NAME` stays "Jogo do 24 Pro" (the dashboard name). "24 Game Pro" must also be reserved in Partner Center for the English listing to use it.

| Listing | Product name |
| --- | --- |
| en | 24 Game Pro |
| pt | Jogo do 24 Pro |

## Images

Rendered in-engine from the game's own drawing code, icon and fonts — no external image editor involved. Run the game with `-- --render-store` (for example `Godot --path jogo-24 -- --render-store`) to make them all again. The App tiles are `icon.png` scaled down. The top level holds the English images; `pt/` holds the Portuguese ones, with "Jogo do 24" on the art and the game running in Portuguese in the screenshots.

| File | Where it goes |
| --- | --- |
| `BoxArt.1080x1080.png`, `BoxArt.2160x2160.png` | Store display images: 1:1 box art |
| `PosterArt.720x1080.png`, `PosterArt.1440x2160.png` | Store display images: 2:3 poster art |
| `HeroArt.1920x1080.png`, `HeroArt.3840x2160.png` | Store display images: 16:9 Super hero art (optional) |
| `AppTile.300x300.png`, `AppTile.150x150.png`, `AppTile.71x71.png` | Store logos: 1:1 app tile icon (optional; top level only, same for both languages) |
| `screenshot.png` | Desktop screenshot: a Classic card on Hard, with √36 and 9/3 disguising two numbers, the first number and × picked |
| `screenshot-2.png` | Desktop screenshot: Double Cards on Medium, the figure-eight card with six numbers |
| `screenshot-3.png` | Desktop screenshot: a Medium card just solved, with confetti and the Next Game button |
| `screenshot-4.png` | Desktop screenshot: the main menu with Double Cards picked and the four difficulty levels |
| `screenshot-5.png` | Desktop screenshot: the Statistics screen, with totals, results by difficulty and recent history |

All screenshots are real gameplay at 2000x1440 (the game's 1000x720 window at twice the size).

## English (en) — 24 Game Pro

### Short description (recommended, up to 1,000 characters; keep under 270 for best display)

A quick math puzzle: combine four numbers with +, −, × and ÷ to make exactly 24. Four difficulty levels, disguised numbers on the hard levels, and the new Double Cards mode with six numbers to use.

(197 characters)

### Description (required, up to 10,000 characters)

24 Game Pro is the classic 24 math card game for Windows. Each round deals a card with four numbers: combine them with addition, subtraction, multiplication and division, in any order, until only one number is left. Reach exactly 24 and you win the round.

Double Cards mode deals a figure-eight card with six numbers, and all six must be used to reach 24. It is a tougher challenge for players who already know the classic cards by heart.

Choose from four difficulty levels, from Easy to Very Hard, shown by the dots in the corners of every card. On Hard and Very Hard some numbers are disguised as square roots or unreduced fractions, so you have to work out their real value first. Every card dealt can be solved, and if you get stuck you can undo any move or view a possible solution.

A round timer and full statistics keep track of your wins, win rate, current and best streak, results for each difficulty and your recent games. Play with the mouse or the keyboard. The game is available in English, Portuguese, Spanish, French, German, Italian, Dutch, Polish and Swedish, with adjustable sound effects and volume. No ads and no in-app purchases.

(1,153 characters)

### Product features (200 characters per feature, 20 max — Store adds bullets automatically, do not add your own)

1. Classic 24 cards: combine four numbers with +, −, × and ÷ to make exactly 24
2. Double Cards mode: a figure-eight card with six numbers, all of them to be used
3. Four difficulty levels, with square roots and fractions disguising numbers on the hard levels
4. Every card can be solved, with Undo and a View Solution button when you are stuck
5. Round timer and statistics: wins, win rate, streaks, results by difficulty and recent games
6. Traditional card design with the numbers, red arms and difficulty dots of the printed game
7. Play in 9 languages, with sound effect and volume settings

## Portuguese (pt) — Jogo do 24 Pro

### Descrição curta (recomendado, até 1000 carateres; manter abaixo de 270 para melhor exibição)

Um puzzle matemático rápido: combina quatro números com +, −, × e ÷ para fazer exatamente 24. Quatro níveis de dificuldade, números disfarçados nos níveis difíceis e o novo modo Cartas Duplas, com seis números para usar.

(220 carateres)

### Descrição (obrigatório, até 10 000 carateres)

Jogo do 24 Pro é o clássico jogo de cartas de matemática do 24 para Windows. Em cada ronda sai uma carta com quatro números: combina-os com adição, subtração, multiplicação e divisão, pela ordem que quiseres, até restar apenas um número. Chega exatamente a 24 e ganhas a ronda.

O modo Cartas Duplas dá-te uma carta em forma de oito com seis números, e tens de usar os seis para chegar a 24. É um desafio mais difícil para quem já conhece as cartas clássicas de cor.

Escolhe entre quatro níveis de dificuldade, do Fácil ao Muito Difícil, indicados pelos pontos nos cantos de cada carta. No Difícil e no Muito Difícil alguns números aparecem disfarçados como raízes quadradas ou frações não simplificadas, por isso tens de descobrir primeiro o seu valor real. Todas as cartas têm solução, e se ficares bloqueado podes desfazer qualquer jogada ou ver uma solução possível.

Um cronómetro e estatísticas completas registam as tuas vitórias, a taxa de vitória, a sequência atual e a melhor, os resultados por dificuldade e os teus jogos recentes. Joga com o rato ou o teclado. O jogo está disponível em português, inglês, espanhol, francês, alemão, italiano, neerlandês, polaco e sueco, com efeitos sonoros e volume ajustáveis. Sem anúncios nem compras na aplicação.

(1263 carateres)

### Funcionalidades do produto (200 carateres por funcionalidade, 20 no máximo — a Store adiciona os marcadores automaticamente, não acrescentes os teus)

1. Cartas clássicas do 24: combina quatro números com +, −, × e ÷ para fazer exatamente 24
2. Modo Cartas Duplas: uma carta em forma de oito com seis números, todos para usar
3. Quatro níveis de dificuldade, com raízes quadradas e frações a disfarçar números nos níveis difíceis
4. Todas as cartas têm solução, com Desfazer e um botão Ver Solução quando ficas bloqueado
5. Cronómetro e estatísticas: vitórias, taxa de vitória, sequências, resultados por dificuldade e jogos recentes
6. Design tradicional das cartas, com os números, os braços vermelhos e os pontos de dificuldade do jogo impresso
7. Joga em 9 idiomas, com definições de efeitos sonoros e volume
