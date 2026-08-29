#!/usr/bin/env python3
"""
export_csv.py - Export server-roadmap.ods (Roadmap & NMS sheets) to CSV and XLSX formats and update README.md
"""

import argparse
import csv
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


def parse_all_ods_sheets(ods_path: Path):
    """Parse all sheets from an OpenDocument Spreadsheet (.ods) file."""
    if not ods_path.exists():
        raise FileNotFoundError(f"Source file not found: {ods_path}")

    with zipfile.ZipFile(ods_path) as z:
        content = z.read('content.xml')
        root = ET.fromstring(content)
        namespaces = {
            'table': 'urn:oasis:names:tc:opendocument:xmlns:table:1.0',
            'text': 'urn:oasis:names:tc:opendocument:xmlns:text:1.0',
            'office': 'urn:oasis:names:tc:opendocument:xmlns:office:1.0'
        }
        tables = root.findall('.//table:table', namespaces)
        if not tables:
            raise ValueError(f"No tables found in {ods_path}")

    sheets_data = {}
    for table_elem in tables:
        table_name = table_elem.attrib.get(f'{{{namespaces["table"]}}}name', 'Sheet1')
        rows = table_elem.findall('.//table:table-row', namespaces)
        parsed_rows = []
        for r in rows:
            cells = r.findall('.//table:table-cell', namespaces)
            row_vals = []
            for c in cells:
                repeat = int(c.attrib.get(f'{{{namespaces["table"]}}}number-columns-repeated', '1'))
                txt_elems = c.findall('.//text:p', namespaces)
                txt = ' '.join(elem.text for elem in txt_elems if elem.text).strip()
                if repeat > 20 and not txt:
                    continue
                for _ in range(min(repeat, 10)):
                    row_vals.append(txt)
            while row_vals and not row_vals[-1]:
                row_vals.pop()
            if row_vals:
                parsed_rows.append(row_vals)
        sheets_data[table_name] = parsed_rows

    return sheets_data


def process_roadmap_sheet(raw_rows):
    records = []
    for row_vals in raw_rows:
        if not row_vals or 'Developer' in row_vals[0]:
            continue
        dev = row_vals[0] if len(row_vals) > 0 else ""
        v1 = row_vals[1] if len(row_vals) > 1 else ""
        v2 = row_vals[2] if len(row_vals) > 2 else ""
        resp = row_vals[3] if len(row_vals) > 3 else ""
        repo = row_vals[4] if len(row_vals) > 4 else ""

        plugin = v1 or v2
        if not plugin:
            continue

        target_version = "V1" if v1 else ("V2" if v2 else "")
        dev_display = dev if dev else "3rd Party"

        records.append({
            "Plugin": plugin,
            "Version": target_version,
            "Developer": dev_display,
            "Responsibilities": resp,
            "Repository": repo
        })
    return records


def process_nms_sheet(raw_rows):
    records = []
    for row_vals in raw_rows:
        if not row_vals or 'Plugin' in row_vals[0]:
            continue
        plugin = row_vals[0] if len(row_vals) > 0 else ""
        uses_nms = row_vals[1] if len(row_vals) > 1 else ""
        tier = row_vals[2] if len(row_vals) > 2 else ""
        details = row_vals[3] if len(row_vals) > 3 else ""
        repo = row_vals[4] if len(row_vals) > 4 else ""

        if not plugin:
            continue

        records.append({
            "Plugin": plugin,
            "Uses NMS": uses_nms,
            "Evidence Tier": tier,
            "Technical Details & Seams": details,
            "Repository": repo
        })
    return records


def export_csv_file(records, csv_path: Path, fieldnames):
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for rec in records:
            writer.writerow(rec)
    print(f"✓ Exported CSV: {csv_path} ({len(records)} entries)")


def export_xlsx(ods_path: Path, xlsx_path: Path, output_dir: Path):
    cmd = ["libreoffice", "--headless", "--convert-to", "xlsx", "--outdir", str(output_dir), str(ods_path)]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"LibreOffice XLSX conversion failed (exit code {res.returncode}): {res.stderr.strip()}")
    if not xlsx_path.exists():
        raise FileNotFoundError(f"Expected XLSX output was not created at: {xlsx_path}")
    print(f"✓ Exported XLSX: {xlsx_path} ({xlsx_path.stat().st_size} bytes)")


def update_readme(roadmap_records, nms_records, readme_path: Path):
    readme_content = f"""# Server Setup Roadmap & Plugin Directory

Spreadsheet roadmap tracking Minecraft server plugins, versions, ownership, responsibilities, repository links, and NMS usage audits.

## 📊 Roadmap Overview

| Plugin | Version | Developer | Responsibilities | Repository |
| :--- | :---: | :--- | :--- | :--- |
"""
    for rec in roadmap_records:
        repo_link = f"[{rec['Repository'].replace('https://github.com/', '')}]({rec['Repository']})" if rec['Repository'] else "—"
        readme_content += f"| **{rec['Plugin']}** | `{rec['Version']}` | {rec['Developer']} | {rec['Responsibilities']} | {repo_link} |\n"

    readme_content += """
---

## 🧩 NMS & Server Internals Audit

Audit of Minecraft internal (`net.minecraft.*` / `org.bukkit.craftbukkit.*`) usage across all roadmap repositories:

| Plugin | Uses NMS | Evidence Tier | Technical Details & Seams | Repository |
| :--- | :---: | :--- | :--- | :--- |
"""
    for rec in nms_records:
        status_badge = f"`{rec['Uses NMS']}`"
        repo_link = f"[{rec['Repository'].replace('https://github.com/', '')}]({rec['Repository']})" if rec['Repository'] else "—"
        readme_content += f"| **{rec['Plugin']}** | {status_badge} | {rec['Evidence Tier']} | {rec['Technical Details & Seams']} | {repo_link} |\n"

    readme_content += """
---

## 📁 Repository Downloads & Formats

| Format | File | Description |
| :--- | :--- | :--- |
| **Roadmap CSV** | [`server-roadmap.csv`](./server-roadmap.csv) | Primary plugin roadmap dataset |
| **NMS Audit CSV** | [`server-roadmap-nms.csv`](./server-roadmap-nms.csv) | NMS and server internals audit dataset |
| **Excel (XLSX)** | [`server-roadmap.xlsx`](./server-roadmap.xlsx) | Multi-sheet Microsoft Excel workbook (`Roadmap` + `NMS` tabs) |
| **OpenDocument (ODS)** | [`server-roadmap.ods`](./server-roadmap.ods) | Multi-sheet LibreOffice / OpenOffice Calc master file |

---

## 🛠️ Syncing & Updating

When you update `server-roadmap.ods`, run the sync script to automatically regenerate the CSVs, XLSX, and README markdown tables:

```bash
python3 export_csv.py
```

To commit and push changes to GitHub (opt-in):
```bash
python3 export_csv.py --push
```
"""
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(readme_content.strip() + "\n")
    print(f"✓ Updated README: {readme_path}")


def git_push(repo_dir: Path, message: str = "Update server roadmap exports (CSV, XLSX, README)"):
    os.chdir(repo_dir)
    subprocess.run(["git", "add", "."], check=True)
    status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, check=True)
    if not status.stdout.strip():
        print("✓ No changes to commit.")
        return
    subprocess.run(["git", "commit", "-m", message], check=True)
    push_res = subprocess.run(["git", "push"], capture_output=True, text=True)
    if push_res.returncode == 0:
        print("✓ Successfully pushed changes to GitHub.")
    else:
        print(f"⚠ Warning: git push failed: {push_res.stderr.strip()}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Export server-roadmap (.ods -> .csv / .xlsx / README)")
    parser.add_argument("--format", choices=["csv", "xlsx", "all"], default="all", help="Export format")
    parser.add_argument("--push", action="store_true", default=False, help="Commit and push changes to GitHub (opt-in)")
    parser.add_argument("--commit-msg", type=str, default="Update server roadmap exports (CSV, XLSX, README)", help="Git commit message")

    args = parser.parse_args()
    repo_dir = Path(__file__).parent.resolve()
    ods_path = repo_dir / "server-roadmap.ods"
    csv_path = repo_dir / "server-roadmap.csv"
    nms_csv_path = repo_dir / "server-roadmap-nms.csv"
    xlsx_path = repo_dir / "server-roadmap.xlsx"
    readme_path = repo_dir / "README.md"

    sheets_data = parse_all_ods_sheets(ods_path)
    roadmap_rows = sheets_data.get('Roadmap', sheets_data.get('Sheet1', []))
    nms_rows = sheets_data.get('NMS', [])

    roadmap_records = process_roadmap_sheet(roadmap_rows)
    nms_records = process_nms_sheet(nms_rows)

    if args.format in ["csv", "all"]:
        export_csv_file(roadmap_records, csv_path, ["Plugin", "Version", "Developer", "Responsibilities", "Repository"])
        if nms_records:
            export_csv_file(nms_records, nms_csv_path, ["Plugin", "Uses NMS", "Evidence Tier", "Technical Details & Seams", "Repository"])

    if args.format in ["xlsx", "all"]:
        export_xlsx(ods_path, xlsx_path, repo_dir)

    update_readme(roadmap_records, nms_records, readme_path)

    if args.push:
        git_push(repo_dir, args.commit_msg)


if __name__ == "__main__":
    main()
