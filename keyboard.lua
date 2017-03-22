local keyboard = {}

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
    if method == prevMethod and layout == prevLayout and sourceID == prevSourceID then
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

-- Send a string as keyboard input to an application (default:
-- frontmost application)
--
-- Some applications cannot handle characters beyond U+FFFF sent via
-- hs.eventtap.keyStrokes(), so this function uses special methods for
-- such applications.
keyboard.send = function (str, application)
  application = application or hs.application.frontmostApplication()
  local appId = application:bundleID()

  if appId == "com.googlecode.iterm2" then
    hs.osascript.applescript(([[
      tell application "iTerm2"
        tell current session of current window
          write text "%s" newline NO
        end tell
      end tell
    ]]):format(str:gsub("([\"\\])", function (c) return "\\" .. c end)))
  elseif appId == "org.gnu.Emacs" then
    for _, cp in utf8.codes(str) do
      if cp >= 0x10000 then
        -- Use C-x 8 RET <codepoint> RET
        hs.eventtap.keyStrokes(("\x188\r%x\r"):format(cp))
      else
        hs.eventtap.keyStrokes(hs.utf8.codepointToUTF8(cp))
      end
    end
  else
    hs.eventtap.keyStrokes(str)
  end
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

-- Show a given string as input mode
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

-- Show the current input mode
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

return keyboard
