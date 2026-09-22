# Microsoft Store listing — Bisca

Written to Microsoft's Store listing rules (character limits, no HTML/code/URLs in the description, no manually-added bullets in Product features): https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/add-and-edit-store-listing-info (same field rules apply to MSIX apps).

The game is only in Portuguese (see `scripts/strings.gd`) and `msix.env` declares only `pt`, so there is a single listing, in Portuguese: add it under Portuguese in Partner Center. The app name is "Bisca", the same as `DISPLAY_NAME` in `msix.env`.

## Images

Rendered in-engine from the game's own drawing code, icon and fonts — no external image editor involved. The Box, Poster and Hero art are redrawn with `Godot --path bisca res://scenes/main.tscn -- --render-store`; the App tiles are `icon.png` scaled down.

| File | Where it goes |
| --- | --- |
| `BoxArt.1080x1080.png`, `BoxArt.2160x2160.png` | Store display images: 1:1 box art |
| `PosterArt.720x1080.png`, `PosterArt.1440x2160.png` | Store display images: 2:3 poster art |
| `HeroArt.1920x1080.png`, `HeroArt.3840x2160.png` | Store display images: 16:9 Super hero art (optional) |
| `AppTile.300x300.png`, `AppTile.150x150.png`, `AppTile.71x71.png` | Store logos: 1:1 app tile icon (optional) |
| `screenshot.png` | Desktop screenshot: mid-hand, your turn, Zé has led the king of hearts, the stock with the trump under it and both players' won cards on the table |
| `screenshot-2.png` | Desktop screenshot: you hold the 2 of trump, the face-up trump glows and the "Trocar o 2" button is shown |
| `screenshot-3.png` | Desktop screenshot: right after the deal, the trump suit announced in the middle of the table |
| `screenshot-4.png` | Desktop screenshot: a hand won by capote (93–27), with confetti |
| `screenshot-5.png` | Desktop screenshot: the title screen with the "Bisca" logo and the four sevens |

All screenshots are real gameplay at 1920x1080.

## Portuguese (pt) — Bisca

### Descrição curta (recomendado, até 1000 carateres; manter abaixo de 270 para melhor exibição)

Joga à Bisca, o clássico jogo de cartas português, contra o computador. Tira cartas do monte, guarda os trunfos, troca o 2 pelo trunfo virado e faz 61 pontos para ganhar a mão. Chega primeiro aos 4 jogos e ganha a partida!

(222 carateres)

### Descrição (obrigatório, até 10 000 carateres)

Bisca traz para o teu computador um dos jogos de cartas mais jogados em Portugal. Jogas a dois, tu contra o Zé, com um baralho de 40 cartas. Cada jogador tem 3 cartas na mão e a carta virada debaixo do monte mostra o trunfo.

As regras são as da Bisca tradicional: enquanto houver monte podes jogar qualquer carta, e depois de cada vaza quem a ganhou tira primeiro uma carta nova. Quem tiver o 2 de trunfo pode trocá-lo pelo trunfo virado. Quando o monte acaba passa a ser obrigatório assistir ao naipe. O Ás vale 11, o 7 vale 10, o Rei 4, o Valete 3 e a Dama 2. Quem fizer 61 dos 120 pontos ganha a mão e soma 1 jogo, 2 com capote (91 pontos ou mais) e 4 com bandeira (os 120 pontos). Ganha a partida quem chegar primeiro aos 4 jogos.

Além da Bisca de 3, podes jogar as variantes de 7 e de 9 cartas na mão, escolhidas no menu.

O Zé joga a sério: guarda os trunfos e as cartas de pontos para quando valem a pena, troca o 2 sempre que pode e, quando o monte acaba e já se sabe que cartas tens, joga o fim da mão sem falhas.

O jogo avisa-te se tentares uma carta que não assiste, ilumina a carta que ganha a vaza e mostra a última vaza num canto, o número de cartas no monte e as cartas que cada jogador já ganhou. As cartas voam pela mesa ao baralhar, dar, jogar e tirar do monte, com sons em cada jogada e confetes quando ganhas.

Joga com o rato ou com o teclado, em velocidade normal ou rápida. As regras completas estão sempre à mão no menu, e as estatísticas guardam as partidas e mãos ganhas, os capotes, as bandeiras e a tua melhor mão. O jogo está em português.

(1571 carateres)

### Funcionalidades do produto (200 carateres por funcionalidade, 20 no máximo — a Store adiciona os marcadores automaticamente, não acrescentes os teus)

1. Bisca tradicional a dois: tu contra um adversário controlado pelo computador
2. Regras completas: tirar do monte, trocar o 2 pelo trunfo, assistir quando o monte acaba, capote e bandeira
3. Três variantes: Bisca de 3, de 7 e de 9 cartas na mão
4. Adversário que guarda os trunfos e joga o fim da mão sem falhas
5. Carta vencedora iluminada, última vaza e cartas no monte sempre à vista
6. Cartas animadas, sons em cada jogada e confetes quando ganhas a mão ou a partida
7. Estatísticas de partidas, mãos, capotes, bandeiras e melhor mão
8. Joga com o rato ou com o teclado, em velocidade normal ou rápida
