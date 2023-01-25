local __dir__ = hs.spoons.scriptPath()

local knu = {
  name = "Knu",
  version = "1.0.0",
  author = "Akinori Musha <knu@iDaemons.org>",
  homepage = "https://github.com/knu/hs-knu",
  license = "BSD-2-Clause - https://opensource.org/licenses/BSD-2-Clause",
}

local function loadModule(name)
  knu[name] = dofile(hs.spoons.resourcePath(name .. ".lua"))
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
