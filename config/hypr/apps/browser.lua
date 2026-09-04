-- Browser types
hl.window_rule({
    name  = "tag-chromium-browsers",
    match = { class = "((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)" },
    tag = "+chromium-based-browser",
})
hl.window_rule({
    name  = "tag-firefox-browsers",
    match = { class = "([fF]irefox|zen|librewolf)" },
    tag = "+firefox-based-browser",
})

-- Force chromium-based browsers into a tile
hl.window_rule({
    name  = "chromium-tile",
    match = { tag = "chromium-based-browser" },
    tile = true,
})

-- Subtle opacity for browsers
hl.window_rule({
    name  = "chromium-opacity",
    match = { tag = "chromium-based-browser" },
    opacity = "1 0.97",
})
hl.window_rule({
    name  = "firefox-opacity",
    match = { tag = "firefox-based-browser" },
    opacity = "1 0.97",
})

-- Video sites: no opacity
hl.window_rule({
    name  = "video-opacity",
    match = { initial_title = "((?i)(?:[a-z0-9-]+\\.)*youtube\\.com_/|app\\.zoom\\.us_/wc/home)" },
    opacity = "1.0 1.0",
})
