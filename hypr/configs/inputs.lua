------------
-- INPUTS --
------------

hl.config({
  input = {
    kb_layout  = "us, ua",
    kb_options = "grp:win_space_toggle",

    repeat_rate = 30,
    repeat_delay = 200,

    numlock_by_default = true,

    follow_mouse = 1,
    sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

    scroll_method = "2fg",

    touchpad = {
      -- can change
      disable_while_typing = true,
      scroll_factor = 1.0,

      -- not change
      natural_scroll = true,
      tap_to_click = true,
      clickfinger_behavior = true
    },
  },
})
