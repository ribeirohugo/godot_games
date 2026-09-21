# Godot games (WebPlatinum)

A monorepo of small Godot 4 games (GDScript, 4.7). Each folder is its own Godot project. Everything is
drawn and synthesized in code (no image or audio files in the games), and text lives in a per-game
`scripts/strings.gd`. Games are published to the Microsoft Store as MSIX packages.

## Repo layout

```
.env / .env.example      Godot path + version for this machine (.env is not committed)
_config.bat              shared setup called by every game's .bat scripts (see below)
_msix.ps1                shared MSIX builder called by every game's export-msix.bat
common/                  code shared by all games
  intro/                 WebPlatinum studio intro (the run/main_scene of every game)
  fonts/                 Arabic / Chinese fallback fonts (see common/fonts/README.md)
  design/                logo design files; NOT copied into games
<game>/                  one Godot project per game
```

Edit shared code in the root `common/`, never in a game's `common/` copy: `_config.bat` mirrors
`common/intro` and `common/fonts` into `<game>/common/` before every run and overwrites them. Those
copies are git-ignored.

## Game folder layout

```
<game>/
  project.godot          run/main_scene = res://common/intro/intro.tscn (the intro then opens scenes/main.tscn)
  scenes/main.tscn       a single Node2D that carries scripts/main.gd
  scripts/               main.gd, strings.gd (translations), sfx.gd (synthesized sounds), game-specific scripts
  icon.png / icon.ico    512x512 icon; icon.png also feeds the Store logos
  export_presets.cfg     presets "Web" and "Windows" (export_path / product_name carry the exe name)
  edit.bat play.bat      open in the editor / run the game
  export-web.bat serve-web.bat export-windows.bat
  export-msix.bat msix.env   Microsoft Store package (only games that are published)
  store-listing/         Store texts and images (only games that are published, see below)
```

New game checklist: copy the `.bat` files, `export_presets.cfg` and `scenes/main.tscn` from a finished
game (Queens is the reference), replace the game name inside them, set `config/name`,
`project/assembly_name` and the viewport size in `project.godot`, and add `strings.gd` with the
`LANGUAGES` / `TEXT` / `install()` / `system_language()` pattern. Keep `.bat` files in CRLF.

## Exporters

All scripts start with `call "%~dp0..\_config.bat" "%~dp0."`, which reads `.env` (`GODOT`,
`GODOT_VERSION`), finds the export templates and refreshes the `common/` copies.

| Script | Output | Notes |
| --- | --- | --- |
| `export-web.bat` | `build\web\index.html` | `serve-web.bat` serves it on http://localhost:8060. Needs web templates and a **non-.NET** Godot: the .NET (mono) build refuses to export Web, so this fails with the current `.env` for every game. |
| `export-windows.bat` | `build\windows\<Name>.exe` | Single exe with the pck embedded (`binary_format/embed_pck`). |
| `export-msix.bat [sign]` | `build\msix\<Name>_<version>_x64.msix` | Runs `_msix.ps1`. See below. |

`build/` and `.godot/` are git-ignored.

### MSIX (`export-msix.bat` + `msix.env` + `_msix.ps1`)

`export-msix.bat` is the same in every game except the `-Exe <Name>.exe` argument, which must match the
`export_path` of the Windows preset. `_msix.ps1` then: exports the Windows exe with Godot, makes every
Store logo from `icon.png` (StoreLogo, Square44/71/150/310, Wide310x150, SplashScreen, taskbar
`targetsize-*` and `altform-unplated` sizes), writes `AppxManifest.xml` and packs it with `makeappx.exe`
(Windows SDK). `export-msix.bat sign` also signs it with a local test certificate so it can be installed
on this PC (the script prints the one-time `Import-Certificate` command). **Upload the unsigned package**
to the Store; Microsoft signs it there.

`msix.env` (KEY=VALUE, no quotes, `#` comments) holds the Partner Center values:

| Key | Meaning |
| --- | --- |
| `IDENTITY_NAME` | Package/Identity/Name, e.g. `WebPlatinum.QueensGame`. Letters, digits, `.` and `-` only |
| `PUBLISHER` | Package/Identity/Publisher, starts with `CN=`. Same for every game: `CN=33F06A6D-7BDD-48EE-AC03-85FC626020AD` |
| `PUBLISHER_DISPLAY_NAME` | `Web Platinum` |
| `DISPLAY_NAME` | The reserved app name, must match Partner Center |
| `DESCRIPTION` | One sentence |
| `VERSION` | `1.0.0.0`; raise it for every Store upload and keep the last number `0` |
| `BACKGROUND_COLOR` | Tile background, `transparent` by default |
| `LANGUAGES` | Comma-separated language codes declared in the manifest (`en,pt,es`). **Each one needs a Store listing in Partner Center**, so list only languages that have a listing section |

`LANGUAGES` must be tags Windows accepts as resource languages, or the Store install fails certification
(10.3.4 "App Is Testable") with error `0x80070057`. A bare `zh` is invalid: use `zh-cn` (Simplified) or
`zh-tw`; `_msix.ps1` now refuses `zh`. Language tags such as `en`, `pt`, `pt-pt`, `sv`, `ar` are fine. To
check a package the way the Store installs it, run `Add-AppxPackage -Register build\msix\package\AppxManifest.xml`
(needs Developer Mode), then `Get-AppxPackage <IDENTITY_NAME> | Remove-AppxPackage`. Its error message names
the problem, which `makeappx` does not.

`IDENTITY_NAME` and `PUBLISHER` for a new game are a guess until copied from Partner Center > Product
management > Product identity; the build does not warn about a wrong guess (it only warns about
`CHANGEME`), and the Store rejects a package whose identity does not match.

## Store listing (`<game>/store-listing/`)

Everything the Store asks for besides the package: texts in one Markdown file, images next to it. The
folder has an empty `.gdignore` file so Godot does not import the images into the game.

```
store-listing/
  .gdignore                    empty; keeps Godot from importing these files
  store-listing.md             all texts, one section per language
  BoxArt.2160x2160.png         1:1 box art  (also BoxArt.1080x1080.png)
  PosterArt.1440x2160.png      2:3 / 9:16 poster art  (also PosterArt.720x1080.png)
  HeroArt.3840x2160.png        16:9 Super hero art, optional  (also HeroArt.1920x1080.png)
  AppTile.300x300.png          Store logos made from icon.png  (also .150x150 and .71x71)
  screenshot.png               desktop screenshot; more as screenshot-2.png, screenshot-3.png, ...
  <lang-code>/                 only when art or screenshots differ per language (snake-world: pt-pt/, de-de/, ...)
```

- Images are rendered from the game itself (its own drawing code, icon and fonts), not made in an
  outside editor. Screenshots are real gameplay; the first one is the most important.
- Each `<lang-code>/` folder uses the Partner Center code (`pt-pt`, `pt-br`, `es-es`, `zh-cn`, ...) and
  holds its own localized Box/Poster art and screenshots. The default language sits at the top level.
- Games with a single language keep just one listing and no language folders.

### `store-listing.md`

Written to Microsoft's Store listing rules: character limits, no HTML, code or URLs in the description,
and no hand-typed bullets in Product features (the Store adds them). Structure, copied from
`queens/store-listing/store-listing.md` (the reference), `snake-world/` for many languages:

```
# Microsoft Store listing — <Game>

<one paragraph: written to the Store rules, link to Microsoft's field-rules page, which languages the
game supports (see scripts/strings.gd) and that a listing is provided for each>. The app name is not
localized (say so, or list the exceptions under "## Product name" as snake-world does).

## Images            (or "## Screenshots")
<table of file -> where it goes in Partner Center, and what each screenshot shows>

## English — <Game>
### Short description (recommended, up to 1,000 characters; keep under 270 for best display)
<text>

(<n> characters)
### Description (required, up to 10,000 characters)
<text, blank line between paragraphs>

(<n> characters)
### Product features (200 characters per feature, 20 max — Store adds bullets automatically, do not add your own)
1. <feature>
2. <feature>

## Portuguese (pt) — <Game>
...same three sections, with the headings translated...
```

Rules of thumb:
- One `## <Language> (<code>) — <Product name>` section per language in `msix.env` `LANGUAGES`, in the
  order English, Portuguese, Spanish, French, German (extra languages after). Use the Partner Center
  code, e.g. `(pt-pt)` when the package declares `pt-pt`.
- Put the character count in parentheses after the short description and the description; keep the short
  description under 270 characters and each feature under 200.
- Translate the three headings and the limits in them (copy the wording from an existing listing).
- Describe only what the game really does (modes, controls, languages); no prices, ratings or URLs.
- Games about money or chance (Roleta, Slot Machine Pro) must say it is play money for fun with no real
  prizes, and expect a higher age rating in the Store questionnaire.
