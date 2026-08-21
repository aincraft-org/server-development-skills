---
name: project-setup
description: Use when creating a new Paper/Minecraft plugin project, writing or editing its Gradle build files, wrapper, plugin.yml, pinning toolchain or plugin versions, configuring CI or releases, or when paper-api coordinates fail to resolve. Triggers include scaffolding a new plugin repo, CalVer versioning, nightly releases, and questions about current Gradle, run-paper, or google-java-format versions.
---

# Project Setup (Paper 26.2 Plugin)

Canonical scaffold for Minecraft **26.2** plugin development. Core principle: **use the pinned versions below — never from memory.** Plugin versioning changed in the 26.x line; stale-memory coordinates do not resolve.

Pins verified 2026-08-21 against: Paper docs (project-setup, plugin-yml), Gradle Plugin Portal metadata, services.gradle.org, Maven Central.

## Pinned versions

| Component | Version |
|---|---|
| JDK toolchain | **25** |
| Gradle wrapper | **9.7.1** |
| paper-api | `io.papermc.paper:paper-api:26.2.build.+` |
| run-paper (`xyz.jpenilla.run-paper`) | **3.1.0** |
| Spotless (`com.diffplug.spotless`) | **8.10.0** |
| google-java-format | **1.36.1** |

Style: [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html) is the only style guide. Enforce mechanically via Spotless — never hand-format.

## Scaffold

```
gradle wrapper --gradle-version 9.7.1   # once, then commit gradlew/
```

`settings.gradle.kts`:

```kotlin
rootProject.name = "example-plugin"
```

`build.gradle.kts`:

```kotlin
plugins {
    java
    id("com.diffplug.spotless") version "8.10.0"
    id("xyz.jpenilla.run-paper") version "3.1.0"
}

val calverDate = java.time.LocalDate.now(java.time.ZoneOffset.UTC)
    .format(java.time.format.DateTimeFormatter.ofPattern("yyyy.MM.dd"))

// CI: YYYY.MM.DD.<github_run_number>; local builds: dated -SNAPSHOT.
version = providers.gradleProperty("buildVersion")
    .orElse(
        providers.environmentVariable("GITHUB_RUN_NUMBER")
            .map { "$calverDate.$it" }
    )
    .orElse("$calverDate-SNAPSHOT")
    .get()

repositories {
    maven {
        name = "papermc"
        url = uri("https://repo.papermc.io/repository/maven-public/")
    }
    mavenCentral()
}

dependencies {
    compileOnly("io.papermc.paper:paper-api:26.2.build.+")
}
processResources {
    filesMatching("plugin.yml") {
        expand("version" to version)
    }
}


java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(25))
}

spotless {
    java {
        googleJavaFormat("1.36.1")
    }
}

tasks {
    runServer {
        minecraftVersion("26.2")
    }
}
```

`src/main/resources/plugin.yml` (api-version MUST be quoted — unquoted `26.2` parses as a YAML float):

```yaml
name: ExamplePlugin
version: '${version}'
api-version: '26.2'
description: An example plugin
```

Main class — one class extends `JavaPlugin`; never name it `Main`; Google style = 2-space indent, 100-col limit, no wildcard imports:

```java
package io.github.username;

import org.bukkit.plugin.java.JavaPlugin;

public final class ExamplePlugin extends JavaPlugin {

  @Override
  public void onEnable() {
    getLogger().info("ExamplePlugin enabled");
  }
}
```

## Multi-module layout (recommended for Java)

For Java projects expected to grow beyond a single module, prefer a `[plugin]-common`, `[plugin]-api`, and `[plugin]-paper` multi-module Gradle layout. This is a recommendation, not a requirement — keep small plugins single-module until the separation provides clear value.

```text
[plugin]/
├── [plugin]-common/   # shared domain models, logic, utilities
├── [plugin]-api/      # public plugin interfaces and contracts
└── [plugin]-paper/    # Paper implementation, commands, listeners, plugin.yml
```

Dependency direction: `[plugin]-paper` → `[plugin]-api` → `[plugin]-common`. The Paper module depends only on the API boundary; platform code stays behind the API.

## Verify the setup

```bash
./gradlew build spotlessCheck   # compiles; FAILS on style violations; resolution errors = wrong coordinates
./gradlew spotlessApply         # fixes violations in place (local use only, never in CI)
./gradlew runServer             # downloads Paper 26.2, launches test server with the plugin jar
```

## Common mistakes (observed in baseline testing)

| Wrong | Right | Why |
|---|---|---|
| `paper-api:26.2-R0.1-SNAPSHOT` | `paper-api:26.2.build.+` | `-R0.1-SNAPSHOT` scheme is gone in 26.x; old coordinates fail resolution |
| run-paper `2.3.1` | `3.1.0` | stale major; 3.x targets current Minecraft |
| `com.github.sherter.google-java-format` | Spotless + `googleJavaFormat` | sherter plugin is abandoned |
| Gradle `8.x` wrapper | `9.7.1` | current stable |
| `com.example.*` package | `io.github.<name>.*` | Paper convention: reverse-domain |
| `version = "1.0.0"` | CalVer from `GITHUB_RUN_NUMBER` | Use the `ci-release` convention; versions must be unique and sortable |
| 4-space indent by hand | `./gradlew spotlessApply` | Google style is 2-space; enforce, don't hand-format |
| `api-version: 26.2` unquoted | `api-version: '26.2'` | YAML parses it as float |

Reproducibility option: after first resolve, pin the exact paper-api build (e.g. `26.2.build.112-stable`) instead of `+`.

## Version bumps

On a Minecraft update, exactly three values change together: `paper-api` coordinate, `runServer.minecraftVersion`, `api-version`. Re-verify all three against docs.papermc.io before committing — never assume the new scheme matches the old one.
