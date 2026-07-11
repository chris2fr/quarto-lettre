-- Stores rendered header/footer content to inject into metadata
local extracted = {}

local french_quotes = false

-- Whether an actual div was found for each fallback-eligible class while
-- walking the document (see find_generic_layout further down).
local seen = {}

-- Quarto can run several output formats of the same document through one
-- persistent Lua state (not a fresh process per format), so every module-
-- level table above must be cleared per format or state leaks from one
-- format's render into the next one's. Meta() runs once at the start of
-- each format's filter pass, so reset here.
function Meta(m)
  french_quotes = m['french-quotes'] == true
  extracted = {}
  seen = {}
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

-- Classes that can fall back to an extension-provided generic/<class>.qmd
-- snippet when the document doesn't define them. header/footer place their
-- content outside the normal body flow (see apply_section); the rest are
-- plain in-body divs, positioned relative to their neighbours in BODY_ORDER
-- (see fill_missing_body_divs).
local FALLBACK_CLASSES = {
  header = true, footer = true,
  date = true, to = true, subject = true, ref = true,
  opening = true, closing = true, signature = true,
}
local HEADER_FOOTER = { header = true, footer = true }

-- Canonical position of every body div in a lettre document. 'from' and
-- 'body' anchor the sequence but never get a generic fallback (sender
-- address and letter content are never generic) — they just mark where
-- fallback divs around them should be inserted.
local BODY_ORDER = { 'from', 'date', 'to', 'subject', 'ref', 'opening', 'body', 'closing', 'signature' }

-- Every class fill_missing_body_divs needs presence tracked for, including
-- from/body which anchor positions but are never synthesized themselves.
local ALL_BODY_CLASSES = {}
for _, class in ipairs(BODY_ORDER) do ALL_BODY_CLASSES[class] = true end

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

-- Track which body-sequence divs are actually present (needed by
-- fill_missing_body_divs to place fallbacks correctly, even for from/body
-- which never get synthesized themselves). header/footer are handed to
-- apply_section (docx/odt Div spliced back in place; every other format is
-- removed from the body, its content living in metadata instead). The rest
-- are left alone here — they're plain in-body divs already styled by each
-- format's own divs.lua filter further down the chain — we only note they exist.
function Div(el)
  for _, class in ipairs(el.classes) do
    if HEADER_FOOTER[class] then
      seen[class] = true
      return apply_section(class, el.content, nil) or {}
    elseif ALL_BODY_CLASSES[class] then
      seen[class] = true
      return nil
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

-- Expand `{{< meta key >}}` shortcodes by hand: the file is read and parsed
-- straight from disk (outside quarto's own document pipeline), so its raw
-- text never goes through quarto's shortcode-resolution pass the way the
-- current document's own content does.
local function expand_meta_shortcodes(text)
  return (text:gsub('{{<%s*meta%s+([%w%.%-_]+)%s*>}}', function(key)
    local value = quarto.metadata.get(key)
    if value == nil then return '' end
    return pandoc.utils.stringify(value)
  end))
end

-- Read a generic layout .qmd, strip any YAML front matter, expand `{{< meta
-- ... >}}` shortcodes, and parse it into blocks the same way a
-- ::: header/footer ::: div's content would arrive.
local function read_generic_layout(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local text = f:read('a')
  f:close()
  text = text:gsub('^%-%-%-\n.-\n%-%-%-\n', '')
  text = expand_meta_shortcodes(text)
  return pandoc.read(text, 'markdown').blocks
end

-- Load a class's generic/<class>.qmd, if any, already parsed into blocks.
local function load_generic(class)
  local path = find_generic_layout(class)
  if not path then return nil end
  local blocks = read_generic_layout(path)
  if blocks and #blocks > 0 then return blocks end
  return nil
end

-- Walk doc.blocks once, following BODY_ORDER: divs that were found are
-- copied through as-is (along with anything interleaved before them, e.g. a
-- header div still sitting in front of ::: from :::); divs that are missing
-- but have a generic/<class>.qmd fallback are synthesized right there, in
-- their canonical position relative to the divs that do exist. Classes with
-- no fallback (from, body, or any without a generic file) are simply left
-- absent, same as today — validate.lua still catches a genuinely missing
-- required div.
local function fill_missing_body_divs(doc)
  local new_blocks = {}
  local idx = 1
  for _, class in ipairs(BODY_ORDER) do
    if seen[class] then
      while idx <= #doc.blocks do
        local block = doc.blocks[idx]
        idx = idx + 1
        table.insert(new_blocks, block)
        if block.t == 'Div' and block.classes:includes(class) then
          break
        end
      end
    elseif FALLBACK_CLASSES[class] then
      local blocks = load_generic(class)
      if blocks then
        table.insert(new_blocks, pandoc.Div(blocks, pandoc.Attr('', { class })))
      end
    end
  end
  while idx <= #doc.blocks do
    table.insert(new_blocks, doc.blocks[idx])
    idx = idx + 1
  end
  doc.blocks = new_blocks
end

-- Inject the extracted values into document metadata so layout templates can
-- reference $page-header$ and $page-footer$; fill in any of
-- date/to/subject/ref/opening/closing/signature missing from the document,
-- in their canonical position; then do the same for header/footer, which
-- instead prepend/append (they sit outside the from…signature sequence).
--
-- This filter is shared by the lettre, compte-rendu and document extensions,
-- but this whole fallback vocabulary (date/to/subject/... and the generic-
-- layout header/footer) is lettre's own — compte-rendu and document use
-- different div classes (or none at all) and must not have lettre content
-- spliced into them. A ::: from ::: div is unique to (and required by)
-- lettre documents, so its presence is used as a reliable, format-agnostic
-- signal instead of inspecting metadata like `base-format` (whose value is
-- inconsistent across lettre's own output formats).
function Pandoc(doc)
  for key, value in pairs(extracted) do
    doc.meta[key] = value
  end

  if seen['from'] then
    fill_missing_body_divs(doc)

    for _, class in ipairs({ 'header', 'footer' }) do
      if not seen[class] then
        local blocks = load_generic(class)
        if blocks then
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
