---
name: pebblehost-deploy
description: Use when deploying a built Minecraft/Paper plugin or mod jar to PebbleHost from CI, installing or authenticating the pb CLI, configuring CI server targets, restarting after an upload, troubleshooting PebbleHost upload or verification failures, or evaluating the deferred deployPebbleHost Gradle plugin. Triggers include "deploy to PebbleHost", "pb login", "pb file push", "PebbleHost CI", "canary rollout", "PEBBLEHOST_API_TOKEN", and "deployPebbleHost".
---

# PebbleHost Deployment

For the current prototype, **CI + the `pb` CLI is the canonical deployment path**. CI builds the exact jar, invokes one pinned push-capable `pb` binary, uploads it to `plugins/` or `mods/`, restarts the target, and verifies the result. `deployPebbleHost` is **deferred/deprecated for new setups**: it wraps the same CLI operations and adds orchestration that belongs in CI while the server topology is changing quickly.

## Path policy

| Path | Status | Use |
|---|---|---|
| CI invoking `pb` directly | **Canonical** | Normal deployments, multiple setups, target matrices, canary gates, and repeatable credentials |
| `pb` CLI directly from a workstation | **Manual fallback** | One-off upload, recovery, or debugging; use the same pinned binary and commands as CI |
| `deployPebbleHost` Gradle task | **Deferred/deprecated** | Do not add to new projects; migrate existing integrations to CI when they are touched |

The CLI performs the remote work. Keep Gradle responsible for building the jar, not for owning remote server topology. Do not maintain the Gradle plugin and CI as equal deployment authorities.

## Artifact model

Deployment is **jar upload, not remote install**: build the jar from the GitHub repository, push it into the server's `plugins/` (or `mods/`) directory, and restart the server. `pb` has no `link`, `install`, or repository command that clones GitHub source onto a PebbleHost server.

GitHub is the source and CI surface; PebbleHost receives the built artifact. Build the exact jar in CI, then pass that jar to `pb file push`. Installing `pb` from a GitHub release is only CLI installation. The deferred Gradle plugin is not part of the canonical project wiring.

Source and behavior facts below were verified 2026-08-29 against `pebblehost-cli` (master, tags, `feat/file-push-restored` branch) and `pebblehost-deploy` sources (`PebbleHostPlugin.java`, `DeployPebbleHostTask.java`, `PebbleHostClient.java`).

## Prerequisites

- A `pb` binary that exposes `file push`.
- A PebbleHost API credential supplied to CI as `PEBBLEHOST_API_TOKEN`.
- A server UUID and remote target directory (`plugins` for a plugin, `mods` for a mod).

Before any upload, bind the capability check to the exact binary CI will invoke:

```bash
PB_BIN="${PB_BIN:-$(command -v pb)}"
test -n "$PB_BIN" || {
    echo "No pb binary found; deployment is unavailable." >&2
    exit 1
}
"$PB_BIN" --version
"$PB_BIN" file --help | grep -Fq 'push' || {
    echo "$PB_BIN does not expose 'file push'; deployment is unavailable." >&2
    exit 1
}
```

Do not validate one binary and deploy with another. In CI, set `PB_BIN` explicitly and use it for every command.

### Current `file push` caveat

As of the 2026-08-29 verification, the latest release/tag `v2026.8.29.29` still does not contain `file push`; that subcommand exists only on the unmerged `feat/file-push-restored` branch. A stock installer can therefore succeed while deployment remains unavailable. Until a release includes `file push`, build or cache a vetted push-capable binary in CI — **pin an immutable commit SHA**, never a floating branch tip (a malicious tip update could exfiltrate `PEBBLEHOST_API_TOKEN` or abuse `power` restart):

```bash
# Pin verified 2026-08-31 against origin/feat/file-push-restored.
# Re-verify and update this SHA (and record the new date) before adopting a newer tip.
PB_CLI_REPO="${PB_CLI_REPO:-https://github.com/mintychochip/pebblehost-cli.git}"
PB_CLI_COMMIT="${PB_CLI_COMMIT:-501428ae0b2e22c1302845f77230b44972b37790}"

git clone "$PB_CLI_REPO" pebblehost-cli
cd pebblehost-cli
git fetch --depth 1 origin "$PB_CLI_COMMIT"
git checkout --detach "$PB_CLI_COMMIT"
test "$(git rev-parse HEAD)" = "$PB_CLI_COMMIT"
cargo build --release
export PB_BIN="$PWD/target/release/pb"
# Optional: record sha256sum of "$PB_BIN" in CI and verify before each deploy.
```

Do **not** `git checkout origin/feat/file-push-restored` (mutable). Prefer caching the built binary as a CI artifact keyed by `$PB_CLI_COMMIT`. Re-check upstream tags before assuming a release includes `file push`; record the new verification date when the pin changes.

### Authentication

Pass the credential non-interactively to the push-capable CLI:

```bash
: "${PEBBLEHOST_API_TOKEN:?PEBBLEHOST_API_TOKEN is required}"
"$PB_BIN" servers --json
```

The released CLI's current master reads `PEBBLEHOST_API_KEY`, while the verified push-capable branch reads `PEBBLEHOST_API_TOKEN`. Do not assume a runner's `pb login` state or an environment variable from a different CLI revision is compatible; pin the binary and use the variable it reads.

## Canonical CI deployment

A consuming project's deploy job should:

1. Check out the repository and run its normal build and quality gates.
2. Select the exact jar produced by that build; do not rebuild or glob an ambiguous artifact during deployment.
3. Expand a versioned target matrix or manifest containing each server UUID and `plugins`/`mods` directory. Keep changing setup topology in CI configuration, not Gradle project configuration.
4. Install or build one pinned push-capable `pb`, run the capability check above, and load `PEBBLEHOST_API_TOKEN` from protected CI secrets.
5. Upload the immutable jar:

   ```bash
   "$PB_BIN" file push "$JAR" \
     --server "$SERVER_ID" \
     --directory "$TARGET_DIR"
   ```

6. Restart because replacing a jar does not hot-reload code:

   ```bash
   "$PB_BIN" power "$SERVER_ID" --action restart
   ```

7. Fail the job on upload or restart errors. Confirm the target returns to the expected running state and confirm the plugin or mod loaded in the server console/log. Reachability alone does not prove that the new artifact loaded.

Do not claim deployment succeeded unless the capability check passes, the upload and restart commands succeed, and the server log confirms the plugin or mod loaded.

## Rollout and rollback

- Represent setups as a CI matrix or checked-in deployment manifest; keep server IDs and target directories out of Gradle build configuration.
- Use a manually gated canary job for the first target, then fan out to the remaining targets only after the canary's server log and health checks pass.
- Do not deploy every ordinary push while the project is prototyping. Use an explicitly invoked or approval-gated CI deployment.
- Retain the previous known-good jar or release identifier. Roll back by running the same `pb file push` and restart sequence with that artifact, then verify again.
- Stop or gate the remaining matrix when a canary or required target fails. The CLI is the deployment primitive; CI owns ordering, gating, and failure policy.
- When rollout is a separate post-canary job, bind it to a GitHub Environment with required reviewers; naming an environment without protection rules does not create an approval gate.

## Manual CLI fallback

Use this only for a one-server manual operation, recovery, or debugging. It is the same operation CI performs, not a second deployment implementation:

```bash
"$PB_BIN" servers --json
"$PB_BIN" file push ./build/libs/myplugin.jar \
  --server <SERVER_ID> \
  --directory plugins
"$PB_BIN" power <SERVER_ID> --action restart
```

Use `mods` for a mod. Confirm the server is running and then verify the plugin or mod in the server console/log. `pb file <SERVER_ID> <path>` reads a file, and `pb files <SERVER_ID>` lists files.

## Deferred Gradle plugin

`deployPebbleHost` is deferred/deprecated during prototyping. Do not add the `dev.mintychochip.pebblehost.deploy` plugin, GitHub Packages `pluginManagement` wiring, or a `pebblehost {}` block to new builds. Existing integrations are migration debt, not the recommended path.

The plugin calls the same `pb file push` primitive, so it does not solve a CLI release that lacks `file push`. Reconsider the plugin only after the deployment contract stabilizes and CI orchestration is demonstrably duplicated across projects.

## Common mistakes

| Wrong | Right | Why |
|---|---|---|
| Treating `deployPebbleHost` as the normal deployment path | Build in CI and invoke the pinned `pb` CLI | The plugin duplicates CLI work and couples changing server topology to Gradle |
| Assuming a successful `pb` install means deployment is available | Run `file --help` and require `push` on the exact `PB_BIN` | Released `pb` exits with `unrecognized subcommand 'file push'` |
| Validating one `pb` binary and invoking another | Set `PB_BIN` and reuse it for checks and deployment | Capability and token behavior vary by CLI revision |
| Building `pb` from a floating branch tip | Pin `PB_CLI_COMMIT` (immutable SHA) and verify `git rev-parse HEAD` | Branch tips move; a bad tip can steal deploy tokens |
| Treating "deploy" as installing the GitHub repository | Build the jar, upload it, and restart | PebbleHost receives artifacts, not repository source |
| Keeping server matrices in Gradle configuration | Store targets in a CI matrix or manifest | Setup topology is changing independently of the build |
| Restarting without verification | Check running state and server console/log load | Reachable does not prove the new artifact loaded |
| Deploying on every CI push | Use an explicit or approval-gated deploy job | Prototype rollouts need human control |
| Uploading to a stopped server without a recovery plan | Ensure it is running or gate the restart/verification path | Uploads to stopped nodes can fail silently |

## Verify

```bash
"$PB_BIN" --version
"$PB_BIN" file --help | grep -Fq 'push'
"$PB_BIN" servers --json
# Run the CI deployment job, or the manual fallback above.
# Then confirm plugin/mod load in the server console/log.
```
