function quarto.project.create(name)
  -- Ask the user questions
  local author   = quarto.ask("Votre nom complet")
  local place    = quarto.ask("Ville d'expédition", "Paris")
  local to_name  = quarto.ask("Nom du destinataire")
  local to_addr  = quarto.ask("Adresse du destinataire")
  local subject  = quarto.ask("Objet de la lettre")

  -- Read the template
  local tmpl = io.open(quarto.extension.path .. "/scaffold/template.qmd"):read("*a")

  -- Replace placeholders
  tmpl = tmpl:gsub("{{author}}",   author)
  tmpl = tmpl:gsub("{{place}}",    place)
  tmpl = tmpl:gsub("{{to_name}}", to_name)
  tmpl = tmpl:gsub("{{to_addr}}", to_addr)
  tmpl = tmpl:gsub("{{subject}}", subject)

  -- Write output file
  local out = io.open(name .. ".qmd", "w")
  out:write(tmpl)
  out:close()
end