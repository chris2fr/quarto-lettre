# Lettre — Quarto Extension

A Quarto extension for composing formal letters in both **PDF** and **HTML** from a single `.qmd` source file.

## Requirements

- Quarto ≥ 1.9.0
- A LaTeX distribution (for PDF output)

## Installation

Copy the `_extensions/lettre/` folder to the root of your project.

## Usage

Declare both formats in your YAML front matter:

```yaml
---
title: Objet de la lettre
author: Prénom Nom
ref: ref-2026-01-01
lang: fr
place: Paris
format:
  lettre-html: default
  lettre-pdf: default
---
```

Then structure your letter using named divs:

| Div             | Role                              |
|-----------------|-----------------------------------|
| `::: from`      | Sender's address                  |
| `::: date`      | Place and date                    |
| `::: to`        | Recipient's address               |
| `::: subject`   | Subject line                      |
| `::: ref`       | Reference number (right-aligned)  |
| `::: opening`   | Salutation                        |
| `::: body`      | Body of the letter                |
| `::: closing`   | Closing formula                   |
| `::: signature` | Signature block                   |

YAML metadata values are reusable anywhere via `{{< meta key >}}`.

## Render

```bash
quarto render lettre.qmd
```

This produces `lettre.pdf` and `lettre.html`.

## Output formats

- **PDF** — LaTeX (`article` class, Libertinus font, A4 paper)
- **HTML** — CSS Grid layout reproducing an A4 letter page

## Structure

```
_extensions/lettre/
├── _extension.yml          # Extension manifest
├── _filters/divs.lua       # Lua filter: maps div classes to LaTeX environments
├── _partials/              # LaTeX partials (header, body wrappers)
├── layout.html             # HTML template
├── layout.tex              # LaTeX template
└── static/css/             # CSS styles for HTML output
```

## Author

Chris Mann
