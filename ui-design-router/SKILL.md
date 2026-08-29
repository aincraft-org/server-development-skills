---
name: ui-design-router
description: Use when designing or building player-facing UI for a Paper plugin — inventory GUIs, chat messages, headers, item names and lore — choosing colors, contrast, fonts, layout, states, or a centralized theme file. Triggers include chest GUIs, MiniMessage, Adventure components, WCAG/contrast, item lore, GUI layout, readable text, UI polish, design tokens, theme configuration, UI states, click feedback, hover text, and layout hierarchy.
---

# UI Design Router (Paper GUIs & Adventure Text)

Routes player-facing UI design decisions to the right principle — semantic theming, WCAG contrast, typography, layout hierarchy, states and feedback, surface conventions — **without reading anything but this file**. Deep dives live in `references/`; read them only when a route's directive does not fit the situation.

Core principle: **UI is a consumer surface; readability and consistency beat decoration. WCAG AA contrast is the floor, not a goal. Keep visual tokens in one theme object instead of scattering colors and materials through handlers.**

## The text stack: Adventure + MiniMessage

Paper exposes the Adventure text stack in its API, and `MiniMessage` is available without adding a dependency. Do not pin a separate Adventure/MiniMessage dependency unless a non-Paper module genuinely needs one.

- Player-facing strings come from MiniMessage (config-driven, human-readable).
- Programmatic composition uses the `Component` API.
- Never emit legacy `§` codes.

MiniMessage essentials (syntax per the official Adventure MiniMessage docs). These examples show syntax only; production renderers use semantic tokens from the adopted theme representation instead of copying literal colors.

```text
<color:#ffaa00>Gold</color>           hex color
<gradient:#ff5555:#55ffff>Title</gradient>
<bold>Header</bold> <italic>…</italic> <underlined>…</underlined> <strikethrough>…</strikethrough>
<newline>                             line break
<click:run_command:/homes>…</click>   run_command | suggest_command | open_url | copy_to_clipboard
<hover:show_text:'<yellow>Tooltip'>…</hover>
```

## How to use

1. **Reviewing UI:** run the [UI review checklist](#ui-review-checklist); for each failing probe, find the matching row in [Signal → route](#signal--route--remediation--verify) and apply its remediation.
2. **Designing new UI:** apply the [10 operative rules](#10-operative-rules-if-you-read-nothing-else); when a rule's cost is unclear, read the matching reference.
3. **Directive doesn't fit:** read the reference file listed in [References](#references-read-only-when-a-directive-does-not-fit) for tradeoffs, then decide.

## 10 operative rules (if you read nothing else)

| # | Rule | Smell when violated |
|---|---|---|
| 1 | One theme object holds every visual decision: semantic tokens (`title`, `body`, `muted`, …) and materials (`filler`, `back`, `close`, `next`) resolve at render time; handlers never hardcode hex codes or materials | Hex/weight/material repeated in handlers; per-screen token names for one role |
| 2 | WCAG AA is the floor: 4.5:1 body text, 3:1 large text and non-text components, measured against each actual rendered surface | dark_red/dark_blue/dark_gray text on dark GUIs; blue body text |
| 3 | Hierarchy comes from weight, color, and spacing — Minecraft's bitmap font has no free size control | Designing around font sizes that don't exist |
| 4 | Bold for headers only; gradients/rainbow are one-per-screen decoration, titles only | Bold body text; gradient bodies |
| 5 | Never rely on color alone to convey state — pair with text or an icon (WCAG 1.4.1) | Color-only status indicators |
| 6 | One layout language: every screen uses the same anatomy, one consistent filler material, fixed navigation slots (back/close/next) | Random fillers per screen; nav slots that move between screens |
| 7 | Identify inventories by a custom `InventoryHolder`, never by title or lore; cancel all `InventoryClickEvent`s and route by slot | Parsing lore for slot identity; title-based identification |
| 8 | Every interactive element has visible states — hover, disabled, error — click feedback, and a confirmation step before destructive actions | Silent buttons; instant irreversible actions |
| 9 | Group and align by meaning: related items stay adjacent, actions sit at consistent edges, empty space is structured filler | Scattered controls; cramped or ambiguous groupings |
| 10 | Keep copy separate from presentation: player text and MiniMessage templates live in `messages.yml`, tokens in the theme | Copy embedded in renderers; theme changes force copy edits |

## Signal → route → remediation → verify

Observable signals from a UI review or a design, mapped to the principle, the concrete remediation, and the check that proves it.

| Signal (what you see) | Principle | Remediation (do this) | Verify |
|---|---|---|---|
| Hex colors, weights, or materials repeated in handlers | Semantic theming | Resolve every visual decision from one validated theme object; renderers map tokens to MiniMessage | No hex codes or `Material` names outside the theme and renderers |
| Text or components that fail contrast on the real surface | WCAG AA floor | Measure against the actual rendered background, not an assumed one; fix the token or the surface | Token + measured ratio reported for each rendered surface |
| Body text bold, gradients in bodies, inconsistent hierarchy | Typography | Weight/color/spacing carry hierarchy; bold and decorations on titles only | Only headers bold; at most one gradient per screen |
| State conveyed by color only | Use of color | Pair color with text or an icon | No state signal that relies solely on color |
| Different fillers per screen; nav slots move around | Layout language | One shared anatomy: one filler material, fixed back/close/next positions | Same skeleton on every screen |
| Inventory identified by title or lore | Identity | Custom `InventoryHolder`; check `getHolder(false) instanceof`; PDC keys for slot data | No title/lore string parsing anywhere in click routing |
| Buttons with no states; destructive action fires on first click | States & feedback | Visible hover/disabled/error states, click feedback, confirm destructive actions | Every click path produces an observable response |
| Slots scattered without grouping; actions in odd positions | Layout hierarchy | Group by meaning, align columns and action edges, use structured filler | One visual grammar per screen; related items adjacent |
| Chat, lore, and titles formatted ad hoc per screen | Surface conventions | Follow per-surface rules (chat vs lore vs action bar vs title) | Each surface follows its convention consistently |
| Icons without labels; copy welded into renderers | Beyond-color accessibility | Label every icon, extract player copy to `messages.yml` | Icons carry text; no sentence built by concatenation |

## UI review checklist

Run after writing or reviewing any player-facing UI. Answer every probe; fix each failure.

1. Does every color, weight, and material come from the theme object — no hex codes or materials in handlers? (semantic theming)
2. Is every foreground/background pair measured against the actual rendered surface at 4.5:1 (body) / 3:1 (large text and components)? (contrast floor)
3. Is hierarchy carried by weight, color, and spacing rather than imagined font sizes? (typography)
4. Are bold and gradients confined to headers — at most one gradient per screen? (typography)
5. Is no state conveyed by color alone? (use of color)
6. Does every screen share one anatomy: same filler, same navigation slots? (layout language)
7. Are inventories identified by custom `InventoryHolder`, clicks cancelled, and routed by slot? (identity)
8. Does every interactive element have hover/disabled/error states and click feedback; do destructive actions confirm first? (states & feedback)
9. Are related items grouped, actions aligned consistently, and empty space filled structurally? (layout hierarchy)
10. Do chat, lore, item names, and action bars each follow their surface's formatting conventions? (surface conventions)
11. Is every icon labeled with text, and is all player copy extracted from renderers? (beyond-color accessibility)

## References (read only when a directive does not fit)

| Reference | Read when |
|---|---|
| [references/01-theme-tokens.md](references/01-theme-tokens.md) | Adopting/adapting `theme.yml`, token/material role contract, startup validation, freezing a `UiTheme` |
| [references/02-color-contrast.md](references/02-color-contrast.md) | WCAG AA ratios, the contrast table, safe defaults, measuring rendered surfaces |
| [references/03-typography-fonts.md](references/03-typography-fonts.md) | Hierarchy without font sizes, gradients, custom fonts and resource packs |
| [references/04-inventory-layout.md](references/04-inventory-layout.md) | GUI anatomy, navigation slots, `InventoryHolder` identity, click routing |
| [references/05-layout-hierarchy.md](references/05-layout-hierarchy.md) | Grouping, alignment, whitespace, scannability, information density |
| [references/06-gui-states-feedback.md](references/06-gui-states-feedback.md) | Hover/disabled/error states, click feedback, destructive confirmation, click economy |
| [references/07-chat-lore-surfaces.md](references/07-chat-lore-surfaces.md) | Formatting conventions per surface: chat, headers, item names and lore, action bar, boss bar |
| [references/08-accessibility-beyond-color.md](references/08-accessibility-beyond-color.md) | Navigation, icon labels, localization readiness, mis-click protection |

## Related skills

- [performance-optimization](../performance-optimization/SKILL.md) — render cost, main-thread discipline, listener hygiene.
- [development-network](../development-network/SKILL.md) — smoke-test GUIs against the local dev network.

## Verify

```bash
./gradlew build spotlessCheck
./gradlew runServer
```

- Theme (when adopted): load it once, validate configured semantic tokens/materials, and verify every foreground/background pair against each actual rendered surface.
- Smoke: open each GUI, screenshot, check headers, body, and hover text are readable and consistent.
- Custom fonts: test with and without the resource pack installed; the fallback must remain readable.

## Common mistakes

| Wrong | Right | Why |
|---|---|---|
| dark_red/dark_blue/dark_gray text on dark GUI | white/gray/gold/yellow/green/red/aqua/light_purple | fails 4.5:1 on dark backgrounds |
| Hex/weight/material repeated in handlers | semantic token or material from the adopted theme/config | one theme change stays consistent across every screen |
| Treating `theme.yml` as mandatory project configuration | adopt or adapt its format only when useful | the file is an implementation guide, not a required runtime contract |
| Per-screen token names for one role | one shared role name per meaning | semantic consistency is the contract |
| Invalid theme entries silently ignored | reject at startup, name the offending key | silent fallbacks defer config errors to runtime |
| Blue text for body | blue only for large/bold headers | #5555FF is 3.77:1 — passes large, fails normal |
| Color alone signals state | pair color with text/icon | WCAG 1.4.1; color-blind players miss it |
| Gradient on body text | gradient only on titles | decoration hurts readability |
| Legacy § codes | MiniMessage/Component | Paper's stack is Adventure |
| Parsing lore for slot identity | PDC keys / InventoryHolder | lore is display, not data |
| Identifying inventory by title | custom InventoryHolder | other plugins/players can collide on titles |
| Inconsistent nav slots | fixed back/close/next positions | players learn one layout |
| Random fillers per screen | one consistent gray glass | visual noise |
| Per-request listeners | one registered listener | leaks (see performance-optimization) |
| Assuming a title character limit | keep titles short, verify against client | title width is a rendering constraint |
| Custom font without fallback testing | test with the resource pack absent | clients without the pack must stay readable |
| Destructive action on first click | confirm step before irreversible actions | mis-clicks destroy progress |
| Silent interactive slots | visible states and click feedback | players can't tell what is clickable |
| Copy assembled by string concatenation | templates with placeholders in messages.yml | breaks grammar order under localization |