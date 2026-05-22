-- Stores rendered header/footer content to inject into metadata
local extracted = {}

-- For LaTeX, a standalone image paragraph inside \fancyhead/\fancyfoot causes
-- "Float(s) lost" because figure environments are floats. Replace them with a
-- plain \includegraphics so the image renders inline inside the header/footer box.
local function replace_images_for_latex(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    local img = nil
    if (block.t == 'Para' or block.t == 'Plain') and
       #block.content == 1 and block.content[1].t == 'Image' then
      img = block.content[1]
    elseif block.t == 'Figure' and block.content and #block.content == 1 then
      -- pandoc 3.x wraps standalone images in a Figure AST node
      local inner = block.content[1]
      if (inner.t == 'Plain' or inner.t == 'Para') and
         inner.content and #inner.content == 1 and
         inner.content[1].t == 'Image' then
        img = inner.content[1]
      end
    end
    if img then
      -- Constrain to headheight so image never overflows the fancyhdr box upward.
      -- adjustbox's max height/width keep the aspect ratio without clipping.
      local latex = '\\includegraphics[keepaspectratio,max height=\\headheight,max width=\\linewidth]{'
                    .. img.src .. '}'
      table.insert(result, pandoc.RawBlock('latex', latex))
    else
      table.insert(result, block)
    end
  end
  return result
end

-- For Typst, a standalone image inside a header renders as a #figure block.
-- Replace it with a plain #image() call constrained to header height.
local function replace_images_for_typst(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    local img = nil
    if (block.t == 'Para' or block.t == 'Plain') and
       #block.content == 1 and block.content[1].t == 'Image' then
      img = block.content[1]
    elseif block.t == 'Figure' and block.content and #block.content == 1 then
      local inner = block.content[1]
      if (inner.t == 'Plain' or inner.t == 'Para') and
         inner.content and #inner.content == 1 and
         inner.content[1].t == 'Image' then
        img = inner.content[1]
      end
    end
    if img then
      table.insert(result, pandoc.RawBlock('typst',
        '#image("' .. img.src .. '", height: 15mm, fit: "contain")'))
    else
      table.insert(result, block)
    end
  end
  return result
end

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
      local content
      if fmt == 'latex' then
        content = replace_images_for_latex(el.content)
      elseif fmt == 'typst' then
        content = replace_images_for_typst(el.content)
      else
        content = el.content
      end
      -- Render the div's content and strip the trailing newline pandoc adds
      local rendered = pandoc.write(pandoc.Pandoc(content), fmt):gsub('\n$', '')
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
