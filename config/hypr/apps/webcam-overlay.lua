-- Webcam overlay for screen recording
hl.window_rule({
    name  = "webcam-float",
    match = { title = "WebcamOverlay" },
    float = true,
})
hl.window_rule({
    name  = "webcam-pin",
    match = { title = "WebcamOverlay" },
    pin = true,
})
hl.window_rule({
    name  = "webcam-nofocus",
    match = { title = "WebcamOverlay" },
    no_initial_focus = true,
})
hl.window_rule({
    name  = "webcam-nodim",
    match = { title = "WebcamOverlay" },
    no_dim = true,
})
hl.window_rule({
    name  = "webcam-position",
    match = { title = "WebcamOverlay" },
    move = "(monitor_w-window_w-40) (monitor_h-window_h-40)",
})
