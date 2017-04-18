local __namespace__, __file__ = ...
__namespace__ = __namespace__:gsub("%.init$", "")  -- just in case
local __dir__ = __file__:match("^(.*)/[^/]+$")

local knu = {}

local function loadModule(name)
  knu[name] = require(__namespace__ .. "." .. name)
  return knu[name]
end

setmetatable(knu, {
    -- Autoload
    __index = function (self, name)
      if name ~= "init" then
        return loadModule(name)
      end
    end
})

-- Preloads all or some submodules
knu.preload = function (...)
  local modules = {...}

  if #modules == 0 then
    -- Load all files
    for file in hs.fs.dir(__dir__) do
      local name = file:match("^([^.]+)%.lua$")
      if name and name ~= "init" then
        return loadModule(name)
      end
    end
  else
    for _, name in modules do
      loadModule(name)
    end
  end
  return true
end

return knu
