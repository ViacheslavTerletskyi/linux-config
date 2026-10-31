# dotfiles

My configs for Arch Linux + Hyprland. The repository is `~/.config` itself, and `.gitignore` works as a whitelist: everything is ignored except the folders below.

| Folder | Contents |
|---|---|
| `hypr/` | Hyprland (Lua config), hypridle, hyprlock, hyprpaper, scripts |
| `quickshell/` | QuickShell desktop shell: bar, launcher, notifications, screenshots, polkit |
| `nvim/` | Neovim with lazy.nvim |
| `kitty/` | Terminal |
| `systemd/user/` | User services: battery warning, Hyprland session target |

Theme everywhere: **Catppuccin Mocha**.

## hypr/

- `hyprland.lua` — entry point, loads the files from `configs/`
- `configs/vars.lua` — modifier key (`SUPER`) and default apps: kitty, dolphin, firefox
- `configs/autostart.lua` — what starts on login: QuickShell, hypridle, hyprpaper, udiskie, cliphist, `hyprland-session.target`
- `configs/bindings.lua` — keybindings
- `configs/monitors.lua`, `inputs.lua`, `appearance.lua`, `window_rules.lua`, `environment.lua` — monitors, keyboard/touchpad, look and feel, window rules, environment variables
- `hypridle.conf` — screen lock and suspend on idle
- `hyprlock.conf` — lock screen
- `hyprpaper.conf` — wallpapers
- `mocha.conf` — Catppuccin Mocha colors for hyprlock
- `scripts/battery-warn.sh` — low battery notifications (run by a systemd timer)

### Main keybindings

| Keys | Action |
|---|---|
| `SUPER + Q` | Terminal (kitty) |
| `SUPER + E` | File manager (dolphin) |
| `SUPER + R` | Launcher |
| `SUPER + F` | Browser |
| `SUPER + H/J/K/L` | Move focus between windows |
| `SUPER + 1..0` / `SUPER + SHIFT + 1..0` | Go to workspace / move window to workspace |
| `SUPER + T` / `SUPER + SHIFT + T` | Toggle the "magic" special workspace / move window there |
| `SUPER + N` | Notification center |
| `SUPER + SHIFT + D` | Do not disturb |
| `SUPER + SHIFT + R` | Clipboard history |
| `SUPER + SHIFT + L` | Lock screen |
| `SUPER + SHIFT + M` | Exit session |
| `PRINT` / `SHIFT + PRINT` / `SUPER + PRINT` | Screenshot of screen / region / window |

Full list in `hypr/configs/bindings.lua`.

## quickshell/

Started from Hyprland with `qs`. Controlled via `qs ipc call ...`.

- `shell.qml` — entry point
- `bar/` — a bar on every monitor: workspaces, clock and calendar, audio, network, Bluetooth, battery, keyboard layout, system stats, notifications
- `launcher/` — app launcher and clipboard history
- `notifications/` — notification popups and notification center
- `screenshot/` — screenshots of the screen, a region or a window
- `polkit/` — password dialog for `pkexec`, `systemctl`, etc.
- `firewall/` — `ufw` management
- `packages/` — installed packages viewer (pacman, flatpak, npm, pipx, cargo, etc.)
- `services/` — data sources for widgets (audio, battery, network, Bluetooth, stats)
- `theme/`, `widgets/` — colors and shared components

## nvim/

- `init.lua` → `lua/config/` — base options (`set.lua`), keymaps (`remap.lua`), plugin manager (`lazy.lua`)
- `lua/config/plugins/` — plugins: telescope, treesitter, LSP + mason, blink (completion), conform (formatting), harpoon, diffview, undotree, mini, roslyn (C#), nightfox theme
- `after/lsp/` — per-server LSP settings (gopls, angularls)

`lazy-lock.json` is not tracked, so plugins install at their latest versions.

## kitty/

FiraCode Nerd Font, semi-transparent background, Catppuccin Mocha theme (`current-theme.conf`).

## systemd/user/

- `battery-warn.timer` + `battery-warn.service` — run `hypr/scripts/battery-warn.sh` every minute; it sends a notification at 20%, 10% and 5%
- `hyprland-session.target` — started from `autostart.lua`; activates `graphical-session.target`, which xdg-desktop-portal depends on

## Installation

Packages:

```sh
sudo pacman -S hyprland hypridle hyprlock hyprpaper xdg-desktop-portal-hyprland \
  kitty neovim ttf-firacode-nerd \
  wl-clipboard cliphist grim brightnessctl playerctl wireplumber libnotify \
  udiskie ufw polkit dolphin breeze-icons
yay -S quickshell
```

Clone into an existing `~/.config`:

```sh
cd ~/.config
git init
git remote add origin <repo-url>
git fetch origin
git checkout -f main
```

`checkout -f` overwrites local files with the same names. The rest of `~/.config` is left untouched.

Enable the battery timer:

```sh
systemctl --user daemon-reload
systemctl --user enable --now battery-warn.timer
```

### Not included in the repo

- **Wallpaper** `~/.config/backgrounds/shaded.png` — used by `hyprpaper.conf` and `hyprlock.conf`. Copy it manually.
- The battery name in `battery-warn.sh` is `BAT0`. It may differ on another laptop (`ls /sys/class/power_supply`).
- Monitors in `hypr/configs/monitors.lua` are set up for specific hardware.
