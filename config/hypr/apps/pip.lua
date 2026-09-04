-- Picture-in-picture overlays
hl.window_rule({
    name  = "pip-tag",
    match = { title = "Picture.?in.?[Pp]icture" },
    tag = "+pip",
})
hl.window_rule({
    name  = "pip-float",
    match = { tag = "pip" },
    float = true,
})
hl.window_rule({
    name  = "pip-pin",
    match = { tag = "pip" },
    pin = true,
})
hl.window_rule({
    name  = "pip-size",
    match = { tag = "pip" },
    size = "600 338",
})
hl.window_rule({
    name  = "pip-keep-aspect",
    match = { tag = "pip" },
    keep_aspect_ratio = true,
})
hl.window_rule({
    name  = "pip-noborder",
    match = { tag = "pip" },
    border_size = 0,
})
hl.window_rule({
    name  = "pip-opacity",
    match = { tag = "pip" },
    opacity = "1 1",
})
hl.window_rule({
    name  = "pip-position",
    match = { tag = "pip" },
    move = "(monitor_w-window_w-40) (monitor_h*0.04)",
})
