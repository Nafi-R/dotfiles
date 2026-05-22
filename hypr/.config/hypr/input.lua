-- Custom input overrides
-- https://wiki.hyprland.org/Configuring/Basics/Variables/#input
hl.config({
    input = {
        kb_layout = "us",
        kb_options = "ctrl:nocaps",

        repeat_rate = 40,
        repeat_delay = 600,

        numlock_by_default = true,

        touchpad = {
            scroll_factor = 0.4,
        },
    },
})

-- Scroll nicely in the terminal
hl.window_rule({
    name  = "terminal-scroll-alacritty-kitty",
    match = { class = "(Alacritty|kitty)" },
    scroll_touchpad = 1.5,
})
hl.window_rule({
    name  = "terminal-scroll-ghostty",
    match = { class = "com.mitchellh.ghostty" },
    scroll_touchpad = 0.2,
})

-- gesture = 3, horizontal, workspace
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
