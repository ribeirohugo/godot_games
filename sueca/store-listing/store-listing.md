# Microsoft Store listing — Jogo da Sueca!

Written to Microsoft's Store listing rules (character limits, no HTML/code/URLs in the description, no manually-added bullets in Product features): https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/add-and-edit-store-listing-info (same field rules apply to MSIX apps).

The game is only in Portuguese (see `scripts/strings.gd`) and `msix.env` declares only `pt`, so there is a single listing, in Portuguese: add it under Portuguese in Partner Center. The app name is "Jogo da Sueca!", the same as `DISPLAY_NAME` in `msix.env`.

## Images

Rendered in-engine from the game's own drawing code, icon and fonts — no external image editor involved. The Box, Poster and Hero art are redrawn with `Godot --path sueca res://scenes/main.tscn -- --render-store`; the App tiles are `icon.png` scaled down.

| File | Where it goes |
| --- | --- |
| `BoxArt.1080x1080.png`, `BoxArt.2160x2160.png` | Store display images: 1:1 box art |
| `PosterArt.720x1080.png`, `PosterArt.1440x2160.png` | Store display images: 2:3 poster art |
| `HeroArt.1920x1080.png`, `HeroArt.3840x2160.png` | Store display images: 16:9 Super hero art (optional) |
| `AppTile.300x300.png`, `AppTile.150x150.png`, `AppTile.71x71.png` | Store logos: 1:1 app tile icon (optional) |
| `screenshot.png` | Desktop screenshot: mid-hand, your turn, three cards in the trick, the playable cards lit and the others dimmed |
| `screenshot-2.png` | Desktop screenshot: right after the deal, the trump suit announced in the middle of the table |
| `screenshot-3.png` | Desktop screenshot: a hand won by capote (103–17), with confetti |
| `screenshot-4.png` | Desktop screenshot: the title screen with the "Jogo da Sueca!" logo |

All screenshots are real gameplay at 1920x1080.

## Portuguese (pt) — Jogo da Sueca!

### Descrição curta (recomendado, até 1000 carateres; manter abaixo de 270 para melhor exibição)

Joga à Sueca, o clássico jogo de cartas português, com a tua parceira contra dois adversários controlados pelo computador. Assiste ao naipe, corta com trunfo e faz 61 pontos para ganhar a mão. Chega primeiro aos 4 jogos e ganha a partida!

(238 carateres)

### Descrição (obrigatório, até 10 000 carateres)

Jogo da Sueca! traz para o teu computador o jogo de cartas mais popular de Portugal. Jogam quatro, em duas equipas: tu e a Rita, a tua parceira, contra o Zé e o Manel. Cada jogador recebe 10 cartas de um baralho de 40, e a última carta de quem dá mostra o trunfo.

As regras são as da Sueca tradicional: é obrigatório assistir ao naipe que saiu, quem não o tem pode cortar com trunfo, e a vaza é da carta mais alta. O Ás vale 11, o 7 vale 10, o Rei 4, o Valete 3 e a Dama 2. A equipa que fizer 61 dos 120 pontos ganha a mão e soma 1 jogo, 2 com capote (91 pontos ou mais) e 4 com bandeira (todas as vazas). Ganha a partida quem chegar primeiro aos 4 jogos.

Os outros três jogadores são controlados pelo computador e jogam a sério: lembram-se das cartas que já saíram, percebem quando alguém já não tem um naipe, carregam pontos na vaza do parceiro e guardam os trunfos para quando valem a pena.

O jogo destaca as cartas que podes jogar e avisa-te se tentares uma carta que não assiste. A carta que está a ganhar a vaza fica iluminada, a última vaza fica à vista num canto e o placar mostra os pontos da mão e os jogos da partida. As cartas voam pela mesa ao baralhar, dar e recolher as vazas, com sons em cada jogada e confetes quando ganhas.

Joga com o rato ou com o teclado, em velocidade normal ou rápida. As regras completas estão sempre à mão no menu, e as estatísticas guardam as partidas e mãos ganhas, os capotes, as bandeiras e a tua melhor mão. O jogo está em português.

(1483 carateres)

### Funcionalidades do produto (200 carateres por funcionalidade, 20 no máximo — a Store adiciona os marcadores automaticamente, não acrescentes os teus)

1. Sueca tradicional a quatro: tu e a tua parceira contra dois adversários controlados pelo computador
2. Regras completas: assistir ao naipe, cortar com trunfo, capote, bandeira e partidas a 4 jogos
3. Parceira e adversários que se lembram das cartas jogadas e jogam em equipa
4. Cartas jogáveis destacadas, carta vencedora iluminada e última vaza sempre à vista
5. Cartas animadas, sons em cada jogada e confetes quando ganhas a mão ou a partida
6. Estatísticas de partidas, mãos, capotes, bandeiras e melhor mão
7. Joga com o rato ou com o teclado, em velocidade normal ou rápida
