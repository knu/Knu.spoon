local runtime = {}

-- Restarts Hammerspoon (calling hs.reload())
runtime.restart = function (message)
  hs.alert.show(message or "Restarting Hammerspoon...")
  -- Give some time for alert to show up before reloading
  hs.timer.doAfter(0.1, hs.reload)
end

local globals = {}

-- Guards an object from garbage collection
runtime.guard = function (object)
  local caller = debug.getinfo(2)
  table.insert(globals, {
      object = object,
      file = caller.source:match("^@?(.+)"),
      line = caller.currentline,
  })
  return object
end

-- Unguards a guarded object
runtime.unguard = function (object)
  for i, tuple in ipairs(globals) do
    if tuple.object == object then
      table.remove(globals, i)
      break
    end
  end
  return object
end

runtime.globals = function ()
  return globals
end

local restarter

-- Enables or disables auto-restart when Lua files under ~/.hammerspoon/ change,
-- excluding dotfiles and files inside dot-directories.
runtime.autorestart = function (flag)
  if flag then
    if restarter == nil then
      local root = hs.fs.pathToAbsolute(".")
      restarter = hs.pathwatcher.new(root,
        function (files)
          for _, file in ipairs(files) do
            local path = file:sub(#root + 1)
            if path:match("%.lua$") and not path:find("/%.") then
              knu.runtime.restart()
              return
            end
          end
        end
      )
    end
    restarter:start()
  else
    if restarter then
      restarter:stop()
    end
  end
end

return runtime
