# Color and Contrast (Reference)

Deep reference for the WCAG AA contrast route in `../SKILL.md`. Read when choosing colors, validating a palette, or measuring a rendered surface.

## The floor

WCAG 2.2 SC 1.4.3 (Contrast, Minimum, Level AA): **4.5:1 for normal text, 3:1 for large text** (≥18pt regular or ≥14pt bold). SC 1.4.11 (Non-text Contrast): **3:1 for UI component boundaries** (buttons, borders, icons, focus indicators). SC 1.4.1 (Use of Color): **color must not be the only visual cue** — pair with text, icon, or shape. Exceptions: inactive components, purely decorative text, logos.

Minecraft's default text is small — treat **4.5:1 as the floor for all body text**.

## The reference table

Illustrative — ratios are computed against an **assumed dark background (#0F0F0F)** using the WCAG relative-luminance formula. Rendered inventory and chat backgrounds vary by client, resource pack, and GUI type; always measure against each actual rendered surface you ship.

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

## Rules for any theme

- Safe defaults on dark backgrounds: white, gray, gold, yellow, red, green, dark_green, aqua, dark_aqua, light_purple.
- Never use dark_gray, dark_red, dark_blue, dark_purple, blue, or black for body text on dark backgrounds.
- blue (#5555FF) and dark_purple pass only at large/bold sizes — reserve them for headers.

## Measuring real surfaces

The table above is a starting point, not the gate. The rendered background varies: inventory GUIs (per-client GUI background, affected by resource packs), chat (client theme), action bar, boss bar, item lore (tooltip background), scoreboards. For each surface you ship:

1. Compute ratios against the actual background color players see (default client values or the project's resource pack).
2. Validate the theme's configured colors against those surfaces as part of the startup/adoption step (see `01-theme-tokens.md`).
3. Report the token name and measured ratio for invalid values — do not silently adjust.

## Common mistakes

| Mistake | Correction |
|---|---|
| dark_red/dark_blue/dark_gray text on dark GUI | white/gray/gold/yellow/green/red/aqua/light_purple — fails 4.5:1 |
| Blue text for body | Blue only for large/bold headers: #5555FF is 3.77:1 |
| Assuming the reference table's background | Measure each actual rendered surface; backgrounds vary by client and pack |
| Color alone signals state | Pair color with text/icon (WCAG 1.4.1); color-blind players miss it |
| Judging contrast by eye on a bright dev monitor | Compute ratios; the eye lies under backlight and gamma |