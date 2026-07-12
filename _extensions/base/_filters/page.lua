-- Stores rendered header/footer content to inject into metadata
local extracted = {}

local french_quotes = false

-- This filter is shared by the lettre, compte-rendu and document extensions.
-- ::: header ::: / ::: footer ::: and their _parts/ fallback (further down)
-- are common to all three. The rest of the fallback vocabulary
-- (from/date/to/subject/ref/opening/closing/signature) is lettre's own —
-- compte-rendu and document use different div classes (or none at all) and
-- must not have that content spliced into them.
-- quarto.format.format_identifier()['extension-name'] reliably names the
-- extension supplying the current output format, for every format
-- (unlike `base-format` in doc.meta, which is inconsistent for `md`).
local is_lettre = false

-- Whether an actual div was found for each fallback-eligible class while
-- walking the document (see find_part further down).
local seen = {}

-- Quarto can run several output formats of the same document through one
-- persistent Lua state (not a fresh process per format), so every module-
-- level table above must be cleared per format or state leaks from one
-- format's render into the next one's. Meta() runs once at the start of
-- each format's filter pass, so reset here.
function Meta(m)
  french_quotes = m['french-quotes'] == true
  is_lettre = quarto.format.format_identifier()['extension-name'] == 'lettre'
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

-- Classes that can fall back to an extension-provided <class>.qmd
-- snippet when the document doesn't define them. header/footer place their
-- content outside the normal body flow (see apply_section); the rest are
-- plain in-body divs, positioned relative to their neighbours in BODY_ORDER
-- (see fill_missing_body_divs).
local FALLBACK_CLASSES = {
  header = true, footer = true,
  from = true, date = true, to = true, subject = true, ref = true,
  opening = true, closing = true, signature = true,
}
local HEADER_FOOTER = { header = true, footer = true }

-- Canonical position of every body div in a lettre document. 'body' anchors
-- the sequence but never gets a generic fallback (the letter's actual
-- content is never generic) — it just marks where fallback divs around it
-- should be inserted.
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

-- Resolve a "part" (the fallback content for one section class), checking
-- in priority order:
--   1. ./_parts/<class>.qmd next to the document being rendered — lets a
--      single document override a section without touching the project.
--   2. <project root>/_parts/<class>.qmd (the directory holding _quarto.yml)
--      — a project-wide override, e.g. shared by every letter in a project.
--   3. the base extension's own bundled default, resolved relative to this
--      filter script's own location (base/_filters/page.lua →
--      base/parts/<class>.qmd) so it works regardless of which
--      project or document is being rendered.
-- The first one found wins: a _parts/ file always takes precedence over the
-- extension's own default.
local function find_part(class)
  local candidates = {}
  if PANDOC_STATE and PANDOC_STATE.input_files and #PANDOC_STATE.input_files > 0 then
    table.insert(candidates, pandoc.path.join({
      pandoc.path.directory(PANDOC_STATE.input_files[1]), '_parts', class .. '.qmd'
    }))
  end
  if quarto and quarto.project and quarto.project.directory and quarto.project.directory ~= '' then
    table.insert(candidates, pandoc.path.join({
      quarto.project.directory, '_parts', class .. '.qmd'
    }))
  end
  if PANDOC_SCRIPT_FILE then
    table.insert(candidates, pandoc.path.join({
      pandoc.path.directory(PANDOC_SCRIPT_FILE), '..', 'parts', class .. '.qmd'
    }))
  end
  for _, path in ipairs(candidates) do
    local f = io.open(path, 'r')
    if f then
      f:close()
      return path
    end
  end
  return nil
end

-- `quarto add` has no post-install hook, so there's no way to scaffold
-- _parts/ right when the extension is installed. Approximate it instead: the
-- first time a document is rendered somewhere without a _parts/ directory
-- yet, populate one (project root if there is a project, else next to the
-- document) with a copy of every part in `classes` this extension can fall
-- back on, so the user has real, editable files to start from. Never touches
-- an existing _parts/ (even an empty one), so this only ever fires once.
-- `classes` is HEADER_FOOTER for compte-rendu/document (they only support
-- header/footer parts) and FALLBACK_CLASSES for lettre (the full set).
local function scaffold_parts(classes)
  if not PANDOC_SCRIPT_FILE then return end
  local base_dir
  if quarto and quarto.project and quarto.project.directory and quarto.project.directory ~= '' then
    base_dir = quarto.project.directory
  elseif PANDOC_STATE and PANDOC_STATE.input_files and #PANDOC_STATE.input_files > 0 then
    base_dir = pandoc.path.directory(PANDOC_STATE.input_files[1])
  end
  if not base_dir then return end

  local parts_dir = pandoc.path.join({ base_dir, '_parts' })
  if pcall(pandoc.system.list_directory, parts_dir) then return end

  local generic_dir = pandoc.path.join({
    pandoc.path.directory(PANDOC_SCRIPT_FILE), '..', 'parts'
  })
  local ok, files = pcall(pandoc.system.list_directory, generic_dir)
  if not ok then return end

  local copied = false
  for _, name in ipairs(files) do
    local class = name:match('^(.*)%.qmd$')
    if class and classes[class] then
      local src = io.open(pandoc.path.join({ generic_dir, name }), 'r')
      if src then
        local content = src:read('a')
        src:close()
        if not copied then
          pandoc.system.make_directory(parts_dir, true)
          copied = true
        end
        local dst = io.open(pandoc.path.join({ parts_dir, name }), 'w')
        if dst then
          dst:write(content)
          dst:close()
        end
      end
    end
  end
  if copied then
    io.stderr:write('[quarto-lettre] _parts/ créé avec les sections par défaut, éditables librement : ' .. parts_dir .. '\n')
  end
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

-- Expand `{{< brand logo <name> >}}` shortcodes by hand, same reason as
-- expand_meta_shortcodes above. Quarto's own brand shortcode also emits a
-- dark-mode variant for HTML theme switching, but the rest of this
-- extension's image handling (extract_image and friends) only understands a
-- single image, so this resolves to one: light if the brand defines it,
-- dark otherwise.
local function expand_brand_shortcodes(text)
  return (text:gsub('{{<%s*brand%s+logo%s+([%w_%-]+)%s*>}}', function(name)
    local mode = quarto.brand.has_mode('light') and 'light' or 'dark'
    local ok, logo = pcall(quarto.brand.get_logo, mode, name)
    if not ok or not logo or not logo.path then return '' end
    return '![](' .. logo.path .. ')'
  end))
end

-- Read a part .qmd, strip any YAML front matter, expand `{{< meta ... >}}`
-- and `{{< brand logo ... >}}` shortcodes, and parse it into blocks the same
-- way a ::: header/footer ::: div's content would arrive.
local function read_part_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local text = f:read('a')
  f:close()
  text = text:gsub('^%-%-%-\n.-\n%-%-%-\n', '')
  text = expand_meta_shortcodes(text)
  text = expand_brand_shortcodes(text)
  return pandoc.read(text, 'markdown').blocks
end

-- Load a class's part file, if any, already parsed into blocks.
local function load_part(class)
  local path = find_part(class)
  if not path then return nil end
  local blocks = read_part_file(path)
  if blocks and #blocks > 0 then return blocks end
  return nil
end

-- Sort doc.blocks into: known-class divs (from/date/to/subject/ref/opening/
-- body/closing/signature — one each — plus header/footer, kept aside so
-- they can be re-prepended/appended untouched), and everything else
-- ("loose" content: bare paragraphs, headings, tables, custom divs with no
-- recognized class...). A qmd doesn't have to wrap its letter content in
-- ::: body :::: any loose content, wherever it appears in the document, is
-- concatenated into the body — but only when no explicit ::: body ::: was
-- written, so an author who does wrap it keeps full control.
local function bucket_blocks(doc)
  local by_class, loose, header_block, footer_block = {}, {}, nil, nil
  for _, block in ipairs(doc.blocks) do
    local class = nil
    if block.t == 'Div' then
      for _, c in ipairs(block.classes) do
        if c == 'header' or c == 'footer' or ALL_BODY_CLASSES[c] then
          class = c
          break
        end
      end
    end
    if class == 'header' then
      header_block = block
    elseif class == 'footer' then
      footer_block = block
    elseif class then
      by_class[class] = block
    else
      table.insert(loose, block)
    end
  end
  return by_class, loose, header_block, footer_block
end

-- Rebuild doc.blocks in BODY_ORDER: divs that were found are used as-is;
-- divs that are missing but have a <class>.qmd fallback are
-- synthesized in their canonical position. 'body' additionally falls back to
-- the document's loose content (see bucket_blocks) before falling back to a
-- generic file. Any class still missing (or without a fallback) is simply
-- left absent, same as today — validate.lua still catches a genuinely
-- missing required div.
local function fill_missing_body_divs(doc)
  local by_class, loose, header_block, footer_block = bucket_blocks(doc)

  local new_blocks = {}
  if header_block then table.insert(new_blocks, header_block) end
  for _, class in ipairs(BODY_ORDER) do
    if by_class[class] then
      table.insert(new_blocks, by_class[class])
    elseif class == 'body' and not seen['body'] and #loose > 0 then
      table.insert(new_blocks, pandoc.Div(loose, pandoc.Attr('', { 'body' })))
      seen['body'] = true
    elseif FALLBACK_CLASSES[class] then
      local blocks = load_part(class)
      if blocks then
        table.insert(new_blocks, pandoc.Div(blocks, pandoc.Attr('', { class })))
      end
    end
  end
  if footer_block then table.insert(new_blocks, footer_block) end
  doc.blocks = new_blocks
end

-- Fill in the per-side margin-inner/margin-outer/margin-top/margin-bottom
-- keys (consumed as-is by every extension's pdf/layout.tex \geometry calls)
-- from the coarser marginx/marginy/margin-all keys, when the more specific
-- one isn't already set by the document. Priority, most to least specific:
--   margin-inner / margin-outer / margin-top / margin-bottom  (untouched if set)
--   marginx (→ inner & outer) / marginy (→ top & bottom)
--   margin-all (→ all four)
-- Note: the bare key `margin` is reserved by Quarto itself (revealjs/typst
-- slide margin, must be a number) — using it here would fail YAML
-- validation for a string like "20mm", hence `margin-all`.
-- PDF-only: these feed LaTeX \geometry values and have no meaning elsewhere.
-- Applies to all three extensions alike (not gated by is_lettre), since the
-- margin-inner/outer/top/bottom mechanism itself already is shared.
local function resolve_margins(doc)
  if not FORMAT:match('latex') then return end
  local margin  = doc.meta['margin-all']
  local marginx = doc.meta['marginx'] or margin
  local marginy = doc.meta['marginy'] or margin
  if not doc.meta['margin-inner']  and marginx then doc.meta['margin-inner']  = marginx end
  if not doc.meta['margin-outer']  and marginx then doc.meta['margin-outer']  = marginx end
  if not doc.meta['margin-top']    and marginy then doc.meta['margin-top']    = marginy end
  if not doc.meta['margin-bottom'] and marginy then doc.meta['margin-bottom'] = marginy end
end

-- Inject the extracted values into document metadata so layout templates can
-- reference $page-header$ and $page-footer$; resolve margin fallbacks (see
-- resolve_margins); scaffold/fall back to _parts/header.qmd and
-- _parts/footer.qmd for every extension; then, lettre only, fill in any of
-- from/date/to/subject/ref/opening/closing/signature missing from the
-- document, in their canonical position (see `is_lettre` above).
function Pandoc(doc)
  for key, value in pairs(extracted) do
    doc.meta[key] = value
  end

  resolve_margins(doc)

  scaffold_parts(is_lettre and FALLBACK_CLASSES or HEADER_FOOTER)

  if is_lettre then
    fill_missing_body_divs(doc)
  end

  for _, class in ipairs({ 'header', 'footer' }) do
    if not seen[class] then
      local blocks = load_part(class)
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

  return doc
end

-- Run Meta as its own pass so french_quotes is set before Quoted/Div run:
-- in a single combined filter, Pandoc visits body elements before metadata,
-- which would otherwise leave french_quotes stale on the first read.
return {
  { Meta = Meta },
  { Quoted = Quoted, Div = Div, Pandoc = Pandoc },
}
