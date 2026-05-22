-- Float LocalSend and fzf file picker
hl.window_rule({
    name  = "localsend-float",
    match = { class = "(Share|localsend)" },
    float = true,
})
hl.window_rule({
    name  = "localsend-center",
    match = { class = "(Share|localsend)" },
    center = true,
})
