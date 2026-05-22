-- Focus floating DaVinci Resolve dialogs
hl.window_rule({
    name  = "resolve-stay-focused",
    match = { class = ".*[Rr]esolve.*", float = true },
    stay_focused = true,
})
