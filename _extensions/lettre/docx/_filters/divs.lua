local style_for_class = {
  from      = 'Letter From',
  date      = 'Letter Date',
  to        = 'Letter To',
  subject   = 'Letter Subject',
  ref       = 'Letter Reference',
  opening   = 'Letter Opening',
  body      = 'Letter Body',
  closing   = 'Letter Closing',
  signature = 'Letter Signature',
}

function Div(el)
  for class, style in pairs(style_for_class) do
    if el.classes:includes(class) then
      el.attributes['custom-style'] = style
      return el
    end
  end
end
