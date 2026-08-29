---
name: architecture-router
description: Use when designing, structuring, or reviewing Paper plugin code — deciding how to organize a feature, a class or listener growing unwieldy, duplicated logic, unclear package or module boundaries, choosing between design patterns, evaluating coupling and cohesion, or reviewing code before merging. Triggers include writing new services, commands, listeners, or domain models, splitting responsibilities, spotting god classes or copy-pasted behavior, planning plugin module layout, and architecture review passes.
---

# Architecture Router

Routes design and review decisions to the right architectural principle — DDD, SOLID, DRY/KISS/YAGNI, composition over inheritance, layered/hexagonal structure, CQRS — **without reading anything but this file**. Deep dives live in `references/`; read them only when a route's directive does not fit the situation.

## How to use

1. **Reviewing code:** run the [Review checklist](#architecture-review-checklist); for each failing probe, find the matching row in [Signal → principle](#signal--principle--remediation--verify) and apply its remediation.
2. **Designing new code:** apply the [12 operative rules](#12-operative-rules-if-you-read-nothing-else); when a rule's cost is unclear, read the matching reference.
3. **Directive doesn't fit:** read the reference file listed in [References](#references-read-only-when-a-directive-does-not-fit) for tradeoffs, then decide.

## 12 operative rules (if you read nothing else)

| # | Rule | Smell when violated |
|---|---|---|
| 1 | Domain logic stays free of Paper/Bukkit imports: models and business rules are plain Java; Bukkit touches only entry points (listeners, commands) and adapters (persistence, I/O). | `import org.bukkit.*` scattered through "domain" classes; business rules inside listeners |
| 2 | Name by business responsibility, not framework role: `PlayerRank`/`RankService`, not `RankManager`/`RankUtil`. Manager/Util/Helper naming means the responsibility is unnamed. | `XxxManager`, `XxxUtil`, `XxxHelper` classes; interfaces named after an implementation |
| 3 | One class, one reason to change: state its purpose in one sentence without "and". | God classes; methods that serve different owners |
| 4 | Entry points (listeners, commands) validate, translate, and delegate. They never hold business state or run domain rules. | Commands computing domain results; listeners implementing rules inline |
| 5 | Composition over inheritance: delegate behavior; subclass only for substitutable "is-a" specialization. | Subclassing to reuse code; overriding methods to disable them |
| 6 | Open/closed: when the variant set is open, add a variant by adding a class, not by editing existing dispatch. | if/else chains on type tags; switch statements growing with every feature |
| 7 | No speculative abstraction: one implementation needs no interface unless it is a domain-owned port (DIP), a test seam, or a public API contract; otherwise add one only when a second consumer or implementation exists. | Single-impl interfaces with no seam; unused generics, parameters, factories, extension points |
| 8 | DRY by rule of three: tolerate two copies, extract the single source of truth at the third. | Abstraction gymnastics for two duplicates; copy-paste at three+ sites |
| 9 | KISS: between designs that both meet the requirement, pick the one with fewer moving parts. | Config knobs, factories, and strategies nothing consumes |
| 10 | Never block or do server-only work on the wrong thread: blocking I/O and heavy computation run off the main thread, and Bukkit/main-thread-only APIs stay on it — orchestrating async calls inside services is fine as long as nothing blocks the main thread (see [performance-optimization](../performance-optimization/SKILL.md)). | Blocking I/O, sleeps, or heavy computation on the main thread; Bukkit calls from async contexts; scheduler calls hidden inside service internals |
| 11 | Separate reads from writes when query shapes diverge from command needs: queries return display shapes, writes go through the domain. | Query logic welded inside command handlers; handlers mutating state to answer reads |
| 12 | Bukkit's event bus is a notification mechanism, not an event store: never replay listener history as the source of truth; persist state explicitly. | Reconstructing state from `@EventHandler` invocations; treating event history as data |

## Signal → principle → remediation → verify

Observable signals from a review or a design, mapped to the principle, the concrete remediation, and the check that proves it.

| Signal (what you see) | Principle | Remediation (do this) | Verify |
|---|---|---|---|
| Business rules inside listeners or commands | DDD · layering | Extract a pure domain service; the entry point validates input and delegates | Entry points contain no domain logic; domain package has no `org.bukkit` imports |
| Domain package imports `org.bukkit`; persistence/types leak into models | DDD · hexagonal | Move adapters to the edges; models depend only on JDK types; inject repository interfaces | Domain package compiles without Paper on the classpath |
| God class: methods serving different owners | SRP | Split per responsibility; each class gets one sentence of purpose | Every class's methods share one owner; no "and" in the class description |
| Copy-pasted logic or parallel structures at 3+ sites | DRY | Extract the single source of truth | One edit point; no remaining duplicate blocks |
| Interface whose methods some implementations don't use | ISP (or YAGNI first) | If one implementer: delete methods. If multiple: split the interface by role | No `UnsupportedOperationException`; every impl implements every method meaningfully |
| if/else or switch on type/enum tags for behavior | OCP | Replace with per-variant classes behind one interface (only when the variant set is open) | New variant = new class; existing classes untouched |
| Subclassing to reuse code; overrides that disable base behavior | Composition | Replace inheritance with delegation; keep interfaces for polymorphism | Hierarchy exists only where "is-a" and substitutability hold |
| Speculative flexibility: single-impl interface, unused params, factory for one variant | YAGNI | Delete unless the abstraction is a domain-owned port (DIP), test seam, or public API contract; add one when a second consumer or implementation exists | No interface with one implementation and no seam; no unused extension points |
| Everything public; entities reduced to getters/setters | DDD | Move behavior into the model; state changes only through methods that enforce invariants | No public field mutation; invariants enforced in one place |
| Methods doing many jobs at mixed abstraction levels | SRP · KISS | Split by level; a method either orchestrates or computes | Methods read top-down in one pass; each has one job |
| Read and write logic tangled in one path; query shapes diverge | CQRS | Split the query side; queries return read shapes | Read path is independent of the command path |
| Event listeners accumulating state or replaying events as truth | Event-sourcing trap | Persist state explicitly; events only notify | No state reconstructed from listener invocations |
| One giant module; plugin grew into an application | Hexagonal | Reorganize by module or package: entry → service → domain, adapters outward (see [project-setup](../project-setup/SKILL.md) for the api/common/paper layout) | Dependency direction is acyclic: entry → application → domain |

## Architecture review checklist

Run after writing or reviewing code. Answer every probe; fix each failure.

1. Can each class's purpose be stated in one sentence without "and"? (SRP)
2. Does the domain package compile without Paper on the classpath? (DDD · hexagonal)
3. Does any listener or command body contain domain logic or hold business state? (layering · DIP)
4. Are there 3+ copies of the same logic or constant, or a third site about to be added? (DRY)
5. Is every interface implemented by exactly one class with no real seam (no domain-owned port, no test mock, no public API contract)? Callers don't matter — a port serves many. (YAGNI — remove it; keep ports and seams)
6. Does any interface have methods some implementations don't use? (ISP)
7. Does adding a new variant require editing existing dispatch code? (OCP — only where the variant set is open)
8. Is any class subclassed to reuse code rather than to specialize? (composition)
9. Are fields private, with state changes routed through methods that enforce invariants? (encapsulation · DDD)
10. Does every public name describe responsibility, not implementation? No `Manager`/`Util`/`Helper`, no `XxxImpl` where the interface should carry the name. (naming)
11. Do dependencies point inward — entry → application → domain — with no cycles? (hexagonal)
12. Are reads separated from writes where query shapes differ from command needs? (CQRS)
13. Is any state reconstructed from Bukkit event invocations? (event-sourcing trap)
14. Are async and I/O confined to the edges? (layering · performance)

## References (read only when a directive does not fit)

| Reference | Read when |
|---|---|
| [references/01-domain-driven-design.md](references/01-domain-driven-design.md) | Designing aggregates, models, or invariants; anemic models; ubiquitous language for the plugin's domain |
| [references/02-solid-principles.md](references/02-solid-principles.md) | SRP/OCP/LSP/ISP/DIP tradeoff decisions; inheritance vs. composition reasoning |
| [references/03-simplicity-principles.md](references/03-simplicity-principles.md) | DRY vs. KISS vs. YAGNI conflicts; rule-of-three judgment; rescuing over-engineered code |
| [references/04-layered-hexagonal.md](references/04-layered-hexagonal.md) | Plugin module/package layout, ports and adapters, dependency direction, when to skip layering |
| [references/05-cqrs-event-sourcing.md](references/05-cqrs-event-sourcing.md) | Separating read/write paths; whether event sourcing could ever fit a plugin |

## Related skills

- [project-setup](../project-setup/SKILL.md) — multi-module layout (`common`/`api`/`paper`) when a plugin outgrows one module.
- [performance-optimization](../performance-optimization/SKILL.md) — main-thread discipline, async chunk loading, listener hygiene (rule 10's enforcement).
- [database-integration](../database-integration/SKILL.md) — persistence adapters behind repository interfaces.
- [spec-driven-development](../spec-driven-development/SKILL.md) — design artifacts before code, for non-trivial features.

## Common mistakes

| Mistake | Correction |
|---|---|
| Routing "fat interface" to ISP when it has one implementer | That is YAGNI: delete the interface or its unused methods until a second real consumer exists, unless the interface is a domain-owned port, test seam, or public API contract, which stays |
| Declaring hexagonal/clean architecture for a small plugin | Apply the dependency-direction rule as package discipline inside one module; split modules only when the plugin outgrows them (see project-setup) |
| Enforcing DRY on the first or second duplication | Rule of three: tolerate two, extract at the third |
| Treating Bukkit listeners as an event store | Events notify; state persists explicitly (see references/05) |
| Adding interfaces "for mockability" before tests exist | Write the test first; the interface appears only when a genuine second implementation or a test demands it |
| Over-applying OCP with premature strategy/visitor patterns | OCP buys machinery; apply it only when the variant set is actually open |
| Reviewing formatting or naming style as architecture | Style gates (Spotless/Checkstyle) live in project-setup; the router handles structure |
| Linking to skills with harness-specific URI schemes | Use repository-relative paths — readable by any harness with filesystem access |