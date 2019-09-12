local emoji = {}

local parse_codepoints = function (str)
  return hs.fnutils.map(
    hs.fnutils.split(str, "-"),
    function (hex)
      return tonumber(hex, 16)
    end
  )
end

local stringify_codepoints = function (codepoints)
  return hs.utf8.codepointToUTF8(table.unpack(codepoints))
end

local get_emojione_table = function ()
  local json_file = "emojione/emoji.json"
  if hs.fs.attributes(json_file, "mode") ~= "file" then
    hs.execute("git clone --depth=1 https://github.com/joypixels/emojione.git")
  else
    hs.execute("cd emojione && git pull")
  end
  local f = io.open(json_file, "r")
  local json = f:read("a")
  f:close()
  return hs.json.decode(json)
end

local get_gemojione_image_dir = function ()
  local dir = "gemojione/assets/png"
  if hs.fs.attributes(dir, "mode") ~= "directory" then
    hs.execute("git clone --depth=1 https://github.com/bonusly/gemojione.git")
  else
    hs.execute("cd gemojione && git pull")
  end
  return dir
end

local categories = {
  "people",
  "nature",
  "food",
  "activity",
  "places",
  "travel",
  "objects",
  "symbols",
  "flags",
  "extras",
  "modifier",
}

local capitalize = function (c, r)
  return string.upper(c) .. r
end

local titlecase = function (text)
  return text:gsub("^(%l)(%w*)", capitalize):gsub("( %l)(%w*)", capitalize)
end

local underscore = function (text)
  return text:gsub("[%s%-]+", "_"):gsub("([^%w_])", function (c)
    if c == 'ō' then
      -- We just type gyoza for gyōza.
      return 'o'
    else
      return c
    end
  end)
end

local initializers = {
  choices = function ()
    local choices = {}
    local compare = function (a, b)
      return a.order < b.order
    end
    local emojione_table = get_emojione_table()
    local image_dir = get_gemojione_image_dir()
    for key in hs.fnutils.sortByKeyValues(emojione_table, compare) do
      local entry = emojione_table[key]
      local matches = entry.code_points.default_matches
      local codepoints_string = hs.fnutils.find(
        matches,
        function (str)
          return (str .. "-"):find("-fe0f-") ~= nil
        end
      ) or matches[1]
      local codepoints = parse_codepoints(codepoints_string)
      local us = hs.fnutils.map(codepoints,
        function (cp)
          return ("U+%04X"):format(cp)
        end
      )
      local moji = stringify_codepoints(codepoints)
      local keywords = { entry.shortname }
      for _, name in ipairs(entry.keywords) do
        local keyword = ":" .. underscore(name) .. ":"
        if not hs.fnutils.some(keywords, function (e) return e == keyword end) then
          table.insert(keywords, keyword)
        end
      end
      local text = titlecase(entry.name)
      local subText = "<" .. table.concat(us, " ") .. "> " .. table.concat(keywords, " ")
      table.insert(choices, {
        text = text,
        subText = subText,
        image = hs.image.imageFromPath(image_dir .. "/" .. entry.code_points.base .. ".png"),
        chars = moji,
      })
    end

    return choices
  end
}

setmetatable(emoji, {
    __index = function (self, name)
      local fn = initializers[name]
      if fn then
        self[name] = fn()
        return self[name]
      end
    end
})

-- Creates a chooser with a given callback, which will be called with
-- a selected emoji, or nil if canceled.
emoji.chooser = function (fn)
  local chooser = hs.chooser.new(function (choice)
      if choice then
        fn(choice.chars)
      else
        fn(nil)
      end
  end)
  chooser:searchSubText(true)
  chooser:queryChangedCallback(
    function (query)
      local choices = emoji.choices
      if #query > 0 then
        local words = hs.fnutils.split(query:lower(), "%s+")
        choices = hs.fnutils.ifilter(choices, function (choice)
            return hs.fnutils.every(words, function (word)
                return choice.text:lower():find(word, 1, true) or choice.subText:lower():find(word, 1, true)
            end)
        end)
      end
      chooser:choices(choices)
    end
  )
  chooser:choices(emoji.choices)

  return chooser
end

-- Preloads the table and choices
emoji.preload = function ()
  local _ = emoji.choices
  return true
end

return emoji
