local runtime = {}

-- Restart Hammerspoon (calling hs.reload())
runtime.restart = function (message)
  hs.alert.show(message or "Restarting Hammerspoon...")
  -- Give some time for alert to show up before reloading
  hs.timer.doAfter(0.1, hs.reload)
end

local globals = {}

-- Guard an object from garbage collection
runtime.guard = function (object)
  local caller = debug.getinfo(2)
  table.insert(globals, {
      object = object,
      file = caller.source:match("^@?(.+)"),
      line = caller.currentline,
  })
  return object
end

runtime.globals = function ()
  return globals
end

return runtime
