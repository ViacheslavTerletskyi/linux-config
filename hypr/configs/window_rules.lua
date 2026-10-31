------------------
-- WINDOW RULES --
------------------

hl.window_rule({
  -- Ignore maximize requests from all apps. You'll probably like this.
  name  = "suppress-maximize-events",
  match = { class = ".*" },

  suppress_event = "maximize",
})

hl.window_rule({
  name  = "fix-xwayland-drags",
  match = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },

  no_focus = true,
})

-----------------
-- LAYER RULES --
-----------------

hl.layer_rule({
  -- Screenshot overlay shows a frozen frame: it must appear instantly, without fade.
  name     = "screenshot-no-anim",
  match    = { namespace = "^quickshell-screenshot$" },
  no_anim  = true,
})
