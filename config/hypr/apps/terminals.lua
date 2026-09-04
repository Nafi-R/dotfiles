-- Define terminal tag to style them uniformly
hl.window_rule({
    name  = "tag-terminals",
    match = { class = "(Alacritty|kitty|com.mitchellh.ghostty)" },
    tag = "+terminal",
})
