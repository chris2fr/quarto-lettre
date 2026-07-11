# Quarto Lettre — Extension family

Three Quarto format extensions for composing formal French documents from a single `.qmd` source file:

| Extension | Purpose | Formats |
|---|---|---|
| `lettre` | Formal letter | HTML, PDF, Typst, DOCX, ODT, Markdown, plain text |
| `compte-rendu` | Meeting minutes | HTML, PDF, Typst, Markdown, plain text |
| `document` | General document | HTML, PDF, Typst, Markdown, plain text |

All three share a common `_extensions/base/` resource directory (Lua filters, CSL style, templates).

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

Since `quarto add` has no post-install hook to scaffold `_parts/` automatically, the extension does the next best thing: the first time a lettre document is rendered in a project (or standalone file) that has no `_parts/` yet, one is created — at the project root if there's a `_quarto.yml`, next to the document otherwise — populated with an editable copy of every fallback-eligible part. An existing `_parts/` (even an empty one, or one missing some files) is never touched again, so this only ever runs once and never overwrites customizations.

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

No special divs — use standard Markdown headings (H1–H4), paragraphs, tables, lists, and images directly in the document body.

---

## PDF margin overrides

All three extensions support per-document margin overrides for PDF output via YAML metadata:

| Key | Default | Applies to |
|---|---|---|
| `margin-inner` | `20mm` | All pages (inner / left) |
| `margin-outer` | `20mm` | All pages (outer / right) |
| `margin-top` | `25mm` | Body pages only |
| `margin-bottom` | `15mm` | Body pages only |

```yaml
margin-inner: 25mm
margin-outer: 25mm
margin-top: 30mm
margin-bottom: 20mm
```

These can be set at the document level (affects all PDF formats) or under a specific format:

```yaml
format:
  lettre-pdf:
    margin-inner: 30mm
    margin-outer: 30mm
```

> The first-page top margin is fixed — it is sized to accommodate the header area. Only body pages (from page 2 onward) are affected by `margin-top`.

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
│   ├── _filters/page.lua          # ::: header/footer :::, part fallback (lettre only), quote style
│   ├── parts/                     # lettre's bundled default section content (see _parts/ above)
│   │   └── <div>.qmd              # e.g. from.qmd, date.qmd, header.qmd, footer.qmd...
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
