local application = {}

local registry = {}

local watcher = hs.application.watcher

application.changeWatcher = hs.application.watcher.new(function (name, type, app)
    if type == watcher.terminated then
      for bundleID, reg in pairs(registry) do
        if reg.app and not reg.app:isRunning() then
          reg.app = nil

          for _, fn in ipairs(reg.fns) do
            fn(name, type, app)
          end

          return
        end        
      end
    else
      local reg = registry[app:bundleID()]
      if not reg then
        return
      end
      reg.app = app

      for _, fn in ipairs(reg.fns) do
        fn(name, type, app)
      end
    end
end):start()

-- Add a watcher function for the application with a given bundle ID
--
-- This framework is handlier than directly using
-- `hs.application.watcher` if you deal with a `terminated` event,
-- because it automatically detects which application in the registry
-- has been terminated and notifies registered functions of its
-- termination.
application.onChange = function (bundleID, fn, terminatedOnStart)
  local reg = registry[bundleID]
  if not reg then
    reg = {
      fns = {}
    }
    registry[bundleID] = reg
  end

  table.insert(reg.fns, fn)

  local app = hs.application(bundleID)
  if app then
    reg.app = app
    local name = app:name()
    fn(name, watcher.launching, app)
    fn(name, watcher.launched, app)
  elseif terminatedOnStart then
    fn(nil, watcher.terminated, nil)
  end
end

-- Remove a watcher function for the application with a given bundle ID
application.offChange = function (bundleID, fn)
  local reg = registry[bundleID]
  if not reg then
    return
  end
  for i = #reg.fns, 1, -1 do
    if reg.fns[i] == fn then
      table.remove(reg.fns, i)
      return
    end
  end
end

return application
