local emoji = {}

local unescape = function (text)
  -- To decode "Keycap: \\x{23}"
  return text:gsub(
    "\\x{(%x+)}",
    function (h)
      return utf8.char(tonumber(h, 16))
    end
  )
end

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
  table = function ()
    local f = io.open("emoji-db/emoji-db.json", "r")
    if f == nil then
      hs.execute("git clone https://github.com/meyer/emoji-db.git")
      f = io.open("emoji-db/emoji-db.json", "r")
    end
    local json = f:read("a")
    f:close()
    return hs.json.decode(json)
  end,

  choices = function ()
    local choices = {}
    for key in hs.fnutils.sortByKeys(emoji.table) do
      local entry = emoji.table[key]
      local us = hs.fnutils.map(entry.codepoints,
        function (cp)
          return ("U+%04X"):format(cp)
        end
      )
      local mnemonics = { entry.emojilib_name }
      for _, keyword in ipairs(entry.keywords) do
        local mnemonic = underscore(keyword)
        if not hs.fnutils.some(mnemonics, function (e) return e == mnemonic end) then
          table.insert(mnemonics, mnemonic)
        end
      end
      local keywords = hs.fnutils.map(mnemonics, function (keyword) return ":" .. keyword .. ":" end)
      local text = titlecase(unescape(entry.name))
      local subText = table.concat(us, " ") .. ": " .. table.concat(keywords, ", ")
      table.insert(choices, {
        text = text,
        subText = subText,
        image = hs.image.imageFromPath("emoji-db/" .. entry.image),
        chars = entry.emoji,
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
  chooser:choices(emoji.choices)

  return chooser
end

-- Preloads the table and choices
emoji.preload = function ()
  local _ = emoji.choices
  return true
end

return emoji
