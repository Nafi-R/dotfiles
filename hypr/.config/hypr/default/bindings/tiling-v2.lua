-- Close windows
hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("nafi-window-close-all"))

-- Control tiling
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + CTRL + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreenstate 0 2"))
hl.bind("SUPER + ALT + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 1"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("nafi-window-pop"))

-- Move focus with arrow keys
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with [1-9; 0]
hl.bind("SUPER + code:10", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + code:11", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + code:12", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + code:13", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + code:14", hl.dsp.focus({ workspace = 5 }))
hl.bind("SUPER + code:15", hl.dsp.focus({ workspace = 6 }))
hl.bind("SUPER + code:16", hl.dsp.focus({ workspace = 7 }))
hl.bind("SUPER + code:17", hl.dsp.focus({ workspace = 8 }))
hl.bind("SUPER + code:18", hl.dsp.focus({ workspace = 9 }))
hl.bind("SUPER + code:19", hl.dsp.focus({ workspace = 10 }))

-- Move active window to workspace
hl.bind("SUPER + SHIFT + code:10", hl.dsp.window.move({ workspace = 1 }))
hl.bind("SUPER + SHIFT + code:11", hl.dsp.window.move({ workspace = 2 }))
hl.bind("SUPER + SHIFT + code:12", hl.dsp.window.move({ workspace = 3 }))
hl.bind("SUPER + SHIFT + code:13", hl.dsp.window.move({ workspace = 4 }))
hl.bind("SUPER + SHIFT + code:14", hl.dsp.window.move({ workspace = 5 }))
hl.bind("SUPER + SHIFT + code:15", hl.dsp.window.move({ workspace = 6 }))
hl.bind("SUPER + SHIFT + code:16", hl.dsp.window.move({ workspace = 7 }))
hl.bind("SUPER + SHIFT + code:17", hl.dsp.window.move({ workspace = 8 }))
hl.bind("SUPER + SHIFT + code:18", hl.dsp.window.move({ workspace = 9 }))
hl.bind("SUPER + SHIFT + code:19", hl.dsp.window.move({ workspace = 10 }))

-- Move active window silently
hl.bind("SUPER + SHIFT + ALT + code:10", hl.dsp.window.move({ workspace = 1, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:11", hl.dsp.window.move({ workspace = 2, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:12", hl.dsp.window.move({ workspace = 3, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:13", hl.dsp.window.move({ workspace = 4, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:14", hl.dsp.window.move({ workspace = 5, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:15", hl.dsp.window.move({ workspace = 6, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:16", hl.dsp.window.move({ workspace = 7, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:17", hl.dsp.window.move({ workspace = 8, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:18", hl.dsp.window.move({ workspace = 9, silent = true }))
hl.bind("SUPER + SHIFT + ALT + code:19", hl.dsp.window.move({ workspace = 10, silent = true }))

-- TAB between workspaces
hl.bind("SUPER + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + CTRL + TAB", hl.dsp.focus({ workspace = "previous" }))

-- Move workspaces to other monitors
hl.bind("SUPER + SHIFT + ALT + LEFT", hl.dsp.workspace.move({ monitor = "+1" }))
hl.bind("SUPER + SHIFT + ALT + RIGHT", hl.dsp.workspace.move({ monitor = "-1" }))

-- Swap active window
hl.bind("SUPER + SHIFT + LEFT", function() hl.dispatch("swapwindow", "l") end)
hl.bind("SUPER + SHIFT + RIGHT", function() hl.dispatch("swapwindow", "r") end)
hl.bind("SUPER + SHIFT + UP", function() hl.dispatch("swapwindow", "u") end)
hl.bind("SUPER + SHIFT + DOWN", function() hl.dispatch("swapwindow", "d") end)

-- Cycle through applications
hl.bind("ALT + TAB", function()
    hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))
    hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch bringactivetotop"))
end)
hl.bind("ALT + SHIFT + TAB", function()
    hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch cyclenext prev"))
    hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch bringactivetotop"))
end)


-- Scroll through workspaces
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Groups
hl.bind("SUPER + G", hl.dsp.exec_cmd("hyprctl dispatch togglegroup"))
hl.bind("SUPER + ALT + G", hl.dsp.exec_cmd("hyprctl dispatch moveoutofgroup"))
hl.bind("SUPER + ALT + LEFT", hl.dsp.exec_cmd("hyprctl dispatch moveintogroup l"))
hl.bind("SUPER + ALT + RIGHT", hl.dsp.exec_cmd("hyprctl dispatch moveintogroup r"))
hl.bind("SUPER + ALT + UP", hl.dsp.exec_cmd("hyprctl dispatch moveintogroup u"))
hl.bind("SUPER + ALT + DOWN", hl.dsp.exec_cmd("hyprctl dispatch moveintogroup d"))

-- Navigate grouped windows
hl.bind("SUPER + ALT + TAB", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive f"))
hl.bind("SUPER + ALT + SHIFT + TAB", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive b"))
hl.bind("SUPER + CTRL + LEFT", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive b"))
hl.bind("SUPER + CTRL + RIGHT", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive f"))

-- Scroll through grouped windows
hl.bind("SUPER + ALT + mouse_down", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive f"))
hl.bind("SUPER + ALT + mouse_up", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive b"))

-- Activate group window by number
hl.bind("SUPER + ALT + code:10", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive 1"))
hl.bind("SUPER + ALT + code:11", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive 2"))
hl.bind("SUPER + ALT + code:12", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive 3"))
hl.bind("SUPER + ALT + code:13", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive 4"))
hl.bind("SUPER + ALT + code:14", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive 5"))
