
#show: doc => lettre(
$if(lang)$
  lang: "$lang$",
$endif$
$if(papersize)$
  paper: "$papersize$",
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$endif$
$if(page-header)$
  page-header: [$page-header$],
$endif$
$if(page-footer)$
  page-footer: [$page-footer$],
$endif$
  doc,
)
