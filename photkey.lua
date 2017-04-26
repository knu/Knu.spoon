local photkey = {}

local keyDown = hs.eventtap.event.types.keyDown

local runtime = require((...):gsub("[^.]+$", "runtime"))
local utils = require((...):gsub("[^.]+$", "utils"))
local keyboard = require((...):gsub("[^.]+$", "keyboard"))

photkey.methods = {
  -- Provide hotkey compatible API for convenience
  enable = function (self)
    return self:start()
  end,

  disable = function (self)
    return self:stop()
  end,

  delete = function (self)
    return runtime.unguard(self:stop())
  end,
}

local meta = {
  __index = function (self, key)
    local tap = self.tap
    local value = photkey.methods[key] or tap[key]
    if type(value) == "function" then
      return function (self, ...)
        local ret = value(tap, ...)
        if ret == tap then
          return self
        end
        return ret
      end
    else
      return value
    end
  end
}

-- Creates a pseudo hotkey
--
-- A pseudo hotkey is implemented by using eventtap, allowing for
-- specifying pseudo modifiers listed below:
--
-- * leftshift, rightshift, leftctrl, rightctrl, leftalt, rightalt,
--   leftcmd, rightcmd and fn
photkey.new = function (pmods, key, fn)
  local modState = keyboard.getModifierState()

  local mods = {}
  local modLr = {}

  for _, pmod in ipairs(pmods) do
    local mod = pmod:match("left(.+)")
    if mod then
      modLr[mod] = 1
    else
      mod = pmod:match("right(.+)")
      if mod then
        modLr[mod] = 2
      else
        mod = pmod
      end
    end
    if modState[mod] == nil then
      error("unknown modifier: " .. pmod)
    end
    mods[#mods+1] = mod
  end

  local code
  if type(key) == "number" then
    code = key
  else
    code = hs.keycodes.map[key]
  end

  local tap = hs.eventtap.new(
    { keyDown },
    function (e)
      if e:getKeyCode() ~= code or not e:getFlags():containExactly(mods) then
        return
      end
      for mod, lr in pairs(modLr) do
        if not modState[mod][lr] then
          return
        end
      end
      fn()
      return true
    end
  )

  return runtime.guard(setmetatable({ tap = tap }, meta))
end

-- Shortcut for knu.photkey.new(...):start()
photkey.bind = function (...)
  return photkey.new(...):start()
end

return photkey
