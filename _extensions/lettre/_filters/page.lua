-- Stores rendered header/footer content to inject into metadata
local extracted = {}

-- Extract a standalone image from a block, or return nil.
-- Handles both a bare Para/Plain(Image) and Pandoc 3.x Figure(Plain(Image)).
local function extract_image(block)
  if (block.t == 'Para' or block.t == 'Plain') and
     #block.content == 1 and block.content[1].t == 'Image' then
    return block.content[1]
  elseif block.t == 'Figure' and block.content and #block.content == 1 then
    local inner = block.content[1]
    if (inner.t == 'Plain' or inner.t == 'Para') and
       inner.content and #inner.content == 1 and
       inner.content[1].t == 'Image' then
      return inner.content[1]
    end
  end
  return nil
end

-- LaTeX: replace with \includegraphics constrained to headheight.
-- Avoids "Float(s) lost" from figure environments inside fancyhdr.
local function replace_images_for_latex(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    local img = extract_image(block)
    if img then
      table.insert(result, pandoc.RawBlock('latex',
        '\\includegraphics[keepaspectratio,max height=\\headheight,max width=\\linewidth]{'
        .. img.src .. '}'))
    else
      table.insert(result, block)
    end
  end
  return result
end

-- Typst: replace with #image() constrained to 15 mm. Avoids #figure wrapper.
local function replace_images_for_typst(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    local img = extract_image(block)
    if img then
      table.insert(result, pandoc.RawBlock('typst',
        '#image("' .. img.src .. '", height: 15mm, fit: "contain")'))
    else
      table.insert(result, block)
    end
  end
  return result
end

-- HTML: replace with a bare <img> (no <figure> wrapper) capped at 3rem tall.
local function replace_images_for_html(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    local img = extract_image(block)
    if img then
      local alt = pandoc.utils.stringify(img.caption):gsub('"', '&quot;')
      table.insert(result, pandoc.RawBlock('html',
        '<img src="' .. img.src .. '" alt="' .. alt
        .. '" style="max-height:3rem;width:auto;max-width:100%;">'))
    else
      table.insert(result, block)
    end
  end
  return result
end

-- docx / odt: unwrap Figure nodes to Plain(Image).
-- pandoc.write() with binary formats produces an unusable blob; store native
-- AST blocks instead so the docx/odt writer renders them directly.
local function replace_images_inline(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    local img = extract_image(block)
    if img then
      table.insert(result, pandoc.Plain({ img }))
    else
      table.insert(result, block)
    end
  end
  return result
end

-- Route smart double-quotes through csquotes (\enquote) in LaTeX so babel-french
-- produces guillemets. For Typst, emit ASCII " so Typst's own smart-quote engine
-- (which knows to use guillemets when lang is "fr") does the work.
function Quoted(el)
  if el.quotetype ~= 'DoubleQuote' then return nil end
  if FORMAT:match('latex') then
    local inner = pandoc.write(pandoc.Pandoc({ pandoc.Plain(el.content) }), 'latex')
                    :gsub('\n$', '')
    return pandoc.RawInline('latex', '\\enquote{' .. inner .. '}')
  elseif FORMAT:match('typst') then
    local inner = pandoc.write(pandoc.Pandoc({ pandoc.Plain(el.content) }), 'typst')
                    :gsub('\n$', '')
    return pandoc.RawInline('typst', '"' .. inner .. '"')
  end
end

-- Intercept ::: header ::: and ::: footer ::: divs.
-- Each matching div is rendered to the current output format and stored as
-- `page-header` / `page-footer` metadata, then removed from the document body.
function Div(el)
  for _, class in ipairs({ 'header', 'footer' }) do
    if el.classes:includes(class) then
      -- Normalise format variants: html* → 'html', markdown* → 'markdown'
      local fmt = FORMAT:match('html') and 'html'
               or FORMAT:match('markdown') and 'markdown'
               or FORMAT

      -- Binary formats: store as native AST (no pandoc.write to binary).
      if fmt == 'docx' or fmt == 'odt' then
        local blocks = replace_images_inline(el.content)
        if #blocks > 0 then
          extracted['page-' .. class] = pandoc.MetaBlocks(blocks)
        end
        return {}
      end

      -- Text formats: render to the target format string and store as a raw block.
      local content
      if     fmt == 'latex'    then content = replace_images_for_latex(el.content)
      elseif fmt == 'typst'    then content = replace_images_for_typst(el.content)
      elseif fmt == 'html'     then content = replace_images_for_html(el.content)
      else                          content = el.content
      end

      local rendered = pandoc.write(pandoc.Pandoc(content), fmt):gsub('\n$', '')
      if rendered ~= '' then
        extracted['page-' .. class] = pandoc.MetaBlocks({ pandoc.RawBlock(fmt, rendered) })
      end
      return {}
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
