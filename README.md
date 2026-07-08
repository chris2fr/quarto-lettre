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

| Div | Role | Required |
|---|---|:---:|
| `::: header` | Page header — printed on every page | ✓ |
| `::: from` | Sender's address | ✓ |
| `::: date` | Place and date | ✓ |
| `::: to` | Recipient's address | ✓ |
| `::: subject` | Subject line | ✓ |
| `::: ref` | Reference number | |
| `::: opening` | Salutation | ✓ |
| `::: body` | Body of the letter | ✓ |
| `::: closing` | Closing formula | ✓ |
| `::: signature` | Sender's name and title | ✓ |
| `::: footer` | Page footer — printed on every page | ✓ |

Leave `::: header` or `::: footer` empty to suppress the header/footer area.

YAML metadata values are reusable anywhere in the document via `{{< meta key >}}`.

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
| `::: header` | Page header — printed on every page |
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
│   ├── _filters/page.lua          # Extracts ::: header / ::: footer to page metadata
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
