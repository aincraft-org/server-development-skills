# Accessibility Beyond Color (Reference)

Deep reference for the beyond-color route in `../SKILL.md`. WCAG contrast (see `02-color-contrast.md`) is the floor; this reference covers the rest. Minecraft GUIs have no standard keyboard-focus/tab model — accessibility is won through redundancy, forgiving interaction, and localization readiness.

## Redundancy: never a single channel

Every signal players must act on is available in at least two channels (WCAG 1.4.1 is the color case; the principle generalizes):

- **Visual + textual**: icon with name, color with verb, glyph with word.
- **Visual + auditory**: sounds confirm clicks (see `06-gui-states-feedback.md`) — a blindfolded player can still complete the common path.
- **State in copy, not just in rendering**: disabled items explain their condition; error messages name the failure.

## Interaction forgivingness

- **Mis-click protection** beats pixel sympathy: confirmations for destructive actions (see `06-gui-states-feedback.md`), and never place a destructive slot next to the most-clicked slot.
- **No time pressure.** Nothing a player needs should require reacting within a transient window: action-bar-only instructions are inaccessible (see `07-chat-lore-surfaces.md`); put instructions in chat or lore.
- **Fat hit targets.** Clickable slots are 18×18px cells — keep interactive items full-cell (no clickable micro-slots inside a cell's corners) and pad hover targets with surrounding empty cells where a row permits.

## Keyboard and input reality

- Chest GUIs respond to clicks and (where enabled) number-key hotbar swaps. Anything clickable once is reachable:
  - Number-key actions: if a row of 9 actions is ordered, 1–9 maps to the top row — document it, keep it stable across screens.
  - `getHolder(false)` routing must ignore creative-mode hotbar actions unless intended (see `04-inventory-layout.md`).

## Localization readiness

- **No concatenation.** Player-facing copy is templates with placeholders (`/homes delete {name}`), never `"You deleted " + home` — sentence order breaks under translation.
- Component-based composition: `Component.translatable("gui.shop.buy", args)` for Adventure-aware localization; MiniMessage templates in `messages.yml` as the config-driven middle ground.
- Unlocalized date/number formatting: format numbers through the server locale, not string literals.
- Copy never encodes layout: no newline-in-string hacks to force alignment — alignment lives in the template/layout layer (`05-layout-hierarchy.md`).

## Common mistakes

| Mistake | Correction |
|---|---|
| Instruction only on the action bar | Transient surfaces never carry must-do info; chat/lore do |
| Copy built by concatenation | Templates with placeholders; translation-safe order |
| Destructive slot adjacent to the primary action | Spread critical pairs; confirmant placement |
| Click sounds on every action, none on errors | Distinct error feedback (sound/chat) so failures are perceivable |
| Icons that only icon-users decode | Every icon has a textual name |
| Hotbar number actions reordered per screen | Stable top-row ordering, documented once |