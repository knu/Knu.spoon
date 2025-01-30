local utils = {}

local modToBit = {
  ["ctrl"] = 1,
  ["control"] = 1,
  ["⌃"] = 1,
  ["shift"] = 2,
  ["⇧"] = 2,
  ["cmd"] = 4,
  ["command"] = 4,
  ["⌘"] = 4,
  ["alt"] = 8,
  ["option"] = 8,
  ["⌥"] = 8,
  ["fn"] = 16,
}

-- Converts a table of modifiers to an integer
utils.modifierFlags = function (mods)
  local flags = 0
  for key, value in pairs(mods) do
    if value == true then
      -- {["cmd"] = true, ["shift"] = true}
      flags = flags | modToBit[key]
    elseif type(key) == "number" then
      -- {"cmd", "shift"}
      flags = flags | modToBit[value]
    end
  end
  return flags
end

local keyTopMap = {
  delete = "⌫",
  down = "↓",
  escape = "⎋",
  forwarddelete = "⌦",
  help = "⍰",
  home = "↖",
  left = "←",
  pad0 = "0︎⃣",
  pad1 = "1︎⃣",
  pad2 = "2︎⃣",
  pad3 = "3︎⃣",
  pad4 = "4︎⃣",
  pad5 = "5︎⃣",
  pad6 = "6︎⃣",
  pad7 = "7︎⃣",
  pad8 = "8︎⃣",
  pad9 = "9︎⃣",
  padclear = "⌧",
  padenter = "⌅",
  pagedown = "⇟",
  pageup = "⇞",
  right = "→",
  tab = "⇥",
  up = "↑",
}
keyTopMap["end"] = "↘"
keyTopMap["return"] = "↩"
keyTopMap["pad*"] = "*︎⃣"
keyTopMap["pad+"] = "+︎⃣"
keyTopMap["pad/"] = "/︎⃣"
keyTopMap["pad-"] = "-︎⃣"
keyTopMap["pad="] = "=︎⃣"

-- Returns a pretty representation of a key
utils.prettyKey = function (mods, key)
  local flags = utils.modifierFlags(mods)
  local fn, cmd, alt, ctrl, shift, k
  if flags & modToBit["fn"] ~= 0 then
    fn = "Fn-"
  end
  if flags & modToBit["cmd"] ~= 0 then
    cmd = "⌘"
  end
  if flags & modToBit["alt"] ~= 0 then
    alt = "⌥"
  end
  if flags & modToBit["ctrl"] ~= 0 then
    ctrl = "⌃"
  end
  if flags & modToBit["shift"] ~= 0 then
    shift = "⇧"
  end
  if type(key) == "string" then
    k = key
  else
    k = hs.keycodes.map[key]
  end
  local function upcase(a, b)
    return a .. b:upper()
  end
  local keytop = keyTopMap[k] or k:gsub("^(%l)", string.upper)
  return table.concat({fn or "", cmd or "", alt or "", ctrl or "", shift or "", keytop})
end

-- Escapes a string for the shell
utils.shellescape = function (s)
  if s == "" then
    return "''"
  end

  return s:gsub("([^A-Za-z0-9_%-.,:/@\n])", "\\%1"):gsub("(\n)", "'\n'")
end

-- Joins a table of arguments into a command line string, escaping
-- each element for the shell
utils.shelljoin = function (...)
  local args = {...}
  local s = ""

  for _, arg in ipairs(args) do
    if s ~= "" then
      s = s .. " "
    end
    if type(arg) == "table" then
      s = s .. utils.shelljoin(table.unpack(arg))
    else
      s = s .. utils.shellescape(tostring(arg))
    end
  end

  return s
end

-- Returns keys of a table
utils.keys = function (table)
  local keys = {}
  for key in pairs(table) do
    keys[#keys + 1] = key
  end
  return keys
end

-- Copies all key-value pairs from one or more source tables to a target table
utils.assign = function (target, ...)
  for _, source in ipairs{...} do
    for key, value in pairs(source) do
      target[key] = value
    end
  end
  return target
end

utils.string = {
  contains = function (str, substring)
    return str:find(substring, 1, true) ~= nil
  end,

  startsWith = function (str, prefix)
    return #prefix <= #str and str:sub(1, #prefix) == prefix
  end,

  endsWith = function (str, suffix)
    return #suffix <= #str and str:sub(-#suffix) == suffix
  end,
}

-- Wraps a function to delay its execution until after a specified time has passed since the last call
--
-- Parameters:
--   - func - The function to debounce.
--   - wait - The delay time in seconds.
-- Returns:
--   - A new debounced function.
utils.debounce = function (func, wait)
  local timer = nil
  return function(...)
    local args = {...}
    if timer then
      timer:stop()
    end
    timer = hs.timer.doAfter(wait, function() func(table.unpack(args)) end)
  end
end

-- Wraps a function to ensure it is called at most once per interval, with an optional trailing execution
--
-- Parameters:
--   - func - The function to throttle.
--   - interval - The minimum time in seconds between calls.
--   - trailing - If true, ensures the last call is executed after the interval.
-- Returns:
--   - A new throttled function.
utils.throttle = function (func, interval, trailing)
  local lastCall = 0
  local scheduled = false

  return function(...)
    local now = hs.timer.absoluteTime() / 1e9
    local args = {...}

    if now - lastCall >= interval then
      lastCall = now
      func(table.unpack(args))
    elseif trailing and not scheduled then
      scheduled = true
      hs.timer.doAfter(interval - (now - lastCall), function()
          lastCall = hs.timer.absoluteTime() / 1e9
          scheduled = false
          func(table.unpack(args))
      end)
    end
  end
end

return utils
