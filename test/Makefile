outdir = ./out
inputfilebase = noheadfoot

all:
	quarto render
# 	make html
# 	make plain
# 	make md
# 	make pdf
# 	make odt
# 	make typst
# 	make docx

html:
	quarto render $(inputfilebase).qmd --output $(inputfilebase).html --output-dir $(outdir) --to lettre-html

pdf:
	quarto render $(inputfilebase).qmd --output $(inputfilebase).pdf --output-dir $(outdir) --to lettre-pdf

typst:
	quarto render $(inputfilebase).qmd --output $(inputfilebase).typst.pdf --output-dir $(outdir) --to lettre-typst

md:
	quarto render $(inputfilebase).qmd --output $(inputfilebase).md --output-dir $(outdir) --to lettre-md

docx:
	quarto render $(inputfilebase).qmd --output $(inputfilebase).docx --output-dir $(outdir) --to lettre-docx

odt:
	quarto render $(inputfilebase).qmd --output $(inputfilebase).odt --output-dir $(outdir) --to lettre-odt

plain:
	quarto render $(inputfilebase).qmd --output $(inputfilebase).plain --output-dir $(outdir) --to lettre-plain

preview:
	quarto preview $(inputfilebase)
