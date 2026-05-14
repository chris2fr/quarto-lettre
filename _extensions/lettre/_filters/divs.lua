local env_for_class = {
  to = 'div-to',
  from = 'div-from',
  body = 'div-body',
  date = 'div-date',
  opening = 'div-opening',
  closing = 'div-closing',
  signature = 'div-signature',
  object = 'div-object',
}

local function wrap_div(el, env)
  if quarto.doc.is_format('pdf') then
    table.insert(el.content, 1, pandoc.RawBlock('latex', '\\begin{' .. env .. '}'))
    table.insert(el.content, pandoc.RawBlock('latex', '\\end{' .. env .. '}'))
  end
  return el
end

function Div(el)
  for class, env in pairs(env_for_class) do
    if el.classes:includes(class) then
      return wrap_div(el, env)
    end
  end
end
