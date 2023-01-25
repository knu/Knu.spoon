local application = {}

local knu = hs.loadSpoon("Knu")
local utils = knu.utils

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

-- Adds a watcher function for the application with a given bundle ID
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

-- Removes a watcher function for the application with a given bundle
-- ID
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

local launchAppInBackground = function (bundlePathOrID)
  local bundleID
  local bundlePath
  local info = hs.application.infoForBundleID(bundlePathOrID)
  if info then
    bundleID = info.CFBundleIdentifier
  else
    info = hs.application.infoForBundlePath(bundlePathOrID)
    if not info then
      return nil
    end
    bundlePath = bundlePathOrID
    bundleID = info.CFBundleIdentifier
  end

  local app = hs.application.get(bundleID)
  if app then
    return app
  end

  if bundlePath then
    hs.execute(utils.shelljoin("/usr/bin/open", "-g", bundlePath))
  else
    hs.execute(utils.shelljoin("/usr/bin/open", "-gb", bundleID))
  end

  return bundleID
end

-- Launches an application in background if it's not already running and invokes a callback function
--
-- Parameters:
--
--   - bundlePathOrID - the bundle path or bundle ID of the application to launch
--   - fn - a callback function which is called with the application object as the only argument, or `nil` if the application could not be found or launched
--   - wait - (optional) the maximum number of seconds to wait for the app to be launched, if not already running; if omitted, defaults to 0; if the app takes longer than this to launch, this function will return `nil`, but the app will still launch
--   - waitForFirstWindow - (optional) if `true`, additionally wait until the app has spawned its first window (which usually takes a bit longer)
application.launchInBackground = function (bundlePathOrID, fn, wait, waitForFirstWindow)
  local deadline = hs.timer.secondsSinceEpoch() + wait
  local app = launchAppInBackground(bundlePathOrID)

  if type(app) ~= "string" then
    fn(app)
    return
  end

  local bundleID = app
  local timer
  timer = hs.timer.doEvery(
    1,
    function ()
      if hs.timer.secondsSinceEpoch() > deadline then
        timer:stop()
        fn(nil)
      else
        local app = hs.application.get(bundleID)
        if app and (not waitForFirstWindow or app:mainWindow()) then
          timer:stop()
          fn(app)
        end
      end
    end
  )
end

-- Opens an application in background and waits for it to launch if it's not already running, returning the application object
--
-- Parameters:
--
--   - bundlePathOrID - the bundle path or bundle ID of the application to launch
--   - wait - (optional) the maximum number of seconds to wait for the app to be launched, if not already running; if omitted, defaults to 0; if the app takes longer than this to launch, this function will return `nil`, but the app will still launch
--   - waitForFirstWindow - (optional) if `true`, additionally wait until the app has spawned its first window (which usually takes a bit longer)
application.openInBackground = function (bundlePathOrID, wait, waitForFirstWindow)
  local deadline = hs.timer.secondsSinceEpoch() + wait
  local app = launchAppInBackground(bundlePathOrID)

  if type(app) ~= "string" then
    return app
  end

  local bundleID = app
  repeat
    local app = hs.application.get(bundleID)
    if app and (not waitForFirstWindow or app:mainWindow()) then
      return app
    end
    hs.timer.usleep(100000)
  until hs.timer.secondsSinceEpoch() > deadline

  return nil
end

return application
