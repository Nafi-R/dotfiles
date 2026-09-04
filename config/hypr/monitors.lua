-- https://wiki.hyprland.org/Configuring/Basics/Monitors/
-- Optimized for retina-class 2x displays

hl.env("GDK_SCALE", "2")

-- Framework 13 w/ Apple XDR display
hl.monitor({ output = "DP-1", mode = "highrr", position = "auto-right", scale = 1.25 })
hl.monitor({ output = "HDMI-A-1", mode = "highres", position = "auto-left", scale = 1 })
