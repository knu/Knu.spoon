hs-knu modules
==============

Usage
-----

```
git clone https://github.com/knu/hs-knu.git ~/.hammerspoon/knu
```

```lua
-- Load all modules
knu = require("knu.all")

-- ...Or just some of them
knu = {
  chord = require("knu.chord"),
  usb = require("knu.usb"),
}
```

Modules
-------

- chord.lua: key chord implementation (`SimultaneousKeyPress`
  in [Karabiner](https://pqrs.org/osx/karabiner/))

- keyboard.lua: functions to handle input source switching

- keymap.lua: application/window based keymap switching

- usb.lua: wrapper for hs.usb.watcher

- utils.lua: common utility functions

License
-------

Copyright (c) 2017 [Akinori MUSHA](https://akinori.org/)

Licensed under the 2-clause BSD license.  See `LICENSE` for details.
