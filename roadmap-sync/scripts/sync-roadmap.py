#!/usr/bin/env python3
"""
sync-roadmap.py - Synchronize Minecraft Server Setup Roadmap & Plugin Directory

Exports .ods spreadsheet into clean .csv and .xlsx formats, regenerates
the README.md overview table, and optionally commits/pushes to GitHub.
Supports task-completion updates via --update-plugin.
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


def update_or_add_plugin_ods(ods_path: Path, plugin_name: str, developer: str = None, version: str = None, responsibilities: str = None, repo_url: str = None):
    """Update or insert a plugin row into the OpenDocument Spreadsheet (.ods)."""
    tmp_dir = Path(tempfile.mkdtemp())
    with zipfile.ZipFile(ods_path, 'r') as zin:
        zin.extractall(tmp_dir)

    content_xml_path = tmp_dir / "content.xml"
    ET.register_namespace('table', 'urn:oasis:names:tc:opendocument:xmlns:table:1.0')
    ET.register_namespace('office', 'urn:oasis:names:tc:opendocument:xmlns:office:1.0')
    ET.register_namespace('text', 'urn:oasis:names:tc:opendocument:xmlns:text:1.0')
    ET.register_namespace('calcext', 'urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0')

    tree = ET.parse(content_xml_path)
    root = tree.getroot()

    ns_table = 'urn:oasis:names:tc:opendocument:xmlns:table:1.0'
    ns_text = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0'
    ns_office = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0'
    ns_calcext = 'urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0'

    t = root.findall(f'.//{{{ns_table}}}table')[0]
    rows = t.findall(f'.//{{{ns_table}}}table-row')

    found_row = None
    for r in rows:
        cells = r.findall(f'.//{{{ns_table}}}table-cell')
        texts = [p.text.strip() for c in cells for p in c.findall(f'.//{{{ns_text}}}p') if p.text]
        if plugin_name.lower() in [txt.lower() for txt in texts]:
            found_row = r
            break

    def set_cell_text(cell, text):
        cell.attrib[f'{{{ns_office}}}value-type'] = 'string'
        cell.attrib[f'{{{ns_calcext}}}value-type'] = 'string'
        p_elems = cell.findall(f'.//{{{ns_text}}}p')
        if p_elems:
            p_elems[0].text = text
        else:
            p = ET.SubElement(cell, f'{{{ns_text}}}p')
            p.text = text

    if found_row is not None:
        cells = found_row.findall(f'.//{{{ns_table}}}table-cell')
        while len(cells) < 5:
            nc = ET.SubElement(found_row, f'{{{ns_table}}}table-cell')
            cells.append(nc)

        if developer is not None:
            set_cell_text(cells[0], developer)
        if version == "V1":
            set_cell_text(cells[1], plugin_name)
            for p in cells[2].findall(f'.//{{{ns_text}}}p'):
                cells[2].remove(p)
        elif version == "V2":
            set_cell_text(cells[2], plugin_name)
            for p in cells[1].findall(f'.//{{{ns_text}}}p'):
                cells[1].remove(p)
        if responsibilities is not None:
            set_cell_text(cells[3], responsibilities)
        if repo_url is not None:
            set_cell_text(cells[4], repo_url)
        print(f"✓ Updated existing plugin '{plugin_name}' in {ods_path}")
    else:
        new_row = ET.SubElement(t, f'{{{ns_table}}}table-row', {f'{{{ns_table}}}style-name': 'ro1'})
        c0 = ET.SubElement(new_row, f'{{{ns_table}}}table-cell')
        if developer:
            set_cell_text(c0, developer)
            
        c1 = ET.SubElement(new_row, f'{{{ns_table}}}table-cell')
        if version != "V2":
            set_cell_text(c1, plugin_name)
            
        c2 = ET.SubElement(new_row, f'{{{ns_table}}}table-cell')
        if version == "V2":
            set_cell_text(c2, plugin_name)
            
        c3 = ET.SubElement(new_row, f'{{{ns_table}}}table-cell')
        if responsibilities:
            set_cell_text(c3, responsibilities)
            
        c4 = ET.SubElement(new_row, f'{{{ns_table}}}table-cell')
        if repo_url:
            set_cell_text(c4, repo_url)
        print(f"✓ Added new plugin '{plugin_name}' to {ods_path}")

    tree.write(content_xml_path, encoding='utf-8', xml_declaration=True)

    with zipfile.ZipFile(ods_path, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
        mimetype_path = tmp_dir / 'mimetype'
        if mimetype_path.exists():
            zout.write(mimetype_path, 'mimetype', compress_type=zipfile.ZIP_STORED)
        for root_p, _, files in os.walk(tmp_dir):
            for file in files:
                if file == 'mimetype':
                    continue
                full_p = Path(root_p) / file
                rel_p = full_p.relative_to(tmp_dir)
                zout.write(full_p, rel_p)

    shutil.rmtree(tmp_dir)


def parse_ods_table(ods_path: Path):
    """Parse table rows from an OpenDocument Spreadsheet (.ods) file."""
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
        t = tables[0]
        rows = t.findall('.//table:table-row', namespaces)

    parsed_records = []
    for r in rows:
        cells = r.findall('.//table:table-cell', namespaces)
        row_vals = []
        for c in cells:
            repeat = int(c.attrib.get('{urn:oasis:names:tc:opendocument:xmlns:table:1.0}number-columns-repeated', '1'))
            txt_elems = c.findall('.//text:p', namespaces)
            txt = ' '.join(elem.text for elem in txt_elems if elem.text).strip()
            if repeat > 20 and not txt:
                continue
            for _ in range(min(repeat, 10)):
                row_vals.append(txt)
        while row_vals and not row_vals[-1]:
            row_vals.pop()
        if not any(row_vals):
            continue

        if 'Developer' in row_vals[0]:
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

        parsed_records.append({
            "Plugin": plugin,
            "Version": target_version,
            "Developer": dev_display,
            "Responsibilities": resp,
            "Repository": repo
        })

    return parsed_records


def export_csv(records, csv_path: Path):
    """Write parsed records to CSV format."""
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["Plugin", "Version", "Developer", "Responsibilities", "Repository"])
        writer.writeheader()
        for rec in records:
            writer.writerow(rec)
    print(f"✓ Exported CSV: {csv_path} ({len(records)} entries)")


def export_xlsx(ods_path: Path, xlsx_path: Path, output_dir: Path):
    """Convert .ods to .xlsx using headless LibreOffice."""
    cmd = [
        "libreoffice",
        "--headless",
        "--convert-to",
        "xlsx",
        "--outdir",
        str(output_dir),
        str(ods_path)
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"LibreOffice XLSX conversion failed (exit code {res.returncode}): {res.stderr.strip()}")
    if not xlsx_path.exists():
        raise FileNotFoundError(f"Expected XLSX output was not created at: {xlsx_path}")
    print(f"✓ Exported XLSX: {xlsx_path} ({xlsx_path.stat().st_size} bytes)")


def update_readme(records, readme_path: Path):
    """Generate clean README.md with table overview."""
    readme_content = f"""# Server Setup Roadmap & Plugin Directory

Spreadsheet roadmap tracking Minecraft server plugins, versions, ownership, responsibilities, and repository links.

## 📊 Roadmap Overview

| Plugin | Version | Developer | Responsibilities | Repository |
| :--- | :---: | :--- | :--- | :--- |
"""
    for rec in records:
        repo_link = f"[{rec['Repository'].replace('https://github.com/', '')}]({rec['Repository']})" if rec['Repository'] else "—"
        readme_content += f"| **{rec['Plugin']}** | `{rec['Version']}` | {rec['Developer']} | {rec['Responsibilities']} | {repo_link} |\n"

    readme_content += """
---

## 📁 Repository Downloads & Formats

| Format | File | Description |
| :--- | :--- | :--- |
| **CSV** | [`server-roadmap.csv`](./server-roadmap.csv) | Raw comma-separated values (for scripts, DBs, and CI) |
| **Excel (XLSX)** | [`server-roadmap.xlsx`](./server-roadmap.xlsx) | Native Microsoft Excel format |
| **OpenDocument (ODS)** | [`server-roadmap.ods`](./server-roadmap.ods) | LibreOffice / OpenOffice Calc master format |

---

## 🛠️ Syncing & Updating

When you update `server-roadmap.ods`, run the sync script to automatically regenerate the CSV, XLSX, and README markdown table:

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
    """Stage, commit, and push updates to the remote git repository when explicitly requested."""
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
    parser = argparse.ArgumentParser(description="Sync and export server roadmap (.ods -> .csv / .xlsx / README)")
    parser.add_argument(
        "--repo-dir",
        type=Path,
        default=Path("/home/jlo/dev/server-roadmap"),
        help="Path to server-roadmap repository directory"
    )
    parser.add_argument(
        "--ods-file",
        type=Path,
        default=None,
        help="Path to source .ods file (defaults to <repo-dir>/server-roadmap.ods)"
    )
    parser.add_argument(
        "--format",
        choices=["csv", "xlsx", "all"],
        default="all",
        help="Export format (csv, xlsx, or all)"
    )
    parser.add_argument(
        "--push",
        action="store_true",
        default=False,
        help="Explicitly commit and push changes to remote GitHub repository (opt-in)"
    )
    parser.add_argument(
        "--commit-msg",
        type=str,
        default="Update server roadmap exports (CSV, XLSX, README)",
        help="Git commit message when --push is used"
    )
    parser.add_argument(
        "--update-plugin",
        type=str,
        default=None,
        help="Plugin name to update or add upon task/milestone completion"
    )
    parser.add_argument(
        "--developer",
        type=str,
        default=None,
        help="Developer name when updating a plugin"
    )
    parser.add_argument(
        "--version-milestone",
        choices=["V1", "V2"],
        default=None,
        help="Milestone version (V1 or V2)"
    )
    parser.add_argument(
        "--responsibilities",
        type=str,
        default=None,
        help="Responsibilities / feature summary when updating a plugin"
    )
    parser.add_argument(
        "--repo-url",
        type=str,
        default=None,
        help="GitHub repository URL when updating a plugin"
    )

    args = parser.parse_args()
    repo_dir = args.repo_dir.resolve()
    ods_path = (args.ods_file or (repo_dir / "server-roadmap.ods")).resolve()
    csv_path = repo_dir / "server-roadmap.csv"
    xlsx_path = repo_dir / "server-roadmap.xlsx"
    readme_path = repo_dir / "README.md"

    if not repo_dir.exists():
        print(f"Error: Repository directory {repo_dir} does not exist", file=sys.stderr)
        sys.exit(1)

    # 1. Update ODS if --update-plugin passed
    if args.update_plugin:
        update_or_add_plugin_ods(
            ods_path,
            plugin_name=args.update_plugin,
            developer=args.developer,
            version=args.version_milestone,
            responsibilities=args.responsibilities,
            repo_url=args.repo_url
        )
        # Also sync ambient Documents copy if it exists
        doc_ods = Path("/home/jlo/Documents/server-roadmap.ods")
        if doc_ods.exists():
            update_or_add_plugin_ods(
                doc_ods,
                plugin_name=args.update_plugin,
                developer=args.developer,
                version=args.version_milestone,
                responsibilities=args.responsibilities,
                repo_url=args.repo_url
            )

    print(f"Reading roadmap from: {ods_path}")
    records = parse_ods_table(ods_path)

    if args.format in ["csv", "all"]:
        export_csv(records, csv_path)

    if args.format in ["xlsx", "all"]:
        export_xlsx(ods_path, xlsx_path, repo_dir)

    update_readme(records, readme_path)

    if args.push:
        commit_msg = args.commit_msg
        if args.update_plugin and args.commit_msg == "Update server roadmap exports (CSV, XLSX, README)":
            commit_msg = f"Update '{args.update_plugin}' in server roadmap"
        git_push(repo_dir, commit_msg)


if __name__ == "__main__":
    main()
