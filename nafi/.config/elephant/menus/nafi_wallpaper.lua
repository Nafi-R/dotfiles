Name = "nafiWallpaper"
NamePretty = "Wallpaper Picker"
Cache = false
HideFromProviderlist = false
SearchName = true

local function ShellEscape(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function FormatName(filename)
  -- Remove file extension
  local name = filename:gsub("%.[^%.]+$", "")
  -- Replace dashes and underscores with spaces
  name = name:gsub("[%-_]", " ")
  -- Capitalize each word
  name = name:gsub("%S+", function(word)
    return word:sub(1, 1):upper() .. word:sub(2):lower()
  end)
  return name
end

function GetEntries()
  local entries = {}
  local home = os.getenv("HOME")
  local wallpaper_dir = home .. "/Wallpapers"

  local handle = io.popen(
    "find " .. ShellEscape(wallpaper_dir)
      .. " -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.bmp' -o -name '*.webp' \\) 2>/dev/null | sort"
  )

  if handle then
    for image in handle:lines() do
      local filename = image:match("([^/]+)$")
      if filename then
        table.insert(entries, {
          Text = FormatName(filename),
          Value = image,
          Actions = {
            activate = "nafi-wallpaper-set " .. ShellEscape(image),
          },
          Preview = image,
          PreviewType = "file",
        })
      end
    end
    handle:close()
  end

  return entries
end
