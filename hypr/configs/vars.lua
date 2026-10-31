----------
-- VARS --
----------

-- Default Keybindings
MAIN_MODE = "SUPER"
MAIN_MODE_SHIFT = MAIN_MODE .. " + SHIFT"

TERMINAL_KEYS = MAIN_MODE .. " + Q"
FILE_MANAGER_KEYS = MAIN_MODE .. " + E"
MENU_KEYS = MAIN_MODE .. " + R"
BROWSER_KEYS = MAIN_MODE .. " + F"

-- Programs
TERMINAL = "kitty"
FILE_MANAGER = "dolphin"
MENU = "qs ipc call launcher toggle"
BROWSER = "firefox"

-- System Programs
DESKTOP_SHELL = "qs" -- QuickShell: bar, notifications, launcher, polkit agent
LOCK_MANAGER = "hypridle"
WALLPAPER_MANAGER = "hyprpaper"
