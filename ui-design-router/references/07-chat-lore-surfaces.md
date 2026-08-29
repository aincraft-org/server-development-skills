# Chat, Lore, and Surface Conventions (Reference)

Deep reference for the surface-conventions route in `../SKILL.md`. Minecraft renders text on several surfaces with different constraints; each has its own convention. Read when formatting chat output, item names/lore, titles, or bars.

## The surfaces

| Surface | Constraints | Convention |
|---|---|---|
| Chat messages | Full width, scrollable history, client themes vary | Complete sentences, `body` default; one highlight color per semantic role; timestamps/context in `muted` |
| Action bar | ~1 line, transient (2–3 s), fills the hotbar strip | Short confirmed states ("+2 diamonds"), never instructions; `success`/`danger` by outcome |
| Boss bar | One long bar, name is short-form text | Progress states (wither/raid style): short noun + counts; color conveys status, text still present |
| Titles / subtitle | Full-screen overlay, transient | Major events only; `title` token bold; subtitle for the detail line |
| Item names | One line, grid-labeled | Short noun ("Home Wand"); never instructions in the name |
| Item lore | Tooltip lines, wraps ~30 chars (client-dependent, ~2 columns) | Smallest information unit per line; instructions live here; align values in columns |
| GUIs | 9-wide slots with name + up to ~4 lore lines visible (count varies) | Name = what it is, lore = what it does; see `04-inventory-layout.md` |

## Chat conventions

- One message = one idea. Prefixes (per-plugin tag) in `accent` or `muted`, message body in `body`.
- Success/error/warning outcomes carry their role tokens plus a verb: "Teleported home." / "Failed: home not set." — never color alone (WCAG 1.4.1).
- Multi-line output aligns values: columns of numbers in `money` token align per line; keep prefixes consistent so lines visually align.
- Global announcements are not chat replies: they get their own consistent prefix, no player-directed address.

## Item names and lore conventions

- **Name states identity; lore states behavior.** "Home Wand" + lore "Click: open homes list / Sneak-click: set home here" beats instructions in the name.
- Lore line budget: up to ~4–6 visible lines; anything beyond is a wall — split into actions/requirements/flavor order, most important first.
- Align lore values into columns (spaces or glyph padding) for numbers, prices, and requirements.

## Feedback surfaces

- Confirmations that must not be missed (purchase, teleport, deletion) go to chat — history is permanent.
- Counters and transient status (cooldown, item count) go to the action bar — transient by nature.
- Never put instructions on the action bar; it disappears.

## Common mistakes

| Mistake | Correction |
|---|---|
| Instructions in item names | Name = identity; lore = behavior |
| Lore walls beyond the visible budget | Trim to ~4–6 lines, ordered by importance |
| Action bar used for instructions | Action bar = short confirmations; chat = instructions |
| Color alone marks an outcome | Verb + role token ("Failed: …" in `danger`) |
| Unaligned value columns in chat/lore | Align numbers and prices per line |
| Every message prefixed loudly | One consistent prefix; body carries the message |