# Typography and Fonts (Reference)

Deep reference for the typography route in `../SKILL.md`. Read when setting hierarchy, using gradients or decoration, or planning custom fonts.

## The constraint

Minecraft renders text with a fixed bitmap font — **font size is not freely controllable**. Hierarchy comes from weight, color, and spacing, not point size:

- **Title/header**: `title` token (default gold or yellow), bold.
- **Body**: `body` token (default white), regular.
- **Secondary/muted**: `muted` token (default gray).
- **Success**: `success` token (default green). **Danger/error**: `danger` token (default red).
- **Money/numbers**: `money` token (default gold).

## Rules

- Bold for headers only; never bold body text.
- Gradients and rainbow are decoration — one per screen, titles only, never body.
- Custom font faces require a **client resource pack**; without one the client falls back to the default font. Test every custom font with the resource pack absent to confirm the fallback stays readable.
- Never rely on color alone to convey state — pair with text or an icon (WCAG 1.4.1).

## Hierarchy without size

With no size axis, signal hierarchy with, in order of strength:

1. **Weight** — bold marks headers; everything else stays regular. Bold body text reads as shouting.
2. **Color roles** — `title`/`accent` vs `muted`: the eye sorts by luminance contrast first.
3. **Spacing and placement** — row 0 header on every GUI, consistent margins, separators made of `border` tokens.

Decorative MiniMessage tags (`<bold>`, `<italic>`, `<underlined>`, `<strikethrough>`) are typography, not decoration — use them for emphasis only where the role calls for it.

## Custom fonts (resource packs)

- A custom font is a client-side resource pack feature: `font="minecraft:default"` fallback happens automatically when the pack is absent, but the fallback must be **tested** — verify every screen with the pack uninstalled.
- Namespaced font definitions and glyph padding live in the pack, not in the plugin. The plugin only references the namespace.
- Never design copy around glyph widths of a custom font; the fallback font has different metrics.

## Common mistakes

| Mistake | Correction |
|---|---|
| Bold body text | Bold for headers only |
| Gradient/rainbow on body text | One decoration per screen, titles only |
| Designing around point sizes | Weight, color, spacing carry hierarchy |
| Custom font shipped without fallback testing | Test with the resource pack absent; fallback must stay readable |
| Strikethrough/underline on body | Reserved for signals (removed items, links/emphasis), not decoration |