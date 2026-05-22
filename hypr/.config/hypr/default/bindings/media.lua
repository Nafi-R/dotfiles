-- Media keys with OSD
local osdclient = "swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\""

hl.bind("XF86AudioRaiseVolume",   hl.dsp.exec_cmd(osdclient .. " --output-volume raise"),    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",   hl.dsp.exec_cmd(osdclient .. " --output-volume lower"),    { locked = true, repeating = true })
hl.bind("XF86AudioMute",          hl.dsp.exec_cmd(osdclient .. " --output-volume mute-toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",       hl.dsp.exec_cmd(osdclient .. " --input-volume mute-toggle"),  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",    hl.dsp.exec_cmd(osdclient .. " --brightness raise"),       { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",  hl.dsp.exec_cmd(osdclient .. " --brightness lower"),       { locked = true, repeating = true })

-- Precise 1% adjustments
hl.bind("ALT + XF86AudioRaiseVolume",  hl.dsp.exec_cmd(osdclient .. " --output-volume +1"), { locked = true, repeating = true })
hl.bind("ALT + XF86AudioLowerVolume",  hl.dsp.exec_cmd(osdclient .. " --output-volume -1"), { locked = true, repeating = true })
hl.bind("ALT + XF86MonBrightnessUp",   hl.dsp.exec_cmd(osdclient .. " --brightness +1"),    { locked = true, repeating = true })
hl.bind("ALT + XF86MonBrightnessDown", hl.dsp.exec_cmd(osdclient .. " --brightness -1"),    { locked = true, repeating = true })

-- Player controls
hl.bind("XF86AudioNext",   hl.dsp.exec_cmd(osdclient .. " --playerctl next"),       { locked = true })
hl.bind("XF86AudioPause",  hl.dsp.exec_cmd(osdclient .. " --playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",   hl.dsp.exec_cmd(osdclient .. " --playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",   hl.dsp.exec_cmd(osdclient .. " --playerctl previous"),   { locked = true })

-- Switch audio output
hl.bind("SUPER + XF86AudioMute", hl.dsp.exec_cmd("nafi-audio-switch"), { locked = true })
