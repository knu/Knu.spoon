local utils = dofile(hs.spoons.resourcePath("utils.lua"))

local menubar = {}

-- Formats a number in human-readable form using k/m/b suffixes
local function humanize(n)
  if n >= 1e9 then
    return string.format("%.1fb", n / 1e9)
  elseif n >= 1e6 then
    return string.format("%.1fm", n / 1e6)
  elseif n >= 1e3 then
    return string.format("%.1fk", n / 1e3)
  else
    return string.format("%d", n)
  end
end

-- Returns the time of noon on the Monday of the week of a given time
local function weekStart(now)
  local t = os.date("*t", now)
  -- os.time() normalizes an out-of-range day; noon keeps DST shifts harmless
  return os.time{ year = t.year, month = t.month, day = t.day - (t.wday + 5) % 7, hour = 12 }
end

-- Menu bar widget that shows coding agent (Claude Code, Codex, etc.)
-- usage via ccusage
--
-- Usage:
--   knu.menubar.ccusage.start()
--   knu.menubar.ccusage.start({ interval = 300 })
--   knu.menubar.ccusage.stop()
--
-- Configurable fields (pass to start() or set directly):
--   - interval - Update interval in seconds. (default: 60)
--   - timeout  - Seconds after which a stuck fetch is killed and
--     restarted. (default: 120)
--   - shell    - Login shell used to run the command. (default: $SHELL or /bin/zsh)
--   - command  - Function that returns an argv table for fetching usage
--     in the `ccusage daily --json --sections daily,weekly,monthly`
--     format.  The default fetches via npx, going back to the start of
--     the current week or month, whichever is earlier.
--   - title    - Function that takes (today, week, month) and returns
--     the menu bar title.  Each argument is a table with totalCost,
--     totalTokens, inputTokens, outputTokens, etc., or nil.
local ccusage = {
  interval = 60,

  timeout = 120,

  shell = os.getenv("SHELL") or "/bin/zsh",

  command = function ()
    local now = os.time()
    local since = math.min(
      os.date("%Y%m%d", weekStart(now)),
      os.date("%Y%m01", now)
    )
    return {
      "npx", "-y", "ccusage", "daily", "--json", "--by-agent",
      "--sections", "daily,weekly,monthly", "--since", since,
    }
  end,

  title = function (today, week, month)
    return string.format("✳ $%.2f", today and today.totalCost or 0)
  end,
}
menubar.ccusage = ccusage

-- Finds an entry with the given period in a report section
local function findPeriod(entries, period)
  for _, entry in ipairs(entries or {}) do
    if entry.period == period then
      return entry
    end
  end
end

-- Appends menu items showing the usage of a report entry
local function appendUsage(items, label, entry)
  if not entry then
    table.insert(items, { title = label .. ": no usage", disabled = true })
    return
  end
  table.insert(items, { title = string.format("%s: $%.2f (%s tokens)", label, entry.totalCost, humanize(entry.totalTokens)), disabled = true })
  table.insert(items, { title = string.format("  in %s / out %s", humanize(entry.inputTokens), humanize(entry.outputTokens)), disabled = true })
  table.insert(items, { title = string.format("  cache read %s / write %s", humanize(entry.cacheReadTokens), humanize(entry.cacheCreationTokens)), disabled = true })
  for _, agent in ipairs(entry.agents or {}) do
    table.insert(items, { title = string.format("  %s: $%.2f (%s)", agent.agent, agent.totalCost, table.concat(agent.modelsUsed, ", ")), disabled = true })
  end
  if not entry.agents then
    for _, model in ipairs(entry.modelBreakdowns or {}) do
      table.insert(items, { title = string.format("  %s: $%.2f", model.modelName, model.cost), disabled = true })
    end
  end
end

local function buildMenu(today, week, month)
  local items = {}

  appendUsage(items, "Today", today)
  table.insert(items, { title = "-" })
  appendUsage(items, "This week", week)
  table.insert(items, { title = "-" })
  appendUsage(items, "This month", month)
  table.insert(items, { title = "-" })
  table.insert(items, { title = "Refresh", fn = function () ccusage.update(true) end })

  return items
end

-- Reopens the drop-down menu at the menu bar item, falling back to
-- the mouse position if the item is off-screen (e.g. hidden by a menu
-- bar manager)
local function popupMenu()
  local frame = ccusage.menu:frame()
  local point = frame and { x = frame.x, y = frame.y + frame.h }
  if not (point and hs.screen.find(point)) then
    point = hs.mouse.absolutePosition()
  end
  ccusage.menu:popupMenu(point)
end

-- Fetches the latest usage and updates the menu bar
--
-- If reopen is true, the drop-down menu is reopened after the update.
ccusage.update = function (reopen)
  ccusage.reopen = ccusage.reopen or reopen or nil
  if not ccusage.menu then
    return
  end
  if ccusage.task then
    if hs.timer.absoluteTime() / 1e9 - ccusage.startedAt < ccusage.timeout then
      return
    end
    -- The fetch is taking too long; kill it and start over
    ccusage.task:terminate()
    ccusage.task = nil
  end

  local task
  task = hs.task.new(ccusage.shell, function (exitCode, stdOut, stdErr)
      if ccusage.task ~= task then
        -- Superseded by a newer fetch
        return
      end
      ccusage.task = nil
      local reopen = ccusage.reopen
      ccusage.reopen = nil
      if not ccusage.menu then
        return
      end

      local ok, data = pcall(hs.json.decode, stdOut)
      if exitCode ~= 0 or not ok or not data then
        ccusage.menu:setTitle("✳ ⚠")
        ccusage.menu:setTooltip(stdErr or "ccusage failed")
        return
      end

      local now = os.time()
      local today = findPeriod(data.daily, os.date("%Y-%m-%d", now))
      local week = findPeriod(data.weekly, os.date("%Y-%m-%d", weekStart(now)))
      local month = findPeriod(data.monthly, os.date("%Y-%m", now))

      ccusage.menu:setTitle(ccusage.title(today, week, month))
      ccusage.menu:setTooltip("Coding agent usage (ccusage)")
      ccusage.menu:setMenu(buildMenu(today, week, month))
      if reopen then
        popupMenu()
      end
  end, {"-lic", "exec " .. utils.shelljoin(ccusage.command())})
  ccusage.startedAt = hs.timer.absoluteTime() / 1e9
  ccusage.task = task
  task:start()
end

-- Starts the ccusage menu bar widget
ccusage.start = function (opts)
  if opts then
    utils.assign(ccusage, opts)
  end
  if ccusage.menu then
    return ccusage
  end

  ccusage.menu = hs.menubar.new(true, "knu.menubar.ccusage")
  ccusage.menu:setTitle("✳ …")
  ccusage.timer = hs.timer.doEvery(ccusage.interval, ccusage.update)
  ccusage.update()
  return ccusage
end

-- Stops the ccusage menu bar widget and removes it from the menu bar
ccusage.stop = function ()
  if ccusage.timer then
    ccusage.timer:stop()
    ccusage.timer = nil
  end
  if ccusage.task then
    ccusage.task:terminate()
    ccusage.task = nil
  end
  if ccusage.menu then
    ccusage.menu:delete()
    ccusage.menu = nil
  end
  return ccusage
end

return menubar
