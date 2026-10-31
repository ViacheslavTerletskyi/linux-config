---------------
-- AUTOSTART --
---------------

hl.on("hyprland.start", function ()
  -- Propagates WAYLAND_DISPLAY and XDG_CURRENT_DESKTOP to D-Bus so services (portals, polkit agent) know we're in a Hyprland session
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY QT_QPA_PLATFORMTHEME XDG_CURRENT_DESKTOP=Hyprland")
  -- Same, but for systemd user units directly (not via D-Bus)
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY QT_QPA_PLATFORMTHEME XDG_CURRENT_DESKTOP")
  -- Starts hyprland-session.target, a signal for WantedBy= units that the Hyprland session is ready
  hl.exec_cmd("systemctl --user start hyprland-session.target")

  hl.exec_cmd(DESKTOP_SHELL)       -- start QuickShell (~/.config/quickshell)
  hl.exec_cmd(LOCK_MANAGER)        -- start lock screen manager
  hl.exec_cmd(WALLPAPER_MANAGER)   -- start wallpapers manager

  hl.exec_cmd("udiskie")                                                   -- start daemon for auto mount storage devices (usb sticks, etc)
  hl.exec_cmd("wl-paste --type text --watch cliphist store")               -- clipboard history: text
  hl.exec_cmd("wl-paste --type image --watch cliphist store")              -- clipboard history: images (screenshots)
end)
