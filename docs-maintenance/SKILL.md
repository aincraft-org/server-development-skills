---
name: docs-maintenance
description: Use when adding or maintaining end-user documentation for a repository, creating or updating a Fumadocs docs site, writing consumer or feature docs, structuring a page from basics to advanced, styling a docs site with design tokens, wiring meta.json sidebars, checking docs links, or keeping docs from drifting after a feature changes. Triggers include Fumadocs, content/docs, MDX pages, meta.json sidebars, player guides, feature docs, docs theming, and docs verification.
---

# Docs Maintenance (Fumadocs)

Every repository carries end-user documentation. Docs are a **consumer surface**, not an engineering artifact: they describe what a person sees, does, and decides — never packages, handlers, or config keys.

Core principle: **every page climbs from floor to ceiling — concept first, day-one basics next, advanced last, each level explicitly labelled.**

Versions verified 2026-08-21 against `registry.npmjs.org`.

## Coverage vs. publishing

Two separate decisions. Do not conflate them.

**Coverage — every repo, no exceptions.** Each repository owns a docs contract in its own tree: `content/docs/` holding `index.mdx`, at least one feature page, and a `meta.json`. That is plain MDX, so it needs no Next app, no `node_modules`, and no deploy target.

**Publishing — a small number of hub sites.** A hub is a full Fumadocs Next app that renders content and ships it. Two exist: `site-docs` (product/platform) and `alkahest-docs` (server, whose `player-guides/` already aggregates the economy, territories, and jobs repos). Add a hub only when an audience needs its own site; otherwise an existing hub renders the repo's content. Scaffolding an app per repo is not viable — there are 162 repos, and they cannot be held on matching Fumadocs versions.

**Declare the audience.** It selects vocabulary, not whether docs exist:

| Repo kind | End user | Floor | Ceiling |
|---|---|---|---|
| Gameplay plugin | Player | first command that works | operator- and plugin-driven machinery |
| Product/platform | Customer | create the first thing | billing, quotas, limits |
| Library, transpiler, internal tool | Developer consuming it | install and one working call | extension points, tuning |

## Fallback: libraries and internal tools

A repo with no players still has consumers. When there is no gameplay or customer surface — `x2x-*`, transpilers, build tooling, internal services — do not skip docs and do not invent a user. Document for **the next developer who has to depend on this**, and apply the reduced contract:

- **Same ladder, developer vocabulary.** "The idea" is what the component is and where it sits in the pipeline; "basics" is install plus the one call that proves it works; "Everyday" is the two or three APIs actually reached for; "Advanced" is extension points, passes, and tuning.
- **Two pages are enough.** `index.mdx` (what this is, who should use it, what it does not do) plus one `getting-started.mdx`. The gate's floor is index plus one page; meeting only the floor is a pass, not a shortfall.
- **Content-only, never an app.** These repos get `content/docs/` and nothing else. Verification runs the gate directly; there is no build of their own.
- **Non-goals are load-bearing.** State plainly what the library will not do and is not stable for. For an internal tool that is often the most valuable section.
- **No published hub is required.** Content can sit unrendered until a hub adopts it. The contract exists so the docs are written and verifiable, not so every repo ships a website.

With no external consumer at all, the audience is the maintainer six months from now and the ceiling is "how to change this safely."

## Pinned versions (hub sites)

| Component | Version |
|---|---|
| `fumadocs-core` | **16.14.5** |
| `fumadocs-mdx` | **15.3.0** |
| `fumadocs-ui` | **`npm:@fumadocs/base-ui@16.14.5`** (alias) |
| `next` | **16.3.2** |
| `react` / `react-dom` | **19.2.x** |
| `tailwindcss` | **4.3.x** |

`fumadocs-ui` is installed as an npm alias to `@fumadocs/base-ui`, pinned to the same version as `fumadocs-core`. Keep those two equal; they ship as a matched pair.

## The floor-to-ceiling ladder

Five levels, in order. **Never open with a command** — a command is evidence of a concept, not the concept.

1. **The idea.** What the thing fundamentally is, in plain words, no commands. "The server runs an economy on a ledger — money is entries, not items."
2. **The basics.** What someone needs on day one, assuming no prior knowledge. Label it **basics**.
3. **Everyday.** The few commands or calls actually reached for daily, each inside a sentence saying when and why. Most readers stop here. Label it **Everyday**.
4. **Advanced.** Later topics, and machinery operators or other systems drive. Open with `<Callout type="info">Advanced — you do not need this to get started.</Callout>`.
5. **What it means for you.** Practical advice and the surprises worth warning about.

Explicit level labels are mandatory; advanced material must never hide inside the basics. Write prose, not fragments — commands belong inside sentences, and a command table is a cheat sheet after the explanation, never the explanation.

Translate implementation into observables: a permission node becomes "operators only"; a `0.5` growth factor becomes "crops grow at half speed in Winter"; package names, classes, and handlers are omitted entirely. Document only behaviour the source supports — leave gaps as gaps rather than inventing.

`references/page-template.mdx` is a complete page showing all five levels.

## Content layout

```text
content/docs/
  meta.json          # ordered: slugs, folder names, "---Section---" separators
  index.mdx          # landing page, <Cards> to the main pages
  <feature>.mdx
  <section>/
    meta.json        # children, "index" first
    index.mdx        # section landing page
```

Frontmatter needs `title` and `description`. **Quote any value containing a colon** — an unquoted colon fails the MDX YAML parse with "Nested mappings are not allowed". Internal links are absolute docs paths (`/docs/player-guides/economy`), which is what makes them checkable.

## Styling contract (hub sites)

Every hub's stylesheet must begin with these three imports, in this order:

```css
@import 'tailwindcss';
@import 'fumadocs-ui/css/neutral.css';   /* or another Fumadocs color scheme */
@import 'fumadocs-ui/css/preset.css';
```

Beyond that, theming is CSS variables — never hardcoded values in components or MDX. Both hubs define their type scale and Fumadocs layout knobs (`--fd-sidebar-width`, `--fd-toc-width`, `--fd-header-height`) as custom properties.

For anything past a type scale, split the tokens out as `site-docs` does: `tokens.css` holds semantic light/dark tokens, brand colors, and the `--color-fd-*` bridge; `theme.css` is the Tailwind `@theme inline` bridge; `global.css` imports both after the Fumadocs layers. A single-file `global.css` (as in `alkahest-docs`) is fine only while a repo has no brand tokens of its own. Either way, brand color is defined once and consumed everywhere else.

## Verification checklist

Copy `references/verify-docs.mjs` to `scripts/verify-docs.mjs` and wire it to `npm test`. It needs no dependencies and auto-detects hub vs. content-only repos, skipping the hub-only assertions when there is no `app/`.

```bash
npm test                                        # or: node scripts/verify-docs.mjs
node scripts/verify-docs.mjs --ladder=player-guides
node verify-docs.mjs --root=../modular-economy  # check a repo from outside it
npm run build                                   # hub only
npm run types:check                             # hub only
```

The gate resolves its target as its own parent directory, which is the repo root once installed at `scripts/verify-docs.mjs`. Run it from anywhere else — including straight out of this skill — and you must pass `--root=PATH` (or set `DOCS_ROOT`), or it will look for `content/docs` beside itself and fail saying so.

| Area | Checked by the gate | Still manual |
|---|---|---|
| **Content** | frontmatter `title`/`description` on every page including nested ones; unquoted-colon values; `index.mdx` plus at least one page | voice, accuracy against source, ladder ordering |
| **Navigation** | every `meta.json` parses; every listed slug resolves to a file or folder; every page is reachable from a sidebar; section folders have their own `meta.json` | that the order reads sensibly |
| **Links** | every internal `/docs/*` link and `href` resolves to a real page, including `<Cards>` and nested paths | external URLs — the gate makes no network calls |
| **Styling** | Tailwind and both Fumadocs CSS layers imported; every local `@import` target exists; no hardcoded hex in content | rendered appearance, dark mode, responsive layout |
| **Build** | — | `npm run build` is the only thing that proves MDX and JSX compile |
| **Ladder** | with `--ladder=<dir>`, guide pages carry basics/Everyday/Advanced labels | whether each level says the right thing |

Scope `--ladder` to the directories that owe a ladder. Unscoped it also flags contributor pages such as `build-and-run.mdx`, which do not owe a player ladder. Landing pages (`index.mdx`) are exempt.

For a content-only repo, run the gate directly, then build the hub that renders it. Preview with `npm run dev` when the layout changed — the gate cannot see appearance.

## Maintenance

Docs drift is the default failure. Prevent it structurally: **a feature change and its docs change land in the same commit.** A behaviour change with no docs diff is incomplete.

Older in-repo `verify-docs` scripts predate this gate and only scan the top level of `content/docs/`, so they miss nested frontmatter, dangling slugs, and broken links. Replace them.

## Common mistakes

| Wrong | Right | Why |
|---|---|---|
| Page opens with a command table | open with the idea; commands at "Everyday" | a reference is not a guide; the reader does not know the feature yet |
| Advanced material mixed into basics | explicit `basics` / `Everyday` / `Advanced` labels | readers cannot tell what is optional |
| Skipping docs for a library or internal tool | reduced contract, developer audience | "no players" is not "no consumers" |
| `description: How Credits work: the ledger` | `description: "How Credits work: the ledger"` | an unquoted colon breaks the MDX YAML parse at build |
| `meta.json` and files out of sync | every page listed, every listed slug real | an unlisted page never appears in the sidebar; a dangling slug breaks navigation |
| Renaming a page without updating links to it | update every `/docs/*` reference | the old path 404s silently until someone clicks it |
| Treating a passing `npm test` as done | also run `npm run build` | the gate checks structure, not that MDX and JSX compile |
| Running the gate from outside the repo without `--root` | `--root=PATH`, or install it at `scripts/verify-docs.mjs` | it resolves `content/docs` relative to its own location, not the shell's |
| Naming a permission node or config key | "operators only", or the behaviour it produces | an implementation detail is not an end-user fact |
| Fragment bullets ("Quick to mine.") | "Runebrick breaks fast, so early on it is a cheap building block" | fragments read as a spec, not a guide |
| Scaffolding a Next app per repo | content-only repos rendered by a hub | 162 apps cannot be held on matching versions |
| `fumadocs-ui` and `fumadocs-core` on different versions | pin both to 16.14.5 | the alias must track core |
| Inventing behaviour the source does not state | leave the gap | fabricated docs are worse than missing docs |
