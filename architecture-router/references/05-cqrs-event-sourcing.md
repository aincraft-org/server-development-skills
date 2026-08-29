# CQRS & Event Sourcing (Reference)

Deep reference for the read/write separation and event-sourcing routes in `../SKILL.md`. Read when query shapes diverge from command paths, or when someone proposes replaying Bukkit events as truth.

## CQRS — Command Query Responsibility Segregation

**Separate the paths that change state (commands) from the paths that read it (queries).** Full CQRS separates models and stores; *query/command separation* — the incremental, plugin-appropriate form — separates the code paths and shapes:

- **Commands**: go through the domain, enforce invariants, return outcome (or nothing).
- **Queries**: return display/read shapes, may skip domain ceremony, must not mutate.

### When it pays

| Signal | Payoff |
|---|---|
| Query results shaped differently from domain models (DTR rows, scoreboard lines, formatted chat) | Read shapes live next to their consumers; domain models stay lean |
| The same entity is fetched with different degrees of eagerness (full object vs. a few fields) | Separate DAO/repository read methods or read models |
| Async reads off the main thread | Query path isolates the async code (rule 10 in the router) |
| Handlers mixing mutation and answer-building | Split: a write command, then a read |

### Minimal plugin pattern

```java
// Command path — domain + invariants
rankService.promote(playerId, Rank.TRIAL);          // mutates, enforces rules

// Query path — read shape for the caller
RankSummary summary = rankReadModel.summary(playerId); // pure read, no mutation
```

The command returns void/success or throws; the query returns a shape and changes nothing. If reads and writes share a shape and a path, separation is overhead — keep one code path (YAGNI).

### When NOT to use CQRS

- Reads and writes use the same model and same path (most small listeners) — separation only adds indirection.
- No divergence in query shapes — the trigger for CQRS is divergence, not fashion.

## Event sourcing — the trap in plugin land

Event sourcing: state is the *replay* of an append-only event log; the log is the source of truth. In a Paper plugin this is almost always a mistake:

| Trap | Why it fails |
|---|---|
| Bukkit's `@EventHandler` bus is a notification mechanism, not an event store | Listeners fire for anything happening anywhere; they are not an ordered, owned log of *your domain* |
| Reconstructing state from listener invocations | Missed/duplicated events (reload, other plugins, server restarts) silently corrupt state |
| Persisting "events" for auditing | Bukkit events lack the boundary and schema of domain events; drift breaks replay |
| Adding an event log for a feature that needs a database row | The row is the state; the log is ceremony |

**The rule: persist state explicitly** (a row, a file — see `database-integration`), and let Bukkit events only notify. If you need an audit/history, write an explicit `HistoryEntry` record at the domain boundary — a purpose-built append, not listener replay.

### A legitimate sliver

An explicit, domain-owned **domain event** — a record written when a rule fires (`RankChanged(playerId, from, to, at)`), persisted alongside state, consumed by other features to react (badges, messages) — is a good pattern. It is *not* event sourcing: state stays authoritative, the event is history + notification.

```java
// History/notification, not event sourcing
public record RankChanged(String playerId, Rank from, Rank to, Instant at) {}

rankService.promote(playerId, Rank.TRIAL);            // state changes here
history.append(new RankChanged(playerId, Rank.MEMBER, Rank.TRIAL, now())); // history here
otherFeatures.onRankChanged(event);                   // notification here
```

## Common mistakes

| Mistake | Correction |
|---|---|
| Replaying `@EventHandler` invocations as the source of truth | Persist state explicitly; events notify only |
| CQRS ceremony for identical read/write paths | One code path until shapes genuinely diverge |
| Commands returning rich query data | Commands return outcome; queries return shapes |
| Using Bukkit events as an audit log | Write explicit domain history records at the boundary |
| Async query path mutating shared state | Query path is read-only; mutations belong to commands |