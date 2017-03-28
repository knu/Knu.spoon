local emoji = {}

local initializers = {
  table = function ()
    local f = io.open("gemoji/emoji.json", "r")
    if f == nil then
      hs.execute([[
      set -e
      /usr/bin/gem install --user-install gemoji
      ~/.gem/ruby/2.0.0/bin/gemoji extract gemoji/images
      /usr/bin/ruby -rgemoji -rfileutils -e 'FileUtils.cp Emoji::data_file, ARGV[0]' gemoji/
    ]])
      f = io.open("gemoji/emoji.json", "r")
    end
    local json = f:read("a")
    f:close()
    return hs.json.decode(json)
  end,

  choices = function ()
    local choices = {}
    for _, entry in ipairs(emoji.table) do
      local chars = entry.emoji
      if chars then
        local path = ("gemoji/images/unicode/%s.png"):format(
          chars:gsub(utf8.charpattern, function (char)
              local cp = utf8.codepoint(char)
              if cp == 0xfe0f or cp == 0x200d then
                return ""
              else
                return ("%04x-"):format(cp)
              end
          end):gsub("-$", "")
        )
        local aliases = {}
        for _, alias in ipairs(entry.aliases) do
          table.insert(aliases, ":" .. alias .. ":")
        end
        local us = chars:gsub(utf8.charpattern, function (char)
            local cp = utf8.codepoint(char)
            return ("U+%04X "):format(cp)
        end):gsub(" $", "")
        table.insert(choices, {
            text = entry.description:gsub("(%l)(%w*)",
              function (c, r)
                return string.upper(c) .. r
              end
            ),
            subText = us .. ": " .. table.concat({
                table.unpack(aliases),
                table.unpack(entry.tags)
            }, ", "),
            image = hs.image.imageFromPath(path),
            chars = chars,
        })
      end
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

-- Create a chooser with a given callback, which will be called with a
-- selected emoji, or nil if canceled.
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

-- Preload the table and choices
emoji.preload = function ()
  local _ = emoji.choices
  return true
end

return emoji
