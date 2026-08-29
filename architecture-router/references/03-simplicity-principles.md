# Simplicity Principles (Reference)

Deep reference for the DRY / KISS / YAGNI / composition-over-inheritance routes in `../SKILL.md`. Read when the rules conflict, or when deciding whether to extract or delete.

## DRY — Don't Repeat Yourself

**Every piece of knowledge has a single, unambiguous source of truth.** Duplication is two forms: *copy-paste logic* (a bug fix must land in N places) and *parallel structures* (same shape re-declared with different names). Both drift until they disagree.

### Rule of three

Tolerate two copies; extract the single source of truth at the third (or when the third is visibly coming). Duplication is cheaper than the wrong abstraction — the wrong abstraction is a shared source of truth for a *different* concept, and every consumer then corrects the same wrong rule.

### Plugin examples

- Permission/format constants repeated across listeners → one constant or one policy object.
- The same validation (`title too long`, `location outside world border`) in command and API paths → one validator.
- Parallel `ItemStack` construction in three shop categories → one builder, if the categories genuinely share the shape (rule of three first).

### When DRY does not apply

- Two copies with *different reasons to change* are not duplicates — they are coincidentally similar code (e.g. offline vs. online player rendering).
- Premature abstraction for one or two sites: wait for the third.
- Configuration-driven data (permission nodes, kits) is data, not duplication — don't unify it into code.

## KISS — Keep It Simple

**Between designs that both meet the requirement, pick the one with fewer moving parts.** Simplicity is a property of the design, not the line count: a 30-line loop beating a 10-line framework call is not simpler if the framework is already in the codebase and the loop is a custom bug farm.

KISS probes:

- Config knobs, factories, strategies — does any consumer actually vary them?
- Can the next reader trace one feature end to end without crossing five indirections?
- Is the design's cost visible in the requirement, or imported by habit?

## YAGNI — You Aren't Gonna Need It

**Don't build abstraction for hypothetical futures. Add it when a real consumer or implementation forces the choice.**

The cheapest time to add an interface or a parameter is when the second consumer appears — the extraction then follows real shape, not prediction.

### Speculative-flexibility inventory (delete until needed)

| Item | Deletion rule |
|---|---|
| Interface with exactly one implementation | Delete the interface; keep the class — unless it is a domain-owned port (DIP), a test seam, or a public API contract, which keep the interface by design |
| Interface methods no implementation uses | Delete the methods (ISP, in `02-solid-principles.md`) |
| Factory for one variant | Delete; construct directly |
| Config option nothing reads | Delete key and wiring |
| Generic parameter used once | Replace with the concrete type |
| Abstract base class with one subclass | Inline the subclass |
| Caching/threading/async "for later" | Remove; scheduler discipline belongs at the edge (rule 10 in the router) |

Re-adding the abstraction when the second consumer exists is a small, well-understood edit; living with the wrong prediction is a permanent tax.

## Composition over inheritance

**Delegate behavior; subclass only for substitutable "is-a" specialization.** (Decision sheet in `02-solid-principles.md`.) In plugin code this usually means: implement an interface, hold a collaborator, and let the Bukkit wiring choose the implementation — not `extends BaseHandler` to inherit three helpers and override the fourth with a no-op.

## Resolving conflicts

| Conflict | Resolution |
|---|---|
| DRY vs. the wrong abstraction | Rule of three first; extract only at shared *concept*, not shared shape |
| KISS vs. YAGNI | They usually align (skip the machinery). When they diverge, YAGNI dominates: hypothetical needs are not a current moving part |
| DRY vs. KISS | Two copies beat a clever indirection that hides both. Extract when the third copy arrives or when the rule's source of truth is a *business rule* (invariants must not duplicate, ever — see `01-domain-driven-design.md`) |
| Composition vs. inheritance | Prefer composition for reuse; inheritance only for genuine substitutability |

## Common mistakes

| Mistake | Correction |
|---|---|
| Extracting after the first duplication | Rule of three: two copies tolerated |
| Unifying coincidentally similar code as "DRY" | Same *reason to change* is the test, not same text |
| Adding mockability interfaces before tests exist | Write the test; the interface appears with the second implementation |
| Removing a config knob another feature's flow actually reads | Delete only dead extension points; verify with `references`/usage search |
| Deep class hierarchies to "reuse code" | Composition; keep inheritance shallow and substitutable |
| Calling copy-paste "pragmatic" at the fifth site | Five copies of a rule is a drift bomb; extract at the third |