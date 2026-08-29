# Plan: development-network documentation addendum

**Date:** 2026-08-27
**Status:** draft — GATE 2 (plan) pending approval
**Spec:** `docs/superpowers/specs/2026-08-27-development-network-docs-addendum-design.md`

## Two tracks

- **Track A (now)**: documentation addendum — port-allocation rules + repo
  ruling in SKILL.md. Executed this session after approval.
- **Track B (future, optional)**: standalone-repo extraction. **NOT executed
  now** — planned with acceptance criteria so it is ready if the user asks.

## Track A — port-allocation docs (FR-001)

Add a "Port allocation" section to `development-network/SKILL.md` (after
"Backend registry"):
- Default: `30067 + sorted-registry-index` (the math booters share).
- Explicit `PORT_<NAME>` overrides win.
- Externals reserve their port (explicit or default) and are never reassigned.
- Managed autos skip occupied + reserved ports.

**Verify**: `grep -n "Port allocation" SKILL.md`; text matches the allocator.

## Track A — repo-structure ruling (FR-002)

Add "Repository structure": keep in this repo; only third-party skills are
submoduled (first-party precedent); future extraction requires a new remote
first.

**Verify**: `grep -n "Repository structure" SKILL.md`.

## Track B — standalone-repo extraction (planned, not executed)

**Out of scope for this session; do not execute.** Acceptance criteria for
when the user triggers it:

- **New remote exists first** (bootstrap: a fresh clone must resolve the
  submodule URL): `gh repo create`/manual, then push the harness.
- **Submodule pin/update**: `git submodule add <remote> development-network` +
  commit (pin to a tag like the previous third-party-submodule precedent),
  documented update flow.
- **Consumer `includeBuild` path**: SKILL.md wiring updated to the new remote
  path (or `$DEV_NETWORK_BIN` env), verified with `./gradlew runNetwork`.
- **Discoverability preserved**: README + frontmatter unchanged in the parent;
  the submodule's SKILL.md remains the source.

## Files

- `development-network/SKILL.md` — only file changed in Track A.
- Spec/plan artifacts under `docs/superpowers/` are new (committed).

## Tasks (Track A only)

**Task 1** [FR-001] — Add "Port allocation" section.
**Task 2** [FR-002] — Add "Repository structure" section.
**Task 3** — Final verification (grep ≥2 headings; `bash -n dev-network.sh`;
`git diff --stat` shows SKILL.md + docs artifacts; one commit per convention)
+ push; `origin/main` updated.

## Alternatives / risks / rollback

- Standalone repo now: rejected (no remote yet; first-party pattern). Trigger
  documented as Track B.
- Docs drift: allocator is source of truth; re-sync.
- Rollback: revert the single commit.

## Commit boundary

One commit for Track A: `development-network: document port allocation +
repo ruling` (spec/plan artifacts included).