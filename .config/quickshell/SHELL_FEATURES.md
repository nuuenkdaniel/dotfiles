# Notifications, display and privacy indicators

For the on-demand Arch-logo dashboard and its settings, see [DASHBOARD.md](DASHBOARD.md).

Hover hints use rounded dark-purple cards with lavender borders and plain,
wrapping text rather than the platform's default yellow tooltip. Hover the
sidebar weekday/date for a read-only current-month calendar with today highlighted.
The calendar appears after a short delay, does not take focus or intercept clicks,
and unloads when hidden. It reuses the existing clock's date updates; no additional
repeating calendar timer or background service is added.
All sidebar and dashboard clocks share a minute-aligned native clock.

These features are independent of the optional Battery power-profile feature.
The Battery uninstaller keeps them, including their settings tabs.

## Notification history (no DND)

- Open **Settings → Notifications**. There is no permanent notification icon in the sidebar.
- The latest 100 notifications are saved, including their original app name,
  title, message and timestamp. Search, remove individual entries, or clear all.
- App notification replacements update their history entry instead of adding
   duplicates. Messages are rendered as plain text, not executable markup.
- Hot reload retains notification identity and timestamps without duplicating
  history or making retained entries unread again. Expiry uses one deadline per
  notification, pauses on hover, and does not run a repeating countdown timer.
- Notification icons are limited to local files/resources and icon-theme names;
  app-provided remote/data icon URLs are not fetched.
- A click can invoke an app-provided action only while the original notification
  is still alive. Expired or previous-session entries remain readable; old
  action identifiers are not replayed against unrelated notifications.
- History is stored at
  `$XDG_STATE_HOME/quickshell/notifications/history.json` (defaults to
  `~/.local/state/quickshell/notifications/history.json`). The directory is
  created with mode 0700. Notification bodies can contain private information;
  clearing history removes them from this file, not from backups or other apps.

## Battery alerts

While discharging, warn at **20%, 15%, 10%, 5%, and 0%**. A large drop sends only
one current warning, not a burst of missed thresholds. A threshold is not repeated
if the battery percentage fluctuates, and warnings stop/reset when plugged in.
Battery checks run at startup and on UPower battery/charger updates, without
an additional repeating battery-check timer. The lowest warned band is stored in the user runtime directory, so reloading
Quickshell does not immediately repeat it. At 5% or less the notification is
critical. There is no automatic suspend, shutdown, or DND behavior.

## Microphone and screen-capture indicators

- A red microphone icon appears when the **default PipeWire input** is muted.
  Clicking it unmutes that input. It is not a hardware microphone-activity meter
  and does not assert that every input or application-specific microphone is muted.
- `XF86AudioMicMute` toggles the default input. `XF86AudioMute` now correctly
  toggles speaker mute rather than setting speaker volume to zero.
- A red capture icon appears for sustained capture activity reported by Hyprland
  screencast IPC events. Click it
  for diagnostics. Transient captures shorter than 300 ms do not flash the icon.
- Detection listens to **events only**, not pixels or recordings. Capture bypassing
  Hyprland, browser-tab-only sharing and captures started before the
  shell may not be detected.
  Missing indicators are not a guarantee that nothing is recording. Camera-only
  streams are not labeled as screen capture.
- There is no `pw-dump` observer or background capture-monitor process. No capture
  log or target list is persisted. Events missed during reload cannot be reconstructed.

## Display, connectivity, diagnostics

- **Display** provides a live brightness slider and preset percentages. It shares
  the brightness backend with the OSD and follows hardware-key changes. It does
  not add monitor mode, GPU tuning, external DDC, or new privileged controls.
  Brightness is read once at startup, on key-triggered OSD display, and while
  a brightness control/OSD is visible—not continuously while hidden. External
  changes made with no visible controls are reflected the next time one opens.
- Bluetooth rows show battery percentage only when BlueZ reports it.
- The sidebar Wi-Fi and Bluetooth popups each include a radio on/off switch.
  The switch stays available when the radio is off, and missing adapters or a
  hardware Wi-Fi block are shown explicitly. Existing Settings switches remain.
- One transparent outside-click window is present per monitor while a sidebar
  menu is open; only the originating monitor renders menu content. Clicking
  outside on another monitor closes it too. Menus are screen-bounded, scrollable,
  and support arrow keys, Enter, Escape, tray submenus and check states. First
  opening snaps vertically into place and slides out horizontally in 200 ms;
  switching open menus on the same monitor morphs width, height and vertical
  position together with a 500 ms eased transition. Rapid switches retarget from
  the current size; submenus and live updates also resize smoothly once open.
  Width adapts to labels within screen limits, and overflowing rows remain clipped
  and scrollable throughout the transition.
  Transparent inverted shoulders join the popup to the bar without a dark divider.
- Radio/audio menus follow native property changes instead of refresh timers.
  Clicking an unknown WPA/WPA2/WPA3-Personal network opens Wi-Fi settings with
  that exact network selected and its masked password field focused. Enter the
  password and press Enter or Connect. Missing/incorrect passwords offer a retry;
  Cancel, closing settings, or losing the network clears the input. Credentials
  go directly through the native networking API; the shell does not save them or
  put them in command arguments. NetworkManager may remember them for future
  connections. New enterprise networks still require system configuration for
  their username/certificate settings; they are never sent a personal-network PSK.
  Existing saved networks continue to use their stored connection profiles;
  wired entries are explicitly read-only connection status, not fake actions.
- Discovery rows retain their objects and focus when sorting changes. Settings
  pages load on first visit and remain instantiated to preserve drafts.
- Clicking a network row in the Wi-Fi tab expands its SSID, signal, security,
  interface, IP addresses, gateway and DNS. NetworkManager is queried only while
  a connected network's details are open. Disconnected networks show only their
  own network information, never another connection's IP settings. Connect and
  Disconnect remain separate buttons. IP addresses and credentials are not saved here.
- **About** shows software versions, read-only service/tool availability,
  indicator coverage and notification-storage errors. **Copy diagnostics** copies
  only that report; it does not include Wi-Fi passwords, IP addresses, hardware
  serial numbers, notification bodies or full configuration files.

No packages, root permissions, or recording software are installed for these
features. They use the existing UPower, PipeWire, BlueZ, NetworkManager, Hyprland,
Python, brightnessctl and notify-send components. Background power automation
uses UPower change events; full Battery state refreshes only while that tab is open.

## Standalone media player

The existing player IPC and appearance are retained. Player selection uses one
filtered list, keeps Plasma browser integration instead of its native browser
duplicates, and recovers when players disappear. Pausing a different player no
longer steals the selection.

Position updates, wave animation and new artwork work are gated on presentation,
including the closing transition. HTTP(S) artwork uses an argument-vector helper
with a 15-second transfer timeout, 8 MiB limit, restricted redirects, and atomic
cache publication. Cancelled transfers are not treated as complete cache entries.
Only recognized artwork cache files are pruned (64 covers / 128 MiB); unrelated
files and symlinks are untouched, and importing the player no longer deletes any
cache trees or creates unrelated AI/media directories. Existing player/theme
preferences remain at their original location for compatibility.

Qt must support the source image format to display artwork. WebP requires the
distribution's Qt image-format plugin package; this configuration does not
install packages or convert images automatically.

Tests: `python3 -B -m unittest discover -s tests`. The pure-JS logic tests use
Node if available and skip otherwise; Node is not a runtime shell dependency.
