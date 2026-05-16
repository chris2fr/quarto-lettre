local function to_typst(blocks)
  return pandoc.write(pandoc.Pandoc(blocks), 'typst'):gsub('\n$', '')
end

local function s(v)
  return v and pandoc.utils.stringify(v) or ''
end

-- Strip lone leading \ left by an empty shortcode with a trailing hard-break.
local function strip_leading_break(str)
  return str:gsub('^\\\n', '')
end

-- from: left-aligned sender + space below.
-- Inject author from meta if shortcode didn't expand.
local function render_from(content, meta)
  local body = strip_leading_break(to_typst(content))
  local head = ''
  if meta.author ~= '' and not body:find(meta.author, 1, true) then
    head = meta.author .. ' \\\n'
  end
  return head .. body .. '\n#v(1em)'
end

-- date: right-aligned small text, built entirely from metadata.
local function render_date(meta)
  return '#align(right)[#text(size: 9pt)[\n' ..
         meta.place .. ', le ' .. meta.date ..
         '\n]]\n#v(1em)'
end

-- ref: right-aligned 13 cm box, small. Append ref value if shortcode failed.
local function render_ref(content, meta)
  local rendered = to_typst(content)
  if meta.ref ~= '' and not rendered:find(meta.ref, 1, true) then
    rendered = rendered .. ' ' .. meta.ref
  end
  return '#pad(left: 4cm)[#block(width: 13cm)[#text(size: 9pt)[\n' ..
         rendered .. '\n]]]'
end

-- subject: right-aligned 13 cm box, bold — built from title metadata.
local function render_subject(meta)
  return '#pad(left: 4cm)[#block(width: 13cm)[#strong[\n' ..
         meta.title .. '\n]]]'
end

-- signature: right-aligned 13 cm box — built from author metadata.
local function render_signature(content, meta)
  local rendered = strip_leading_break(to_typst(content))
  if meta.author ~= '' and not rendered:find(meta.author, 1, true) then
    rendered = meta.author
  end
  return '#pad(left: 4cm)[#block(width: 13cm)[\n' .. rendered .. '\n]]'
end

local handlers = {
  from    = function(c, m) return render_from(c, m) end,
  date    = function(_, m) return render_date(m) end,
  to      = function(c, _)
    return '#pad(left: 9cm)[\n' .. to_typst(c) .. '\n]\n#v(1em)'
  end,
  subject  = function(_, m) return render_subject(m) end,
  ref      = function(c, m) return render_ref(c, m) end,
  opening  = function(c, _)
    return '#v(1em)\n#pad(left: 4cm)[#block(width: 13cm)[\n' .. to_typst(c) .. '\n]]'
  end,
  body     = function(c, _) return to_typst(c) .. '\n#v(1em)' end,
  closing  = function(c, _)
    return '#pad(left: 4cm)[#block(width: 13cm)[\n' .. to_typst(c) .. '\n]]\n#v(1em)'
  end,
  signature = function(c, m) return render_signature(c, m) end,
}

-- Use Pandoc (runs last) so metadata is available when we process divs.
function Pandoc(doc)
  local meta = {
    author = s(doc.meta.author),
    place  = s(doc.meta.place),
    title  = s(doc.meta.title),
    ref    = s(doc.meta.ref),
    date   = s(doc.meta.date),
  }

  local new_blocks = {}
  for _, block in ipairs(doc.blocks) do
    local converted = false
    if block.t == 'Div' then
      for class, handler in pairs(handlers) do
        if block.classes:includes(class) then
          table.insert(new_blocks,
            pandoc.RawBlock('typst', handler(block.content, meta)))
          converted = true
          break
        end
      end
    end
    if not converted then
      table.insert(new_blocks, block)
    end
  end

  doc.blocks = new_blocks
  return doc
end
