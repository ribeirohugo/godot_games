# Fonts

Godot's default UI font (`ThemeDB.fallback_font`) has no Arabic or Chinese glyphs, so
games that offer those languages need a fallback font for the characters it's missing.

These are subsets of [Noto Sans Arabic](https://fonts.google.com/noto/specimen/Noto+Sans+Arabic)
and [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC) (Google Fonts,
SIL Open Font License — see `OFL.txt`), cut down to keep the games small:

- `NotoSansArabic-subset.ttf` — the Arabic block, Arabic presentation forms, and basic
  Latin/digits/punctuation. Broad enough for any reasonable Arabic UI text.
- `NotoSansSC-subset.ttf` — only the exact Han characters a game's `strings.gd` actually
  uses, plus CJK punctuation and basic Latin/digits. Regenerate it if a game adds Chinese
  text using characters outside the current set (see below) — an unlisted character
  falls back to `ThemeDB.fallback_font`, which shows as a blank box.

Both started as the variable "Regular" weight, pinned to a static instance with
`fonttools.varLib.instancer`, then cut down with `fonttools.subset`. To regenerate the
Chinese subset with a wider character set:

```
python -m fontTools.subset NotoSansSC-static.ttf --unicodes="U+0000-007F,U+3000-303F,U+FF00-FFEF" \
    --text-file=your_chars.txt --output-file=NotoSansSC-subset.ttf
```

A game loads these at runtime with `FontFile.load_dynamic_font()` and lists them as
`fallbacks` on a `FontVariation` wrapping `ThemeDB.fallback_font` — see `snake-quest/scripts/main.gd`.
