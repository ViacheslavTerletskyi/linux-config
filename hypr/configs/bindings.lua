--------------
-- BINDINGS --
--------------

-- Open Programs
hl.bind(MENU_KEYS,         hl.dsp.exec_cmd(MENU),         { description = "Open Menu"        })
hl.bind(BROWSER_KEYS,      hl.dsp.exec_cmd(BROWSER),      { description = "Open Browser"     })
hl.bind(TERMINAL_KEYS,     hl.dsp.exec_cmd(TERMINAL),     { description = "Open Terminal"    })
hl.bind(FILE_MANAGER_KEYS, hl.dsp.exec_cmd(FILE_MANAGER), { description = "Open FileManager" })

-- Screenshots
hl.bind(                      "PRINT", hl.dsp.exec_cmd("qs ipc call screenshot screen"), { description = "Took a screenshot for whole screen"    })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("qs ipc call screenshot region"), { description = "Region screenshot with editor (QuickShell)" })
hl.bind(MAIN_MODE_SHIFT .. " + Escape", hl.dsp.exec_cmd("qs ipc call screenshot cancel"), { description = "Emergency: close screenshot overlay" })
hl.bind(MAIN_MODE       .. " + PRINT", hl.dsp.exec_cmd("qs ipc call screenshot window"), { description = "Took a screenshot for one window"      })

-- System Operations
hl.bind(MAIN_MODE_SHIFT .. " + l", hl.dsp.exec_cmd("hyprlock"),             { description = "Open lockscreen"              })
hl.bind(MAIN_MODE_SHIFT .. " + D", hl.dsp.exec_cmd("qs ipc call notifications toggleDnd"),    { description = "Toggle showing notifications" })
hl.bind(MAIN_MODE       .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggleCenter"), { description = "Toggle notification center"   })
hl.bind(MAIN_MODE_SHIFT .. " + R", hl.dsp.exec_cmd("qs ipc call launcher clipboard"),          { description = "Clipboard history"            })

hl.bind(MAIN_MODE_SHIFT .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"), { description = "Stop Current Session" })

-- Window Operations
hl.bind(MAIN_MODE .. " + C", hl.dsp.window.close(),                      { description = "Close Window"         })
hl.bind(MAIN_MODE .. " + P", hl.dsp.window.pseudo(),                     { description = "Window Pseudo Toggle" })
hl.bind(MAIN_MODE .. " + S", hl.dsp.layout("togglesplit"),               { description = "Window Split Toggle"  })
hl.bind(MAIN_MODE .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Window Float Toggle"  })

hl.bind(MAIN_MODE_SHIFT .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }), { description = "Window Fullscreen Toggle" })

-- Move/Resize Windows
hl.bind(MAIN_MODE .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true }, { description = "Move Window With Mouse"   })
hl.bind(MAIN_MODE .. " + mouse:273", hl.dsp.window.resize(), { mouse = true }, { description = "Resize Window With Mouse" })

-- Magic Workspace
hl.bind(MAIN_MODE       .. " + T", hl.dsp.workspace.toggle_special("magic"),            { description = "Toggle Magic Workspace"         })
hl.bind(MAIN_MODE_SHIFT .. " + T", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move Window To Magic Workspace" })

-- Multimedia Operations
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Raise volume"     })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Lower volume"     })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true, description = "Mute Audio"       })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true, description = "Mute Mic"         })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true, description = "Raise Brightness" })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true, description = "Lower Brightness" })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next Media"  })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Pause Media" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play Media"  })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Prev Media"  })

-- Move Around Tiles
hl.bind(MAIN_MODE .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(MAIN_MODE .. " + j", hl.dsp.focus({ direction = "down"  }))
hl.bind(MAIN_MODE .. " + k", hl.dsp.focus({ direction = "up"    }))
hl.bind(MAIN_MODE .. " + l", hl.dsp.focus({ direction = "right"  }))

-- Switch workspaces
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(MAIN_MODE .. " + " .. key,         hl.dsp.focus({ workspace = i}))
    hl.bind(MAIN_MODE .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
