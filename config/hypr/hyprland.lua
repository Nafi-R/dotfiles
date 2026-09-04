-- Hyprland 0.55+ Lua configuration
-- https://wiki.hyprland.org/Configuring/Start/

-- Defaults
require("default/bindings/media")
require("default/bindings/clipboard")
require("default/bindings/tiling-v2")
require("default/bindings/utilities")
require("default/envs")
require("default/looknfeel")
require("default/input")
require("default/windows")
require("theme/theme")

-- User overrides
require("monitors")
require("input")
require("bindings")
require("looknfeel")
require("autostart")
require("envs")
require("apps")
