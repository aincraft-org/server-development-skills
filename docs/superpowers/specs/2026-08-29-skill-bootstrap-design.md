# Skill Bootstrap and Profile Installer Design

**Date:** 2026-08-29
**Status:** approved for implementation

## Goal

Provide one first-party `skill-bootstrap` workflow plus install/update scripts that configure the repository's Paper skills and selected external Pi/Codex skills without vendoring third-party repositories as Git submodules, silently tracking upstream `main`, installing global tools, or changing credentials.

## Scope

### In scope

- A new `skill-bootstrap/SKILL.md` that guides an agent through profile selection, installation, update, latest-version checks, prerequisite handling, and verification.
- `scripts/install-skills.sh` for installing the `paper`, `superpowers`, `google-sheets`, and `all` profiles for an explicit `pi`, `codex`, or `both` target.
- `scripts/update-skills.sh` for reconciling the same pinned refs and a read-only `--check-latest` mode.
- A shared Bash parser/helper and a maintainer smoke-test script so the Markdown-embedded catalog is validated before any installation command runs.
- A strict machine-readable catalog block inside `skill-bootstrap/SKILL.md`; it is the sole source of profile membership and external refs.
- A README catalog entry and script usage documentation.

### Out of scope

- Adding `obra/superpowers`, `googleworkspace/cli`, or any other external repository as a Git submodule.
- Installing the `gws` binary, Node, Pi, Codex, or any other global package.
- Running OAuth setup, opening a browser, handling credentials, or mutating Google Cloud configuration.
- Automating Superpowers installation through Codex's marketplace; the official marketplace/plugin action remains a documented manual step.
- Supporting harnesses other than Pi and Codex in this change.
- Automatically changing the pinned refs or editing `SKILL.md` during an update.

## Profiles and sources

`paper` contains every current native skill listed in `README.md`: `project-setup`, `ci-release`, `autonomous-testing`, `database-integration`, `performance-optimization`, `ui-design`, `docs-maintenance`, `spec-driven-development`, `pebblehost-deploy`, `development-network`, and `proxy-first-paper-smoke`. It installs from the current checkout so forks and local changes remain usable.

`superpowers` uses the official `obra/superpowers` release tag `v6.3.0`, whose resolved commit is `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`. Pi uses the upstream Pi package install path. Codex uses the official Codex plugin marketplace action documented by Superpowers; scripts print the exact manual action and never copy Superpowers into a Codex skill directory.

`google-sheets` installs the complete dependency closure from `googleworkspace/cli` at commit `a3768d0e82ad83cca2da97724e46bea4ff0e6dbd`: `gws-shared`, `gws-sheets`, `gws-sheets-append`, and `gws-sheets-read`. The profile checks whether `gws` is on `PATH` and prints the official install/authentication guidance when it is absent.

`all` is the composition of the three profiles, not a fourth independent source set.

The standard `skills` CLI is pinned to npm package version `1.5.23`; scripts invoke `npx --yes skills@1.5.23`, never bare `npx skills`.

Pins and source ownership were checked 2026-08-29 against:

- [Pi package installation](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md)
- [Pi skill discovery](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md)
- [Superpowers installation matrix](https://github.com/obra/superpowers/blob/main/README.md)
- [Superpowers Codex manifest](https://github.com/obra/superpowers/blob/main/.codex-plugin/plugin.json)
- [Google Workspace Sheets skill](https://github.com/googleworkspace/cli/blob/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills/gws-sheets/SKILL.md)
- [Google Workspace shared skill](https://github.com/googleworkspace/cli/blob/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills/gws-shared/SKILL.md)
- [Open Agent Skills CLI](https://github.com/vercel-labs/skills/blob/main/README.md)
- [Pinned `skills` npm package metadata](https://registry.npmjs.org/skills/1.5.23)

## Functional requirements

### FR-001 — Triggered workflow skill

`skill-bootstrap/SKILL.md` shall use the repository's required frontmatter and a trigger-style description. It shall activate when a user asks to discover, install, update, bootstrap, or verify Pi/Codex skills or one of the supported profiles.

**Acceptance criterion AC-001:** Frontmatter contains `name: skill-bootstrap`, a non-empty trigger description, and a `Common mistakes` table; the body documents every supported profile and target.

### FR-002 — Single catalog source

`skill-bootstrap/SKILL.md` shall contain a catalog delimited by the exact markers `<!-- skill-bootstrap-catalog:v1 -->` and `<!-- /skill-bootstrap-catalog -->`. The first row shall declare these tab-separated columns:

`kind<TAB>profile<TAB>agent<TAB>name<TAB>source<TAB>ref<TAB>subpath<TAB>mode`

Each subsequent non-empty row shall contain exactly eight tab-separated fields. Allowed values are:

- `kind`: `skill` or `tool`.
- `profile`: `paper`, `superpowers`, `google-sheets`, or `all` only for shared tool rows.
- `agent`: `pi`, `codex`, `both`, or `all`.
- `name`: lowercase letters, digits, and hyphens.
- `source`, `ref`, and `subpath`: non-empty values with no tabs.
- `mode`: `local-skill`, `pi-package`, `skills-cli`, `manual-marketplace`, or `npm-package`.

The parser shall reject missing markers, a wrong header, malformed rows, duplicate `(kind, profile, agent, name)` keys, unknown profiles/agents/modes, and invalid kind/mode combinations before invoking any installer.

**Acceptance criterion AC-002:** A valid catalog passes validation; each of malformed row, duplicate key, unknown profile, and unknown mode fixtures fails with a clear error and no external command is attempted.

### FR-003 — Explicit install interface

`install-skills.sh` shall accept `--profile paper|superpowers|google-sheets|all`, `--agent pi|codex|both`, and `--dry-run`, plus `--help`. Profile and agent are required; the script shall reject unknown or missing values before side effects.

**Acceptance criterion AC-003:** Help output documents the flags, and dry-run output contains the selected pinned commands without changing user settings or files.

### FR-004 — Supported install behavior

For Pi, the script shall install native and Google skills with the pinned `skills` CLI and install Superpowers with `pi install git:github.com/obra/superpowers@v6.3.0`. For Codex, it shall install native and Google skills with the pinned `skills` CLI and print the official Superpowers marketplace action instead of copying Superpowers skill files.

The `both` target shall complete supported Pi/Codex work even when the Codex Superpowers manual action remains pending.

**Acceptance criterion AC-004:** Dry-run output proves that Pi Superpowers uses the pinned Pi package command, Codex Superpowers is manual-only, and Google Sheets emits all four dependency-closure skills at the pinned commit.

### FR-005 — Prerequisite preflight

The Google Sheets profile shall check for `gws` without invoking authentication or an API call. If missing, output shall include the official CLI installation choices and `gws auth setup`/`gws auth login` guidance. The profile may still install skill files, but the script shall report the unresolved prerequisite.

**Acceptance criterion AC-005:** A test with `gws` absent reports the prerequisite and leaves credentials untouched; a test with a stub `gws` on `PATH` does not perform authentication.

### FR-006 — Pinned update behavior

`update-skills.sh` shall accept the same profile/agent flags plus `--dry-run`, `--check-latest`, and `--help`. Without `--check-latest`, it shall reconcile the exact refs in the catalog by re-running pinned install commands; it shall not call `skills update` or select a newer ref.

`--check-latest` shall be read-only. It may query upstream Git refs and npm metadata, then report the recorded ref, observed upstream ref, and whether drift exists. It shall never edit `SKILL.md`, install packages, or update agent settings.

**Acceptance criterion AC-006:** Update dry-run shows only pinned commands; latest-check output reports drift without writing files or invoking an unpinned package.

### FR-007 — Manual-action and failure status

Scripts shall use these statuses: `0` for complete requested work, `1` for an operational/catalog failure, `2` when supported work completed but a manual action or missing `gws` prerequisite remains, and `64` for invalid command-line usage. Failures shall identify the affected profile/source and shall not be hidden by `set -e` cleanup.

**Acceptance criterion AC-007:** `both` plus Superpowers returns `2` after supported installs and prints the Codex marketplace step; malformed arguments return `64`; a failed installer command returns `1`.

### FR-008 — Repository discoverability

`README.md` shall list `skill-bootstrap` with a trigger-oriented purpose and document the two scripts, explicit target requirement, supported profiles, and no-credentials/no-submodule boundary.

**Acceptance criterion AC-008:** The README link resolves to `skill-bootstrap/SKILL.md`, and every script/profile name in the README matches the skill and catalog.

## Non-functional requirements

- **NFR-001:** Scripts shall run under Bash 3.2+ on Linux/macOS and use only Bash plus standard `awk`, `sed`, `mktemp`, `git`, `npm`/`npx`, and `pi`; no additional runtime package is required.
- **NFR-002:** No command that executes remote package code may use an implicit latest ref. The `skills` CLI invocation shall include `skills@1.5.23`; Git sources shall include their catalog ref.
- **NFR-003:** Full catalog validation shall complete before the first install/update command, and `--dry-run` shall perform no network or filesystem mutation outside temporary test data.
- **NFR-004:** The catalog grammar and source pins shall be documented inside `SKILL.md`; no second lock manifest shall be introduced.
- **NFR-005:** Every external version/ref and verification date shall be visible in the skill, and observed failures shall be recorded in its `Common mistakes` table.

## Failure handling

- Missing `--profile` or `--agent`, unknown values, or unknown flags: print usage and exit `64`.
- Missing or malformed catalog: identify the row/field and exit `1` before any external command.
- Missing `npx` for a standard skill install: report the Node/npm prerequisite and exit `1`.
- Missing `pi` for a Pi Superpowers install: report the Pi prerequisite and exit `1`; continue independent Codex/Paper/Sheets rows when the requested target permits it.
- Missing `gws`: install skill files, print non-secret official setup instructions, and exit `2` unless another hard failure occurs.
- Codex Superpowers requested: print the official plugin marketplace steps, continue supported work, and exit `2` unless another hard failure occurs.
- A failed network/download/install command: identify its source and exit `1`; never claim that profile complete.
- `--check-latest` network or metadata failure: report which source could not be checked and exit `1` without mutating anything.

## Verification policy

The repository has no application build; verification is shell behavior and static skill consistency:

1. `bash -n scripts/skill-bootstrap-common.sh scripts/install-skills.sh scripts/update-skills.sh scripts/test-skill-bootstrap.sh` — syntax passes.
2. `scripts/test-skill-bootstrap.sh` — valid catalog passes; malformed, duplicate, unknown-profile, and unknown-mode fixtures fail before command dispatch.
3. `scripts/install-skills.sh --help` and `scripts/update-skills.sh --help` — usage documents required flags and statuses.
4. `scripts/install-skills.sh --profile paper --agent pi --dry-run` — emits all eleven native skill names and `npx --yes skills@1.5.23`; no settings/files change.
5. `scripts/install-skills.sh --profile google-sheets --agent codex --dry-run` — emits all four pinned tree sources and the `gws` preflight; no authentication command runs.
6. `scripts/install-skills.sh --profile superpowers --agent both --dry-run` — emits the pinned Pi package command and Codex marketplace instructions; it does not emit a Codex `npx skills add` for Superpowers.
7. `scripts/update-skills.sh --profile all --agent both --dry-run` — emits only pinned reconciliation commands and the manual Codex notice.
8. `scripts/update-skills.sh --profile google-sheets --agent codex --check-latest` — reports source/CLI drift or an explicit network failure without modifying repository or agent files.
9. Validate changed `SKILL.md` frontmatter, required sections, catalog grammar, source URLs, and README links with a repository-local check.
