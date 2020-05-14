local keyboard = {}

local utils = require((...):gsub("[^.]+$", "utils"))

-- Some of the known Japanese input source IDs:
--   com.apple.inputmethod.Kotoeri.Japanese
--   com.apple.inputmethod.Kotoeri.Japanese.FullWidthRoman
--   com.apple.inputmethod.Kotoeri.Japanese.HalfWidthKana
--   com.apple.inputmethod.Kotoeri.Japanese.Katakana
--   com.apple.inputmethod.Kotoeri.Roman
--   com.apple.keylayout.UnicodeHexInput
--   com.google.inputmethod.Japanese.FullWidthRoman
--   com.google.inputmethod.Japanese.HalfWidthKana
--   com.google.inputmethod.Japanese.Katakana
--   com.google.inputmethod.Japanese.Roman
--   com.google.inputmethod.Japanese.base
--   com.justsystems.inputmethod.atok29.Japanese
--   com.justsystems.inputmethod.atok29.Japanese.FullWidthEisu
--   com.justsystems.inputmethod.atok29.Japanese.FullWidthEisuKotei
--   com.justsystems.inputmethod.atok29.Japanese.FullWidthRoman
--   com.justsystems.inputmethod.atok29.Japanese.HalfWidthEiji
--   com.justsystems.inputmethod.atok29.Japanese.HalfWidthEisu
--   com.justsystems.inputmethod.atok29.Japanese.HalfWidthInput
--   com.justsystems.inputmethod.atok29.Japanese.HalfWidthKana
--   com.justsystems.inputmethod.atok29.Japanese.HalfWidthKanaKotei
--   com.justsystems.inputmethod.atok29.Japanese.HiraganaKotei
--   com.justsystems.inputmethod.atok29.Japanese.Katakana
--   com.justsystems.inputmethod.atok29.Japanese.KatakanaKotei
--   com.justsystems.inputmethod.atok29.Roman
--   jp.sourceforge.inputmethod.aquaskk
--   jp.sourceforge.inputmethod.aquaskk.Ascii
--   jp.sourceforge.inputmethod.aquaskk.FullWidthRoman
--   jp.sourceforge.inputmethod.aquaskk.HalfWidthKana
--   jp.sourceforge.inputmethod.aquaskk.Hiragana
--   jp.sourceforge.inputmethod.aquaskk.Katakana

-- Check if the keyboard is currently in Japanese mode
keyboard.isJapaneseMode = function (sid)
  sid = sid or hs.keycodes.currentSourceID()

  return sid:find("%.Roman$") == nil and
    (sid:find("%.Japanese") or sid:find("%.aquaskk%.[^A]")) ~= nil
end

-- Check if the keyboard is currently in Unicode Hex Input mode
keyboard.isUnicodeHexInputMode = function (sid)
  sid = sid or hs.keycodes.currentSourceID()

  return sid == "com.apple.keylayout.UnicodeHexInput"
end

local fnsOnChange = {}
local prevMethod, prevLayout, prevSourceID

hs.keycodes.inputSourceChanged(function ()
    local method, layout, sourceID = hs.keycodes.currentMethod(), hs.keycodes.currentLayout(), hs.keycodes.currentSourceID()
    if sourceID == prevSourceID and method == prevMethod and layout == prevLayout then
      return
    end
    for _, fn in ipairs(fnsOnChange) do
      fn()
    end
    prevMethod, prevLayout, prevSourceID = method, layout, sourceID
end)

-- Add a input source change handler
keyboard.onChange = function (fn)
  table.insert(fnsOnChange, fn)
  fn()
  return fn
end

-- Remove a input source change handler
keyboard.offChange = function (fn)
  for i = #fnsOnChange, 1, -1 do
    if fnsOnChange[i] == fn then
      table.remove(fnsOnChange, i)
      return
    end
  end
end

-- Switch the keyboard to the specified method and layout
keyboard.switch = function (method, layout)
  if method then
    hs.keycodes.setMethod(method)
  end
  if layout then
    hs.keycodes.setLayout(layout)
  end
end

-- A table mapping BundleID to function to paste a string to the
-- application
keyboard.pasteFunctions = {
}

local savePB = function (delay)
  local data = hs.pasteboard.readAllData()
  return function ()
    hs.timer.doAfter(delay or 0.5, function ()
        hs.pasteboard.writeAllData(data)
    end)
  end
end

local function defaultPaste(str)
  local restorePB = savePB()
  hs.pasteboard.setContents(str)
  hs.eventtap.keyStroke({"cmd"}, "v")
  restorePB()
end

setmetatable(keyboard.pasteFunctions, {
    __index = function (_, key)
      return defaultPaste
    end
})

-- Paste a string to the frontmost application, saving the original
-- content of pasteboard if possible
--
-- This function should not be called more than one time from a
-- function, because it posts an event.  Use hs.timer.doAfter() if you
-- need to.
keyboard.paste = function(str)
  keyboard.pasteFunctions[hs.application.frontmostApplication():bundleID()](str)
end

local function pasteOrSend(str)
  if str:find("[\xf0-\xfd]") then
    keyboard.paste(str)
  else
    hs.eventtap.keyStrokes(str)
  end
end

-- A table mapping BundleID to function to paste a string to the
-- application, defaulted to hs.eventtap.keyStrokes
keyboard.sendFunctions = {
  ["com.apple.Terminal"] = pasteOrSend,

  ["com.googlecode.iterm2"] = function (str)
    hs.osascript.applescript(([[
      tell application "iTerm2"
        tell current session of current window
          write text "%s" newline NO
        end tell
      end tell
    ]]):format(str:gsub("([\"\\])", function (c) return "\\" .. c end)))
  end,

  ["org.gnu.Emacs"] = function (str)
    for _, cp in utf8.codes(str) do
      if cp >= 0x10000 then
        -- Use C-x 8 RET <codepoint> RET
        hs.eventtap.keyStrokes(("\x188\r%x\r"):format(cp))
      else
        hs.eventtap.keyStrokes(hs.utf8.codepointToUTF8(cp))
      end
    end
  end,
}

-- Send a string as keyboard input to the frontmost application
--
-- It uses special methods registered in sendFunctions, and uses
-- hs.eventtap.keyStroke() for other applications.
--
-- An optional parameter fallback, defaulted to
-- hs.eventtap.keyStrokes, specifies the function to use when
-- sendFunction does not have a method for the application.
--
-- Attributed text fields do not accept emoji sent via
-- hs.eventtap.keyStrokes(), so try paste() instead.
keyboard.send = function (str, fallback)
  local bundleID = hs.application.frontmostApplication():bundleID()
  local fn = keyboard.sendFunctions[bundleID] or fallback or hs.eventtap.keyStrokes
  fn(str)
end

local uuid = nil
local shown = nil

keyboard.alertStyle = {
  textSize = 24,
  strokeWidth = 0,
  strokeColor = { alpha = 0.25 },
  fillColor = { alpha = 0.25 },
  radius = 9
}

-- Shows a given string as input mode
keyboard.showInputMode = function (s, duration)
  duration = duration or 0.5
  if s == shown then
    return
  end
  if uuid then
    hs.alert.closeSpecific(uuid)
  end
  uuid = hs.alert.show(s, keyboard.alertStyle, hs.screen.mainScreen(), duration)
  shown = s
end

-- Shows the current input mode
keyboard.showCurrentInputMode = function (sid, duration)
  if type(sid) == "number" then
    sid, duration = nil, sid
  end
  sid = sid or hs.keycodes.currentSourceID()
  if keyboard.isJapaneseMode(sid) then
    keyboard.showInputMode("あ⃣", duration)
  elseif keyboard.isUnicodeHexInputMode(sid) then
    keyboard.showInputMode("U⃣", duration)
  else
    keyboard.showInputMode("A⃣", duration)
  end
end

local modState = {
  shift = {false, false},
  ctrl = {false, false},
  alt = {false, false},
  cmd = {false, false},
  fn = false
}

local modTracer = hs.eventtap.new({hs.eventtap.event.types.flagsChanged},
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

-- Gets the modifier state object (table)
--
-- This always returns the same object.
keyboard.getModifierState = function ()
  modTracer:start()
  return modState
end

keyboard.switchKarabinerProfile = function (name)
  hs.execute(utils.shelljoin(
      "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli",
      "--select-profile",
      name
  ))
end

return keyboard
