---
name: roadmap-sync
description: Use when syncing, updating, exporting, or publishing the Minecraft server setup roadmap, plugin directory, or spreadsheet (server-roadmap.ods, server-roadmap.csv, server-roadmap.xlsx), converting .ods spreadsheets into clean CSV and Excel XLSX formats, updating repository README tables, or pushing roadmap updates to the mintychochip/server-roadmap repository upon task completion or plugin milestone releases. Triggers include "update roadmap", "export csv", "export xlsx", "sync roadmap", server-roadmap, and task completion roadmap update.
---

# Roadmap Synchronization & Export

Maintains and synchronizes the Minecraft server setup roadmap between master OpenDocument spreadsheets (`.ods`), clean comma-separated values (`.csv`), Microsoft Excel workbooks (`.xlsx`), and the repository `README.md` markdown table.

Behaviors and tool chains verified 2026-08-29 against LibreOffice 25.x / 26.x headless CLI, Python 3.14 standard XML/CSV libraries, and GitHub CLI (`gh`).

---

## 🎯 Architecture & Workflow

```
[ server-roadmap.ods ]  (Master spreadsheet edited via Calc/LibreOffice or CLI)
         │
         ├──► [ python3 roadmap-sync/scripts/sync-roadmap.py ]
         │          ├──► [ server-roadmap.csv ]   (Raw tabular dataset for CLI/CI)
         │          ├──► [ server-roadmap.xlsx ]  (Converted Excel format)
         │          └──► [ README.md ]            (Rendered Markdown table)
         │
         └──► (Explicit --push) ──► git commit & push to mintychochip/server-roadmap
```

---

## 🛠️ Usage

### 1. Basic Synchronization (Local)
Regenerates CSV, XLSX, and README from `server-roadmap.ods`:

```bash
# Run the sync script within the skill directory:
./roadmap-sync/scripts/sync-roadmap.py

# Or targeting a specific repository directory:
./roadmap-sync/scripts/sync-roadmap.py --repo-dir /path/to/server-roadmap
```

### 2. Task Completion & Plugin Milestone Updates
Agents or scripts can update or add a plugin directly upon completing a task or cutting a release:

```bash
./roadmap-sync/scripts/sync-roadmap.py \
  --update-plugin "Kitsune" \
  --developer "mintychochip" \
  --version-milestone "V1" \
  --responsibilities "AI semantic storage search, natural language item finder" \
  --repo-url "https://github.com/mintychochip/kitsune" \
  --push
```

### 3. Export Specific Formats
```bash
# Only CSV:
./roadmap-sync/scripts/sync-roadmap.py --format csv

# Only XLSX:
./roadmap-sync/scripts/sync-roadmap.py --format xlsx
```

### 4. Sync and Push to GitHub (Explicit Opt-in)
Staging, committing, and pushing to the remote repository is strictly opt-in via `--push`:

```bash
./roadmap-sync/scripts/sync-roadmap.py --push --commit-msg "Update plugin roadmap and dependencies"
```

---

## 📋 Data Schema

The roadmap synchronizer parses and normalizes the following 5 columns:

| Column | Header | Description | Example |
| :---: | :--- | :--- | :--- |
| **A** | `Developer` | Lead developer or `3rd Party` | `mintychochip`, `ChaosInferno` |
| **B** | `V1` | V1 milestone plugin name | `Mint`, `Guilds`, `Kitsune` |
| **C** | `V2` | V2 milestone plugin name | `Processes`, `Cinematics` |
| **D** | `Responsibilities` | Feature scope and purpose | `Durable economy ledger...` |
| **E** | `Repository` | Verified GitHub URL | `https://github.com/aincraft-org/mint` |

---

## ⚠️ Common Mistakes

| Mistake | Consequence | Fix |
| :--- | :--- | :--- |
| Editing `server-roadmap.csv` directly | Overwritten on next `.ods` sync | Always edit `server-roadmap.ods` (or pass `--update-plugin`), then run `sync-roadmap.py`. |
| Missing LibreOffice for XLSX conversion | XLSX export fails or stays stale | Verify `libreoffice --version` is present; script raises RuntimeError if conversion fails. |
| Committing LibreOffice lock files (`.~lock.*.ods#`) | Pollutes git history | Ensure `.gitignore` ignores `.~lock.*.ods#`. |
| Expecting automated push | Changes stay local | Push is opt-in by design; pass `--push` explicitly when ready to update GitHub. |

---

## ✅ Verification

Run the verification test against the repository:

```bash
/home/jlo/dev/server-development-skills/roadmap-sync/scripts/sync-roadmap.py --repo-dir /home/jlo/dev/server-roadmap
git -C /home/jlo/dev/server-roadmap status --short
```
