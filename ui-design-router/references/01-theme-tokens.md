# Theme Tokens (Reference)

Deep reference for the semantic theming route in `../SKILL.md`. Read when adopting or adapting `theme.yml`, defining roles, or validating a theme at startup. The canonical format and safe starting defaults ship as [`../theme.yml`](../theme.yml).

## The contract

`theme.yml` is the canonical format reference and the source of safe starting defaults. The file is **optional** — no plugin is required to ship it, and it is not a runtime file or a required API. Agents MAY copy it verbatim or adapt it to the project's existing configuration conventions (YAML, JSON, TOML, or a code object). Adapting keeps the same semantic roles with the same meanings; do not introduce a second configuration hierarchy next to an existing one just to match this reference.

### Format contract

- `version`: integer schema version. Loaders MUST reject unsupported versions at startup.
- `tokens.<name>.color`: an `#RRGGBB` foreground color.
- `tokens.<name>.weight`: `regular` or `bold`.
- `materials.<name>`: a Bukkit `Material` enum name.
- Token names are lowercase `[a-z][a-z0-9_]*`. The nine roles below are the semantic contract: each meaning is fixed and MUST NOT be repurposed. An adopted `theme.yml` keeps the canonical names; a project MAY add roles beyond the nine. Only when adapting the format to an existing configuration (JSON, TOML, code object, or the project's own config) may key names differ — a renamed key keeps its role's meaning on every screen.

### Default token roles

The hex values are starting defaults only — preserve an existing project's palette instead of forcing them. The roles and their meanings are the contract.

| Token | Default color | Default weight | Use for |
|---|---|---|---|
| `title` | `#FFAA00` | bold | GUI/section headers, titles |
| `money` | `#FFAA00` | regular | currency, prices, numeric values |
| `body` | `#FFFFFF` | regular | default player-facing text |
| `muted` | `#AAAAAA` | regular | hints, secondary info, timestamps |
| `accent` | `#55FFFF` | regular | interactive emphasis, focus indicators |
| `success` | `#55FF55` | regular | successful outcomes |
| `warning` | `#FFFF55` | regular | warnings, caution |
| `danger` | `#FF5555` | regular | errors, destructive actions |
| `border` | `#AAAAAA` | regular | frame borders, dividers, separators |

### Default material roles

| Material key | Default | Use for |
|---|---|---|
| `filler` | `GRAY_STAINED_GLASS_PANE` | empty slots on every screen |
| `back` | `ARROW` | navigation slot 45 (54-slot GUI) |
| `close` | `BARRIER` | navigation slot 49 |
| `next` | `ARROW` | navigation slot 53 |

Use one filler material and one set of navigation materials so every screen uses the same visual language (see `04-inventory-layout.md`).

## Adopting the format

Use these steps when the project adopts the format:

1. Copy `theme.yml` into the project's chosen resource/config location (commonly `src/main/resources/theme.yml`). Keep `version` and the token/material roles; change colors, weights, and materials to match the project palette.
2. Load the theme **once during plugin startup**. Validate everything: the `version` is supported, every color parses as `#RRGGBB`, every weight is `regular` or `bold`, every material resolves to a Bukkit `Material`. Apply operator overrides using the project's existing startup/config policy, then validate again. Reject invalid or incomplete values and fail startup — never silently skip a bad entry.
3. Freeze the validated result into one immutable `UiTheme` object; pass that object to renderers. Renderers resolve semantic tokens at build time — `theme.token("title").color()` / `.weight()`, `theme.material("filler")` — and never read hex codes or materials anywhere else.
4. Keep player copy and MiniMessage templates in `messages.yml`, separate from the presentation tokens in `theme.yml`. A theme change updates colors, weights, and materials without editing renderers or copy; a copy change updates `messages.yml` without touching the theme.
5. Validate every configured color against the actual rendered surface: body tokens need 4.5:1, large text (≥18pt regular or ≥14pt bold) 3:1, and borders/icons/focus indicators 3:1. Report the token name and measured ratio for invalid values.

## Validation and lookup rules

Every bad input is an error at startup, named by key; nothing is silently skipped:

- Unsupported `version` → fail startup.
- Missing fixed role → fail startup. The nine tokens and four materials above are all required in an adopted file.
- Invalid value → fail startup, name the key: a `color` that does not parse as `#RRGGBB`, a `weight` other than `regular` or `bold`, a material that does not resolve to a Bukkit `Material`.
- Extra keys are allowed (a project MAY add tokens/materials), but they follow the same rules and must not reuse a fixed role's meaning under a new name.
- Runtime lookups: `theme.token(name)` / `theme.material(name)` throw when the name is absent from the validated theme — a renderer typo fails fast. Never fall back to defaults silently.

## Minimal load, validate, and resolve

The loader runs once in plugin startup, validates, and freezes the theme (Paper 1.21+ API, illustrative — the shape matters, not the exact calls):

```java
ConfigSection file = YamlConfiguration.loadConfiguration(
        new InputStreamReader(plugin.getResource("theme.yml"), StandardCharsets.UTF_8));
if (file.getInt("version") != 1) throw new IllegalStateException("theme.yml: unsupported version");

UiTheme.Builder b = UiTheme.builder();
for (TokenRole role : TokenRole.FIXED) {  // title, money, body, muted, accent, success, warning, danger, border
    String hex    = file.getString("tokens." + role.id() + ".color");
    String weight = file.getString("tokens." + role.id() + ".weight", "regular");
    if (hex == null || !hex.matches("^#[0-9a-fA-F]{6}$")) {
        throw new IllegalStateException("theme.yml: invalid color for " + role.id() + ": " + hex);
    }
    if (!weight.equals("regular") && !weight.equals("bold")) {
        throw new IllegalStateException("theme.yml: invalid weight for " + role.id() + ": " + weight);
    }
    b.token(role, TextColor.fromHexString(hex),
            weight.equals("bold") ? TextDecoration.State.TRUE : TextDecoration.State.FALSE);
}
for (MaterialRole role : MaterialRole.FIXED) {  // filler, back, close, next
    String name = file.getString("materials." + role.id());
    Material m = name == null ? null
            : Registry.MATERIAL.get(NamespacedKey.minecraft(name.toLowerCase(Locale.ROOT)));
    if (m == null) throw new IllegalStateException("theme.yml: invalid material for " + role.id() + ": " + name);
    b.material(role, m);
}
UiTheme theme = b.build();  // immutable; pass to every renderer
```

Then build a Component from a resolved token:

```java
UiToken title = theme.token("title");
Component header = Component.text("Your Homes").style(
    style -> style
        .color(title.color())
        .decoration(TextDecoration.BOLD, title.weight() == Weight.BOLD
            ? TextDecoration.State.TRUE : TextDecoration.State.FALSE)
);
```

Never put raw theme values into untrusted MiniMessage input — renderers own the token-to-MiniMessage conversion.

## Not adopting the format

If a project does not adopt a separate theme file, its existing config or code format can provide the palette through one theme adapter/object — one immutable object exposing the same roles. There is no need for a second configuration hierarchy. The semantic-token consistency rule still applies: the same role keeps the same meaning across every screen, even when the project renames keys or uses a different file format.

## Common mistakes

| Mistake | Correction |
|---|---|
| Treating `theme.yml` as mandatory project configuration | Adopt or adapt its format only when useful; one theme object with the same roles suffices |
| Per-screen token names for one role | One shared role name per meaning — the semantic contract |
| Invalid theme entries silently skipped | Reject at startup and name the offending key |
| Falling back to defaults on runtime lookup miss | Fail fast: throw on absent tokens/materials |
| Two config hierarchies (project config + theme.yml) | Adapt the theme into the project's existing format |
| Raw hex in MiniMessage templates | Renderers convert tokens; never interpolate raw palette into untrusted input |