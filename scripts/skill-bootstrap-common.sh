#!/usr/bin/env bash
# Shared catalog parsing and dry-run helpers for the skill-bootstrap scripts.
# Keep this file sourceable: callers own shell options and command dispatch.

_catalog_validate_awk() {
  awk '
    BEGIN {
      TAB = sprintf("%c", 9)
      HEADER = "kind" TAB "profile" TAB "agent" TAB "name" TAB "source" TAB "ref" TAB "subpath" TAB "mode"
      OPEN = "<!-- skill-bootstrap-catalog:v1 -->"
      CLOSE = "<!-- /skill-bootstrap-catalog -->"
      FS = TAB
      in_catalog = 0
      closed = 0
      header_seen = 0
      open_count = 0
      close_count = 0
      errors = 0
    }
    function error(message) {
      printf "catalog: %s\n", message
      errors++
    }
    function allowed(value, first, second, third, fourth) {
      return value == first || value == second || value == third || value == fourth
    }
    {
      if ($0 == OPEN) {
        open_count++
        if (open_count > 1)
          error("duplicate start marker at line " NR)
        if (closed)
          error("start marker appears after the end marker at line " NR)
        in_catalog = 1
        next
      }
      if ($0 == CLOSE) {
        close_count++
        if (!in_catalog)
          error("end marker appears without a start marker at line " NR)
        else if (closed)
          error("duplicate end marker at line " NR)
        closed = 1
        next
      }
      if (!in_catalog || closed)
        next

      if (!header_seen) {
        if ($0 ~ /^[[:space:]]*$/)
          next
        header_seen = 1
        if ($0 != HEADER)
          error("missing or invalid eight-column header at line " NR)
        next
      }

      if ($0 ~ /^[[:space:]]*$/)
        next

      row++
      if (index($0, TAB) == 0) {
        error("row " row " (line " NR ") is not tab-separated")
        next
      }
      field_count = split($0, field, TAB)
      if (field_count != 8) {
        error("row " row " (line " NR ") has " field_count " fields; expected 8")
        next
      }

      kind = field[1]
      profile = field[2]
      agent = field[3]
      name = field[4]
      source = field[5]
      ref = field[6]
      subpath = field[7]
      mode = field[8]

      if (kind != "skill" && kind != "tool")
        error("row " row ", field kind: unknown value '" kind "'")
      if (!allowed(agent, "pi", "codex", "both", "all"))
        error("row " row ", field agent: unknown value '" agent "'")
      if (name !~ /^[a-z0-9-]+$/)
        error("row " row ", field name: expected lowercase letters, digits, or hyphens")
      if (source == "")
        error("row " row ", field source: value is required")
      if (ref == "")
        error("row " row ", field ref: value is required")
      if (subpath == "")
        error("row " row ", field subpath: value is required")
      if (!allowed(mode, "local-skill", "pi-package", "skills-cli", "manual-marketplace") && mode != "npm-package")
        error("row " row ", field mode: unknown value '" mode "'")

      key = kind SUBSEP profile SUBSEP agent SUBSEP name
      if (seen[key]++)
        error("row " row ": duplicate key (" kind ", " profile ", " agent ", " name ")")

      if (kind == "tool") {
        if (profile != "all")
          error("row " row ", field profile: tool rows must use profile all")
        if (agent != "all")
          error("row " row ", field agent: shared tool rows must use agent all")
        if (name != "skills")
          error("row " row ", field name: the shared tool must be skills")
        if (mode != "npm-package")
          error("row " row ", field mode: the skills tool must use npm-package")
      } else {
        if (profile == "all")
          error("row " row ", field profile: all is reserved for the shared tool row")
        if (!allowed(profile, "paper", "superpowers", "google-sheets", ""))
          error("row " row ", field profile: unknown value '" profile "'")
        if (agent == "all")
          error("row " row ", field agent: all is reserved for the shared tool row")
        if (profile == "paper") {
          if (source != "local")
            error("row " row ": paper rows must use source local")
          if (mode != "local-skill")
            error("row " row ": Paper rows must use mode local-skill")
        } else if (profile == "superpowers") {
          if (agent == "pi" && mode != "pi-package")
            error("row " row ": Superpowers Pi rows must use mode pi-package")
          else if (agent == "codex" && mode != "manual-marketplace")
            error("row " row ": Superpowers Codex rows must use mode manual-marketplace")
          else if (agent != "pi" && agent != "codex")
            error("row " row ": Superpowers rows must target pi or codex")
          if (mode == "pi-package" && (agent != "pi" || profile != "superpowers"))
            error("row " row ": pi-package is only valid for Superpowers/Pi")
          if (mode == "manual-marketplace" && (agent != "codex" || profile != "superpowers"))
            error("row " row ": manual-marketplace is only valid for Superpowers/Codex")
        } else if (profile == "google-sheets") {
          if (mode != "skills-cli")
            error("row " row ": Google rows must use mode skills-cli")
        } else {
          error("row " row ", field profile: value is required")
        }
      }
    }
    END {
      if (open_count == 0)
        error("missing start marker")
      else if (open_count != 1)
        error("expected exactly one start marker")
      if (close_count == 0)
        error("missing end marker")
      else if (close_count != 1)
        error("expected exactly one end marker")
      if (open_count == 1 && close_count == 1 && !header_seen)
        error("missing catalog header")
      if (errors)
        exit 1
    }
  ' "$1"
}

catalog_validate() {
  if [ "$#" -ne 1 ]; then
    printf 'catalog: usage: catalog_validate FILE\n' >&2
    return 1
  fi
  if [ ! -r "$1" ]; then
    printf 'catalog: cannot read catalog: %s\n' "$1" >&2
    return 1
  fi
  _catalog_validate_awk "$1" >&2
}

_catalog_rows_awk() {
  awk -v requested="$2" '
    BEGIN {
      TAB = sprintf("%c", 9)
      FS = TAB
      OPEN = "<!-- skill-bootstrap-catalog:v1 -->"
      CLOSE = "<!-- /skill-bootstrap-catalog -->"
      in_catalog = 0
      closed = 0
    }
    function emit(target, profile) {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", field[1], profile, target, field[4], field[5], field[6], field[7], field[8]
    }
    {
      if ($0 == OPEN) { in_catalog = 1; next }
      if ($0 == CLOSE) { closed = 1; next }
      if (!in_catalog || closed || $0 ~ /^[[:space:]]*$/)
        next
      if (!header_seen) { header_seen = 1; next }
      split($0, field, TAB)
      if (field[1] != "skill")
        next
      if (requested != "all" && field[2] != requested)
        next
      profile = field[2]
      if (requested == "all")
        profile = field[2]
      if (field[3] == "both") {
        emit("pi", profile)
        emit("codex", profile)
      } else if (field[3] == "pi" || field[3] == "codex") {
        emit(field[3], profile)
      }
    }
  ' "$1"
}

catalog_rows() {
  if [ "$#" -ne 2 ]; then
    printf 'catalog: usage: catalog_rows FILE PROFILE\n' >&2
    return 1
  fi
  catalog_validate "$1" || return $?
  case "$2" in
    paper|superpowers|google-sheets|all) ;;
    *)
      printf "catalog: unknown profile '%s'\n" "$2" >&2
      return 1
      ;;
  esac
  _catalog_rows_awk "$1" "$2"
}

_catalog_tool_ref_awk() {
  awk -v wanted="$2" '
    BEGIN {
      TAB = sprintf("%c", 9)
      FS = TAB
      OPEN = "<!-- skill-bootstrap-catalog:v1 -->"
      CLOSE = "<!-- /skill-bootstrap-catalog -->"
      in_catalog = 0
      closed = 0
    }
    {
      if ($0 == OPEN) { in_catalog = 1; next }
      if ($0 == CLOSE) { closed = 1; next }
      if (!in_catalog || closed || $0 ~ /^[[:space:]]*$/)
        next
      if (!header_seen) { header_seen = 1; next }
      split($0, field, TAB)
      if (field[1] == "tool" && field[4] == wanted) {
        count++
        result = field[6]
      }
    }
    END {
      if (count == 0) {
        printf "catalog: tool '%s' not found\n", wanted
        exit 1
      }
      if (count > 1) {
        printf "catalog: tool '%s' is duplicated\n", wanted
        exit 1
      }
      print result
    }
  ' "$1"
}

catalog_tool_ref() {
  local result status
  if [ "$#" -ne 2 ]; then
    printf 'catalog: usage: catalog_tool_ref FILE TOOL_NAME\n' >&2
    return 1
  fi
  catalog_validate "$1" || return $?
  result="$(_catalog_tool_ref_awk "$1" "$2")" || {
    status=$?
    printf '%s\n' "$result" >&2
    return "$status"
  }
  printf '%s\n' "$result"
}

catalog_source_url() {
  local source ref subpath
  if [ "$#" -ne 3 ]; then
    printf 'catalog: usage: catalog_source_url SOURCE REF SUBPATH\n' >&2
    return 1
  fi
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    printf 'catalog: source URL arguments must be non-empty\n' >&2
    return 1
  fi
  source="${1%/}"
  ref="${2#/}"
  subpath="${3#/}"
  printf '%s/tree/%s/%s\n' "$source" "$ref" "$subpath"
}

print_command() {
  local first argument
  if [ "$#" -eq 0 ]; then
    printf 'catalog: print_command requires at least one argument\n' >&2
    return 1
  fi
  first=1
  for argument in "$@"; do
    if [ "$first" -eq 1 ]; then
      printf '%q' "$argument"
      first=0
    else
      printf ' %q' "$argument"
    fi
  done
  printf '\n'
}
