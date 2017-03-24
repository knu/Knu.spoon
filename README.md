hs-knu modules
==============

Usage
-----

```
git clone https://github.com/knu/hs-knu.git ~/.hammerspoon/knu
```

```lua
knu = require("knu")
-- Function to guard a given object from GC
guard = knu.runtime.guard

-- Enable auto-restart when any of the *.lua files under ~/.hammerspoon/ is modified
knu.runtime.autorestart(true)

-- Emoji input
function inputEmoji()
  local window = hs.window.focusedWindow()
  knu.emoji.chooser(function (chars)
      window:focus()
      if chars then
        local appId = hs.application.frontmostApplication():bundleID()
        if appId == "com.googlecode.iterm2" or appId == "org.gnu.Emacs" then
          -- Enhanced version of hs.eventtap.keyStrokes() that supports emoji on iTerm2 and Emacs.app
          knu.keyboard.send(chars)
        elseif appId == "com.twitter.TweetDeck" then
          -- Loses focus on text field, so just copy and notify
          hs.pasteboard.setContents(chars)
          hs.alert.show("Copied! " .. chars)
        else
          knu.keyboard.paste(chars)
        end
      end
  end):show()
end

-- Speed up the first invocation
knu.emoji.preload()

--- z+x+c opens the emoji chooser to input an emoji to the frontmost window
guard(knu.chord.bind({}, {"z", "x", "c"}, inputEmoji))


function withRepeat(fn)
  return fn, nil, fn
end

-- Define some bindings specific to KeePassXC
knu.keymap.register("org.keepassx.keepassxc", knu.keymap.new(
    -- I'm not sure why Qt on Mac does not respond to those, but anyway.
    hs.hotkey.new({"ctrl"}, "h", withRepeat(function ()
          hs.eventtap.keyStroke({}, "delete", 0)
    end)),
    hs.hotkey.new({"ctrl"}, "k", withRepeat(function ()
          hs.eventtap.keyStroke({"ctrl", "shift"}, "e", 0)
          hs.eventtap.keyStroke({"cmd"}, "x", 0)
    end)),
    hs.hotkey.new({"ctrl"}, "p", withRepeat(function ()
          hs.eventtap.keyStroke({}, "up", 0)
    end))
))
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
