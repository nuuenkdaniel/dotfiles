# Battery settings

Open the sidebar gear, then **Battery**. Reading battery state and editing
preferences do not require administrator access. No saving preferences or
automatic rules are enabled by default.

## One-time setup

Use **Open setup terminal…** in the Battery tab, or run:

```sh
bash ~/.config/quickshell/bin/setup-power.sh
```

The setup installs/enables `power-profiles-daemon` and installs a root-owned
copy of `bin/power-control.py` at
`/usr/local/libexec/quickshell-power-control`. It refuses to continue with an
active or enabled TLP, tuned, or auto-cpufreq service. Do not run multiple policy managers.
Installing/starting the daemon may apply its default or remembered profile.
Setup does not set charging thresholds or manual CPU limits.

Setup also installs `/usr/local/libexec/quickshell-boost-control` and a dedicated
Polkit action/rule. Only the installing user in an **active local session** may
toggle boost without a password. The boost-only executable accepts exactly one
argument (0 or 1) and can only write Intel's `no_turbo` switch. It cannot change
CPU performance limits, charging settings, or arbitrary files. Existing installs
must rerun setup once; the original hardware baseline is preserved.

Managed permission files:
- `/usr/share/polkit-1/actions/org.local.quickshell.power.boost.policy`
- `/etc/polkit-1/rules.d/49-quickshell-boost.rules`

Both permission files and the boost executable are tracked for uninstall.

Before starting the daemon for the first time, setup saves a root-owned baseline
at `/var/lib/quickshell-power/install.json`: CPU limits, CPU governor/energy
preferences, firmware profile, charging mode/thresholds, existing profile, and
whether the package/service were already present/enabled/running. Rerunning setup
does not overwrite this original baseline.

## Uninstall / restore original settings

Use **Cleanup / uninstall Battery feature…** at the bottom of the tab, or run
as your normal user (not with sudo):

```sh
bash ~/.config/quickshell/bin/uninstall-power.sh
```

The script describes its scope and requires typing `REMOVE`. It:

1. Disables this feature's automation and restores tracked display, brightness,
   keyboard-light, and compositor changes without overwriting detectable later edits.
2. Restores the previous power profile and original service enable/running state.
3. Restores CPU settings and both active charging mode and stored thresholds
   from the pre-setup baseline, including thresholds when the original mode was Fast.
4. Removes `power-profiles-daemon` **only if setup originally installed it**,
   using `pacman -R` (no recursive removal of other packages or dependencies).
5. Removes both protected executables, the tracked boost Polkit policy/rule,
   and its system baseline.
6. Removes the Battery tab, backend, preferences, session files, battery tests,
   documentation, and its own setup/uninstall scripts. All other tabs, OSDs,
   notifications, and Hyprland configuration remain.

If you want to keep the now-disabled menu/source, pass `--keep-tab`. To check
only the source-removal markers without changing anything, use `--check`.

Cleanup stops on failed restoration or package removal and keeps the baseline
and helper when possible so you can investigate/retry. It refuses to guess
hardware settings for older installations that have no original baseline.
It removes only specifically named files; no broad recursive deletion is used.

The uninstaller itself has not been run against the live installation during
development. Automated tests and `--check` exercise cleanup safety without
removing your feature.

There is no passwordless sudo rule, custom unrestricted Polkit policy, or
root Quickshell process. CPU performance-limit and charging writes invoke the
fixed helper with `pkexec`, using normal administrator authentication. Boost-only
writes use the narrowly scoped permission described above. Only the
fixed BAT0 charging controls and Intel boost/performance-limit paths are
writable through that helper; arbitrary paths and commands are not accepted.

## Mode switching and presets

- **Performance** requests the daemon's performance profile, when supported.
- **Balanced** is the normal everyday mode (`balanced`).
- **Power saving** requests `power-saver` and applies a fixed recommended preset:
  lower screen brightness to at most 40% on entry without increasing it, and
  select a supported 60 Hz display mode. It also disables CPU turbo boost using
  the protected helper, preserving the previous boost state and maximum-performance
  limit for restoration. After installing the scoped permission, boost toggles
  do not require passwords in the installing user's active local session.
  Keyboard lighting and visual effects
  remain user-controlled. This preset's supported 60 Hz mode stays active without
  a confirmation timer, until another mode is selected.
  Brightness is a one-time adjustment, not a continuously enforced ceiling.
- **Custom** uses a saved base profile and separate preferences. Only Custom
  exposes the display/keyboard/effects and advanced CPU tuning controls. Saved
  edits take effect on selecting Custom or clicking **Apply Custom**. The
  brightness-now slider and keyboard buttons apply immediately and save their
  values for the next Custom selection.
- The sidebar shows a small green leaf alongside its unchanged battery icon
  whenever the actual system profile is `power-saver`, including an externally
  selected profile or a Custom configuration based on it. Battery charge level,
  low-charge colors, and the charging glyph remain visible. The badge uses
  Quickshell's native PowerProfiles updates rather than background polling.
- Brightness caps never raise the current brightness.
- Switching modes restores values that the previous preset changed, but only if their current
  value still matches what the preset applied. It does not overwrite later
  manual changes that are detectable from the current value.
- External profile changes are observed through native PowerProfiles events even
  when automatic switching is disabled. They reconcile tracked overrides before
  any automation evaluation and pause automatic rules until a plug/unplug event.
  Background reconciliation never opens an administrator prompt; protected CPU
  recovery records remain available for an explicitly authorized manual action.
- Display mode changes preserve the detected resolution, position, scale,
  transform, VRR, and bit depth. A **Custom** 60 Hz preview requires confirmation within
  15 seconds. An independent watchdog restores the previous mode if the menu
  or shell exits. Monitor hotplug/layout changes invalidate automatic restoration.
- Reduced effects temporarily disable Hyprland blur, shadows, and animations.
  No Hyprland configuration file is edited.

## Advanced controls

CPU boost and maximum-performance controls are optional **Custom** overrides.
They require Apply Custom. CPU performance-limit changes and restoration still
require administrator authorization; boost-only changes use the scoped local
permission. The pre-Custom values are tracked and restored on switching modes.
Background rules check authorization without requesting interaction: boost-only
changes may run automatically when permitted, while performance-limit restoration
or unavailable boost permission requires explicit manual selection. They do not
set energy-performance preference (EPP), which belongs
to the profile daemon. Firmware and profiles may further constrain effective
performance. A performance percentage is not a CPU-utilization or wattage percentage.

Charging controls show the active mode and stored custom thresholds separately.
Only Custom mode uses those thresholds. The UI validates start 50–95%, stop
55–100%, and a gap of at least 5%. The helper checks firmware readback and
attempts to restore prior settings if a write fails. Firmware may impose
additional restrictions. These settings can persist across reboots and are
not reset by selecting Normal or removing the shell.

Automatic switching is opt-in and reacts to UPower battery and charger updates,
including an evaluation when rules are enabled. There is no closed-menu polling
timer. Full state refreshes every 2 seconds only while the Battery tab is open;
brightness is read every half-second while that tab is open. Read-only refreshes do not lock
the controls. A manual selection pauses rules until the next detected plug/unplug;
low-battery recovery has a 5% margin. Suspend naturally pauses checks; they
resume when the shell runs again. No background rule runs with Quickshell off.
Brightness shares the Display/OSD reader instead of starting a second poller.
Slow-changing profiles/helper/permission information is cached for up to a minute
and invalidated when installation files change. This cache is for display only:
background operations still perform a fresh authorization check. Worker startup
failures release the action queue and surface an error instead of leaving it busy.
Actions that might require authorization conservatively release the Settings
overlay's keyboard focus, independently of cached permission information.

## Files and recovery

- Preferences: `~/.config/quickshell/battery-preferences.json`
- Original/applied temporary values: `~/.local/state/quickshell/power-session.json`
  (honors `XDG_CONFIG_HOME` and `XDG_STATE_HOME`). Session data is boot-scoped.
- Protected helper: `/usr/local/libexec/quickshell-power-control`

To request Balanced and restore tracked temporary settings from a terminal:

```sh
python3 ~/.config/quickshell/bin/power.py mode balanced
```

To revert an unconfirmed display change immediately:

```sh
python3 ~/.config/quickshell/bin/power.py revert-display
```

For a manual CPU limit, use the Battery tab to restore the values noted before
editing; the initial observed values on this laptop were boost allowed and
maximum performance 100%. Do not assume those are appropriate on another system.

Battery and health readings come from UPower and firmware, not a calculated
battery-life promise. This implementation does not change fan curves, voltage,
GPU clocks, core topology, wireless state, or kernel boot parameters.
