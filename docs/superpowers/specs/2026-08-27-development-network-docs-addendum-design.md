# Development-network skill documentation & repository addendum

**Date:** 2026-08-27
**Status:** draft — GATE 1 (spec) pending approval

## Goal

Close the two open items from the development-network skill work: (1) document
the port-allocation/reservation rules (explicit `PORT_<NAME>`, external
reservation, auto-skip) in `development-network/SKILL.md`; (2) decide and
record whether the harness ships as a standalone repo + submodule or stays a
first-party dir in `server-development-skills` — with the decision reflected
in SKILL.md and README. No behavior/code changes.

## Scope

- `development-network/SKILL.md`: add "Port allocation" docs section.
- `README.md`: no change expected unless the repo decision changes it.
- Repo-structure decision: recommend **keep in this repo** (first-party
  skills are not submoduled; the harness composes with sibling skills).
  Document that ruling; no actual split.
- Explicitly out of scope: any code/behavior change; actually creating a
  standalone repo; a real client-login test; proxy permission plugin install.

## Functional requirements

- **FR-001** — SKILL.md shall include a section explaining the port
  allocation: default `30067 + sorted-registry-index`; explicit `PORT_<NAME>`
  overrides; external backends reserve their port (explicit or default) and
  are never reassigned; managed autos skip occupied + reserved ports.
  - AC-1: the section exists with all four rules stated.
- **FR-002** — SKILL.md shall state the repo-structure ruling (keep in this
  repo) and the submodule precedent, plus the bootstrap condition for any
  future split ("only once a new remote exists").
  - AC-1: a "Repository structure" section states the ruling + condition.

## Non-functional requirements

- **NFR-001** — the addendum must not exceed ~40 lines of additions.

## Failure handling

- If the section text drifts from the actual allocator, the allocator is the
  source of truth; docs re-synced before commit.

## Verification policy

- `grep` both new sections in SKILL.md; `bash -n` the allocator;
  `git diff --stat` shows only SKILL.md changed; commit pushed, `origin/main`
  updated.