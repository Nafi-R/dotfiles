-- Remove animation on hyprshot selection overlay
hl.layer_rule({
    name  = "hyprshot-no-anim",
    match = { namespace = "selection" },
    no_anim = true,
})
