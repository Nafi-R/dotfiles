-- No screen share on Bitwarden
hl.window_rule({
    name  = "bitwarden-no-screen-share",
    match = { class = "^(Bitwarden)$" },
    no_screen_share = true,
})
hl.window_rule({
    name  = "bitwarden-float",
    match = { class = "^(Bitwarden)$" },
    tag = "+floating-window",
})
