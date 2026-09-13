---@diagnostic disable: undefined-global

hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.2, disabled = false })
hl.monitor({ output = "DP-1", mode = "preferred", position = "auto", scale = 1.5  })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("XCURSOR_SIZE", 24)
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.on("hyprland.start", function ()
  hl.exec_cmd("quickshell & swaybg -i $HOME/Pictures/Wallpapers/inazuma.jpg & hypridle")
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  -- Dark Theme GTK
  hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
  hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"')
end)

hl.config({
  general = {
    border_size = 1,
    gaps_in = 0,
    gaps_out = 0,
    col = {
      active_border = {
        colors = {"rgba(8833ffee)", "rgba(55aaffee)"},
        angle = 45
      },
      inactive_border = "rgba(595959aa)",
    },
    layout = "dwindle",
    allow_tearing = false,
  },

  decoration = {
    rounding = 0,
    blur = {
      enabled = true,
      size = 3,
      passes = 1
    },
    shadow = {
      enabled = true,
      range = 30,
      render_power = 3,
      color = "rgba(1a1a1aee)",
      offset = {4, 4},
      scale = 1.0
    }
  },

  animations = { enabled = false },

  input = {
    kb_model = "",
    kb_layout = "us",
    kb_variant = "",
    kb_options = "",
    kb_rules = "",
    sensitivity = 0.0,
    follow_mouse = 1,
  },

  group = {
    col = {
      border_active = {
        colors = {"rgba(8833ffee)", "rgba(55aaffee)"},
        angle = 45
      },
      border_inactive = "rgba(595959aa)"
    },
    groupbar = {
      enabled = true,
      font_size = 12,
      col = {
        active = "rgba(8833ffee)",
        inactive = "rgba(595959aa)"
      }
    }
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
    vrr = 3,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
    animate_manual_resizes = true,
    animate_mouse_windowdragging = false
  },

  xwayland = {
    enabled = true,
    force_zero_scaling = true
  },

  cursor = { default_monitor = "DP-1" },

  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
    enforce_permissions = true
  }
})

hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.animation({ leaf = "windows", enabled = true, speed = 10, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 1, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3,  bezier = "myBezier" })

local mainMod = "SUPER"
-- Window Manipulation
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + SHIFT + mouse:272", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + A", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + D", hl.dsp.focus({ workspace = "e+1" }))

-- Workspace Manipulation
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Tab Manipulation
hl.bind(mainMod .. " + T", hl.dsp.group.toggle())
hl.bind("ALT + TAB", hl.dsp.group.next())
hl.bind("ALT + BackSpace", hl.dsp.group.prev())
hl.bind("ALT + SHIFT + L", hl.dsp.group.move_window({ forward = true }))
hl.bind("ALT + SHIFT + H", hl.dsp.group.move_window({ forward = false }))
for i = 1, 10 do
    local key = i % 10
    hl.bind("ALT + SHIFT + " .. key, hl.dsp.group.active({ index = i }))
end

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 0%"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("changeAudio"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })

-- Quickshell
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc call status toggle"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call status toggle"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call status toggle"), { release = true })
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("qs ipc call player toggle"))

-- Screenshots
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("screenshot"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("screenshot -s"))

-- Other
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("pkill wofi || wofi --show drun"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'"), { locked = true })
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprshutdown -t 'Rebooting...' --post-cmd 'reboot'"), { locked = true })
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("pkill xdotool || autoclick"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("bemene-run"))

hl.bind(mainMod .. " + SHIFT + P", hl.dsp.submap("passthrough"), { description = "Moonlight Passthrough" })

hl.define_submap("passthrough", function()
    hl.bind(mainMod .. " + SHIFT + P", hl.dsp.submap("reset"), { description = "Exit Moonlight Passthrough" })
end)
