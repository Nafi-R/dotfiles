-- https://wiki.hyprland.org/Configuring/Basics/Monitors/

-- Integer scale only: fractional scaling (1.25) makes Hyprland render the
-- output at 3200x1800 and downscale every frame (+56% pixels @144Hz), which
-- competes with games for GPU time and is far worse while a screencast is
-- active. See https://wiki.hypr.land/Configuring/Performance/

-- DP-1: VX2705-2KP, 2560x1440 @144Hz
hl.monitor({ output = "DP-1", mode = "highrr", position = "auto-right", scale = 1 })
-- HDMI-A-1: DELL P2412H, 1920x1080 @60Hz
hl.monitor({ output = "HDMI-A-1", mode = "highres", position = "auto-left", scale = 1 })
