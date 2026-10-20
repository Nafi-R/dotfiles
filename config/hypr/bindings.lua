-- Application bindings
-- (description is kept as comment only; Lua binds don't have label fields)
hl.bind(
	"SUPER + ALT + RETURN",
	hl.dsp.exec_cmd([[uwsm-app -- xdg-terminal-exec --dir="$(nafi-terminal-cwd)" tmux new]])
)
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd([[uwsm-app -- xdg-terminal-exec --dir="$(nafi-terminal-cwd)"]]))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("noctalia msg panel-open launcher"))
hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("nafi-launch-browser"))
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("nafi-vpn"))
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd("uwsm-app -- nautilus --new-window"))
hl.bind("SUPER + SHIFT + ALT + F", hl.dsp.exec_cmd([[uwsm-app -- nautilus --new-window "$(nafi-terminal-cwd)"]]))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("nafi-launch-browser"))
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("nafi-launch-tui btop"))
hl.bind("SUPER + SHIFT + ALT + B", hl.dsp.exec_cmd("nafi-launch-browser --private"))
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("nafi-launch-or-focus spotify"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("nafi-launch-or-focus steam"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("nafi-launch-editor"))
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("nafi-launch-or-focus podman-desktop"))
hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd([[nafi-launch-or-focus ^signal$ "uwsm-app -- signal-desktop"]]))
hl.bind(
	"SUPER + SHIFT + O",
	hl.dsp.exec_cmd([[nafi-launch-or-focus ^obsidian$ "uwsm-app -- obsidian -disable-gpu --enable-wayland-ime"]])
)
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("nafi-menu-wallpaper"))
hl.bind("SUPER + SHIFT + SLASH", hl.dsp.exec_cmd("uwsm-app -- 1password"))

-- Switch workspaces (NUMPAD)
hl.bind("SUPER + KP_End", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + KP_Down", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + KP_Page_Down", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + KP_Left", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + KP_Begin", hl.dsp.focus({ workspace = 5 }))
hl.bind("SUPER + KP_Right", hl.dsp.focus({ workspace = 6 }))
hl.bind("SUPER + KP_Home", hl.dsp.focus({ workspace = 7 }))
hl.bind("SUPER + KP_Up", hl.dsp.focus({ workspace = 8 }))
hl.bind("SUPER + KP_Page_Up", hl.dsp.focus({ workspace = 9 }))
hl.bind("SUPER + KP_Insert", hl.dsp.focus({ workspace = 10 }))

-- Move active window (NUMPAD)
hl.bind("SUPER + SHIFT + KP_End", hl.dsp.window.move({ workspace = 1 }))
hl.bind("SUPER + SHIFT + KP_Down", hl.dsp.window.move({ workspace = 2 }))
hl.bind("SUPER + SHIFT + KP_Page_Down", hl.dsp.window.move({ workspace = 3 }))
hl.bind("SUPER + SHIFT + KP_Left", hl.dsp.window.move({ workspace = 4 }))
hl.bind("SUPER + SHIFT + KP_Begin", hl.dsp.window.move({ workspace = 5 }))
hl.bind("SUPER + SHIFT + KP_Right", hl.dsp.window.move({ workspace = 6 }))
hl.bind("SUPER + SHIFT + KP_Home", hl.dsp.window.move({ workspace = 7 }))
hl.bind("SUPER + SHIFT + KP_Up", hl.dsp.window.move({ workspace = 8 }))
hl.bind("SUPER + SHIFT + KP_Page_Up", hl.dsp.window.move({ workspace = 9 }))
hl.bind("SUPER + SHIFT + KP_Insert", hl.dsp.window.move({ workspace = 10 }))

-- Move active window silently (NUMPAD)
hl.bind("SUPER + SHIFT + ALT + KP_End", hl.dsp.window.move({ workspace = 1, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Down", hl.dsp.window.move({ workspace = 2, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Page_Down", hl.dsp.window.move({ workspace = 3, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Left", hl.dsp.window.move({ workspace = 4, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Begin", hl.dsp.window.move({ workspace = 5, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Right", hl.dsp.window.move({ workspace = 6, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Home", hl.dsp.window.move({ workspace = 7, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Up", hl.dsp.window.move({ workspace = 8, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Page_Up", hl.dsp.window.move({ workspace = 9, silent = true }))
hl.bind("SUPER + SHIFT + ALT + KP_Insert", hl.dsp.window.move({ workspace = 10, silent = true }))

-- Discord global keybinds (XDG GlobalShortcuts portal).
-- Discord (1.0.16x) registers its custom keybinds through
-- xdg-desktop-portal-hyprland, which stores them in Hyprland but never assigns
-- a trigger (it always returns an empty trigger_description), so Discord's UI
-- keeps saying "Your desktop hasn't allowed this shortcut yet" and its own key
-- field does nothing. The trigger has to be bound here:
-- action id = "<appid>:<shortcut-id>", see `hyprctl globalshortcuts`.
hl.bind("KP_Divide", hl.dsp.global("discord:discord-toggle-deafen"))
hl.bind("KP_Multiply", hl.dsp.global("discord:discord-toggle-mute"))
hl.bind("F8", hl.dsp.global("discord:discord-toggle-go-live-streaming"))
