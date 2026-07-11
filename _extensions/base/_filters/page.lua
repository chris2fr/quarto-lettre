-- Stores rendered header/footer content to inject into metadata
local extracted = {}

local french_quotes = false

function Meta(m)
  french_quotes = m['french-quotes'] == true
end

-- Unwrap a single inline into (image, link-target). The image may be bare
-- or wrapped in a Link (e.g. `[![alt](logo.png)](https://example.org)`).
local function unwrap_image(inline)
  if inline.t == 'Image' then
    return inline, nil
  elseif inline.t == 'Link' and #inline.content == 1 and inline.content[1].t == 'Image' then
    return inline.content[1], inline.target
  end
  return nil
end

-- Extract a standalone image (optionally linked) from a block, or return nil.
-- Handles both a bare Para/Plain(Image) and Pandoc 3.x Figure(Plain(Image)).
local function extract_image(block)
  local img, link
  if (block.t == 'Para' or block.t == 'Plain') and #block.content == 1 then
    img, link = unwrap_image(block.content[1])
  elseif block.t == 'Figure' and block.content and #block.content == 1 then
    local inner = block.content[1]
    if (inner.t == 'Plain' or inner.t == 'Para') and
       inner.content and #inner.content == 1 then
      img, link = unwrap_image(inner.content[1])
    end
  end
  -- Quarto promotes a standalone (possibly linked) image to a Figure and
  -- moves its alt text to the Figure's own caption (a Blocks value), leaving
  -- img.caption empty. Pull the inline content back out so descriptions
  -- survive either way.
  if img and #img.caption == 0 and block.t == 'Figure' and
     block.caption and #block.caption.long > 0 then
    local first = block.caption.long[1]
    if first and (first.t == 'Plain' or first.t == 'Para') then
      img.caption = first.content
    end
  end
  return img, link
end

-- LaTeX: replace with \includegraphics constrained to headheight.
-- Avoids "Float(s) lost" from figure environments inside fancyhdr.
local function replace_images_for_latex(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    local img, link = extract_image(block)
    if img then
      local graphic = '\\includegraphics[keepaspectratio,max height=\\headheight,max width=\\linewidth]{'
        .. img.src .. '}'
      if link then
        graphic = '\\href{' .. link .. '}{' .. graphic .. '}'
      end
      table.insert(result, pandoc.RawBlock('latex', graphic))
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
    local img, link = extract_image(block)
    if img then
      local image = '#image("' .. img.src .. '", height: 15mm, fit: "contain")'
      if link then
        image = '#link("' .. link .. '")[' .. image .. ']'
      end
      table.insert(result, pandoc.RawBlock('typst', image))
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
    local img, link = extract_image(block)
    if img then
      local alt = pandoc.utils.stringify(img.caption):gsub('"', '&quot;')
      local tag = '<img src="' .. img.src .. '" alt="' .. alt
        .. '" style="max-height:3rem;width:auto;max-width:100%;">'
      if link then
        tag = '<a href="' .. link .. '">' .. tag .. '</a>'
      end
      table.insert(result, pandoc.RawBlock('html', tag))
    else
      table.insert(result, block)
    end
  end
  return result
end

-- docx / odt: unwrap Figure nodes to Plain(Image), capped at 15mm tall (same
-- as Typst) since the writer would otherwise emit the image at full native size.
-- pandoc.write() with binary formats produces an unusable blob; store native
-- AST blocks instead so the docx/odt writer renders them directly.
local function replace_images_inline(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    local img, link = extract_image(block)
    if img then
      img.attr.attributes['height'] = '15mm'
      local inline = link and pandoc.Link({ img }, link) or img
      table.insert(result, pandoc.Para({ inline }))
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
  elseif FORMAT:match('html') and french_quotes then
    local inner = pandoc.write(pandoc.Pandoc({ pandoc.Plain(el.content) }), 'html')
                    :gsub('\n$', '')
    return pandoc.RawInline('html', '\u{00AB}\u{00A0}' .. inner .. '\u{00A0}\u{00BB}')
  end
end

-- Intercept ::: header ::: and ::: footer ::: divs.
-- For docx/odt the div stays in the body (see below). For every other format
-- it is rendered and stored as `page-header` / `page-footer` metadata, then
-- removed from the document body.
function Div(el)
  for _, class in ipairs({ 'header', 'footer' }) do
    if el.classes:includes(class) then
      -- Normalise format variants: html* → 'html', markdown* → 'markdown'
      local fmt = FORMAT:match('html') and 'html'
               or FORMAT:match('markdown') and 'markdown'
               or FORMAT

      -- Binary formats: docx/odt have no template to consume page-header /
      -- page-footer metadata, so keep the div in the body (styled by
      -- docx/_filters/divs.lua) instead of stashing it where it would be
      -- silently dropped.
      if fmt == 'docx' or fmt == 'odt' then
        el.content = replace_images_inline(el.content)
        return el
      end

      -- Text formats: keep as native AST (stored in metadata) rather than
      -- pre-rendering to a string. Pre-rendering via pandoc.write() here would
      -- freeze any not-yet-resolved shortcode/custom nodes (e.g. `{{< brand ... >}}`)
      -- as inert text, since those are only expanded in a later pass that walks
      -- the final document, not raw strings produced mid-filter-chain.
      local content
      if     fmt == 'latex'    then content = replace_images_for_latex(el.content)
      elseif fmt == 'typst'    then content = replace_images_for_typst(el.content)
      elseif fmt == 'html'     then content = replace_images_for_html(el.content)
      else                          content = el.content
      end

      if #content > 0 then
        extracted['page-' .. class] = pandoc.MetaBlocks(content)
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

-- Run Meta as its own pass so french_quotes is set before Quoted/Div run:
-- in a single combined filter, Pandoc visits body elements before metadata,
-- which would otherwise leave french_quotes stale on the first read.
return {
  { Meta = Meta },
  { Quoted = Quoted, Div = Div, Pandoc = Pandoc },
}
