local usb = {}

local fnsOnChange = {}

usb.changeWatcher = hs.usb.watcher.new(function (device)
    for _, fn in ipairs(fnsOnChange) do
      fn(device)
    end
end):start()

-- Add a USB watcher function
--
-- A given function is immediately called for each device that is
-- currently attached.
usb.onChange = function (fn)
  table.insert(fnsOnChange, fn)
  for _, device in ipairs(hs.usb.attachedDevices()) do
    device.eventType = "added"
    fn(device)
  end
end

-- Remove a USB watcher function
usb.offChange = function (fn)
  for i = #fnsOnChange, 1, -1 do
    if fnsOnChange[i] == fn then
      table.remove(fnsOnChange, i)
      return
    end
  end
end

return usb
