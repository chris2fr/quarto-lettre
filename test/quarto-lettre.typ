// quarto-lettre.typ
// Shared page-setup function for the lettre and compte-rendu Quarto extensions.

#let ql-page-setup(
  lang:        "fr",
  paper:       "a4",
  fontsize:    11pt,
  margin:      (top: 25mm, bottom: 25mm, left: 20mm, right: 20mm),
  page-header: none,
  page-footer: none,
  doc,
) = {
  set page(
    paper:  paper,
    margin: margin,
    header: context if counter(page).get().first() == 1 and page-header != none {
      pad(top: 5mm, align(center, text(size: 9pt, page-header)))
    },
    footer: context {
      let pg = counter(page).get().first()
      align(center, text(size: 9pt)[
        #if pg > 1 [#pg \ ]
        #if page-footer != none { page-footer }
      ])
    },
    numbering: none,
  )
  set text(lang: lang, size: fontsize)
  set par(justify: true, leading: 0.65em, spacing: 1.2em)
  set table(inset: 6pt, stroke: none)
  doc
}
