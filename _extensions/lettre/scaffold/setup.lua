-- Interactive scaffold — fills in template.qmd from user input.
-- Usage: lua setup.lua [target.qmd]

local function first_qmd()
  local p = io.popen("ls *.qmd 2>/dev/null | head -1")
  if p then
    local name = p:read("*l")
    p:close()
    if name and name ~= "" then return name end
  end
end

local target = (arg and arg[1]) or first_qmd() or "template.qmd"

local f = io.open(target, "r")
if not f then
  io.stderr:write("Error: " .. target .. " not found. Run from the project root.\n")
  os.exit(1)
end
local content = f:read("*a")
f:close()

local function yaml_get(key)
  return content:match("\n" .. key .. ": ([^\n]+)") or
         content:match("^" .. key .. ": ([^\n]+)")
end

local function ask(prompt, default)
  local hint = default and (" [" .. default .. "]") or ""
  io.write(prompt .. hint .. " : ")
  io.flush()
  local input = io.read()
  return (input and input ~= "") and input or default or ""
end

local title  = ask("Objet de la lettre", yaml_get("title"))
local author = ask("Auteur (Prénom Nom)", yaml_get("author"))
local place  = ask("Lieu d'envoi       ", yaml_get("place"))
local ref    = ask("Référence          ", yaml_get("ref"))
local date   = os.date("%Y-%m-%d")

local replacements = {
  title  = title,
  author = author,
  place  = place,
  ref    = ref,
  date   = date,
}

local result = {}
for line in (content .. "\n"):gmatch("([^\n]*)\n") do
  local key = line:match("^(%a+):")
  local out_line = (key and replacements[key]) and (key .. ": " .. replacements[key]) or line
  table.insert(result, out_line)
end
if result[#result] == "" then table.remove(result) end

local out = io.open(target, "w")
out:write(table.concat(result, "\n") .. "\n")
out:close()

-- Update _quarto.yml render list to point to target
local quarto_yml = "_quarto.yml"
local yml_file = io.open(quarto_yml, "r")
if yml_file then
  local yml_content = yml_file:read("*a")
  yml_file:close()
  local updated = yml_content:gsub("(    %- )([^\n]+%.qmd)", "%1" .. target)
  if updated ~= yml_content then
    local yml_out = io.open(quarto_yml, "w")
    yml_out:write(updated)
    yml_out:close()
    print("_quarto.yml updated — render target: " .. target)
  end
end

print("\n" .. target .. " updated. Edit the letter body, then:")
print("  quarto render " .. target)
