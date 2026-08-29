# Layered & Hexagonal Structure (Reference)

Deep reference for the layering/hexagonal routes in `../SKILL.md`. Read when deciding module/package layout, ports and adapters, or whether a plugin needs more structure at all.

## Why structure matters

A plugin that grows past a few features accumulates hidden dependencies: listeners touching files, commands reaching into other features' internals, domain code depending on Paper. The structure rules keep dependency direction predictable so any class can be understood and changed locally.

## The dependency-direction rule (the part that always applies)

All dependencies point **inward**:

```
entry (commands, listeners)   --validates, translates, delegates-->
application/services          --orchestrates, owns use cases-->
domain (models, rules)        <-- depends on nothing framework-specific
adapters (persistence, rendering, Bukkit I/O)  --implement domain interfaces-->
```

- Entry points know about services and domain types, not internals.
- Adapters implement domain-owner interfaces (repository, renderer) and own Bukkit/SQLite details.
- The domain imports no `org.bukkit.*` and no persistence classes.

**Cycle = smell.** `domain → adapter → domain` or `service → listener → service` means responsibilities are misplaced, not that "layering is hard". Break cycles by moving the shared piece to the layer both sides may depend on.

## One module vs. multi-module

Per `project-setup/SKILL.md`'s recommended layout, plugins expected to grow use `common` (domain), `api` (public plugin contracts), `paper` (Paper implementation). The rule for *this* decision: split modules when the separation provides clear value — different teams, genuinely reusable domain, or test isolation — not "because architecture". A small plugin applies the same dependency direction as **package discipline inside one module**:

```text
src/main/java/io/github/username/
├── rank/
│   ├── Rank.java                  # domain: plain Java model + invariants
│   ├── RankRepository.java        # domain-owned interface
│   ├── RankService.java           # application: use cases
│   ├── command/RankCommand.java   # entry
│   └── persistence/SqliteRankRepository.java  # adapter
└── economy/  (same shape)
```

Package boundaries between features are bounded contexts in miniature: `rank` must not reach into `economy`'s internals; cross-feature communication happens through services or domain events.

## Ports and adapters (hexagonal) in plugin terms

| Hexagonal term | Plugin meaning |
|---|---|
| Port | Interface the domain defines — `RankRepository`, `MessageSender`, `WarpGate` |
| Adapter | Implementation at the edge — SQLite repo, Adventure chat renderer, Paper event listener |
| Input adapter | Commands, listeners — receive Paper types, translate to domain calls |
| Output adapter | Persistence, chat/scoreboard, external APIs — implement ports |

Enable an application *inside* the server: domain + application logic testable with plain JUnit, no server boot. This is the payoff — not the diagrams.

## Vertical slices vs. technical layers

Two organizing schemes; pick per feature:

- **Technical layers** (all controllers / all services / all repos): consistent but scatters one feature across the tree.
- **Vertical slices** (feature packages, layers inside each): one feature in one place; boundaries match bounded contexts.

For plugins, vertical slices match the domain-first discipline better and keep the dependency rule local. Use technical layers only when features share so much backbone (a common request pipeline) that slicing fragments it.

## When to skip the ceremony

- Tiny plugins (one feature, no shared rules): keep the dependency direction (no Bukkit in models), skip packages/services splitting — add structure when the second feature arrives.
- Prototypes/throwaway: rules 1 and 10 from the router only.
- Existing tangled codebases: introduce the direction *incrementally* — start with the next new feature; do not attempt a one-shot migration.

## Common mistakes

| Mistake | Correction |
|---|---|
| Declaring clean/hexagonal architecture for a small plugin | Package discipline inside one module; split modules only when separation earns its cost |
| Domain classes importing `org.bukkit.*` | Adapters own Bukkit; domain depends only on JDK types |
| Repositories implemented inside the domain package | Implementation lives at the edge; the interface stays with the domain |
| Listeners directly calling repository/DB code | Listeners are input adapters: validate, delegate to services |
| Cycles between feature packages | Move the shared piece to a lower, shared layer |
| Ports created for every dependency | YAGNI: a port needs a second implementation or a real test seam (rules 7 in the router) |
| Reorganizing everything at once | Introduce direction incrementally; migrate feature by feature |