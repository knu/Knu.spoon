local pasteboard = {}

-- Show the current input mode
pasteboard.readAllData = function (name)
  local contents = {}
  for _, uti in ipairs(hs.pasteboard.contentTypes(name)) do
    contents[uti] = hs.pasteboard.readDataForUTI(name, uti)
  end
  return contents
end

pasteboard.writeAllData = function (...)
  local name, contents
  if #{...} == 1 then
    contents = ...
  else
    name, contents = ...
  end

  local ok = true
  hs.pasteboard.clearContents(name)
  for uti, data in pairs(contents) do
    ok = ok and hs.pasteboard.writeDataForUTI(name, uti, data)
  end
  return ok
end

return pasteboard
