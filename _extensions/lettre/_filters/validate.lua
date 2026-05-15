local required = { 'from', 'date', 'to', 'subject', 'opening', 'body', 'closing', 'signature' }
local seen = {}

function Div(el)
  for _, class in ipairs(required) do
    if el.classes:includes(class) then
      seen[class] = true
    end
  end
end

function Pandoc(doc)
  local blocks = {}
  for _, block in ipairs(doc.blocks) do
    if block.t == 'Div' then
      table.insert(blocks, block)
    end
  end
  doc.blocks = blocks

  local missing = {}
  for _, class in ipairs(required) do
    if not seen[class] then
      table.insert(missing, '::: ' .. class .. ' :::')
    end
  end
  if #missing > 0 then
    error('Lettre: missing required div(s):\n  ' .. table.concat(missing, '\n  '))
  end
  return doc
end
