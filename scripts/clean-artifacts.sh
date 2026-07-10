#!/usr/bin/env bash
# Post-render cleanup: removes LaTeX/Typst intermediate files and support
# directories that Quarto leaves next to the source .qmd files (format
# resources such as quarto-lettre.cls are never cleaned up by Quarto itself).
set -euo pipefail

prune=(-path './_extensions' -o -path './_output' -o -path './.quarto' -o -path './.git')

find . \( "${prune[@]}" \) -prune -o \
  -type f \( -name '*.tex' -o -name '*.cls' -o -name '*.typ' \) -print0 | xargs -0 -r rm -f

find . \( "${prune[@]}" \) -prune -o \
  -type d -name '*_files' -print0 | xargs -0 -r rm -rf
