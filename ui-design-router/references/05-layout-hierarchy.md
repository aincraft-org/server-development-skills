# Layout and Hierarchy (Reference)

Deep reference for the layout-hierarchy route in `../SKILL.md`. General composition principles applied to the 9-wide inventory grid and chat surfaces. Read when a screen feels cluttered, ambiguous, or hard to scan.

## The grid is the canvas

Inventory GUIs are a 9-column grid with fixed row heights. Layout decisions are slot placement decisions — and slots are cheap. Use them deliberately:

- **Group by meaning.** Related actions stay adjacent within a row; unrelated items never share a neighborhood. A "shop" tab with the purchase button on the far edge from the items it buys is a grouping failure.
- **Proximity beats labels twice over.** Players infer what a click does from what is next to it. If two slots need labels to disambiguate, the grouping is wrong — move them.
- **Alignment is contract.** Buttons that float mid-row read as decoration, not action. Align interactive columns (left, center, or right) and keep them aligned across every screen of a flow.
- **Whitespace via filler.** Empty slots are not neutral — they are planes that players must visually skip. One consistent filler material (see `04-inventory-layout.md`) converts noise into structure. Prefer a full filler background with a clear content column over scattered items in an empty chest.

## Scannability

- **One dominant element per screen.** The header (title + item in row 0) states what this screen is. Everything else should answer "what can I do here" in one glance.
- **Header row as information architecture.** Row 0 carries the title and any state the screen tracks (balance, page, selection). Content rows 1–4 are the interaction space. Footer is navigation only — never primary actions.
- **Order by frequency or progress.** Most-used action first; multi-step flows place the next step consistently (e.g. next page at 53, always).
- **Density limits.** A 54-slot content area with 40 populated slots is a wall of noise. Split data-driven screens into pages (per-page limits of 18–28 items are the readable range for a 5-row layout) or introduce a category/tab level.
- **Icons carry meaning, text confirms.** Item icons (materials) are the primary cue; the item name is the confirmation. Every icon dereferences to at least one knowable item — no mystery meat icons.

## Hierarchy modifiers available

Ranked by visual strength on the canvas:

1. **Placement** — row 0 header, content rows, footer navigation (strongest, cheapest).
2. **Borders and separators** — `border` token lines, vertical separator columns (e.g. a glass column splitting content from info).
3. **Weight/color roles** — `title` vs `body` vs `muted` (see `03-typography-fonts.md`).
4. **Item-name prefix glyphs** — namespaced font glyphs for list bullets/status (only with a tested resource pack).

## Common mistakes

| Mistake | Correction |
|---|---|
| Scattered unrelated items across the grid | Group by meaning; adjacent = related |
| Floating action slots | Align interactive columns consistently across screens |
| Empty grid as raw noise | Structure it with one consistent filler |
| 40+ items per page | Split into pages/tabs; readable density |
| Navigation slot carries a primary action | Footer = navigation; primary actions live in content rows |
| Icons with no textual name | Every icon identifiable by name; text confirms the icon |