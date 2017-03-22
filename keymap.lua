local keymap = {}

-- Create a keymap
--
-- Keymap is a collection of hotkeys and eventtaps that can be enabled
-- or disabled all at once.
keymap.new = function (...)
  return setmetatable({...}, { __index = keymap })
end

function keymap:add(...)
  for _, binding in ipairs({...}) do
    table.insert(self, binding)
  end
end

function keymap:enable()
  for _, binding in ipairs(self) do
    (binding.enable or binding.start)(binding)
  end
end

function keymap:disable()
  for _, binding in ipairs(self) do
    (binding.disable or binding.stop)(binding)
  end
end

local localKeymaps = {}

-- Register a keymap that is only enabled in the application specified
-- by a bundle ID or windows that satisfy a function
keymap.register = function (matcher, keymap)
  local fn
  if type(matcher) == "function" then
    fn = matcher
  elseif type(matcher) == "string" then
    fn = function (w)
      return w ~= nil and w:application():bundleID() == matcher
    end
  end

  local wf = hs.window.filter.new(fn)
  :subscribe(hs.window.filter.windowFocused, function () keymap:enable() end)
  :subscribe(hs.window.filter.windowUnfocused, function () keymap:disable() end)

  if fn(hs.window.frontmostWindow()) then
    keymap:enable()
  end

  local keymaps = localKeymaps[matcher]
  if keymaps == nil then
    keymaps = {}
    localKeymaps[matcher] = keymaps
  end
  keymaps[keymap] = wf
  return keymap
end

-- Unregister a registered keymap
keymap.unregister = function (matcher, keymap)
  local keymaps = localKeymaps[matcher]
  if keymaps then
    local wf = keymaps[keymap]
    if wf then
      wf:unsubscribeAll()
    end
    keymaps[keymap] = nil
  end
  return keymap
end

return keymap
