-- Steam: float all windows, then specialize Friends List
hl.window_rule({
    name  = "steam-float",
    match = { class = "steam" },
    float = true,
})
hl.window_rule({
    name  = "steam-friends-float",
    match = { class = "steam", title = "Friends List" },
    float = true,
})
hl.window_rule({
    name  = "steam-friends-center",
    match = { class = "steam", title = "Friends List" },
    center = true,
})
hl.window_rule({
    name  = "steam-friends-size",
    match = { class = "steam", title = "Friends List" },
    size = "460 800",
})
