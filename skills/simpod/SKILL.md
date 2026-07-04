---
name: simpod
description: Drive a booted iOS Simulator from an agent with the `simpod` CLI — stream it to a browser, tap/swipe/type, send hardware buttons, rotate, read the accessibility tree, set appearance/location/status bar, open URLs, manage permissions, and tail logs. macOS only.
---

# simpod Agent Guide

simpod streams a **booted iOS Simulator** to a web browser and lets an agent
drive it: touch, type, hardware buttons, rotation, GPS, status bar, appearance,
permissions, and accessibility inspection. It is **macOS only** — it shells out
to `xcrun simctl` and a native Swift helper that uses private CoreSimulator APIs.
There is no Android support.

Use the **CLI** for automation and the **browser UI** for live human visibility.

## When to use

- The user wants an agent to **tap, swipe, type, or send hardware buttons** to a running iOS Simulator.
- The user wants to **stream a simulator** to a browser (local or LAN) for review or remote control.
- The user wants to **read the accessibility tree** to find UI elements without pixel-hunting.
- The user wants to **rotate the device**, **set appearance** (light/dark), **mock GPS**, **override the status bar**, **open a deep link**, or adjust **Dynamic Type / contrast**.
- The user wants to **grant/revoke/reset app privacy permissions** or **tail the system log**.

## When NOT to use

- Android emulators → use `adb` tooling.
- Building or installing an app → use `xcodebuild` / `xcrun simctl install`.
- Real iOS hardware devices → use `xcrun devicectl` or Xcode.
- Editing the simpod monorepo itself (protocols, packages, build) → that is a
  development task; see `references/` for the codebase docs, not this guide.

## Prerequisites

Verify these on the first invocation in a session. If something is missing, tell
the user exactly what to install — do not proceed.

| Requirement | Check | Why |
|---|---|---|
| macOS 14+ | `sw_vers -productVersion` ≥ 14 | The native helper requires it. |
| Xcode CLI tools | `xcrun --version` exits 0 | `simctl` drives the simulator. |
| A booted simulator | `xcrun simctl list devices booted` | Most commands need one. |
| `simpod` on PATH | `simpod --version` | The released binary, or run from source (below). |

If no simulator is booted, simpod will boot the first available one, or you can
boot a specific device with `xcrun simctl boot <UDID>`.

**Running from source** (no released binary):
`dart run packages/simpod/bin/simpod.dart` replaces the `simpod`
command (any working directory). The compiled `build/simpod` (built by
`./build.sh`) runs from anywhere.

## Mental model

```text
┌──────────────┐  capture+HID  ┌─────────────────────┐  HTTP/WS  ┌─────────┐
│ iOS Simulator│ ◀───────────▶ │ simpod-helper-bin    │ ◀──────▶ │ Browser │
└──────────────┘  (Swift,      │ (one per device,     │   live   └─────────┘
                  private API) │  :5400+)             │  stream
                               └─────────▲───────────┘
                                         │ spawns + proxies
                               ┌─────────┴───────────┐
                               │ simpod CLI / preview │  http://127.0.0.1:5210
                               │ server (:5210)       │
                               └─────────────────────┘
```

Invariants to respect:

- **All touch coordinates are normalized `0..1`**, `(0,0)` top-left, `(1,1)`
  bottom-right. Never pass pixel coordinates.
- **One helper per device.** Multiple booted simulators are supported; target one
  with `-d <udid|name>`.
- **Preview server defaults to `http://127.0.0.1:5210`**; helpers listen on
  `5400+`. The browser connects directly to the helper's WebSocket for the live
  stream and input.
- **Orientation set via `rotate` is remembered by the helper**, and later gestures
  are rotated accordingly — you don't compensate manually.
- **State lives under `$TMPDIR/simpod/`** (session + pid files). Query it with
  `simpod --list`; don't read the JSON directly.

## Start the server

Run `simpod` first; it starts (or reuses) the preview server and streams the
target device. Pass a device name or UDID to target a specific simulator.

```bash
simpod                       # foreground: stream + web UI, blocks until Ctrl+C
simpod --detach -q           # background: returns JSON immediately (agent loops)
simpod --no-preview          # stream to the terminal, no web UI
simpod -p 5211               # use a non-default preview port
simpod --host 0.0.0.0        # expose on the LAN (enables device pairing)
simpod "iPhone 16 Pro"       # target a device by name
simpod -d <UDID>             # target a device by UDID
simpod --list                # list running sessions (add -q for JSON)
simpod --kill                # stop all sessions + detached preview servers
simpod --kill -d <UDID>      # stop one device's session
```

Example `simpod --detach -q`:

```json
{"pid": 91285, "url": "http://127.0.0.1:5210"}
```

Read the per-device session details (helper port, `wsUrl`, …) with
`simpod --list -q` once the server is up.

**Device resolution** when you don't name one: explicit `[device]` (by UDID or
name) → else the first booted simulator → else boot the first available one.

Foreground `simpod` blocks until Ctrl+C and tears down the helpers it started.
For agent loops use `--detach` and stop with `--kill` — not Ctrl+C.

### LAN pairing

When bound to `0.0.0.0`, loopback is auto-trusted but other devices must pair.
Run **`simpod pair`** to print the access token, the pairing deep link
(`http://<lanIP>:5210/pair?t=<token>`), and a scannable **QR** of it — scan it
(or paste the token on the pairing screen) to authorize a new device.
`simpod pair --reset` rotates the token; `-q` emits JSON. The token is
persistent across runs. Loopback (`127.0.0.1`) needs no pairing.

## Show the stream in your agent's preview

When the user asks to "see the simulator here" / "show it in preview":

1. Start detached and capture the URL: `simpod --detach -q` → read the `url`
   field (`http://127.0.0.1:5210`).
2. **Always surface the URL plainly** so the user can open it in any browser.
3. **Probe your host's preview tool** and hand off the URL if one exists
   (`preview_start`, `mcp__Claude_Preview__preview_start`, a `browser_open` /
   `open_url` tool, …). If none is available, print the URL and tell the user to
   open it themselves.
4. **Do not assume a specific preview tool exists.** Inspect the tools available
   in the session.

Multiple clients (host preview + the user's browser) can read the same URL at
once. The stream stays alive until `simpod --kill`.

## Device and app lifecycle

```bash
simpod devices                       # simulators + boot state (compact JSON with -q)
simpod boot <UDID>                   # boot + attach a helper, returns the session
simpod shutdown -d <UDID>            # shut down + detach
```

Build and install apps with project tooling / `xcrun simctl install`; simpod
focuses on driving an already-booted device.

## Inspect the UI (accessibility tree)

The fastest way to find elements without pixel-hunting. simpod reads the
simulator's accessibility tree (private CoreSimulator AX bridge).

```bash
simpod describe                      # whole-screen AX tree (JSON)
simpod describe --point 0.5 0.5      # only the element under a normalized point
```

Each node carries a `label`/`title`/`identifier`, `role`, and a device-point
`frame` (`frameX/Y/Width/Height`). To tap a node, take its frame center and
normalize against the device's screen size (root node frame), then `simpod tap`.

**Guard pattern:** if you fetched the AX tree to locate a target and found no
match, **fail loudly** — report "target not found" rather than tapping a guessed
coordinate.

## Interact

Coordinates are normalized `0..1`. Prefer the AX tree to locate targets; use raw
coordinates only when you must.

```bash
simpod tap 0.5 0.5                    # single tap
simpod gesture '{"type":"touch","data":{"phase":"begin","x":0.2,"y":0.8}}'   # multi-step: thread begin→move→end
simpod type 'hello world'            # type into the focused field (US keyboard)
simpod button home                   # hardware button (default: home)
simpod button app_switcher
simpod button lock
simpod button side_button
simpod button siri
simpod rotate landscape_left         # portrait | portrait_upside_down | landscape_left | landscape_right
simpod rotate-left                   # quarter-turn helpers
simpod rotate-right
```

For drags/swipes and pinches, use `gesture` and thread a single sequence
(`begin` → `move` × N → `end`) with normalized coordinates and an optional
`edge` for screen-edge pulls. Use `tap` for plain taps — don't synthesize a tap
from separate `gesture` begin/end calls. Full gesture shapes and recipes are in
`references/gestures.md`; the button/orientation vocabulary is in
`references/buttons-and-rotation.md`.

## Device state and environment

```bash
simpod appearance dark               # set light | dark appearance
simpod accessibility                           # print all current accessibility values
simpod accessibility --text-size increment     # Dynamic Type: increment | decrement | <size>
simpod accessibility --contrast                # Increase Contrast on (--no-contrast for off)
simpod accessibility --reduce-motion           # Reduce Motion on (--no-reduce-motion for off)
simpod accessibility --reduce-transparency     # Reduce Transparency on (--no-... for off)
simpod accessibility --show-borders            # Show Borders on (--no-show-borders for off)
simpod open-url myapp://route        # open a deep link or https URL
simpod open-url https://example.com
simpod location 37.3349 -122.0090    # mock GPS (latitude longitude)
simpod status-bar --battery 80 --time 9:41   # override the status bar
simpod status-bar --clear            # clear all status-bar overrides
simpod permissions grant photos com.example.App   # grant | revoke | reset <service> [bundle]
```

## Evidence

```bash
simpod logs                          # tail the simulator system log (Ctrl+C to stop)
simpod logs --seconds 30             # bounded capture
simpod screenshot -o out.png         # PNG screenshot (-q prints {"path": ...})
simpod bezel -o frame.png            # device bezel/chrome PNG (needs a session)
```

For recordings, capture from the live stream URL or use
`xcrun simctl io <UDID> recordVideo`. Prefer `describe` for token-efficient
state checks over re-screenshotting every step.

## Default loop

1. Start the server (`simpod --detach -q`), hand the URL to a preview tool if one
   exists, and confirm/boot the target device.
2. Run one `simpod describe` to understand an unfamiliar screen.
3. Locate targets via the AX tree; tap by selector-derived coordinates, falling
   back to raw normalized coords only when needed.
4. Verify the specific element/text that proves the step worked — don't re-dump
   the whole tree after every action.
5. Tail `simpod logs` only when you need to diagnose.
6. Stop with `simpod --kill` when finished, unless the user wants it left running.

## Anti-patterns

- **Don't pass pixel coordinates.** Everything is normalized `0..1`. If given
  pixels, divide by the device screen size from the AX root frame.
- **Don't use `gesture` for a plain tap.** Use `tap`; split begin/end gestures can
  register as a long-press.
- **Don't assume a server is already running.** Verify with `simpod --list`; start
  it explicitly if absent.
- **Don't guess coordinates when an AX lookup returns nothing.** Report
  "target not found".
- **Don't skip the prerequisites check** on first use — wrong macOS version, no
  Xcode CLI tools, or no booted simulator produce confusing downstream errors.
- **Don't parse human output** in loops — pass `-q` for JSON.
- **Don't leave orphan servers** across unrelated tasks; `simpod --kill` frees the
  ports and helpers.
- **Don't expose the server publicly.** `--host 0.0.0.0` is for trusted LAN +
  pairing only.

## Reference

Agent-usage references — load the one for the area you're driving:

- `references/gestures.md` — coordinate system, the `hid_input` frame shape, single/multi-touch, edge values, recipes, why `tap` beats `gesture`.
- `references/buttons-and-rotation.md` — the valid button names and orientations, with behavioral gotchas.
- `references/workflows.md` — end-to-end recipes (AX-driven tap, deep-link verify, clean screenshot, preview handoff, clean slate, reliable drags).
- `references/endpoints.md` — the HTTP API and the `/ws` protocol for agents that bypass the CLI, plus the auth/pairing handshake.

For simpod's own internals (packages, ports, protocols, build), see the repo
`README.md` and the `packages/` source.

See `evals/` for behavior checks an agent using this skill should pass.
