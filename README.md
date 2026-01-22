Knu.spoon for Hammerspoon
=========================

This is a Hammerspoon Spoon that contains useful modules written by Akinori Musha a.k.a. [@knu](https://github.com/knu).

Requirements
------------

- Hammerspoon 0.9.53 or later

Usage
-----

### Install

Put the following snippet in your `~/.hammerspoon/init.lua`:

```lua
if hs.fs.attributes("Spoons/Knu.spoon") == nil then
  hs.execute("mkdir -p Spoons; curl -L https://github.com/knu/Knu.Spoon/raw/release/Spoons/Knu.spoon.zip | tar xf - -C Spoons/")
end
```

Alternatively, you can use [SpoonInstall](https://www.hammerspoon.org/Spoons/SpoonInstall.html) like so:

```lua
if hs.fs.attributes("Spoons/SpoonInstall.spoon") == nil then
  hs.execute("mkdir -p Spoons; curl -L https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip | tar xf - -C Spoons/")
end

hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.Knu = {
  url = "https://github.com/knu/Knu.spoon",
  desc = "Knu.spoon repository",
  branch = "release",
}
spoon.SpoonInstall.use_syncinstall = true
spoon.SpoonInstall:andUse("Knu", { repo = "Knu" })
```

After that, you can load Knu.spoon.

```lua
knu = hs.loadSpoon("Knu")

-- Enable auto-restart when any of the *.lua files under ~/.hammerspoon/ is modified
knu.runtime.autorestart(true)
```

### Example: pseudo hotkeys

```lua
knu.photkey.bind({"fn"}, "l", function ()
    -- Wait a second to skip an inevitable key-up event
    hs.timer.doAfter(1.0, function () hs.application.launchOrFocus("ScreenSaverEngine") end)
end)
```

```lua
knu.photkey.bind({"leftshift", "rightshift"}, "l", function ()
    -- This is invoked with both shift keys down + L
    hs.eventtap.keyStrokes("LGTM!\n")
end)
```

```lua
knu.photkey.bind({"rightcmd", "shift"}, "q", function ()
    -- This is invoked with right command + shift (left or right) + Q
    hs.execute(("kill %d"):format(hs.application.frontmostApplication():pid()))
end)
```

### Example: emoji input and key chord

```lua
function inputEmoji()
  local window = hs.window.focusedWindow()
  knu.emoji.chooser(function (chars)
      window:focus()
      if chars then
        local appId = hs.application.frontmostApplication():bundleID()
        if appId == "com.twitter.TweetDeck" then
          -- TweetDeck does not restore focus on text field, so just copy and notify user
          hs.pasteboard.setContents(chars)
          hs.alert.show("Copied! " .. chars)
        else
          -- knu.keyboard.send uses an appropriate method for the frontmost application to send a text
          -- knu.keyboard.paste pastes a string to the frontmost application, which is specified as a fallback function here
          knu.keyboard.send(chars, knu.keyboard.paste)
        end
      end
  end):show()
end

-- Speed up the first invocation
knu.emoji.preload()

-- Function to guard a given object from GC
guard = knu.runtime.guard

--- z+x+c opens the emoji chooser to input an emoji to the frontmost window
guard(knu.chord.bind({}, {"z", "x", "c"}, inputEmoji))
```

### Example: application specific keymap

```lua
function withRepeat(fn)
  return fn, nil, fn
end

-- Define some bindings for specific applications
local keymapForQt = knu.keymap.new(
    hs.hotkey.new({"ctrl"}, "h", withRepeat(function ()
          hs.eventtap.keyStroke({}, "delete", 0)
    end)),
    hs.hotkey.new({"ctrl"}, "k", withRepeat(function ()
          hs.eventtap.keyStroke({"ctrl", "shift"}, "e", 0)
          hs.eventtap.keyStroke({"cmd"}, "x", 0)
    end)),
    hs.hotkey.new({"ctrl"}, "n", withRepeat(function ()
          hs.eventtap.keyStroke({}, "down", 0)
    end)),
    hs.hotkey.new({"ctrl"}, "p", withRepeat(function ()
          hs.eventtap.keyStroke({}, "up", 0)
    end))
)
knu.keymap.register("org.keepassx.keepassxc", keymapForQt)
knu.keymap.register("jp.naver.line.mac", keymapForQt)
```

### Example: Keyboard layout watcher and helper functions

```lua
-- F18 toggles IM between Japanese <-> Roman
do
  local eisu = hs.hotkey.new({}, "f18", function ()
      hs.eventtap.keyStroke({}, "eisu", 0)
  end)
  local kana = hs.hotkey.new({}, "f18", function ()
      hs.eventtap.keyStroke({}, "kana", 0)
  end)

  knu.keyboard.onChange(function ()
      knu.keyboard.showCurrentInputMode()
      if knu.keyboard.isJapaneseMode() then
        kana:disable()
        eisu:enable()
      else
        kana:enable()
        eisu:disable()
      end
  end)
end
```

### Example: Shell escape

```lua
-- knu.utils.shelljoin() is a method to build a command line from a list of arguments
-- with shell meta characters properly escaped

local extra_options = { "--exclude", ".*" }

hs.execute(knu.utils.shelljoin(
    "rsync",
    "-a",
    extra_options, -- no need for table.unpack()
    src,
    dest
))
```

### Example: USB watcher

```lua
-- Switch the Karabiner-Elements profile when an external keyboard is attached or detached
knu.usb.onChange(function (device)
    local name = device.productName
    if name and (
        name:find("PS2") or -- PS/2-USB converter
          (not device.vendorName:find("^Apple") and name:find("Keyboard"))
      ) then
      if device.eventType == "added" then
        knu.keyboard.switchKarabinerProfile("External")
      else
        knu.keyboard.switchKarabinerProfile("Default")
      end
    end
end)
```

### Example: Enhanced application watcher

```lua
-- Enable hotkey for launching an app only while not running
function launchByHotkeyWhileNotRunning(mods, key, bundleID)
  local hotkey = hs.hotkey.new(mods, key, function ()
      hs.application.open(bundleID)
  end)

  -- Writing an application watcher for a specific application made
  -- easy by knu.application.onChange()
  knu.application.onChange(bundleID, function (name, type, app)
      if type == hs.application.watcher.launched then
        hotkey:disable()
      elseif type == hs.application.watcher.terminated then
        hotkey:enable()
      end
  end, true)
end

-- Suppose you have set up system-wide hotkeys for activating apps in
-- their preferences, but also want to launch them if they are not
-- running.
launchByHotkeyWhileNotRunning({"alt", "ctrl"}, "/", "com.kapeli.dashdoc")
launchByHotkeyWhileNotRunning({"alt", "ctrl"}, "t", "com.googlecode.iterm2")
```

### Example: Enhanced application launcher function

```lua
-- Refresh calendars every 15 minutes
hs.timer.doEvery(15 * 60, function ()
    knu.application.launchInBackground("com.apple.iCal", function (app)
        if app ~= nil then
          app:selectMenuItem({"View", "Refresh Calendars"})
          -- Depending on your language settings...
          -- app:selectMenuItem({"表示", "カレンダーを更新"})
        end
    end, 10, true)
end)
```

### Example: Enable the hold-to-scroll mode with the middle button

```lua
-- Scroll by moving the mouse while holding the middle button
knu.mouse.holdToScrollButton():enable()
```

### Example: URL unshortener

```lua
url, error = knu.http.unshortenUrl(originalURL)
if error ~= nil then
  logger.e("Error in unshortening a URL " .. originalURL .. ": " .. error)
end

-- Use url
```

Modules
-------

- application.lua: application change watcher and advanced application launcher functions

- chord.lua: key chord implementation (`SimultaneousKeyPress`
  in [Karabiner](https://pqrs.org/osx/karabiner/))

- emoji.lua: emoji database and chooser

- http.lua: functions to manipulate URLs

- keyboard.lua: functions to handle input source switching

- keymap.lua: application/window based keymap switching

- mouse.lua: functions to handle mouse events

- photkey.lua: pseudo hotkeys with extended modifiers support

- runtime.lua: functions like restart() and guard() (from GC)

- usb.lua: wrapper for hs.usb.watcher

- utils.lua: common utility functions

License
-------

Copyright (c) 2017-2026 [Akinori MUSHA](https://akinori.org/)

Licensed under the 2-clause BSD license.  See `LICENSE` for details.

Visit [GitHub Repository](https://github.com/knu/Knu.spoon) for the latest information.
