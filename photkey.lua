local photkey = {}

local keyDown = hs.eventtap.event.types.keyDown
local keyUp = hs.eventtap.event.types.keyUp

-- Only keyboard event types carry a keycode and modifier flags that
-- this module dispatches on, so only these are supported.
local supportedTypes = {
  [keyDown] = true,
  [keyUp] = true,
}

local knu = hs.loadSpoon("Knu")
local runtime = knu.runtime
local keyboard = knu.keyboard

-- A single eventtap is shared among all photkeys that listen for the
-- same event type.  The registry maps an event type to a shared tap
-- and a table of entries keyed by keycode:
--
--   sharedTaps[type] = {
--     tap = <hs.eventtap>,
--     count = <number of enabled entries>,
--     byCode = { [code] = { entry, ... } },
--   }
--
-- where each entry is { mods = ..., modLr = ..., modState = ..., fn = ... }.
local sharedTaps = {}

-- Checks if a given entry matches the modifier flags of an event.
local matches = function (entry, flags)
  if not flags:containExactly(entry.mods) then
    return false
  end
  local modState = entry.modState
  for mod, lr in pairs(entry.modLr) do
    local modStateLr = 0
    if modState[mod][1] then
      modStateLr = modStateLr | 1
    end
    if modState[mod][2] then
      modStateLr = modStateLr | 2
    end
    if modStateLr ~= lr then
      return false
    end
  end
  return true
end

local makeHandler = function (shared)
  return function (e)
    local entries = shared.byCode[e:getKeyCode()]
    if entries == nil then
      return
    end
    local flags = e:getFlags()
    local matched = false
    -- Iterate backwards so a handler may disable itself or later
    -- entries for this key without disrupting the traversal.
    for i = #entries, 1, -1 do
      local entry = entries[i]
      if matches(entry, flags) then
        entry.fn(e)
        matched = true
      end
    end
    if matched then
      return true
    end
  end
end

local getSharedTap = function (type)
  local shared = sharedTaps[type]
  if shared == nil then
    shared = { count = 0, byCode = {} }
    shared.tap = hs.eventtap.new({ type }, makeHandler(shared))
    sharedTaps[type] = shared
  end
  return shared
end

local register = function (self)
  for _, type in ipairs(self.types) do
    local shared = getSharedTap(type)
    local entries = shared.byCode[self.code]
    if entries == nil then
      entries = {}
      shared.byCode[self.code] = entries
    end
    local found = false
    for _, entry in ipairs(entries) do
      if entry == self.entry then
        found = true
        break
      end
    end
    if not found then
      entries[#entries+1] = self.entry
      shared.count = shared.count + 1
      shared.tap:start()
    end
  end
  return self
end

local unregister = function (self)
  for _, type in ipairs(self.types) do
    local shared = sharedTaps[type]
    if shared then
      local entries = shared.byCode[self.code]
      if entries then
        for i = #entries, 1, -1 do
          if entries[i] == self.entry then
            table.remove(entries, i)
            shared.count = shared.count - 1
            if shared.count == 0 then
              shared.tap:stop()
            end
          end
        end
        if #entries == 0 then
          shared.byCode[self.code] = nil
        end
      end
    end
  end
  return self
end

photkey.methods = {
  start = function (self)
    return register(self)
  end,

  stop = function (self)
    return unregister(self)
  end,

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

local meta = { __index = photkey.methods }

-- Creates a pseudo hotkey
--
-- A pseudo hotkey is implemented by using eventtap, allowing for
-- specifying pseudo modifiers listed below:
--
-- * leftshift, rightshift, leftctrl, rightctrl, leftalt, rightalt,
--   leftcmd, rightcmd and fn
--
-- The handler function is called with a key event.
--
-- The types paramter specifies the event types to capture, defaulted
-- to { hs.eventtap.event.types.keyDown }.  Only keyDown and keyUp are
-- supported; any other type raises an error.
--
-- All photkeys that listen for the same event type share a single
-- eventtap, which is started only while at least one photkey for that
-- type is enabled.
photkey.new = function (pmods, key, fn, types)
  types = types or { keyDown }
  for _, type in ipairs(types) do
    if not supportedTypes[type] then
      error("unsupported event type: " .. tostring(type))
    end
  end
  local modState = keyboard.getModifierState()

  local mods = {}
  local modLr = {}

  for _, pmod in ipairs(pmods) do
    local mod = pmod:match("left(.+)")
    if mod then
      modLr[mod] = (modLr[mod] or 0) | 1
    else
      mod = pmod:match("right(.+)")
      if mod then
        modLr[mod] = (modLr[mod] or 0) | 2
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

  local entry = {
    mods = mods,
    modLr = modLr,
    modState = modState,
    fn = fn,
  }

  return runtime.guard(setmetatable({
        types = types,
        code = code,
        entry = entry,
  }, meta))
end

-- Shortcut for knu.photkey.new(...):start()
photkey.bind = function (...)
  return photkey.new(...):start()
end

return photkey
