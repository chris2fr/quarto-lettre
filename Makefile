outdir = ./out

all:
	make html
	make plain
	make md
	make pdf
	make docx
	make odt

html:
	quarto render lettre.qmd --output-dir $(outdir)/html --to lettre-html

pdf:
	quarto render lettre.qmd --output-dir $(outdir)/pdf --to lettre-pdf
	mv lettre.tex $(outdir)/pdf/lettre.tex

md:
	quarto render lettre.qmd --output-dir $(outdir)/md --to lettre-md

docx:
	quarto render lettre.qmd --output-dir $(outdir)/docx --to lettre-docx

odt:
	quarto render lettre.qmd --output-dir $(outdir)/odt --to lettre-odt

plain:
	quarto render lettre.qmd --output-dir $(outdir)/plain --to lettre-plain
