-- No screen share on 1Password
hl.window_rule({
    name  = "1password-no-screen-share",
    match = { class = "^(1[pP]assword)$" },
    no_screen_share = true,
})
hl.window_rule({
    name  = "1password-float",
    match = { class = "^(1[pP]assword)$" },
    tag = "+floating-window",
})
