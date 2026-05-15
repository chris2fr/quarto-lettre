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
	quarto render template.qmd --output-dir $(outdir)/html --to lettre-html

pdf:
	quarto render template.qmd --output-dir $(outdir)/pdf --to lettre-pdf
	mv template.tex $(outdir)/pdf/template.tex

typst:
	quarto render template.qmd --output-dir $(outdir)/typst --to lettre-typst
	mv template.typ $(outdir)/typst/template.typ

md:
	quarto render template.qmd --output-dir $(outdir)/md --to lettre-md

docx:
	quarto render template.qmd --output-dir $(outdir)/docx --to lettre-docx

odt:
	quarto render template.qmd --output-dir $(outdir)/odt --to lettre-odt

plain:
	quarto render template.qmd --output-dir $(outdir)/plain --to lettre-plain

preview:
	quarto preview template.qmd 