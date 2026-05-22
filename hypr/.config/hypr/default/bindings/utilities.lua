-- Menus
hl.bind("SUPER + K", hl.dsp.exec_cmd("nafi-menu-keybindings"))
hl.bind("XF86Calculator", hl.dsp.exec_cmd("gnome-calculator"))

-- Aesthetics
hl.bind("SUPER + SHIFT + SPACE", hl.dsp.exec_cmd("nafi-toggle-waybar"))
hl.bind("SUPER + BACKSPACE",
    hl.dsp.exec_cmd([[hyprctl dispatch setprop "address:$(hyprctl activewindow -j | jq -r '.address')" opaque toggle]]))
hl.bind("SUPER + SHIFT + BACKSPACE", hl.dsp.exec_cmd("nafi-workspace-toggle-gaps"))

-- Notifications
hl.bind("SUPER + COMMA", hl.dsp.exec_cmd("makoctl dismiss"))
hl.bind("SUPER + SHIFT + COMMA", hl.dsp.exec_cmd("makoctl dismiss --all"))
hl.bind("SUPER + CTRL + COMMA",
    hl.dsp.exec_cmd(
        "makoctl mode -t do-not-disturb && makoctl mode | grep -q 'do-not-disturb' && notify-send 'Silenced notifications' || notify-send 'Enabled notifications'"))
hl.bind("SUPER + ALT + COMMA", hl.dsp.exec_cmd("makoctl invoke"))
hl.bind("SUPER + SHIFT + ALT + COMMA", hl.dsp.exec_cmd("makoctl restore"))

-- Toggle idling / nightlight
hl.bind("SUPER + CTRL + I", hl.dsp.exec_cmd("nafi-toggle-idle"))
hl.bind("SUPER + CTRL + N", hl.dsp.exec_cmd("nafi-toggle-nightlight"))

-- Captures
hl.bind("PRINT", hl.dsp.exec_cmd("nafi-screenshot"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("nafi-screenshot smart clipboard"))
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -a"))

-- Waybar-less info
hl.bind("SUPER + CTRL + ALT + T", hl.dsp.exec_cmd([[notify-send "    $(date +'%A %H:%M  —  %d %B W%V %Y')"]]))
hl.bind("SUPER + CTRL + ALT + B", hl.dsp.exec_cmd("notify-send \"Battery is at $(nafi-battery-remaining)%\""))

-- Control panels
hl.bind("SUPER + CTRL + A", hl.dsp.exec_cmd("nafi-launch-audio"))
hl.bind("SUPER + CTRL + B", hl.dsp.exec_cmd("nafi-launch-bluetooth"))
hl.bind("SUPER + CTRL + W", hl.dsp.exec_cmd("nafi-launch-wifi"))
hl.bind("SUPER + CTRL + T", hl.dsp.exec_cmd("nafi-launch-tui btop"))


-- Lock system
hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd("nafi-lock-screen"))
