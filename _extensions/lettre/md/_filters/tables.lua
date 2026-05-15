function Table(el)
  return pandoc.RawBlock('markdown', pandoc.write(pandoc.Pandoc({el}), 'gfm'))
end
