#import "quarto-lettre.typ": ql-page-setup

#let lettre(
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
  margin:      (top: 20mm, bottom: 30mm, left: 30mm, right: 30mm),
  page-header: page-header,
  page-footer: page-footer,
  doc,
)
