---
name: ui-design
description: Use when designing or building player-facing UI for a Paper plugin — inventory GUIs, chat messages, headers, item names and lore — choosing colors, contrast, fonts, layout, or a centralized theme file. Triggers include chest GUIs, MiniMessage, Adventure components, WCAG/contrast, item lore, GUI layout, readable text, UI polish, design tokens, and theme configuration.
---

# UI Design (Paper GUIs & Adventure Text)

Design player-facing UI — inventory GUIs, chat messages, headers, item names — that is readable, consistent, and accessible. Core principle: **UI is a consumer surface; readability and consistency beat decoration. WCAG AA contrast is the floor, not a goal. Keep visual tokens in one theme file instead of scattering colors and materials through handlers.**

## The text stack: Adventure + MiniMessage

Paper exposes the Adventure text stack in its API, and `MiniMessage` is available without adding a dependency. Do not pin a separate Adventure/MiniMessage dependency unless a non-Paper module genuinely needs one.

- Player-facing strings come from MiniMessage (config-driven, human-readable).
- Programmatic composition uses the `Component` API.
- Never emit legacy `§` codes.

## Theme file: recommended format

`theme.yml` at the root of this skill is an implementation-oriented reference for agents and plugin authors. It is optional, not a runtime file or exact API. Agents MAY adopt or adapt the format to the project's existing configuration conventions.

If an agent adopts or adapts this format, it MUST preserve semantic-token consistency: the same role keeps the same meaning across every screen, even when the project renames keys or uses a different file format.

The recommended shape is:

- `version`: an integer schema version.
- `tokens.<name>.color`: an `#RRGGBB` foreground color.
- `tokens.<name>.weight`: `regular` or `bold`.
- Suggested token roles: `title`, `money`, `body`, `muted`, `accent`, `success`, `warning`, `danger`, and `border`.
- `materials.<name>`: a Bukkit `Material` name; suggested names are `filler`, `back`, `close`, and `next`.

The values in `theme.yml` are safe starting defaults: gold and bold for `title`, gold and regular for `money`, white for `body`, gray for `muted` and `border`, aqua for `accent`, green for `success`, yellow for `warning`, red for `danger`, gray stained glass for `filler`, and arrow/barrier navigation materials. Preserve an existing project's palette instead of forcing these exact values.

When this format is adopted, use these implementation steps:

1. Copy or adapt `theme.yml` into the project's chosen resource/config location.
2. Load the chosen theme once during plugin startup into an immutable `UiTheme`; pass that object to renderers.
3. Resolve semantic tokens when building Components. Keep copy and MiniMessage templates in `messages.yml` separate from presentation tokens.
4. Validate configured colors against the actual rendered surface. Body tokens need 4.5:1, large text (≥18pt regular or ≥14pt bold) 3:1, and borders/icons/focus indicators 3:1. Report the token name and measured ratio for invalid values.
5. Validate operator overrides using the project's existing startup/config policy. Reject invalid or incomplete values rather than silently accepting them.

If a project does not adopt a separate theme file, its existing config or code format can provide the palette through one theme adapter/object. There is no need to introduce a second configuration hierarchy merely to match this reference. A project without operator customization can keep its palette in its existing configuration or one immutable object.

When a theme is adopted, apply `color` and `weight` from semantic tokens through the Component API. Keep raw theme values out of untrusted MiniMessage input. Keep one filler material and one set of navigation materials together so every screen uses the same visual language.

Keeping player copy separate from theme presentation lets a theme change update colors, weights, and materials without editing every renderer; a copy change can update `messages.yml` without changing the theme.

MiniMessage essentials (syntax per the official Adventure MiniMessage docs). These examples show syntax only; production renderers use semantic tokens from the adopted theme representation instead of copying literal colors.

```text
<color:#ffaa00>Gold</color>           hex color
<gradient:#ff5555:#55ffff>Title</gradient>
<bold>Header</bold> <italic>…</italic> <underlined>…</underlined> <strikethrough>…</strikethrough>
<newline>                             line break
<click:run_command:/homes>…</click>   run_command | suggest_command | open_url | copy_to_clipboard
<hover:show_text:'<yellow>Tooltip'>…</hover>
```

## Color and contrast: WCAG AA floor

WCAG 2.2 SC 1.4.3 (Contrast, Minimum, Level AA): **4.5:1 for normal text, 3:1 for large text** (≥18pt regular or ≥14pt bold). SC 1.4.11 (Non-text Contrast): **3:1 for UI component boundaries** (buttons, borders, icons, focus indicators). SC 1.4.1 (Use of Color): **color must not be the only visual cue** — pair with text, icon, or shape. Exceptions: inactive components, purely decorative text, logos.

Minecraft's default text is small — treat **4.5:1 as the floor for all body text**.

The table below is **illustrative** — ratios are computed against an **assumed dark background (#0F0F0F)** using the WCAG relative-luminance formula. Rendered inventory and chat backgrounds vary by client, resource pack, and GUI type; always measure against each actual rendered surface you ship.

| Color | Hex | Contrast (vs #0F0F0F) | AA normal (4.5) | AA large (3.0) |
|---|---|---|---|---|
| white | #FFFFFF | 19.17 | ✓ | ✓ |
| gray | #AAAAAA | 8.25 | ✓ | ✓ |
| gold | #FFAA00 | 10.04 | ✓ | ✓ |
| yellow | #FFFF55 | 17.97 | ✓ | ✓ |
| red | #FF5555 | 6.10 | ✓ | ✓ |
| green | #55FF55 | 14.44 | ✓ | ✓ |
| dark_green | #00AA00 | 6.16 | ✓ | ✓ |
| aqua | #55FFFF | 15.64 | ✓ | ✓ |
| dark_aqua | #00AAAA | 6.69 | ✓ | ✓ |
| light_purple | #FF55FF | 7.30 | ✓ | ✓ |
| blue | #5555FF | 3.77 | ✗ | ✓ |
| dark_purple | #AA00AA | 3.00 | ✗ | ✓ (borderline) |
| dark_gray | #555555 | 2.57 | ✗ | ✗ |
| dark_red | #AA0000 | 2.47 | ✗ | ✗ |
| dark_blue | #0000AA | 1.44 | ✗ | ✗ |
| black | #000000 | 1.10 | ✗ | ✗ |

Rules for any theme:

- Safe defaults on dark backgrounds: white, gray, gold, yellow, red, green, dark_green, aqua, dark_aqua, light_purple.
- Never use dark_gray, dark_red, dark_blue, dark_purple, blue, or black for body text on dark backgrounds.
- blue (#5555FF) and dark_purple pass only at large/bold sizes — reserve them for headers.

## Typography and fonts

Minecraft renders text with a fixed bitmap font — **font size is not freely controllable**. Hierarchy comes from weight, color, and spacing, not point size:

- **Title/header**: `title` token (default gold or yellow), bold.
- **Body**: `body` token (default white), regular.
- **Secondary/muted**: `muted` token (default gray).
- **Success**: `success` token (default green). **Danger/error**: `danger` token (default red).
- **Money/numbers**: `money` token (default gold).

Typography rules:

- Bold for headers only; never bold body text.
- Gradients and rainbow are decoration — one per screen, titles only, never body.
- Custom font faces require a **client resource pack**; without one the client falls back to the default font. Test every custom font with the resource pack absent to confirm the fallback stays readable.
- Never rely on color alone to convey state — pair with text or an icon (WCAG 1.4.1).

## Inventory GUI layout

- Sizes are multiples of 9, 9–54 for chest-type GUIs.
- Standard anatomy: row 0 = header, rows 1–4 = content, row 5 = footer (navigation).
- Fill empty slots with one consistent filler material from the adopted theme/config (the reference default is gray stained glass).
- Navigation in fixed slots: back (45), close (49), next (53) on a 54-slot GUI.
- Keep titles short — title width is a client-side rendering constraint, not a server-enforced limit. (The legacy `String`-title 32-char limit does not apply to Adventure `Component` titles.)
- Identify your inventories with a custom `InventoryHolder`, not by title or lore; check `inventory.getHolder(false) instanceof MyHolder` in the click listener.
- Cancel all `InventoryClickEvent`s and route by slot.

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
