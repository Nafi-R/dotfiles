-- RetroArch: fullscreen, opaque, inhibit idle
hl.window_rule({
    name  = "retroarch-fullscreen",
    match = { class = "com.libretro.RetroArch" },
    fullscreen = true,
})
hl.window_rule({
    name  = "retroarch-opacity",
    match = { class = "com.libretro.RetroArch" },
    opacity = "1 1",
})
hl.window_rule({
    name  = "retroarch-idle-inhibit",
    match = { class = "com.libretro.RetroArch" },
    idle_inhibit = "fullscreen",
})
