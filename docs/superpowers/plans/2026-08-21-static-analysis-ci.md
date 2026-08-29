# Static Analysis CI Implementation Plan

> **For agentic workers:** REQUIRED: Implement this plan task-by-task, per the `spec-driven-development` execution rules. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Paper plugin setup and CI guidance execute Spotless, Checkstyle, PMD, and SpotBugs as mandatory Gradle quality gates.

**Architecture:** `project-setup/SKILL.md` owns the canonical Gradle configuration, including built-in Gradle Checkstyle/PMD plugins, their tool versions, and the externally versioned SpotBugs plugin. `ci-release/SKILL.md` invokes the single lifecycle command `./gradlew clean check` for build and release workflows. README descriptions mirror those responsibilities.

**Tech Stack:** Markdown skill documents, Gradle Kotlin DSL snippets, Gradle Checkstyle/PMD built-in plugins, SpotBugs Gradle plugin, Spotless, GitHub Actions.

## Global Constraints

- All configured analyzer violations MUST fail the build.
- `check` MUST depend on all available analyzer tasks; CI MUST invoke exactly `./gradlew clean check` as its quality gate.
- Checkstyle and PMD plugin IDs are Gradle built-ins; document their `toolVersion` pins rather than inventing plugin versions.
- SpotBugs is an external Gradle plugin and requires a verified plugin-version pin.
- Do not document `spotbugsTest` or any task name unless verified against the selected plugin version; prefer task-type wiring when availability differs.
- `spotlessApply` is local-only and MUST NOT run in CI.
- Record official-source verification dates for all version pins.
- Preserve separate atomic commits for project setup and CI/release changes.
- Skip formatters, linters, and project-wide test suites during task execution; run repository verification once at the end.

---

### Task 1: Verify analyzer versions and task model

**Files:**
- Modify: `project-setup/SKILL.md` only if verification reveals an existing stale pin during this task.

**Interfaces:**
- Produces the exact verified SpotBugs Gradle plugin version, Checkstyle tool version, PMD tool version, SpotBugs engine version if separately configured, and the actual task types created by each plugin.

- [ ] **Step 1: Inspect official metadata**

Check the Gradle Plugin Portal and official project documentation for the selected SpotBugs Gradle plugin, Checkstyle, PMD, and SpotBugs versions. Record source URLs and verification date in working notes.

- [ ] **Step 2: Verify task availability**

Use a minimal temporary Gradle project with the candidate plugins and Java source sets. Run `./gradlew tasks --all` and inspect task names/types. Confirm whether SpotBugs creates main-only or main/test tasks and identify safe `tasks.withType<...>` wiring.

- [ ] **Step 3: Record the implementation contract**

Choose the smallest executable snippet that applies the built-in `checkstyle` and `pmd` plugins, applies the external SpotBugs plugin, sets tool versions, enables XML/HTML reports, and attaches analyzer task types to `check` without hardcoded nonexistent tasks.

- [ ] **Step 4: Preserve evidence**

Keep the verified version/source details available for Tasks 2 and 3. Do not commit this task separately; it is prerequisite research for the project-setup documentation commit.

---

### Task 2: Update project setup quality gates

**Files:**
- Modify: `project-setup/SKILL.md`
- Modify: `README.md` project-setup catalog row

**Interfaces:**
- Consumes: Task 1’s verified versions and task types.
- Produces: A copyable `build.gradle.kts` analyzer configuration and a canonical `./gradlew clean check` verification command.

- [ ] **Step 1: Write the failing documentation checks**

Create a temporary shell/Python consistency check (not committed) that asserts the updated skill contains:

```text
id("com.diffplug.spotless")
id("com.github.spotbugs")
checkstyle
pmd
spotbugs
./gradlew clean check
```

and rejects unsupported hardcoded task references such as `spotbugsTest` unless Task 1 verified that task.

- [ ] **Step 2: Run the checks before editing**

Run the temporary check against the current documents. Expected: FAIL because the current project-setup skill has no Checkstyle, PMD, or SpotBugs configuration and uses `build spotlessCheck` rather than the canonical quality gate.

- [ ] **Step 3: Update pinned-version guidance**

Separate Gradle built-in plugin IDs from tool versions. Keep the existing verified Gradle/Java/Spotless/run-paper pins. Add a table containing the verified Checkstyle tool version, PMD tool version, SpotBugs Gradle plugin version, and any SpotBugs engine version. State the official source and verification date for each.

- [ ] **Step 4: Add executable Gradle Kotlin DSL**

Add a complete configuration following this shape, replacing the angle-bracket markers with Task 1’s verified values and exact plugin task types before committing. The markers are planning notation only and MUST NOT remain in the skill:

```kotlin
plugins {
    java
    checkstyle
    pmd
    id("com.diffplug.spotless") version "8.10.0"
    id("com.github.spotbugs") version "6.5.10"
    id("xyz.jpenilla.run-paper") version "3.1.0"
}

checkstyle {
    toolVersion = "13.11.0"
    config = resources.text.fromUri(
        "https://raw.githubusercontent.com/checkstyle/checkstyle/checkstyle-13.11.0/src/main/resources/google_checks.xml"
    )
}

pmd {
    toolVersion = "7.26.0"
    isIgnoreFailures = false
}

spotbugs {
    toolVersion.set("4.9.7")
    ignoreFailures.set(false)
}

tasks.withType<Checkstyle>().configureEach {
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

tasks.withType<Pmd>().configureEach {
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

tasks.withType<com.github.spotbugs.snom.SpotBugsTask>().configureEach {
    reports {
        create("xml") { required.set(true) }
        create("html") { required.set(true) }
    }
}

tasks.named("check") {
    dependsOn(tasks.withType<Checkstyle>())
    dependsOn(tasks.withType<Pmd>())
    dependsOn(tasks.withType<com.github.spotbugs.snom.SpotBugsTask>())
}
```

Use the verified plugin API if the report DSL differs; do not publish a snippet that has not parsed in the temporary project.

- [ ] **Step 5: Update verification and mistakes**

Make `./gradlew clean check` the primary verification command. Retain `./gradlew spotlessApply` as local-only. Add common mistakes covering: invoking `build` without `check`, treating built-in plugins as externally pinned, assuming `spotbugsTest` exists, setting report-only behavior, and forgetting to wire analyzer task types into `check`.

- [ ] **Step 6: Update README discoverability**

Change only the project-setup row to mention executable Spotless, Checkstyle, PMD, and SpotBugs quality gates.

- [ ] **Step 7: Run the documentation checks**

Run the temporary consistency check. Expected: PASS, including frontmatter, required sections, exact quality command, and absence of unsupported task names.

- [ ] **Step 8: Commit the project-setup unit**

```bash
git add project-setup/SKILL.md README.md
git commit -m "Tune project setup static analysis gates"
```

The commit must contain only project-setup analyzer configuration and its catalog wording.

---

### Task 3: Update CI and release quality gates

**Files:**
- Modify: `ci-release/SKILL.md`
- Modify: `README.md` ci-release catalog row

**Interfaces:**
- Consumes: The canonical `check` contract documented by Task 2.
- Produces: CI, nightly, and stable-release examples that cannot bypass static analysis.

- [ ] **Step 1: Write the failing documentation checks**

Create a temporary consistency check that asserts every Gradle invocation in CI/release examples uses `./gradlew clean check`, and rejects `./gradlew build spotlessCheck` as the primary gate.

- [ ] **Step 2: Run the checks before editing**

Expected: FAIL because current build and release snippets invoke `build spotlessCheck`.

- [ ] **Step 3: Update CI workflow examples**

Replace build and nightly commands with:

```yaml
- run: ./gradlew clean check
```

Keep Java setup, Gradle setup, permissions, and release behavior unchanged unless required to ensure publishing follows the successful gate.

- [ ] **Step 4: Update stable release example**

Replace the stable release build command with:

```bash
./gradlew -PbuildVersion="$VERSION" clean check
```

Keep the exact version override and ensure release publishing remains a later step.

- [ ] **Step 5: Update guidance and mistakes**

State that `check` is the canonical quality gate and includes formatting plus all configured static analyzers. Add common mistakes for running `build` alone, invoking only `spotlessCheck`, and publishing before `clean check` succeeds.

- [ ] **Step 6: Update README discoverability**

Change only the ci-release row to mention mandatory static-analysis CI gates alongside release workflows.

- [ ] **Step 7: Run the documentation checks**

Run the temporary consistency check. Expected: PASS with no stale primary CI command.

- [ ] **Step 8: Commit the CI/release unit**

```bash
git add ci-release/SKILL.md README.md
git commit -m "Gate CI releases on static analysis"
```

The commit must contain only CI/release quality-gate guidance and its catalog wording.

---

### Task 4: Final repository verification

**Files:**
- Verify: `project-setup/SKILL.md`
- Verify: `ci-release/SKILL.md`
- Verify: `README.md`
- Verify: `docs/superpowers/specs/2026-08-21-static-analysis-ci-design.md`
- Verify: `docs/superpowers/plans/2026-08-21-static-analysis-ci.md`

- [ ] **Step 1: Validate skill frontmatter and required sections**

Run a repository-local script that parses each changed SKILL.md frontmatter and confirms `name`, trigger-style `description`, and `Common mistakes` are present.

- [ ] **Step 2: Validate command consistency**

Assert that `project-setup` uses `./gradlew clean check` as its canonical gate and `ci-release` uses that command in build/nightly examples plus the `-PbuildVersion` form for stable releases.

- [ ] **Step 3: Validate task-name safety**

Assert that no unsupported hardcoded SpotBugs task names appear. Confirm the documented `tasks.withType` class and plugin API match the verified plugin version from Task 1.

- [ ] **Step 4: Review atomic history and status**

Run `git status --short` and inspect the final diffs for each commit. Confirm the project-setup and ci-release commits are separate and each tree state is documentation-consistent.

- [ ] **Step 5: Mark completion only after evidence**

Report the exact verification commands and observed pass/fail results. Do not claim a real plugin build was executed in this repository because it contains skill documentation rather than a Gradle project.
