-- Interactive scaffold — fills in template.qmd from user input.
-- Usage: lua setup.lua [target.qmd]

local target = (arg and arg[1]) or "template.qmd"

local f = io.open(target, "r")
if not f then
  io.stderr:write("Error: " .. target .. " not found. Run from the project root.\n")
  os.exit(1)
end
local content = f:read("*a")
f:close()

local function ask(prompt)
  io.write(prompt)
  io.flush()
  return io.read()
end

local title  = ask("Objet de la lettre : ")
local author = ask("Auteur (Prénom Nom) : ")
local place  = ask("Lieu d'envoi        : ")
local ref    = ask("Référence           : ")
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

print("\n" .. target .. " updated. Edit the letter body, then:")
print("  quarto render " .. target)
