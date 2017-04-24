local photkey = {}

local keyDown = hs.eventtap.event.types.keyDown
local flagsChanged = hs.eventtap.event.types.flagsChanged

local runtime = require((...):gsub("[^.]+$", "runtime"))
local utils = require((...):gsub("[^.]+$", "utils"))

local modState = {
  shift = {false, false},
  ctrl = {false, false},
  alt = {false, false},
  cmd = {false, false},
  fn = false
}

local modTracer = hs.eventtap.new({flagsChanged},
  function (e)
    local code = e:getKeyCode()
    local cmod, cidx
    if code == 63 then
      modState.fn = e:getFlags().fn == true
      return
    elseif code == 56 then
      cmod, cidx = "shift", 1
    elseif code == 60 then
      cmod, cidx = "shift", 2
    elseif code == 59 then
      cmod, cidx = "ctrl", 1
    elseif code == 62 then
      cmod, cidx = "ctrl", 2
    elseif code == 58 then
      cmod, cidx = "alt", 1
    elseif code == 61 then
      cmod, cidx = "alt", 2
    elseif code == 55 then
      cmod, cidx = "cmd", 1
    elseif code == 54 then
      cmod, cidx = "cmd", 2
    else
      return
    end

 local lr = modState[cmod]
    lr[cidx] = not lr[cidx]
    local flag = (e:getFlags()[cmod] == true)
    if (lr[1] or lr[2]) ~= flag then
      -- Fix unsynced modifier state typically caused by other eventtaps
      lr[1] = false
      lr[2] = false
      lr[cidx] = flag
    end
  end
)

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
  modTracer:start()

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
