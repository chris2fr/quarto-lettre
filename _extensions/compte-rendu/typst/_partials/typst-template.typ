#import "quarto-lettre.typ": ql-page-setup

#let compte-rendu(
  lang:        "fr",
  paper:       "a4",
  fontsize:    11pt,
  page-header: none,
  page-footer: none,
  doc,
) = ql-page-setup(
  lang:        lang,
  paper:       paper,
  fontsize:    fontsize,
  margin:      (top: 25mm, bottom: 25mm, left: 20mm, right: 20mm),
  page-header: page-header,
  page-footer: page-footer,
  doc,
)
