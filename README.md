hs-knu modules
==============

Usage
-----

### Install

```
git clone https://github.com/knu/hs-knu.git ~/.hammerspoon/knu
```

```lua
knu = require("knu")
-- Function to guard a given object from GC
guard = knu.runtime.guard

-- Enable auto-restart when any of the *.lua files under ~/.hammerspoon/ is modified
knu.runtime.autorestart(true)
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

### Example: USB watcher and shell escaping

```lua
-- Switch between Karabiner-Elements profiles by keyboard

function switchKarabinerElementsProfile(name)
  hs.execute(knu.utils.shelljoin(
      "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli",
      "--select-profile",
      name
  ))
end

knu.usb.onChange(function (device)
    local name = device.productName
    if name and (
        name:find("PS2") or  -- I still use PS/2 Kinesis Keyboard via USB adapter...
          (not device.vendorName:find("^Apple") and name:find("Keyboard"))
      ) then
      if device.eventType == "added" then
        switchKarabinerElementsProfile("External")
      else
        switchKarabinerElementsProfile("Default")
      end
    end
end)
```

Modules
-------

- chord.lua: key chord implementation (`SimultaneousKeyPress`
  in [Karabiner](https://pqrs.org/osx/karabiner/))

- emoji.lua: emoji database and chooser

- keyboard.lua: functions to handle input source switching

- keymap.lua: application/window based keymap switching

- runtime.lua: functions like restart() and guard() (from GC)

- usb.lua: wrapper for hs.usb.watcher

- utils.lua: common utility functions

License
-------

Copyright (c) 2017 [Akinori MUSHA](https://akinori.org/)

Licensed under the 2-clause BSD license.  See `LICENSE` for details.
