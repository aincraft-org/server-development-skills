# Skill Bootstrap and Profile Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a self-contained `skill-bootstrap` workflow and safe install/update scripts for the repository's Paper skills plus pinned Pi/Codex external skill profiles.

**Architecture:** `skill-bootstrap/SKILL.md` owns the human instructions and a strict tab-separated catalog containing all profile membership and external refs. A shared Bash helper extracts and validates that catalog before either wrapper executes a command. `install-skills.sh` dispatches pinned installs; `update-skills.sh` replays pinned installs or performs read-only upstream drift checks.

**Tech Stack:** Markdown with YAML frontmatter; Bash 3.2+; `awk`, `sed`, `mktemp`, `git`, `npm`/`npx`, and `pi`; the pinned `skills@1.5.23` CLI.

**Spec:** `docs/superpowers/specs/2026-08-29-skill-bootstrap-design.md`

## Global Constraints

- Keep all external repositories out of Git submodules.
- Support only explicit `paper`, `superpowers`, `google-sheets`, and `all` profiles and explicit `pi`, `codex`, or `both` targets.
- Keep the catalog, profile membership, and external refs inside `skill-bootstrap/SKILL.md`; do not add a second lock manifest.
- Invoke the skills CLI only as `npx --yes skills@1.5.23`; never execute bare or latest `npx skills`.
- Pin Superpowers to `v6.3.0` / commit `b36e0829c6d0140e93cfef2ca599b1b07d4a7797` and Google Workspace CLI skills to commit `a3768d0e82ad83cca2da97724e46bea4ff0e6dbd`.
- Never install `gws`, Node, Pi, Codex, or credentials automatically.
- Treat Codex Superpowers as an official marketplace/plugin action; never copy it with `npx skills`.
- Validate the complete catalog before the first install/update command.
- Use the repository's existing Bash style and retain a `Common mistakes` table in the new skill.

---

### Task 1: Add the authoritative skill and catalog

**Files:**
- Create: `skill-bootstrap/SKILL.md`
- Test: `scripts/test-skill-bootstrap.sh` (created in Task 2 and run after Task 4)

**Interfaces:**
- Produces the exact catalog consumed by `scripts/skill-bootstrap-common.sh`.
- Produces the profile/target behavior and manual-action instructions consumed by both wrapper scripts.

- [ ] **Step 1: Write the frontmatter and workflow sections**

Create `skill-bootstrap/SKILL.md` with:

```yaml
---
name: skill-bootstrap
description: Use when discovering, installing, updating, bootstrapping, or verifying Pi or Codex agent skills, including the paper, superpowers, google-sheets, or all profiles.
---
```

Document the four profiles, explicit target requirement, dry-run behavior, status codes (`0`, `1`, `2`, `64`), Pi and Codex differences, `gws` preflight, and the rule that updates reconcile pins rather than follow upstream latest.

- [ ] **Step 2: Add the strict catalog block**

Add the exact markers and header:

```text
<!-- skill-bootstrap-catalog:v1 -->
kind	profile	agent	name	source	ref	subpath	mode
<!-- /skill-bootstrap-catalog -->
```

Use one literal tab between fields. The block contains one tool row for `skills` version `1.5.23`, eleven `paper` rows for `project-setup`, `ci-release`, `autonomous-testing`, `database-integration`, `performance-optimization`, `ui-design`, `docs-maintenance`, `spec-driven-development`, `pebblehost-deploy`, `development-network`, and `proxy-first-paper-smoke`, two `superpowers` rows for Pi and Codex, and four `google-sheets` rows for `gws-shared`, `gws-sheets`, `gws-sheets-append`, and `gws-sheets-read`. Use `local`/`working-tree`/the skill directory/`local-skill` for Paper rows, `https://github.com/obra/superpowers`/`v6.3.0`/`.` with `pi-package` or `manual-marketplace` for Superpowers, and `https://github.com/googleworkspace/cli`/`a3768d0e82ad83cca2da97724e46bea4ff0e6dbd`/the matching `skills/gws-*` path/`skills-cli` for Google rows.


- [ ] **Step 3: Document source verification and safety**

Record the exact Superpowers tag/commit, Google Workspace commit, and `skills` CLI version with the verification date `2026-08-29`. Link the official Pi, Superpowers, Google Workspace, and skills CLI documentation. Explain that Pi packages and skills can execute powerful actions, that third-party content must be reviewed, and that scripts never handle OAuth or credentials.

- [ ] **Step 4: Add usage and common mistakes**

Document concrete commands for installation, pinned reconciliation, `--check-latest`, and dry runs. Include mistakes for installing only `gws-sheets`, using bare `npx skills`, trying to automate Codex Superpowers through a skill copy, omitting the target, and assuming a missing `gws` binary is authenticated. End with a `Common mistakes` table.

- [ ] **Step 5: Verify the skill text**

Run:

```bash
awk '/^---$/{n++} n==1 || (n==2 && NR<=8)' skill-bootstrap/SKILL.md
awk '/skill-bootstrap-catalog:v1/{start++} /\/skill-bootstrap-catalog/{end++} END { exit !(start == 1 && end == 1) }' skill-bootstrap/SKILL.md
```

Expected: required frontmatter fields are present, and exactly one catalog start/end marker pair exists.

### Task 2: Implement the strict catalog parser and fixtures

**Files:**
- Create: `scripts/skill-bootstrap-common.sh`
- Create: `scripts/test-skill-bootstrap.sh`

**Interfaces:**
- `catalog_validate FILE` returns `0` only for a valid catalog and prints diagnostics to stderr otherwise.
- `catalog_rows FILE PROFILE` prints normalized matching rows after validation.
- `catalog_tool_ref FILE TOOL_NAME` prints a tool ref.
- `catalog_source_url SOURCE REF SUBPATH` builds a pinned GitHub tree URL for `skills-cli` rows.
- `print_command` accepts an argv vector and prints a shell-safe dry-run command without executing it.

- [ ] **Step 1: Implement marker and row extraction**

In `skill-bootstrap-common.sh`, use `awk` to read only lines between the exact catalog markers, require the exact eight-column header, ignore blank rows, and emit data rows as tab-separated records. Reject a missing marker, duplicate marker, missing header, or non-tab-separated row.

- [ ] **Step 2: Implement grammar and cross-field validation**

Validate the eight fields with `awk` before producing rows:

- `kind` is `skill` or `tool`.
- `profile` is `paper`, `superpowers`, `google-sheets`, or `all` only for the shared tool row.
- `agent` is `pi`, `codex`, `both`, or `all`.
- `name` matches `[a-z0-9-]+`.
- `source`, `ref`, and `subpath` are non-empty and contain no tabs.
- `mode` is `local-skill`, `pi-package`, `skills-cli`, `manual-marketplace`, or `npm-package`.
- Valid combinations are enforced: local rows use `local-skill`; `pi-package` is only Superpowers/Pi; `manual-marketplace` is only Superpowers/Codex; Google rows use `skills-cli`; the tool row is `skills`/`npm-package`.
- Reject duplicate `(kind, profile, agent, name)` keys.

Return a clear row/field error and never run an installer while validation fails.

Make `catalog_rows` expand `all` into `paper`, `superpowers`, and `google-sheets`, expand `both` into one row per target, and preserve catalog order. Make `catalog_tool_ref` fail if the named tool is missing or duplicated. Build `skills-cli` URLs as `SOURCE/tree/REF/SUBPATH` and derive the exact Pi form `git:github.com/obra/superpowers@v6.3.0` from the Superpowers source and ref.

- [ ] **Step 4: Add fixture-based parser tests**

`test-skill-bootstrap.sh` shall copy the valid catalog block to temporary fixture files, then exercise `catalog_validate` against:

1. the valid catalog;
2. a row with seven fields;
3. a duplicate key;
4. an unknown profile;
5. an unknown mode.

Assert valid input succeeds and every invalid fixture fails. Use a temporary directory and remove it with an `EXIT` trap. Do not invoke `npx`, `pi`, `git`, or network commands.

- [ ] **Step 5: Verify parser syntax and tests**

Run:

```bash
bash -n scripts/skill-bootstrap-common.sh scripts/test-skill-bootstrap.sh
scripts/test-skill-bootstrap.sh
```

Expected: syntax succeeds; the valid fixture passes; all four invalid fixtures fail with diagnostics and the test script reports success.

### Task 3: Implement profile installation

**Files:**
- Create: `scripts/install-skills.sh`
- Modify: `scripts/skill-bootstrap-common.sh`

**Interfaces:**
- CLI: `scripts/install-skills.sh --profile PROFILE --agent AGENT [--dry-run] [--help]`, where PROFILE is one of `paper`, `superpowers`, `google-sheets`, or `all`, and AGENT is one of `pi`, `codex`, or `both`.
- Exit `0` for completion, `1` for hard failure, `2` for pending manual/prerequisite work, and `64` for usage errors.

- [ ] **Step 1: Implement argument parsing and preflight**

Parse long options without accepting unknown flags. Require exactly one profile and target. Resolve `REPO_ROOT` from the script directory. Validate the catalog before checking or running installers. In real mode, require `npx` for `local-skill`/`skills-cli` rows and `pi` for Pi Superpowers; in dry-run mode, print missing-command requirements without invoking them. For Google Sheets, run only `command -v gws`; record a pending prerequisite when absent.

- [ ] **Step 2: Implement pinned standard skill installs**

For each selected local Paper row, print or execute:

```bash
npx --yes skills@1.5.23 add "$REPO_ROOT" --global --agent "$target" --copy --yes --skill "$name"
```
For each selected Google row, print or execute the same pinned CLI against its exact tree URL: `https://github.com/googleworkspace/cli/tree/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills/gws-shared`, `https://github.com/googleworkspace/cli/tree/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills/gws-sheets`, `https://github.com/googleworkspace/cli/tree/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills/gws-sheets-append`, and `https://github.com/googleworkspace/cli/tree/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills/gws-sheets-read`. Never call `skills update` or a source without its ref.

- [ ] **Step 3: Implement Superpowers agent-specific behavior**

For Pi, print or execute:

```bash
pi install git:github.com/obra/superpowers@v6.3.0
```

For Codex, print the official marketplace sequence (`/plugins`, search `superpowers`, choose `Install Plugin`) and the upstream documentation URL. Do not execute `npx skills add` for Superpowers. Continue supported rows for `both`; return `2` when the manual action remains pending.

- [ ] **Step 4: Implement dry-run and failure aggregation**

Ensure dry-run performs no network, package, settings, or credential operation. Execute independent rows while recording failures, print the affected source on failure, preserve the manual/prerequisite pending state, and return `1` for any hard failure unless usage status `64` applies.

- [ ] **Step 5: Verify install behavior**

Run:

```bash
bash -n scripts/install-skills.sh
scripts/install-skills.sh --help
scripts/install-skills.sh --profile paper --agent pi --dry-run
scripts/install-skills.sh --profile google-sheets --agent codex --dry-run
scripts/install-skills.sh --profile superpowers --agent both --dry-run
```

Expected: help documents flags/statuses; Paper output contains all eleven names and `skills@1.5.23`; Google output contains all four pinned tree URLs and only a `gws` presence check; Superpowers output contains the pinned Pi command and Codex marketplace instructions but no Codex skill copy.

### Task 4: Implement pinned update and latest-check behavior

**Files:**
- Create: `scripts/update-skills.sh`
- Modify: `scripts/skill-bootstrap-common.sh`

**Interfaces:**
- CLI: `scripts/update-skills.sh --profile PROFILE --agent AGENT [--dry-run] [--check-latest] [--help]`, using the same PROFILE and AGENT values as the install script.
- Default mode replays the pinned install dispatch; `--check-latest` is read-only and does not install.

- [ ] **Step 1: Reuse pinned install dispatch**

Share the Task 3 dispatch functions from `skill-bootstrap-common.sh` so update mode uses exactly the same catalog rows and commands. With no `--check-latest`, re-run Pi's pinned `pi install` and the pinned `npx --yes skills@1.5.23 add "$PINNED_SOURCE" --global --agent "$TARGET" --copy --yes` command for each selected standard skill. Do not call `skills update`.

- [ ] **Step 2: Implement read-only upstream checks**

For every external Git source, use `git ls-remote` to verify the recorded ref exists and report the remote default `HEAD` alongside the recorded ref. For the npm tool row, use `npm view skills version` only to report the registry version versus `1.5.23`; do not execute the package. Skip local Paper rows. Report Codex Superpowers's manual marketplace state without attempting installation.

- [ ] **Step 3: Enforce no-mutation latest-check mode**

Reject or ignore install dispatch when `--check-latest` is present. Do not call `npx`, `pi`, or any command that changes settings. Return `1` for network/metadata failure and `0` when all checks complete; preserve clear per-source output.

- [ ] **Step 4: Verify update behavior**

Run:

```bash
bash -n scripts/update-skills.sh
scripts/update-skills.sh --help
scripts/update-skills.sh --profile all --agent both --dry-run
scripts/update-skills.sh --profile google-sheets --agent codex --check-latest
```

Expected: update dry-run contains only pinned reconciliation commands and the manual Codex notice; latest-check performs no install and reports either drift or a named network failure.

### Task 5: Document the public interface and integrate discoverability

**Files:**
- Modify: `README.md`
- Modify: `skill-bootstrap/SKILL.md`

**Interfaces:**
- README links to the new skill and exposes the exact script commands.
- Skill documentation matches the installed script flags, profiles, refs, and exit statuses.

- [ ] **Step 1: Add the README catalog row**

Add `skill-bootstrap` to the Skills table with a trigger-style purpose covering discovery/install/update/verification for Pi/Codex skills. Keep the existing Paper skill rows and submodule boundary unchanged.

- [ ] **Step 2: Add script usage documentation**

Add a short README section showing explicit examples for `paper`, `superpowers`, `google-sheets`, `all`, `--dry-run`, and `--check-latest`. State that `gws` is only preflighted, Codex Superpowers requires the marketplace, and no third-party source is submoduled.

- [ ] **Step 3: Run static consistency checks**

Run:

```bash
awk '/skill-bootstrap\/SKILL.md/ {found=1} END {exit !found}' README.md
awk '/scripts\/install-skills.sh|scripts\/update-skills.sh|google-sheets|superpowers/ {count++} END {exit !(count >= 6)}' README.md skill-bootstrap/SKILL.md
```

Expected: README links the skill and both files agree on the public names. Then rerun the focused parser and dry-run checks from Tasks 2–4.

### Task 6: Final verification and cleanup

**Files:**
- Verify: `skill-bootstrap/SKILL.md`
- Verify: `scripts/skill-bootstrap-common.sh`
- Verify: `scripts/install-skills.sh`
- Verify: `scripts/update-skills.sh`
- Verify: `scripts/test-skill-bootstrap.sh`
- Verify: `README.md`

- [ ] **Step 1: Run the exact verification policy**

Run all commands listed in the spec, including syntax checks, parser fixtures, help output, Paper/Sheets/Superpowers dry runs, pinned update dry-run, and latest-check.

- [ ] **Step 2: Confirm side-effect boundaries**

Run dry-run commands from a temporary directory and compare `~/.pi/agent/settings.json`, `~/.codex/skills`, and the repository tree before and after. Expected: no changes from dry-run or latest-check.

- [ ] **Step 3: Review source consistency**

Confirm every catalog ref appears in the skill prose, every external row has the correct mode, the four Google Sheets rows are present, and no bare `npx skills`, unpinned Git source, or Codex Superpowers copy command remains.

- [ ] **Step 4: Remove scratch data**

Delete only temporary fixture directories created by the test script and leave no generated lockfiles, package caches, credentials, or scratch files in the repository.
