-- Stores rendered header/footer content to inject into metadata
local extracted = {}

-- Intercept ::: header ::: and ::: footer ::: divs.
-- Each matching div is rendered to the current output format and stored as
-- `page-header` / `page-footer` metadata, then removed from the document body.
function Div(el)
  for _, class in ipairs({ 'header', 'footer' }) do
    if el.classes:includes(class) then
      -- Normalise format variants: html* → 'html', markdown* → 'markdown' (strict
      -- variants don't support Quarto FloatRefTarget nodes and emit a warning)
      local fmt = FORMAT:match('html') and 'html'
               or FORMAT:match('markdown') and 'markdown'
               or FORMAT
      -- Render the div's content and strip the trailing newline pandoc adds
      local rendered = pandoc.write(pandoc.Pandoc(el.content), fmt):gsub('\n$', '')
      -- Wrap in MetaBlocks so templates receive a block-level value.
      -- Skip empty renders so $if(page-header)$ stays false when the div has no content.
      if rendered ~= '' then
        extracted['page-' .. class] = pandoc.MetaBlocks({ pandoc.RawBlock(fmt, rendered) })
      end
      return {}  -- remove this div from the document
    end
  end
end

-- Inject the extracted values into document metadata so layout templates
-- can reference $page-header$ and $page-footer$
function Pandoc(doc)
  for key, value in pairs(extracted) do
    doc.meta[key] = value
  end
  return doc
end
