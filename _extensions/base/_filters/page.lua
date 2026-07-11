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

-- Classes handled by this filter, and whether an actual ::: header/footer :::
-- div was found for each while walking the document (see find_generic_layout).
local seen = { header = false, footer = false }

-- Format-specific rendering shared by both a real div and a generic-layout
-- fallback file. For docx/odt returns a content list to place in the body
-- (wrapped in a Div so docx/_filters/divs.lua can still style it); for every
-- other format it stashes `page-<class>` metadata for the layout templates.
-- `doc` is nil when called while still walking the tree (a real div, before
-- Pandoc(doc) exists) — the metadata is queued in `extracted` and applied
-- once Pandoc(doc) runs. When called from Pandoc(doc) itself (generic-layout
-- fallback) `doc` is passed through so metadata can be set directly.
local function apply_section(class, content, doc)
  -- Normalise format variants: html* → 'html', markdown* → 'markdown'
  local fmt = FORMAT:match('html') and 'html'
           or FORMAT:match('markdown') and 'markdown'
           or FORMAT

  -- Binary formats: docx/odt have no template to consume page-header /
  -- page-footer metadata, so keep the content in the body (styled by
  -- docx/_filters/divs.lua) instead of stashing it where it would be
  -- silently dropped.
  if fmt == 'docx' or fmt == 'odt' then
    return pandoc.Div(replace_images_inline(content), pandoc.Attr('', { class }))
  end

  -- Text formats: keep as native AST (stored in metadata) rather than
  -- pre-rendering to a string. Pre-rendering via pandoc.write() here would
  -- freeze any not-yet-resolved shortcode/custom nodes (e.g. `{{< brand ... >}}`)
  -- as inert text, since those are only expanded in a later pass that walks
  -- the final document, not raw strings produced mid-filter-chain.
  local rendered
  if     fmt == 'latex' then rendered = replace_images_for_latex(content)
  elseif fmt == 'typst' then rendered = replace_images_for_typst(content)
  elseif fmt == 'html'  then rendered = replace_images_for_html(content)
  else                       rendered = content
  end

  if #rendered > 0 then
    local key = 'page-' .. class
    if doc then
      doc.meta[key] = pandoc.MetaBlocks(rendered)
    else
      extracted[key] = pandoc.MetaBlocks(rendered)
    end
  end
  return nil
end

-- Intercept ::: header ::: and ::: footer ::: divs and hand their content to
-- apply_section. The docx/odt Div returned here is spliced back in place;
-- every other format is removed from the body (its content lives in metadata).
function Div(el)
  for _, class in ipairs({ 'header', 'footer' }) do
    if el.classes:includes(class) then
      seen[class] = true
      return apply_section(class, el.content, nil) or {}
    end
  end
end

-- The base extension ships a generic default header/footer under its own
-- layout/generic/ directory. When the document itself has no
-- ::: header/footer ::: div, fall back to that file's content, resolved
-- relative to this filter script's own location (base/_filters/page.lua →
-- base/layout/generic/<class>.qmd) so it works regardless of which project
-- or document is being rendered.
local function find_generic_layout(class)
  if not PANDOC_SCRIPT_FILE then return nil end
  local path = pandoc.path.join({
    pandoc.path.directory(PANDOC_SCRIPT_FILE), '..', 'layout', 'generic', class .. '.qmd'
  })
  local f = io.open(path, 'r')
  if f then
    f:close()
    return path
  end
  return nil
end

-- Read a generic layout .qmd, strip any YAML front matter, and parse it into
-- blocks the same way a ::: header/footer ::: div's content would arrive.
local function read_generic_layout(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local text = f:read('a')
  f:close()
  text = text:gsub('^%-%-%-\n.-\n%-%-%-\n', '')
  return pandoc.read(text, 'markdown').blocks
end

-- Inject the extracted values into document metadata so layout templates
-- can reference $page-header$ and $page-footer$, and fill in any
-- header/footer missing from the document from the extension's generic
-- layout files.
function Pandoc(doc)
  for key, value in pairs(extracted) do
    doc.meta[key] = value
  end

  for _, class in ipairs({ 'header', 'footer' }) do
    if not seen[class] then
      local path = find_generic_layout(class)
      if path then
        local blocks = read_generic_layout(path)
        if blocks and #blocks > 0 then
          local div = apply_section(class, blocks, doc)
          if div then
            if class == 'header' then
              table.insert(doc.blocks, 1, div)
            else
              table.insert(doc.blocks, div)
            end
          end
        end
      end
    end
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
