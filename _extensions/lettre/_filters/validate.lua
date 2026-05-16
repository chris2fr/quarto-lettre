-- Required YAML front-matter keys
local required_meta = { 'title', 'author', 'lang', 'date' }

-- Optional YAML front-matter keys (recognized by the extension but not mandatory)
local optional_meta = { 'place', 'ref' }

-- Required named divs that the letter document must contain
local required_divs = { 'from', 'date', 'to', 'subject', 'opening', 'body', 'closing', 'signature' }

-- Tracks which required divs have been found during traversal
local seen = {}

-- Walk every Div in the document and mark required ones as seen
function Div(el)
  for _, class in ipairs(required_divs) do
    if el.classes:includes(class) then
      seen[class] = true
    end
  end
end

function Pandoc(doc)
  -- Build a lookup of all keys the extension knows about
  local known_meta = {}
  for _, k in ipairs(required_meta) do known_meta[k] = true end
  for _, k in ipairs(optional_meta) do known_meta[k] = true end

  -- Keep only top-level Div blocks; other block types are not valid in a lettre document
  local blocks = {}
  for _, block in ipairs(doc.blocks) do
    if block.t == 'Div' then
      table.insert(blocks, block)
    end
  end
  doc.blocks = blocks

  -- Validate metadata
  local missing = {}
  for _, key in ipairs(required_meta) do
    if not doc.meta[key] then
      table.insert(missing, key)
    end
  end
  if #missing > 0 then
    error('Lettre: missing required metadata: ' .. table.concat(missing, ', '))
  end

  -- Warn about single-word lowercase keys not in either list (likely typos)
  for key, _ in pairs(doc.meta) do
    if key:match('^%l+$') and not known_meta[key] then
      io.stderr:write('WARNING [lettre]: unrecognized metadata key: ' .. key .. '\n')
    end
  end

  -- Validate required divs (populated by the Div walker above)
  for _, class in ipairs(required_divs) do
    if not seen[class] then
      table.insert(missing, '::: ' .. class .. ' :::')
    end
  end
  if #missing > 0 then
    error('Lettre: missing required div(s):\n  ' .. table.concat(missing, '\n  '))
  end

  return doc
end
