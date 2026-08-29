---
name: skill-bootstrap
description: Use when discovering, installing, updating, bootstrapping, or verifying Pi or Codex agent skills, including the paper, superpowers, google-sheets, or all profiles.
---

# Skill bootstrap

Use this skill when a user needs to discover, install, update, bootstrap, or verify the
supported agent skills in this repository. The catalog below is the sole
machine-readable source of profile membership, source ownership, refs, and modes.
The prose explains the safe workflow; scripts must parse and validate the catalog
before dispatching any installer.

## Profiles and targets

There are four profiles:

- **`paper`** installs the ten native Paper skills from this checkout: `project-setup`,
  `ci-release`, `autonomous-testing`, `database-integration`,
  `performance-optimization`, `ui-design`, `docs-maintenance`,
  `spec-driven-development`, `pebblehost-deploy`, and `development-network`.
- **`superpowers`** installs the pinned Superpowers release for Pi and documents the
  official Codex plugin-marketplace action. Codex is never provisioned by copying
  Superpowers files into a skill directory.
- **`google-sheets`** installs the complete Google Workspace Sheets skill closure:
  `gws-shared`, `gws-sheets`, `gws-sheets-append`, and `gws-sheets-read`, all from
  the pinned Google Workspace CLI commit.
- **`all`** composes `paper`, `superpowers`, and `google-sheets`; it is not a fourth
  independent source set.

Every install or update requires both an explicit profile and an explicit target:
`pi`, `codex`, or `both`. Never infer a target from the current shell or agent. A
`both` request expands supported rows for each target. The scripts reject a missing,
unknown, or ambiguous `--profile` or `--agent` before side effects and return status
`64` for command-line usage errors.

## Workflow

1. Read this skill and select exactly one profile and one target.
2. Review the catalog rows selected by that profile and target. Verify that the
   source, ref, subpath, and mode are expected before running anything.
3. Run the corresponding script with explicit flags. Use `--dry-run` first when
   reviewing a new target, and confirm that every command contains its pinned ref.
4. For `google-sheets`, let the script perform the non-invasive `gws` PATH preflight.
   It may install skill files when `gws` is absent, but it must report the unresolved
   prerequisite and return status `2` unless another hard failure returns `1`.
5. For Codex Superpowers, follow the printed official marketplace action manually.
   The supported repository/skill work can still complete for a `both` request.
6. Verify the installed skill names and the agent-facing result. Never claim a
   profile is complete when an installer failed or a required manual action remains.

### Pi and Codex behavior

Pi receives native Paper and Google Sheets skills through the pinned `skills` CLI.
Pi Superpowers uses the official pinned package command:

```bash
pi install git:github.com/obra/superpowers@v6.3.0
```

Codex receives native Paper and Google Sheets skills through the same pinned `skills`
CLI. Codex Superpowers is manual-only: open the Codex plugin interface with
`/plugins`, search for `superpowers`, and choose **Install Plugin**. Follow the
official Superpowers instructions; do not use `npx skills add` to copy it into a
Codex skill directory.

The `skills` CLI command is always explicitly pinned and non-interactive:

```bash
npx --yes skills@1.5.23 add <source> --global --agent <pi|codex> --copy --yes --skill <name>
```

For Paper rows, `<source>` is this repository root. For Google rows, the wrapper
constructs the exact pinned tree URL as `SOURCE/tree/REF/SUBPATH` from the catalog's
repository root, commit, and skill directory before invoking the CLI. Do not replace
the version with bare `npx skills`, `skills update`, or an unpinned source.

### Dry runs and updates

`--dry-run` validates the complete catalog and prints the selected pinned commands,
manual actions, and prerequisite checks without network access, package installs,
agent-setting changes, credential access, or other mutation. It is safe to use for
reviewing a target/profile combination.

An update reconciles the pins recorded here; it does **not** follow upstream latest,
run `skills update`, silently rewrite this file, or choose a newer ref. Without
`--check-latest`, the update script replays the same pinned installation behavior.
`--check-latest` is read-only: it may inspect remote Git refs and npm metadata and
reports the recorded ref, observed upstream ref, and drift. It does not install,
edit this catalog, or change agent settings. Local Paper rows are skipped during
remote latest checks.

Examples:

```bash
# Inspect and install the native Paper profile for Pi.
scripts/install-skills.sh --profile paper --agent pi --dry-run
scripts/install-skills.sh --profile paper --agent pi

# Reconcile exact pins for both agents without making changes first.
scripts/update-skills.sh --profile all --agent both --dry-run
scripts/update-skills.sh --profile all --agent both

# Install all Google Sheets dependencies and check the gws prerequisite.
scripts/install-skills.sh --profile google-sheets --agent codex --dry-run
scripts/install-skills.sh --profile google-sheets --agent codex

# Check upstream drift without installing or mutating anything.
scripts/update-skills.sh --profile google-sheets --agent codex --check-latest

# Review the Pi package and Codex manual action.
scripts/install-skills.sh --profile superpowers --agent both --dry-run
```

### Exit statuses

- **`0`** — all requested work completed and no pending prerequisite or manual action
  remains.
- **`1`** — an operational or catalog failure occurred. The output identifies the
  affected profile/source; failures are not hidden by cleanup or `set -e` behavior.
- **`2`** — supported work completed, but Codex Superpowers still needs its manual
  marketplace action or `gws` is missing and needs official setup/authentication.
- **`64`** — invalid command-line usage, including a missing/unknown profile or target
  or an unknown option.

A hard failure takes precedence over pending status `2`. A missing `npx` or a failed
network/download/install command is status `1`; a missing `pi` is status `1` for a
requested Pi Superpowers action. `--check-latest` reports a named metadata/network
failure and returns `1` without mutation.

## Source verification and safety

Pins and source ownership were verified on **2026-08-29** against these official
sources:

- [Pi package installation](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md)
- [Pi skill discovery](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md)
- [Superpowers installation matrix](https://github.com/obra/superpowers/blob/main/README.md)
- [Superpowers Codex manifest](https://github.com/obra/superpowers/blob/main/.codex-plugin/plugin.json)
- [Google Workspace Sheets skill](https://github.com/googleworkspace/cli/blob/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills/gws-sheets/SKILL.md)
- [Google Workspace shared skill](https://github.com/googleworkspace/cli/blob/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills/gws-shared/SKILL.md)
- [Open Agent Skills CLI](https://github.com/vercel-labs/skills/blob/main/README.md)
- [Pinned `skills` npm package metadata](https://registry.npmjs.org/skills/1.5.23)

The Superpowers tag `v6.3.0` resolves to commit
`b36e0829c6d0140e93cfef2ca599b1b07d4a7797`. Google Workspace CLI skills are pinned
to commit `a3768d0e82ad83cca2da97724e46bea4ff0e6dbd`. The Open Agent Skills CLI is
pinned to npm version `1.5.23`. These exact refs are repeated in the catalog so
scripts can validate and consume one source of truth.

Pi packages and skills can execute powerful actions in the user's environment,
and third-party skill content must be reviewed before installation and use. Check
source ownership, the pinned ref, requested target, and requested skill names before
approving a dry run or real install. This workflow does not install Node, npm, Pi,
Codex, or `gws`, and it never runs OAuth setup, opens a browser, handles tokens, or
changes Google Cloud configuration. Scripts never handle OAuth or credentials; when
`gws` is absent they print only the official installation and authentication guidance
for the user to perform separately (`gws auth setup`, then `gws auth login`). No
external repository is added as a Git submodule.

## Authoritative catalog

The following tab-separated block is the only machine-readable profile source. Every
data row has exactly eight fields in the declared order:
`kind`, `profile`, `agent`, `name`, `source`, `ref`, `subpath`, `mode`.
`local`/`working-tree` identifies a Paper skill in this checkout; external rows use
their pinned source, ref, and subpath. `local-skill` rows are copied from the local
checkout, `skills-cli` rows use the pinned CLI, `pi-package` is the Pi Superpowers
package path, `manual-marketplace` is the Codex Superpowers action, and
`npm-package` identifies the pinned CLI tool.

<!-- skill-bootstrap-catalog:v1 -->
kind	profile	agent	name	source	ref	subpath	mode
tool	all	all	skills	npm	1.5.23	.	npm-package
skill	paper	both	project-setup	local	working-tree	project-setup	local-skill
skill	paper	both	ci-release	local	working-tree	ci-release	local-skill
skill	paper	both	autonomous-testing	local	working-tree	autonomous-testing	local-skill
skill	paper	both	database-integration	local	working-tree	database-integration	local-skill
skill	paper	both	performance-optimization	local	working-tree	performance-optimization	local-skill
skill	paper	both	ui-design	local	working-tree	ui-design	local-skill
skill	paper	both	docs-maintenance	local	working-tree	docs-maintenance	local-skill
skill	paper	both	spec-driven-development	local	working-tree	spec-driven-development	local-skill
skill	paper	both	pebblehost-deploy	local	working-tree	pebblehost-deploy	local-skill
skill	paper	both	development-network	local	working-tree	development-network	local-skill
skill	superpowers	pi	superpowers	https://github.com/obra/superpowers	v6.3.0	.	pi-package
skill	superpowers	codex	superpowers	https://github.com/obra/superpowers	v6.3.0	.	manual-marketplace
skill	google-sheets	both	gws-shared	https://github.com/googleworkspace/cli	a3768d0e82ad83cca2da97724e46bea4ff0e6dbd	skills/gws-shared	skills-cli
skill	google-sheets	both	gws-sheets	https://github.com/googleworkspace/cli	a3768d0e82ad83cca2da97724e46bea4ff0e6dbd	skills/gws-sheets	skills-cli
skill	google-sheets	both	gws-sheets-append	https://github.com/googleworkspace/cli	a3768d0e82ad83cca2da97724e46bea4ff0e6dbd	skills/gws-sheets-append	skills-cli
skill	google-sheets	both	gws-sheets-read	https://github.com/googleworkspace/cli	a3768d0e82ad83cca2da97724e46bea4ff0e6dbd	skills/gws-sheets-read	skills-cli
<!-- /skill-bootstrap-catalog -->

## Common mistakes

| Mistake | Why it fails | Correct action |
| --- | --- | --- |
| Installing only `gws-sheets` | The Sheets skill depends on shared, append, and read skills; a partial install leaves the closure incomplete. | Select `--profile google-sheets`; it installs all four pinned Google rows. |
| Running bare `npx skills` | An implicit latest package is not reproducible and can change behavior between runs. | Run `npx --yes skills@1.5.23` through the scripts. |
| Trying to automate Codex Superpowers through a skill copy | Superpowers is a Codex plugin/marketplace action, not a skill-copy install. | Use `/plugins`, search `superpowers`, and choose **Install Plugin** manually. |
| Omitting the target | The same profile has different Pi and Codex behavior, especially for Superpowers. | Always provide `--agent pi`, `--agent codex`, or `--agent both`. |
| Assuming a missing `gws` binary is authenticated | PATH presence and OAuth authentication are separate; this workflow must not inspect or mutate credentials. | Install `gws` using official guidance, then perform `gws auth setup` and `gws auth login` yourself. |
