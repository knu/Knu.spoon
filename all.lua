local __module__, __file__ = ...
local __dir__ = __file__:match("^(.*)/[^/]+$")
local __name__ = __module__:match("[^.]+$")

local knu = {}

-- Load all files in the same directory
for file in hs.fs.dir(__dir__) do
  local name = file:match("^([^.]+)%.lua$")
  if name and name ~= __name__ then
    knu[name] = require(__module__:gsub("[^.]+$", name))
  end
end

return knu
