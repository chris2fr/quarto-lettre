# Quarto Lettre — Extension family

Three Quarto format extensions for composing formal French documents from a single `.qmd` source file:

| Extension | Purpose | Formats |
|---|---|---|
| `lettre` | Formal letter | HTML, PDF, Typst, DOCX, ODT, Markdown, plain text |
| `compte-rendu` | Meeting minutes | HTML, PDF, Typst, Markdown, plain text |
| `document` | General document | HTML, PDF, Typst, Markdown, plain text |

All three share a common `_extensions/base/` resource directory (Lua filters, CSL style, templates).

---

## Quickstarts

```
quarto use template chris2fr/quarto/doc
quarto add chris2fr/quarto
```

---

## Requirements

- Quarto ≥ 1.9.0
- A LaTeX distribution — for `*-pdf` formats
- Typst — for `*-typst` formats (bundled with Quarto ≥ 1.4)

---

## lettre

### Metadata

```yaml
---
title: Objet de la lettre
author: Prénom Nom
ref: ref-2026-01-01
lang: fr
place: Paris
date: today
format:
  lettre-html: default
  lettre-pdf: default
  lettre-typst: default
  lettre-docx: default
  lettre-odt: default
  lettre-md: default
  lettre-plain: default
---
```

`title`, `author`, `lang`, `date`, `place`, and `ref` are all required — rendering stops with an error listing whichever are missing.

### Divs

| Div | Role | If missing |
|---|---|---|
| `::: header` | Page header — printed on the first page only | falls back to a part (see below), or omitted |
| `::: from` | Sender's address | falls back to a part |
| `::: date` | Place and date | falls back to a part |
| `::: to` | Recipient's address | falls back to a part |
| `::: subject` | Subject line | falls back to a part |
| `::: ref` | Reference number | falls back to a part, or omitted |
| `::: opening` | Salutation | falls back to a part |
| `::: body` | Body of the letter | any content in the document that isn't inside one of these divs is concatenated into the body automatically — see below |
| `::: closing` | Closing formula | falls back to a part |
| `::: signature` | Sender's name and title | falls back to a part |
| `::: footer` | Page footer — printed on every page | falls back to a part, or omitted |

Leave `::: header` or `::: footer` **empty** (`::: header\n:::`) to suppress the header/footer area outright — that's different from omitting the div entirely, which triggers the part fallback below.

YAML metadata values are reusable anywhere in the document via `{{< meta key >}}`.

#### Body without a `::: body :::` wrapper

`::: body` doesn't have to be written explicitly. Any top-level content that isn't inside a recognized div — paragraphs, headings, tables, images, custom divs — is concatenated, in document order, into the body automatically. This means a minimal letter can be just:

```markdown
---
title: Objet de la lettre
author: Prénom Nom
lang: fr
date: today
format:
  lettre-html: default
---

Le corps de la lettre, sans aucun div.
```

Everything else (`from`, `date`, `to`, `subject`, `opening`, `closing`, `signature`, `header`, `footer`) is filled in from parts (see below). Mixing is fine: write the divs you care about, and let the rest fall back.

#### Logo, link and description in the header

`::: header` (and `::: footer`) accept a linked, described image — the description doubles as the image's alt text:

```markdown
::: header
[![Organisation — courte description](logo.png)](https://example.org)
:::
```

The image is capped to a sensible header height and centered in every format (HTML, Typst, PDF/LaTeX, docx, odt). If the project has a [brand.yml](https://quarto.org/docs/authoring/brand.html), the logo can come from there instead via the `{{< brand logo <size> >}}` shortcode (`small`, `medium`, or `large`), optionally wrapped in a link the same way:

```markdown
::: header
[{{< brand logo medium >}}](https://example.org)
:::
```

#### `_parts/` — overriding or omitting a section

Any div listed as "falls back to a part" above can be left out of the document entirely. When it is, its content is resolved in priority order:

1. `./_parts/<div>.qmd` — next to the `.qmd` being rendered (overrides just that document)
2. `<project root>/_parts/<div>.qmd` — the directory holding `_quarto.yml` (overrides every letter in the project)
3. the extension's own bundled default (`_extensions/base/parts/<div>.qmd`)

The first one found wins, so a project- or document-level `_parts/<div>.qmd` always takes precedence over the extension's default. Part files are plain Markdown and support `{{< meta key >}}` and `{{< brand logo <size> >}}` shortcodes.

`::: header` / `::: footer` and their `_parts/header.qmd` / `_parts/footer.qmd` fallback work the same way in `compte-rendu` and `document` — a single `_parts/header.qmd` at the project root gives every letter, meeting minutes, and document in the project the same letterhead and footer. The rest of the fallback vocabulary (`from`, `date`, `to`, `subject`, `ref`, `opening`, `closing`, `signature`) is specific to `lettre`.

Since `quarto add` has no post-install hook to scaffold `_parts/` automatically, the extension does the next best thing: the first time a document is rendered in a project (or standalone file) that has no `_parts/` yet, one is created — at the project root if there's a `_quarto.yml`, next to the document otherwise — populated with an editable copy of every fallback-eligible part for that extension (just `header.qmd`/`footer.qmd` for `compte-rendu`/`document`; the full set for `lettre`). An existing `_parts/` (even an empty one, or one missing some files) is never touched again, so this only ever runs once and never overwrites customizations.

---

## compte-rendu

### Metadata

```yaml
---
title: Réunion du projet
author: Prénom Nom
organization: Nom de l'organisation
date: today
place: Paris
lang: fr
format:
  compte-rendu-html: default
  compte-rendu-pdf: default
  compte-rendu-typst: default
  compte-rendu-md: default
  compte-rendu-plain: default
---
```

### Divs

| Div | Role |
|---|---|
| `::: header` | Page header — printed on the first page only |
| `::: participants` | Attendees and apologies |
| `::: agenda` | Meeting agenda (ordered list) |
| `::: body` | Meeting notes — supports headings H1–H4, images, tables |
| `::: decisions` | Decisions taken |
| `::: actions` | Action items — typically a Markdown table |
| `::: next-meeting` | Date and details of the next meeting |
| `::: approval` | Approval statement |
| `::: footer` | Page footer — printed on every page |

`::: header` and `::: footer` can be omitted — see "`_parts/` — overriding or omitting a section" under `lettre` above (the rest of this table has no fallback here; unlike `lettre`, a missing `::: participants` or `::: body` is still an error).

---

## document

### Metadata

```yaml
---
title: Titre du document
subtitle: Sous-titre
author: Prénom Nom
date: today
lang: fr
format:
  document-html: default
  document-pdf: default
  document-typst: default
  document-md: default
  document-plain: default
---
```

No special divs — use standard Markdown headings (H1–H4), paragraphs, tables, lists, and images directly in the document body. It does, however, support `::: header` and `::: footer`, with the same `_parts/` fallback as `compte-rendu` above — omit them and the page header/footer come from `_parts/header.qmd` / `_parts/footer.qmd` if present.

---

## PDF margin overrides

All three extensions support per-document margin overrides for PDF output via YAML metadata, at three levels of granularity — the most specific one set wins:

| Key | Sets | Default |
|---|---|---|
| `margin-inner` | inner / left margin, all pages | `20mm` |
| `margin-outer` | outer / right margin, all pages | `20mm` |
| `margin-top` | top margin, body pages only | `25mm` |
| `margin-bottom` | bottom margin, body pages only | `15mm` |
| `marginx` | `margin-inner` **and** `margin-outer`, if not set individually | — |
| `marginy` | `margin-top` **and** `margin-bottom`, if not set individually | — |
| `margin-all` | all four, if not set by any of the above | — |

```yaml
# every page gets 15mm on the sides; top/bottom keep their defaults
marginx: 15mm

# same as writing all four margin-* keys explicitly
margin-all: 18mm

# margin-top wins over marginy, which wins over margin-all — bottom falls
# back to margin-all since neither margin-bottom nor marginy set it
margin-all: 10mm
marginy: 15mm
margin-top: 30mm
```

> `margin` (without a suffix) is reserved by Quarto itself (revealjs/typst slide margin, must be a number) — use `margin-all` instead for a plain string like `"20mm"`.

These can be set at the document level (affects all PDF formats) or under a specific format:

```yaml
format:
  lettre-pdf:
    margin-inner: 30mm
    margin-outer: 30mm
```

> The first-page top margin is fixed — it is sized to accommodate the header area. Only body pages (from page 2 onward) are affected by `margin-top`.

---

## Brand fonts

All three extensions use `theme: none` for HTML (a fully custom template, no Bootstrap) and a fully custom LaTeX `.cls` for PDF, so Quarto's own [brand.yml](https://quarto.org/docs/authoring/brand.html) → CSS/fontspec pipeline never runs there — `typography` in a brand file is otherwise silently ignored in both. This is filled in by hand: the resolved `base`, `headings`, and `monospace` font families are read from the active brand and applied per format.

This works with any brand — the project's own (`brand: _brand/_brand.yml` in `_quarto.yml` or document front matter) if set, otherwise the extensions' own bundled default (`_extensions/base/brand.yml`, Jura) via `contributes.metadata.project.brand` — and needs nothing from the document itself; a document with no brand configured at all gets no font changes, silently.

- **HTML**: the fonts are injected as a Google Fonts `<link>` plus matching `font-family` CSS rules — always works, since the browser fetches them at view time regardless of what's installed on the machine that rendered the document.
- **Typst**: gets brand fonts from Quarto's own typst-brand integration automatically (visible as `#show heading: set text(font: (...))` etc. in the generated `.typ`) — nothing to do there.
- **PDF (LaTeX)**: each font is set with `\setmainfont`/`\setmonofont` (headings via a `\QLheadingfont` hook used inside the class's `\titleformat`), but only if `\IfFontExistsTF` confirms it's actually installed on the machine doing the render — otherwise that assignment is a silent no-op and the class's default (Libertinus) stays in effect. Unlike HTML's web fonts, a PDF font must be present locally to be embedded, and LaTeX's `fontspec` raises a **hard compile error** (not a fallback) for a family it can't find — this guard is what keeps a brand referencing an uninstalled Google Font from breaking the build.
- **docx and odt do not pick up brand fonts** — no dynamic mechanism for either (the reference doc's styles are static).

---

## French guillemets in HTML

In LaTeX and Typst output, smart double quotes (`"..."`) are always rendered as French guillemets (« ... »). In HTML output this is opt-in via the `french-quotes` metadata key — enabled by default:

```yaml
format:
  lettre-html:
    french-quotes: true
```

Set it at the document level or under a specific HTML format to override the extension's default.

---

## Render

```bash
quarto render my-letter.qmd
```

---

## Extension structure

```
_extensions/
├── base/                          # Shared resources (not a format)
│   ├── _filters/page.lua          # ::: header/footer :::, part fallback (all 3), lettre-only body/margins, HTML+PDF brand fonts, quote style
│   ├── brand.yml                  # default brand (contributed to every project via _extension.yml)
│   ├── parts/                     # bundled default section content (see _parts/ above)
│   │   └── <div>.qmd              # header.qmd, footer.qmd (all 3); from/date/... (lettre only)
│   ├── md/
│   │   ├── _filters/tables.lua    # Markdown table filter
│   │   └── layout.md              # Markdown template
│   ├── plain/layout.txt           # Plain text template
│   └── resources/biblio.csl       # CSL bibliography style
│
├── lettre/
│   ├── _extension.yml
│   ├── _filters/validate.lua      # Validates required divs and metadata
│   ├── html/{layout.html,css/}
│   ├── pdf/{layout.tex,quarto-lettre.cls,_filters/,_partials/}
│   ├── typst/{layout.typ,_filters/,_partials/}
│   ├── docx/{reference.docx,_filters/}
│   └── odt/reference.odt
│
├── compte-rendu/
│   ├── _extension.yml
│   ├── _filters/validate.lua
│   ├── html/{layout.html,css/}
│   ├── pdf/{layout.tex,quarto-lettre.cls,_filters/,_partials/}
│   ├── typst/{layout.typ,_filters/,_partials/}
│   └── md/_filters/divs.lua
│
└── document/
    ├── _extension.yml
    ├── _filters/validate.lua
    ├── html/{layout.html,css/}
    ├── pdf/{layout.tex,quarto-lettre.cls,_filters/,_partials/}
    └── typst/{_filters/,_partials/}
```

---

## Author

Chris Mann — [chris@lesgrandsvoisins.com](mailto:chris@lesgrandsvoisins.com)
