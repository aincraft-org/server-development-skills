# GUI States and Feedback (Reference)

Deep reference for the states-and-feedback route in `../SKILL.md`. Read when designing interactive slots, destructive actions, or click handling.

## Every interactive element has states

A clickable slot must show that it is clickable, that it is being acted on, and what happened. Three states minimum:

| State | How to show it (ink + item, never color alone) |
|---|---|
| Idle / available | Normal item, name states the action ("Buy", "Teleport") |
| Hover / focused | Hover text (name + lore) previews the consequence; interactive items carry an `accent`-tinted name or a glyph that marks clickability |
| Disabled / unavailable | Distinct from idle: `muted` name, no hover consequence, click does nothing AND the item reads disabled (e.g. "Locked — reach level 5" instead of silent no-op) |
| Error/rejected | `danger` feedback describing what failed ("Not enough money", "Cooldown active") |

Rules:

- **Disabled is visibly different from idle.** A grayed item that still hovers like a button is a lie; a colored item that silently ignores clicks is a trap.
- **Hover text previews consequences.** `hover:show_text` on interactive slots states the outcome ("Click to withdraw 5 diamonds") before the click. Non-interactive items never get click-shaped hover.
- **State changes are rendered, not just handled.** When an action changes what a screen allows (item bought → row locks), refresh the GUI so the new disabled states are visible. Stale states are bugs.

## Click feedback

- **Every successful click produces a visible or audible response** within the same interaction: GUI refresh (item moves/updates), chat confirmation, sound (play a click/ping), or navigation. Silent handlers read as broken.
- **Feedback matches the surface.** In-GUI actions: refresh the screen or an item update. Global actions (teleport, purchase): chat confirmation with `success`/`money` tokens.
- **No double-fire.** Cancel all `InventoryClickEvent`s and route by slot (see `04-inventory-layout.md`); debounce where a double-click would double-purchase.

## Destructive actions

- **Confirm irreversible actions on a dedicated confirmation screen** (second click, distinct layout: item + "Confirm" / "Cancel" pair). Never destroy progress on the first click — chest UIs make mis-clicks routine.
- Confirmation copy states the object and the consequence: "Delete home `base`? This cannot be undone."
- Reserved `danger` token for destructive confirmation; `warning` for caution-level actions (overwrite, kick).

## Click economy

Click economy = how many clicks a goal costs. Optimize the common path:

- Two-click flows (select → confirm) beat three-click flows (select → submenu → confirm) for non-destructive actions.
- **Modal confirmation only for irreversible or high-cost actions.** Asking "are you sure?" on everything trains players to click through it, and the guard stops mattering (alert fatigue).
- Pagination counts: 54-slot GUI, 28-item page, browsing to item 60 costs 3 clicks. A category tab costs 1. Where browsing dominates, tabs beat pages.

## Common mistakes

| Mistake | Correction |
|---|---|
| Disabled item that still looks clickable | `muted` + no hover consequence + reason text |
| Silent successful click | Visible or audible response: refresh, confirmation, sound |
| Destructive action on first click | Dedicated confirm screen with consequence copy |
| Confirming every action | Reserve confirmations for irreversible/high-cost; alert fatigue kills the guard |
| Color-only state change | Pair color with text/icon; state visible in the item itself |
| Stale disabled states after an action | Re-render the GUI so states match the new situation |