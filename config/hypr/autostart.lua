-- Extra autostart processes
hl.on("hyprland.start", function()
	hl.exec_cmd("uwsm-app -- hypridle")
	hl.exec_cmd("uwsm-app -- swaync")
	hl.exec_cmd("uwsm-app -- noctalia")
	hl.exec_cmd("uwsm-app -- fcitx5")
	hl.exec_cmd("uwsm-app -- awww-daemon")
	hl.exec_cmd("sleep 0.5 && nafi-wallpaper-restore")
	hl.exec_cmd("uwsm-app -- swayosd-server")
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

	-- Slow app launch fix
	hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
end)
