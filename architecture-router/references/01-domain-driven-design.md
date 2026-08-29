# Domain-Driven Design (Reference)

Deep reference for the DDD routes in `../SKILL.md`. Read only when the router's directive does not fit your situation.

## What DDD gives a Paper plugin

DDD focuses design on the **business domain** — what the plugin does for players/operators — instead of the framework. A plugin's domain is usually small (ranks, homes, shops, kits, quests, economy), but the discipline pays off as it grows: rules live where they can be unit-tested without a server, and Bukkit stays at the edges. For a plugin whose logic is trivial (a permission check), skip the ceremony — the router's rules still apply cheaply.

## Core concepts, plugin-sized

| Concept | Plugin meaning | Example |
|---|---|---|
| Ubiquitous language | The words players/operators use, used in code | `Rank`, `trialExpiry`, `home`, `marketListing` — not `entity`, `data`, `item` |
| Bounded context | One module/package with its own language; other contexts translate at their boundary | `ranking/` vs `economy/` packages each with their own models |
| Aggregate | A cluster of objects changed as one unit, with one root enforcing invariants | `Rank` root with its rules; `Home` root owning location/title/owner rules |
| Repository | Persistence behind an interface the domain defines | `RankRepository` injected into `RankService`; SQLite impl lives elsewhere |
| Domain service | A stateless operation that orchestrates aggregates and rules | `RankService.applyTrial(playerId, rank)` |
| Application service (optional) | Coordinates use cases; delegates to domain; owns transactions | `RankCommand` calls a thin use-case that calls `RankService` |
| Invariant | A rule the domain never lets break, enforced in one place | "A rank cannot expire before its start"; "a home name is unique per player" |

## The anemic-model smell

An entity reduced to getters/setters with no behavior, all rules living in `Manager`/`Util` classes:

```java
// Anemic model — rules live outside, anyone can mutate anything
public class Rank {
  private String name;
  private long trialExpiry;
  public void setName(String name) { this.name = name; }
  public void setTrialExpiry(long trialExpiry) { this.trialExpiry = trialExpiry; }
}
// RankManager checks "expired?" at every call site with copy-pasted rules
```

Fix: move the rules into the model.

```java
// Rich model — state changes only through methods that enforce invariants
public final class Rank {
  public static final Duration TRIAL_LENGTH = Duration.ofDays(30);
  private final String name;
  private final Instant grantedAt;
  private final Instant trialExpiry;

  public Rank(String name, Instant grantedAt, Instant trialExpiry) {
    if (trialExpiry.isBefore(grantedAt)) {
      throw new IllegalArgumentException("trial cannot expire before it starts");
    }
    this.name = name;
    this.grantedAt = grantedAt;
    this.trialExpiry = trialExpiry;
  }

  public boolean isActiveAt(Instant now) {
    return now.isBefore(trialExpiry);
  }
}
```

Invariants enforced at construction and through methods, not checked ad hoc at call sites.

## The dependency rule, plugin-sized

- **Domain package** (`com.example.plugin.rank.domain` or a `common` module): plain Java; no `org.bukkit.*`, no persistence, no scheduler. Unit-testable without a server.
- **Application/entry**: commands, listeners — validate input, translate Paper types to domain types, delegate, report results.
- **Adapters**: repository implementations (SQLite files, `database-integration` patterns), scoreboard/chat rendering of domain results.

Dependency direction: entry and adapters depend on the domain; the domain depends on nothing framework-specific. Inject repository **interfaces** the domain defines.

## Repository interface example

```java
// Defined in the domain; implementation lives at the edge
public interface RankRepository {
  Optional<Rank> find(String playerId);
  void save(Rank rank);
}
```

The domain service depends on `RankRepository`, never on the SQLite class.

## Applying DDD incrementally

1. Name the package/s by business concept, not framework role.
2. Put each piece of behavior next to the data it governs (start with invariants — the rules that are currently copy-pasted).
3. Abstract persistence behind an interface only when a second implementation or a test requires it (YAGNI — the router rule 7 still applies).
4. Skip aggregates/ubiquitous-language ceremony if the model is a handful of fields and one rule; the dependency direction is the part that always pays.

## When DDD does not fit

- Trivial plugins (a few command handlers, no shared rules): the dependency direction still applies, aggregates do not.
- Plugin internals nobody extends or tests: discipline should not block shipping; apply rules 1 and 10 from the router and stop there.

## Common mistakes

| Mistake | Correction |
|---|---|
| Entities as getter/setter bags with `Manager` classes | Move behavior into the model; invariants enforced in one place |
| Domain package importing Bukkit types | Adapters own Bukkit; domain depends only on JDK types |
| Repository interface created before any consumer needs it | YAGNI — inject the concrete class until a second implementation or a test exists |
| Commands containing domain rules | Commands validate and delegate; rules live in the domain layer |
| Treating Bukkit events as domain events | Bukkit's bus is notification; persist state explicitly (see 05-cqrs-event-sourcing) |
| Modeling with framework vocabulary (`Entity`, `Event` wrappers) instead of domain vocabulary | Use the ubiquitous language—`Rank`, `Home`, `Listing` |
| Over-engineering: aggregates, repositories, services for a 50-line plugin | The dependency rule is the floor; the rest scales with real complexity |