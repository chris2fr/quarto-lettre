local heading_for_class = {
  participants     = 'Participants',
  agenda           = 'Ordre du jour',
  decisions        = 'Décisions',
  actions          = 'Actions',
  ['next-meeting'] = 'Prochaine réunion',
  approval         = 'Approbation du compte-rendu',
}

function Div(el)
  for class, heading in pairs(heading_for_class) do
    if el.classes:includes(class) then
      local blocks = { pandoc.Header(2, pandoc.Str(heading)) }
      for _, block in ipairs(el.content) do
        table.insert(blocks, block)
      end
      return blocks
    end
  end
end
