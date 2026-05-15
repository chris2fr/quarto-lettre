# Lettre — Quarto Extension

A Quarto format extension for composing formal French letters from a single `.qmd` source file, with output to **seven formats**: HTML, PDF (LaTeX), PDF (Typst), Word, OpenDocument, Markdown, and plain text.

## Requirements

- Quarto ≥ 1.9.0
- A LaTeX distribution — for `lettre-pdf`
- Typst — for `lettre-typst` (bundled with Quarto ≥ 1.4)

## Installation

```bash
quarto use template chris2fr/quarto-content
```

This copies `template.qmd`, `_extensions/lettre/`, and `_quarto.yml` into your project. Two starting files are provided:

| File | Purpose |
|---|---|
| `template.qmd` | Blank template — fill in to write your letter |
| `_quarto.yml` | Project config — renders `template.qmd` to `_output/` |

### Interactive scaffold

After installation, run the setup script to fill in the metadata interactively:

```bash
lua _extensions/lettre/scaffold/setup.lua
```

It reads the current values from `template.qmd` as defaults and lets you override each field.

## Usage

Declare the desired output formats in your YAML front matter:

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

Then structure your letter using named divs:

### Page divs (header and footer on every page)

| Div | Role |
|---|---|
| `::: header` | Page header — printed on every page |
| `::: footer` | Page footer — printed on every page |

### Letter divs

| Div | Role |
|---|---|
| `::: from` | Sender's address |
| `::: date` | Place and date (e.g. `Paris, le {{< meta date >}}`) |
| `::: to` | Recipient's address |
| `::: subject` | Subject line |
| `::: ref` | Reference number |
| `::: opening` | Salutation (e.g. `Madame, Monsieur,`) |
| `::: body` | Body of the letter |
| `::: closing` | Closing formula |
| `::: signature` | Sender's name and title |

YAML metadata values are reusable anywhere in the document via `{{< meta key >}}`.

All letter divs are required. The filter raises an error if any are missing.

## Output formats

| Format | Description |
|---|---|
| `lettre-html` | HTML page — CSS Grid layout reproducing an A4 letter |
| `lettre-pdf` | PDF via LaTeX — Libertinus font, A4, fancyhdr header/footer |
| `lettre-typst` | PDF via Typst — A4, matching LaTeX layout |
| `lettre-docx` | Word document — dedicated paragraph styles |
| `lettre-odt` | OpenDocument — dedicated paragraph styles |
| `lettre-md` | GitHub Flavored Markdown |
| `lettre-plain` | Plain text |

## Render

```bash
# Render the example letter
quarto render lettre.qmd

# Render your own letter
quarto render template.qmd
```

## Extension structure

```
_extensions/lettre/
├── _extension.yml               # Extension manifest
├── _filters/
│   ├── page.lua                 # Extracts ::: header / ::: footer to page metadata
│   └── validate.lua             # Validates required divs and metadata fields
├── html/
│   ├── layout.html              # HTML template
│   └── css/                     # CSS styles
├── pdf/
│   ├── layout.tex               # LaTeX template (fancyhdr, Libertinus, A4)
│   ├── _partials/               # LaTeX include files (header, body wrappers)
│   └── _filters/divs.lua        # Maps divs to LaTeX environments
├── typst/
│   ├── layout.typ               # Typst Pandoc template
│   ├── _partials/               # Typst template partials (lettre function)
│   └── _filters/divs.lua        # Maps divs to Typst layout primitives
├── docx/
│   ├── reference.docx           # Reference document with Letter* paragraph styles
│   └── _filters/divs.lua        # Applies custom-style attributes
├── odt/
│   └── reference.odt            # Reference document with Letter* paragraph styles
├── md/layout.md                 # Markdown template
└── plain/layout.txt             # Plain text template
```

## Author

Chris Mann — [chris@lesgrandsvoisins.com](mailto:chris@lesgrandsvoisins.com)
