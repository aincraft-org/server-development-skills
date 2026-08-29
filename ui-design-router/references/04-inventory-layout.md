# Inventory GUI Layout (Reference)

Deep reference for the layout-language and identity routes in `../SKILL.md`. Read when building or reviewing a chest-type GUI.

## Anatomy

- Sizes are multiples of 9, 9–54 for chest-type GUIs.
- Standard anatomy: row 0 = header, rows 1–4 = content, row 5 = footer (navigation).
- Fill empty slots with one consistent filler material from the adopted theme/config (the reference default is gray stained glass).
- Navigation in fixed slots: back (45), close (49), next (53) on a 54-slot GUI.
- Keep titles short — title width is a client-side rendering constraint, not a server-enforced limit. (The legacy `String`-title 32-char limit does not apply to Adventure `Component` titles.)

## Identity and click routing

- Identify your inventories with a custom `InventoryHolder`, not by title or lore; check `inventory.getHolder(false) instanceof MyHolder` in the click listener.
- Cancel all `InventoryClickEvent`s and route by slot.
- Slot data (which item, which entity, which page) belongs in PDC keys on the clicked item or in the holder — not in lore text.

## Navigation conventions

- One set of navigation materials across every screen: `back` (45), `close` (49), `next` (53) at 54 slots; scaled down proportionally for smaller screens (e.g. bottom row center trio).
- A screen without a previous page still shows the back slot if it is reachable from a parent screen; hide only what is unreachable.
- Deep navigation needs breadcrumbs — encode the trail in the holder, not in item lore.

## Slot routing patterns

- Route by fixed slot constants for navigation; switch on slot index for content.
- Dynamic slot→action maps for data-driven screens (shops, kits) — one map renderer instead of per-slot if/else (DRY rule of three; see architecture-router).
- Never parse lore for identity: lore is display, PDC is data.

## Common mistakes

| Mistake | Correction |
|---|---|
| Random fillers per screen | One consistent gray glass (or adopted filler) |
| Nav slots that move between screens | Fixed back/close/next positions; players learn one layout |
| Parsing lore for slot identity | PDC keys / InventoryHolder |
| Identifying inventory by title | Custom InventoryHolder; titles collide across plugins |
| Assuming a 32-char title limit | Keep titles short, verify against client; width is a rendering constraint |
| Per-request listeners | One registered listener; route by holder + slot |