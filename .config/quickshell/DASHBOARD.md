# Dashboard

Click the Arch logo above the workspace capsule, or press **Super + Shift + D**,
to toggle the top-centered dashboard (the shortcut uses the focused monitor).
Click outside, click the logo again, press the shortcut again, or press Escape
to close it. Its frame appears only while open and does not reserve screen space.
The purple surface has real transparent concave shoulders, rounded lower corners,
and an elastic slide. It does not depend on Caelestia or its compiled plugins.

## Pages

- **Dashboard:** weather, actual OS/session/uptime, local avatar (or initial),
  clock, Monday-first month calendar, and compact CPU/RAM/filesystem meters.
- **Performance:** CPU usage, used/total RAM, and selected filesystem used/total.
  CPU starts as “Sampling…” until there are two actual counter samples.

The calendar is a date calendar, not an appointments or event-calendar service.
System identity is refreshed on opening; uptime is an opening-time snapshot.

## Settings → Dashboard

Dashboard configuration is available only through the main Settings menu; there
is no dashboard gear or Media page. Opening Settings closes the dashboard and
opening the dashboard closes Settings on that screen.

- Weather is disabled until configured. Search a city/postal code and explicitly
  choose a result. Set Celsius/Fahrenheit or disable weather at any time.
- **Startup auto-location** is enabled for this setup and can be switched off.
  When weather is enabled, it makes at most one IP-based city lookup per Quickshell
  process, using `https://ipapi.co/json/`. The provider sees your public IP; the
  shell saves only the city label and coordinates, not the returned IP or profile.
  Opening the dashboard, hot reloads, reconnects, and VPN changes do not repeat it.
- Before the request it checks active NetworkManager connection types, kernel
  interfaces, IPv4/IPv6 policy rules, default routes, and proxy environment variables.
  Ordinary Tailscale mesh is exempted only after verifying no exit node is selected
  and that Tailscale's routes are private/mesh routes. An exit node, another VPN,
  uncertain checks, a missing tool, or an offline start leaves the saved location
  untouched. This deliberately skips some unusual but otherwise valid networks.
  There is no attempt to bypass a VPN or disable network services.
- Checks are repeated after the lookup; a changed network discards the result.
  This cannot eliminate the brief check/request race or identify every unusual
  VPN/proxy setup. IP-based city estimates can also be inaccurate. Manual city
  selection remains available and wins over an in-flight automatic lookup.
- Search sends the entered city to Open-Meteo's geocoder (GeoNames data).
  Forecast requests send the selected coordinates to Open-Meteo. There is no
  GPS lookup, API key, or location-permission service. IP geolocation is used only
  by the optional startup check described above.
- Weather is fetched on opening, with a 30-minute disk cache. No repeating weather
  timer. On a failed refresh, same-location cached data is marked as cached;
  another location's weather is never substituted. Hover for the update timestamp.
- Choose an available local filesystem, default `/`. No remote mount scanning or
  adding together partitions that might share underlying storage.
- An optional absolute local avatar path overrides `~/.face`. Missing artwork
  falls back to the user initial. No avatar download is performed.
- Reduced motion replaces the elastic entrance with a short slide/fade.

Preferences are stored in
`$XDG_STATE_HOME/quickshell/dashboard/settings.json`, defaulting to
`~/.local/state/quickshell/dashboard/settings.json`. The directory is created
with mode 0700. The weather cache lives at
`$XDG_CACHE_HOME/quickshell/dashboard/weather.json` (default `~/.cache`).

## Efficiency and isolation

Dashboard contents load when opening and unload after the closing transition.
The clock shares the sidebar's minute-aligned native clock rather than adding a
per-second timer. Settings pages load on first visit and preserve their state.
The window stays mapped and retains its last card values throughout closing;
reversing the animation does not hide or recreate its contents.
Resource reads stop immediately when closing. CPU and RAM are sampled every
two seconds while open, storage every 30 seconds; identity and storage are also
read on opening. No long-running monitor, root permission, packages, or permanent
resource history is introduced. An in-flight dashboard weather request is stopped
on closing. Explicit settings searches are separate and stop when that page closes.
The startup location check is intentionally independent of dashboard visibility;
it exits after its one attempt. Its per-process guard lives under
`$XDG_RUNTIME_DIR/quickshell-dashboard/`, so a hot reload cannot repeat the lookup.
Disabling weather or auto-location cancels an in-flight startup check. There are
no location timers, retries, watchers, or tracking histories.

Existing sidebar indicators, notifications, brightness OSD, Battery settings and
hardware configuration remain independent. The Battery feature uninstaller keeps
the dashboard and its settings.

Optional IPC:

```sh
quickshell ipc call dashboard toggle
quickshell ipc call dashboard close
quickshell ipc call dashboard tab 0  # 0 Overview, 1 Performance
quickshell ipc call dashboard settings
```

Tests: `python3 -B -m unittest discover -s tests`.
