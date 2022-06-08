local mouse = {}

local runtime = require((...):gsub("[^.]+$", "runtime"))

-- Creates a hold-to-scroll button mode
--
--
-- holdToScrollButton([button[, scrollOffsetsFunction[, delay]]]) -> mode
--
-- Parameters:
--
--   - button - A button number. (0: left, 1: right, 2: middle, ...)  Mouse movement while this button is held gets converted to scroll events. (default: 2)
--   - scrollOffsetsFunction - A function that takes three arguments (delta, origin, current) and returns { scrollX, scrollY }.
--     Parameters:
--       - delta - the change in the mouse position in pixels; a table containing x and y values
--       - origin - the mouse position where dragging started; a table containing x and y values
--       - current - the current mouse position; a table containing x and y values
--   - delay - Mouse dragging is ignored until this delay in milliseconds passes after the last mouse down. (default: 150)
--
-- Returns:
--
--   - A mode object that has two methods: enable() and disable().
mouse.holdToScrollButton = function (button, scrollOffsetsFunction, delay)
  if button == nil then
    button = 2
  end

  if scrollOffsetsFunction == nil then
    scrollOffsetsFunction = function (delta, origin, current)
      return { -delta.x, -delta.y }
    end
  end

  if delay == nil then
    delay = 150
  end

  local state = 0 -- 0: up, 1: down, 2: dragged
  local origin
  local downAt
  local deltas = {}
  local logger = hs.logger.new("knu.mouse")
  local mouseDownEventType
  local mouseUpEventType
  local mouseDraggedEventType

  if button == 0 then
    -- Who would do this?
    mouseDownEventType = hs.eventtap.event.types.leftMouseDown
    mouseUpEventType = hs.eventtap.event.types.leftMouseUp
    mouseDraggedEventType = hs.eventtap.event.types.leftMouseDragged
  elseif button == 1 then
    mouseDownEventType = hs.eventtap.event.types.rightMouseDown
    mouseUpEventType = hs.eventtap.event.types.rightMouseUp
    mouseDraggedEventType = hs.eventtap.event.types.rightMouseDragged
  elseif button >= 2 then
    mouseDownEventType = hs.eventtap.event.types.otherMouseDown
    mouseUpEventType = hs.eventtap.event.types.otherMouseUp
    mouseDraggedEventType = hs.eventtap.event.types.otherMouseDragged
  else
    error("button number must not be negative.")
  end

  local mouseDown = hs.eventtap.new({ mouseDownEventType }, function (e)
      if e:getButtonState(button) then
        if state == 0 then
          downAt = hs.timer.absoluteTime()
          origin = e:location()
          deltas = {}
          state = 1
          return true
        end
      end

      return false
  end)

  local mouseUp = hs.eventtap.new({ mouseUpEventType }, function (e)
      if state ~= 0 and not e:getButtonState(button) then
        if state == 1 then
          local pos = e:location()
          local dx = 0
          local dy = 0
          for _, delta in ipairs(deltas) do
            dx = dx + delta.x
            dy = dy + delta.y
          end
          state = 0
          deltas = {}
          hs.timer.doAfter(0, function ()
              local pos = hs.mouse.absolutePosition()
              pos.x = pos.x + dx
              pos.y = pos.y + dy
              hs.mouse.absolutePosition(pos)
              local move = hs.eventtap.event.newEvent(hs.eventtap.event.types.mouseMoved, pos)
              move:setProperty(hs.eventtap.event.properties.mouseEventDeltaX, dx)
              move:setProperty(hs.eventtap.event.properties.mouseEventDeltaY, dy)
              move:post()
          end)
          e:location(origin)
          return true, {
            e:copy():setType(mouseDownEventType),
            e
          }
        elseif state == 2 then
          state = 0
          return true
        end
      end

      return false
  end)

  local mouseDragged = hs.eventtap.new({ mouseDraggedEventType }, function (e)
      if e:getButtonState(button) then
        local pos = e:location()
        hs.mouse.absolutePosition(pos)

        deltas[#deltas + 1] = {
          x = e:getProperty(hs.eventtap.event.properties.mouseEventDeltaX),
          y = e:getProperty(hs.eventtap.event.properties.mouseEventDeltaY)
        }

        if state == 1 then
          local millisecondsPassed = (hs.timer.absoluteTime() - downAt) / 1000000

          if millisecondsPassed <= delay then
            return true
          end
        end

        local events = hs.fnutils.mapCat(
          deltas,
          function (delta)
            local offsets = scrollOffsetsFunction(delta, origin, pos)

            if offsets ~= nil then
              return {
                hs.eventtap.event.newScrollEvent(offsets, {}, "pixel")
              }
            else
              return {}
            end
          end
        )

        state = 2
        deltas = {}

        return true, events
      end

      return false
  end)

  return runtime.guard({
      enable = function (self)
        mouseDown:start()
        mouseUp:start()
        mouseDragged:start()
      end,

      disable = function (self)
        mouseDown:stop()
        mouseUp:stop()
        mouseDragged:stop()
      end,
  })
end

return mouse
