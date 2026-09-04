-- Fix JetBrains splash screen
hl.window_rule({
    name  = "jetbrains-splash-tag",
    match = { class = "^(jetbrains-.*)$", title = "^(splash)$", float = true },
    tag = "+jetbrains-splash",
})
hl.window_rule({
    name  = "jetbrains-splash-center",
    match = { tag = "jetbrains-splash" },
    center = true,
})
hl.window_rule({
    name  = "jetbrains-splash-nofocus",
    match = { tag = "jetbrains-splash" },
    no_focus = true,
})
hl.window_rule({
    name  = "jetbrains-splash-noborder",
    match = { tag = "jetbrains-splash" },
    border_size = 0,
})

-- Center JetBrains popups/find windows
hl.window_rule({
    name  = "jetbrains-popup-tag",
    match = { class = "^(jetbrains-.*)", title = "^()$", float = true },
    tag = "+jetbrains",
})
hl.window_rule({
    name  = "jetbrains-popup-center",
    match = { tag = "jetbrains" },
    center = true,
})
hl.window_rule({
    name  = "jetbrains-stay-focused",
    match = { tag = "jetbrains" },
    stay_focused = true,
})
hl.window_rule({
    name  = "jetbrains-popup-noborder",
    match = { tag = "jetbrains" },
    border_size = 0,
})

-- Min size for popups
hl.window_rule({
    name  = "jetbrains-popup-minsize",
    match = { class = "^(jetbrains-.*)", title = "^()$", float = true },
    min_size = "(monitor_w*0.5) (monitor_h*0.5)",
})

-- Disable window flicker from autocomplete
hl.window_rule({
    name  = "jetbrains-tooltip-nofocus",
    match = { class = "^(jetbrains-.*)$", title = "^(win.*)$", float = true },
    no_initial_focus = true,
})

-- Disable mouse focus
hl.window_rule({
    name  = "jetbrains-no-follow-mouse",
    match = { class = "^(jetbrains-.*)$" },
    no_follow_mouse = true,
})
