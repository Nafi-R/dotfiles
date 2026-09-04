-- Floating windows (via tag)
hl.window_rule({
    name  = "float-floating-window",
    match = { tag = "floating-window" },
    float = true,
})
hl.window_rule({
    name  = "center-floating-window",
    match = { tag = "floating-window" },
    center = true,
})
hl.window_rule({
    name  = "size-floating-window",
    match = { tag = "floating-window" },
    size = "875 660",
})

-- Tag windows as floating
hl.window_rule({
    name  = "tag-floating-apps",
    match = { class = "(org.nafi.bluetui|org.nafi.impala|org.nafi.wiremix|org.nafi.btop|org.nafi.terminal|org.nafi.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|About|TUI.float|imv|mpv)" },
    tag = "+floating-window",
})
hl.window_rule({
    name  = "tag-file-dialogs",
    match = { class = "(xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus)", title = "^(Open.*Files?|Open [Ff]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[Cc]hoose.*)" },
    tag = "+floating-window",
})

-- Calculator always floats
hl.window_rule({
    name  = "calculator-float",
    match = { class = "org.gnome.Calculator" },
    float = true,
})

-- No transparency on media windows
hl.window_rule({
    name  = "media-opacity",
    match = { class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$" },
    opacity = "1 1",
})

-- Popped window rounding
hl.window_rule({
    name  = "pop-rounding",
    match = { tag = "pop" },
    rounding = 8,
})

-- Prevent idle while open
hl.window_rule({
    name  = "noidle-inhibit",
    match = { tag = "noidle" },
    idle_inhibit = "always",
})
