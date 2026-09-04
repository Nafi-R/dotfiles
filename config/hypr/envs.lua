hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("PATH", os.getenv("HOME") .. "/.local/share/nafi/bin:" .. (os.getenv("PATH") or ""))
