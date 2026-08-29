# SOLID Principles (Reference)

Deep reference for the SOLID routes in `../SKILL.md`. Read when an SRP/OCP/LSP/ISP/DIP decision does not resolve from the router's directives, or when weighing inheritance vs. composition.

## SRP — Single Responsibility

**One reason to change.** State each class's purpose in one sentence; if the sentence needs "and", split the class.

Signals and fixes:

| Signal | Fix |
|---|---|
| A class both computes domain results and saves them | Give the computation to the domain; handle persistence in a repository |
| A command both validates and executes | Entry points validate; services execute |
| One class handles `@EventHandler` for unrelated feature areas | One listener class per bounded feature; delegate to services |

SRP is about *owners* of change, not lines of code. Splitting a cohesive workflow into five classes with one owner each is not SRP — it is fragmentation.

## OCP — Open/Closed

**Open for extension, closed for modification.** Adding a new *variant* should add a class, not edit existing dispatch. The variant set must actually be open — a closed set (e.g. two permission tiers fixed by the product) needs no machinery.

```java
// Closed dispatch — every new rank tier edits this chain
if (tier == Tier.ADMIN) { ... } else if (tier == Tier.MOD) { ... } else { ... }

// Open dispatch — new tier = new class
public interface TierRules {
  boolean canUse(CommandSender sender);
  int warpLimit();
}
```

Apply OCP where variants genuinely arrive over time (chat formatting, enchant behavior, tool tiers). Skip it for fixed sets and one-variant behavior — that is YAGNI's territory.

## LSP — Liskov Substitution

**A subclass must be usable wherever its parent is expected**, without callers knowing the difference: preconditions not strengthened, postconditions not weakened, inherited expectations preserved.

Signals and fixes:

| Signal | Fix |
|---|---|
| Override throws `UnsupportedOperationException` | The hierarchy is wrong — split the interface by capability (ISP) or delegate |
| Override that silently ignores base behavior ("disable it") | The type is mis-classified; compose behavior instead |
| `instanceof` checks to pick behavior per subclass | Capability belongs on the interface, or the classes are not substitutable |

In plugin code, prefer delegation: a `Rank` that "is-a" `PermissionHolder` only if every `PermissionHolder` contract meaningfully holds.

## ISP — Interface Segregation

**Clients should not depend on methods they do not use.** A fat interface forces implementations to carry dead weight.

```java
// Fat interface — a listener implementing this handles unrelated notifications
public interface PlayerActivityListener {
  void onJoin(PlayerJoinEvent e);
  void onRankChanged(RankChanged e);
  void onShopTransaction(ShopTransaction e);
}

// Segregated — each consumer depends only on its slice
public interface JoinListener { void onJoin(PlayerJoinEvent e); }
public interface RankChangedListener { void onRankChanged(RankChanged e); }
```

First check YAGNI: a fat interface with one implementer and one consumer is a deletion, not a segregation. Segregate only at the second real consumer with genuinely different needs.

## DIP — Dependency Inversion

**Depend on abstractions owned by the consumer; high-level policy must not depend on low-level detail.**

Plugin-sized applications:

- `RankService` (policy) depends on `RankRepository` (interface), not `SqliteRankRepository` (detail) — the domain owns the interface, the adapter implements it (see `01-domain-driven-design.md`).
- Commands depend on services, not on Bukkit internals.
- Business rules do not depend on `PaperScheduler`; the entry point owns scheduling and calls the service.

Inversion means *who owns the interface*, not merely "program to an interface". An interface bolted on after the fact, owned by the implementation and consumed by one caller, is ceremony — YAGNI wins until a second consumer or a test demands it.

## Inheritance vs. composition, decision sheet

| Situation | Choice |
|---|---|
| "I want to reuse this class's code" | Composition — delegate to an instance. Inheritance for reuse couples you to the parent's internals |
| "This IS genuinely a specialized kind of that, and every parent contract holds" | Inheritance (subclassing) — but keep it shallow |
| "I want to override this method to make it do nothing" | Neither — redesign the contract; overrides that disable behavior break LSP |
| "I want polymorphism over a family of behaviors" | Interface + implementation classes (composition-friendly); prefer this over deep class hierarchies |

Deep inheritance trees and `super` chains are the top maintenance hazard; shallow hierarchies plus delegation read better and change locally.

## Common mistakes

| Mistake | Correction |
|---|---|
| Splitting a cohesive class to "apply SRP" | SRP is about change owners; fragmentation adds indirection without new owners |
| Strategy/visitor patterns for a fixed variant set | YAGNI — OCP machinery pays only for open sets |
| "Program to an interface" with one implementation | The interface is dead weight until a second implementation or a test needs it |
| Implementing a fat interface with no-op methods | ISP: split by capability; or YAGNI: delete what nobody consumes |
| Deep inheritance to reuse code | Composition; reserve inheritance for substitutable is-a |
| Domain classes depending on Bukkit interfaces | DIP: invert — the domain owns the contracts, adapters implement them |
| Putting repository interfaces in the implementation package | Interfaces belong with their consumers (domain); impls live at the edge |