local chord = {}

local keyDown = hs.eventtap.event.types.keyDown
local keyUp = hs.eventtap.event.types.keyUp

local utils = require((...):gsub("[^.]+$", "utils"))
local runtime = require((...):gsub("[^.]+$", "runtime"))

chord.methods = {
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
    local value = chord.methods[key] or tap[key]
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

-- Creates an eventtap that responds to a key chord
chord.new = function (mods, keys, fn, threshold)
  threshold = threshold or 0.05

  if #keys < 2 then
    error("a table of two or more keys must be passed.")
  end

  local flagMask = (1 << #keys) - 1
  local downFlags = 0
  local function isAllDown()
    return downFlags & flagMask == flagMask
  end
  local function setDown(i, bool)
    if bool then
      downFlags = downFlags | (1 << (i - 1))
    else
      downFlags = downFlags & ~(1 << (i - 1))
    end
  end
  local function resetAllDown()
    downFlags = 0
  end
  local pendingFlags = 0
  local function isPending(i)
    return pendingFlags & (1 << (i - 1)) ~= 0
  end
  local function setPending(i, bool)
    if bool then
      pendingFlags = pendingFlags | (1 << (i - 1))
    else
      pendingFlags = pendingFlags & ~(1 << (i - 1))
    end
  end
  local function resetAllPending()
    pendingFlags = 0
  end
  local passthroughFlags = 0
  local function isPassthrough(i)
    return passthroughFlags & (1 << (i - 1)) ~= 0
  end
  local function setPassthrough(i, bool)
    if bool then
      passthroughFlags = passthroughFlags | (1 << (i - 1))
    else
      passthroughFlags = passthroughFlags & ~(1 << (i - 1))
    end
  end

  local index = {}
  local events = {}
  local timers = {}

  for i, key in ipairs(keys) do
    local c
    if type(key) == "string" then
      c = hs.keycodes.map[key]
    else
      c = key
    end
    index[c] = i
    events[i] = hs.eventtap.event.newKeyEvent(mods, c, true)
  end

  function timers:start(i)
    self:stop(i)
    self[i] = hs.timer.doAfter(threshold, function ()
        self[i] = nil
        setDown(i, false)
        if isPending(i) then
          setPassthrough(i, true)
          events[i]:post()
        end
    end)
  end
  function timers:stop(i)
    local timer = self[i]
    if timer then
      timer:stop()
      self[i] = nil
      return true
    else
      return false
    end
  end
  function timers:stopAll()
    for i = 1, #keys do
      self:stop(i)
    end
  end

  local tap = hs.eventtap.new(
    {
      keyDown,
      keyUp,
    },
    function (e)
      local c = e:getKeyCode()
      local i = index[c]
      if e:getType() == keyUp then
        if i then
          setDown(i, false)
          if timers:stop(i) and isPending(i) then
            return true, {events[i], e}
          end
          return not isPending(i)
        end
        return false
      end
      if i and utils.modifierFlags(e:getFlags()) == utils.modifierFlags(mods) then
        if isPassthrough(i) then
          setPassthrough(i, false)
          return false
        end
        setDown(i, true)
        if isAllDown() then
          resetAllPending()
          resetAllDown()
          timers:stopAll()
          fn()
        else
          setPending(i, true)
          timers:start(i)
        end
        return true
      end

      local es = {e}
      for j = 1, #keys do
        if timers:stop(j) and isPending(j) then
          table.insert(es, 1, events[j])
          setPassthrough(j, true)
        end
      end
      return true, es
    end
  )

  return runtime.guard(setmetatable({ tap = tap }, meta))
end

-- Shortcut for knu.chord.new(...):start()
chord.bind = function (...)
  return chord.new(...):start()
end

return chord
