outdir = ./out

all:
	make html
	make plain
	make md
	make pdf
	make docx
	make odt

html:
	quarto render lettre.qmd --output-dir $(outdir)  --execute-dir $(outdir) --to lettre-html

pdf:
	quarto render lettre.qmd --output-dir $(outdir)  --execute-dir $(outdir) --to lettre-pdf
	mv lettre.tex $(outdir)/lettre.tex

md:
	quarto render lettre.qmd --output-dir $(outdir)  --execute-dir $(outdir) --to lettre-md

docx:
	quarto render lettre.qmd --output-dir $(outdir)  --execute-dir $(outdir) --to lettre-docx

odt:
	quarto render lettre.qmd --output-dir $(outdir)  --execute-dir $(outdir) --to lettre-odt

plain:
	quarto render lettre.qmd --output-dir $(outdir)  --execute-dir $(outdir) --to lettre-plain


