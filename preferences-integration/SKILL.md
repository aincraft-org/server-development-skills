---
name: preferences-integration
description: Use when hooking a Paper plugin into the Preferences plugin — registering typed preferences, loading PreferencesService, choosing player vs global scope, picking a PreferenceCodec, reading or writing preference values programmatically, reacting to PreferenceChangeEvent, or debugging why a preference does not persist or show in the /preferences dialog. Triggers include PreferencesService, PreferenceBuilder, PreferenceCodec, StorageCodec, PreferenceChangeEvent, /preferences, and plugins/Preferences/data.
---

# Preferences Integration (Hooking Plugin)

Give your Paper plugin typed, GUI-editable, persisted preferences by registering them with the
**Preferences** plugin. You declare the preference; Preferences owns the dialog GUI, validation,
caching, permissions, and debounced YAML persistence.

Core principle: **register once in `onEnable`; read and write through the typed `Preference<T>` handle; never touch the plugin's data files or internal classes.**

Pins verified 2026-08-24 against this repository (AGENTS.md usage guide, `preferences-api` sources, `preferences-paper` plugin.yml, root build).

## Pinned versions

| Component | Version |
|---|---|
| preferences-api | `dev.mintychochip:preferences-api:0.2.0` |
| paper-api | `io.papermc.paper:paper-api:26.2.build.+` |
| Java toolchain | **25** |

The API coordinate is documented in the Preferences usage guide (AGENTS.md). Resolve locally
with `./gradlew :preferences-api:publishToMavenLocal` from the Preferences repo when testing
against an unpublished build.

## 1. Declare the dependency

`plugin.yml`:

```yaml
depend: [Preferences]      # core behavior requires preferences — fail fast
# or
softdepend: [Preferences]  # degrade gracefully when absent
```

Use `depend` when your plugin's core behavior needs preferences (you disable yourself when the
service is missing); use `softdepend` when preferences are optional. Preferences loads first in
either case.

`build.gradle.kts`:

```kotlin
repositories {
    mavenLocal() // after :preferences-api:publishToMavenLocal
    maven {
        url = uri("https://maven.pkg.github.com/aincraft-org/preferences")
        credentials {
            username = project.findProperty("gpr.user") as String?
                ?: System.getenv("GITHUB_ACTOR")
            password = project.findProperty("gpr.key") as String?
                ?: System.getenv("GITHUB_TOKEN")
        }
    }
    maven("https://repo.papermc.io/repository/maven-public/")
}

dependencies {
    compileOnly("dev.mintychochip:preferences-api:0.2.0")
    compileOnly("io.papermc.paper:paper-api:26.2.build.+")
}
```

## 2. Load the service

```java
PreferencesService prefs = Bukkit.getServicesManager().load(PreferencesService.class);
if (prefs == null) {
    getLogger().severe("Preferences service missing!");
    getServer().getPluginManager().disablePlugin(this);
    return;
}
```

## 3. Register preferences

```java
Preference<Boolean> notifications = prefs.register(this, Boolean.class, b -> b
    .playerScoped("notifications")
    .label(Component.text("Notifications"))
    .description(Component.text("Receive notifications"))
    .codec(PreferenceCodec.booleanBox())
    .defaultValue(true)
    .onChange(c -> getLogger().info("notifications: " + c.oldValue() + " -> " + c.newValue())));
```

- `.playerScoped(name)` — per-player value. `.global(name)` — server-wide.
- `label`, `codec`, `defaultValue` required; `description` and `onChange` optional.
- Keys are **namespaced per plugin**: `PreferenceKey` = `<plugin-name-lowercase>:<name>`
  (e.g. `myplugin:volume`). Namespace derives from `plugin.getName().toLowerCase()`. Names must
  match `[a-z0-9_-]+` — no dots (Bukkit YAML path separator corrupts storage).
- Duplicate registration of the same key throws `IllegalStateException`.

### Built-in codecs

| Factory | Type | Dialog control |
|---|---|---|
| `PreferenceCodec.string(maxLength)` | `String` | Text field |
| `PreferenceCodec.booleanBox()` | `Boolean` | Checkbox |
| `PreferenceCodec.integerSlider(min, max, step)` | `Integer` | Slider |
| `PreferenceCodec.longSlider(min, max, step)` | `Long` | Slider |
| `PreferenceCodec.floatSlider(min, max, step)` | `Float` | Slider |
| `PreferenceCodec.doubleSlider(min, max, step)` | `Double` | Slider |
| `PreferenceCodec.enumerated(EnumClass.class, e -> Component.text(...))` | enum | Option picker |
| `PreferenceCodec.storageOnly(storageCodec)` | any | none (read-only in GUI) |

Custom types: implement `StorageCodec<T>` (`parse(String)` / `write(T)`, must round-trip) and
optionally `DialogInputAdapter<T>`, then bundle with `PreferenceCodec.storageOnly(...)` or a
custom `PreferenceCodec`.

## 4. Programmatic access

```java
int val = volume.get(player);        // player-scoped read
volume.set(player, 12);              // validates, fires event, caches, queues async persist
volume.reset(player);                // revert to default

boolean g = announceLogins.getGlobal();   // global read
announceLogins.setGlobal(value);          // editor == null in the event
announceLogins.setGlobal(admin, value);   // attributes change to an admin
announceLogins.resetGlobal();
```

**Wrong-scope accessors throw** — `get(player)`/`set(player, ...)` on a global preference and
`getGlobal()`/`setGlobal(...)` on a player-scoped one. Match the accessor to the scope you
declared.

`set` fires a cancellable `PreferenceChangeEvent` before persistence; cancellation aborts the
change. Values persist **asynchronously** — allow the flush window (default 5s) before asserting
hard on disk.

## 5. React to changes

Bukkit event (fires before persistence, cancellable):

```java
@EventHandler
public void onPreferenceChange(PreferenceChangeEvent e) {
    PreferenceKey key = e.key();   // namespace:name, e.g. "myplugin:volume"
    String oldV = e.oldValue();     // stored-string form, NOT the typed value
    String newV = e.newValue();
    e.setCancelled(true);           // block the change entirely
}
```

`oldValue()`/`newValue()` are **stored-string forms** produced by the `StorageCodec`, not typed
Java values. For typed values, read through the `Preference<T>` handle (`pref.get(player)`).
`e.editor()` is the editing player's UUID, or `null` for programmatic/console changes.

Or the per-preference callback: `b.onChange(c -> ...)` with `PreferenceChange(key, oldValue, newValue)`.

## Verify

```bash
./gradlew :preferences-api:build :preferences-common:build :preferences-paper:build :preferences-test:build test
./gradlew :preferences-test:runServer   # local Paper 26.2 smoke server
```

Start the server, run `/preferences` as a player, confirm your preferences appear with the right
controls, change a value, restart, and confirm it survived. Confirm the data file
`plugins/Preferences/data/<plugin-name-lowercase>.yml` is created.

## Common mistakes (observed in baseline testing)

| Wrong | Right | Why |
|---|---|---|
| `depend` when preferences are optional | `softdepend` | A missing Preferences plugin hard-fails startup for no reason |
| Reading typed values from `PreferenceChangeEvent` | `pref.get(player)` / stored strings from the event | Event payloads are stored-string forms, not typed values |
| Calling `get(player)` on a global preference | `getGlobal()` (and vice versa) | Wrong-scope accessors throw |
| Importing `dev.mintychochip.preferences.common.internal.*` | Import only `dev.mintychochip.preferences.api.*` | Internal classes are not part of the stable API |
| Baking a namespaced key into dialog input | Vanilla `[a-zA-Z0-9_]` input keys | Namespaced keys break dialog rendering |
| Asserting on disk immediately after `set` | Allow the flush window (default 5s) | Persistence is debounced and asynchronous |
| Hand-editing `plugins/Preferences/data/*.yml` while the server runs | Stop the server first | A later flush overwrites manual edits |
| Guessing the namespace for keys/filtering | `<plugin-name-lowercase>:<name>` | Derived from `plugin.getName().toLowerCase()` |
