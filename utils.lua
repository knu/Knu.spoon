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

-- Runs a shell command, optionally loading the users shell environment first, and returns stdout as a string, followed by the same result codes as `os.execute` would return.
--
-- Parameters:
--   - command  - The command to run, either as a string or a table of arguments.
--   - user_env - If true, loads the user's login shell environment before running the command.  If a table, passes the key-value pairs as environment variables to the command.
-- Returns:
--   - stdout    - The standard output of the command as a string.
--   - status    - The status of the command execution (true if successful, false otherwise).
--   - exit_type - The type of exit (e.g., "exit", "signal").
--   - rc        - The return code of the command.
utils.execute = function (command, user_env)
  local commandline
  if type(command) == "table" then
    commandline = utils.shelljoin(command)
  else
    commandline = command
  end
  if type(user_env) == "table" then
    local env = {}
    for key, value in pairs(user_env) do
      if value ~= os.getenv(key) then
        env[#env + 1] = key .. "=" .. value
      end
    end
    commandline = utils.shelljoin("export", env) .. ";" .. commandline
  elseif user_env then
    commandline = utils.shelljoin(os.getenv("SHELL"), "-lic", commandline)
  end
  local f = io.popen(commandline, 'r')
  local s = f:read('*a')
  local status, exit_type, rc = f:close()
  return s, status, exit_type, rc
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

-- Provides additional string functions
--
-- To use them as methods, run `knu.utils.assign(string, knu.utils.string)`.
utils.string = {
  -- Tests if a string contains a substring
  contains = function (str, substring)
    return str:find(substring, 1, true) ~= nil
  end,

  -- Tests if a string starts with a prefix
  startsWith = function (str, prefix)
    return #prefix <= #str and str:sub(1, #prefix) == prefix
  end,

  -- Tests if a string ends with a suffix
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

-- Returns a JSON representation of a value
--
-- Unlike `hs.json.encode`, this function can encode a scalar value
-- (string, number, boolean) or nil without wrapping it in an array.
--
-- Parameters:
--   - value - The value to encode.  Can be nil, a boolean, a number, a string, or a table.
-- Returns:
--   - A JSON string representation of the value.
utils.toJson = function (value)
  if value == nil then
    return "null"
  elseif type(value) == "table" then
    return hs.json.encode(value)
  else
    return (hs.json.encode{value}):sub(2, -2)
  end
end

return utils
