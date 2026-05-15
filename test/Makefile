outdir = ./out

all:
	make html
	make plain
	make md
	make pdf
	make odt
	make typst
	make docx

html:
	quarto render lettre-de-documentation-quarto.qmd --output-dir $(outdir)/html --to lettre-html

pdf:
	quarto render lettre-de-documentation-quarto.qmd --output-dir $(outdir)/pdf --to lettre-pdf
	mv lettre-de-documentation-quarto.tex $(outdir)/pdf/

typst:
	quarto render lettre-de-documentation-quarto.qmd --output-dir $(outdir)/typst --to lettre-typst
	mv lettre-de-documentation-quarto.typ $(outdir)/typst/

md:
	quarto render lettre-de-documentation-quarto.qmd --output-dir $(outdir)/md --to lettre-md

docx:
	quarto render lettre-de-documentation-quarto.qmd --output-dir $(outdir)/docx --to lettre-docx

odt:
	quarto render lettre-de-documentation-quarto.qmd --output-dir $(outdir)/odt --to lettre-odt

plain:
	quarto render lettre-de-documentation-quarto.qmd --output-dir $(outdir)/plain --to lettre-plain

preview:
	quarto preview lettre-de-documentation-quarto.qmd
