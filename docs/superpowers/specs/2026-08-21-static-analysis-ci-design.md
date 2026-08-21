# Static Analysis CI Design

## Goal

Tune the Paper plugin setup and CI skills so new projects run Spotless, Checkstyle, PMD, and SpotBugs as executable, mandatory Gradle quality gates.

## Scope

This is a targeted update to `project-setup/SKILL.md`, `ci-release/SKILL.md`, and the README skill catalog. It does not create a new skill or change the other domain skills.

## Design

`project-setup` owns the canonical Gradle configuration. It will pin and apply Checkstyle, PMD, and SpotBugs alongside the existing Java, Spotless, and run-paper plugins. The configuration will use executable task wiring: Checkstyle and PMD use their actual source-set task types, while SpotBugs is wired only through task types provided by the selected plugin/version. The documentation must not promise a task such as `spotbugsTest` unless verification shows that task exists.

Analyzer violations fail the build. Reports include machine-readable XML and developer-readable HTML where supported. The Gradle `check` lifecycle is the single local and CI contract, so all available analyzer tasks must be dependencies of `check` without requiring callers to remember a separate task list.

`ci-release` owns workflow invocation and release gating. Build, nightly, and stable-release examples will use the exact command `./gradlew clean check`; publishing occurs only after that command succeeds. `spotlessApply` remains a local formatting command and is never run by CI.

The README catalog will advertise the quality-gate capability so the documented skill purpose matches the implementation.

## Version and verification policy

Every new plugin/tool version must be checked against its official repository or Gradle Plugin Portal metadata and recorded with the existing verification date. The implementation must verify the actual Gradle task graph for the pinned plugin versions before documenting task names.

## Failure handling

- Formatting violations fail through `spotlessCheck`.
- Checkstyle violations fail through Checkstyle tasks.
- PMD violations fail through PMD tasks.
- SpotBugs violations fail through SpotBugs tasks.
- Missing analyzer tasks must not be referenced by name; task-type wiring or guarded configuration must keep the canonical snippet executable.
- CI must not publish artifacts if `clean check` fails.

## Atomic change boundaries

1. `project-setup/SKILL.md` plus the README project-setup catalog wording: Gradle analyzer setup and discoverability.
2. `ci-release/SKILL.md` plus the README ci-release catalog wording: CI and release quality-gate invocation.

These boundaries preserve the repository convention of one skill change per commit. If README wording cannot be cleanly assigned, it becomes a separate documentation commit.

## Verification

The completed work must be checked for valid frontmatter and required skill sections, exact CI command consistency, absence of unsupported SpotBugs task names, and internal agreement between Gradle task wiring and the documented verification commands. The repository has no project Gradle build; verification is therefore documentation/static consistency checking rather than executing `./gradlew` in this skills repository.
