local extracted = {}

function Div(el)
  for _, class in ipairs({ 'header', 'footer' }) do
    if el.classes:includes(class) then
      local fmt = FORMAT:match('html') and 'html' or FORMAT
      local rendered = pandoc.write(pandoc.Pandoc(el.content), fmt):gsub('\n$', '')
      extracted['page-' .. class] = pandoc.MetaBlocks({ pandoc.RawBlock(fmt, rendered) })
      return {}
    end
  end
end

function Pandoc(doc)
  for key, value in pairs(extracted) do
    doc.meta[key] = value
  end
  return doc
end
