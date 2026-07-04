
<p align="center">
  <h1 align="center">Simpod</h1>

  <p align="center">
    Simpod streams a booted <b>iOS Simulator</b> to the browser and drive it — from your IDE, an
AI agent (Claude Code, Cursor, Codex), or the <code>simpod</code> CLI.
  </p>
</p>

<hr/>

![Codex Screenshot](./assets/codex-screenshot.png)

## Install

Requires macOS 14+, Xcode command-line tools (`xcrun simctl`), and a booted
simulator.

```sh
dart pub global activate simpod
simpod
```

The package embeds the native helper and the web dashboard, so no extra
downloads are needed. Alternatively, build the self-contained `build/simpod`
binary with `./build.sh`, or run from source (below).

```sh
simpod
# → Preview at http://127.0.0.1:5210
```

Simpod spawns a small native Swift helper that captures the simulator's
framebuffer (VideoToolbox H.264 / MJPEG), injects HID input, and reads the
accessibility tree. A Dart CLI orchestrates the helpers and serves a Flutter web
dashboard on top. It works with any booted simulator — no Xcode plugin, no
in-app instrumentation.

## Features

- Low-latency 60 FPS stream in the browser (H.264/AVCC with an MJPEG fallback).
- Full control: tap, swipe, pinch, type, hardware buttons, rotation.
- Accessibility inspection — read the live AX tree to find elements by label, and
  an in-browser overlay that highlights element frames.
- Device controls: light/dark appearance, mock GPS, status-bar overrides, deep
  links, privacy permissions.
- Live simulator system logs forwarded to the browser (and to agents).
- Device bezels/chrome rendered from CoreSimulator assets.
- Loopback is auto-trusted; LAN devices pair with a printed QR / token.
- An **Agent Skill** that teaches AI agents the stable simpod workflow.


## CLI

```
simpod [device...]                 Start the stream + web preview (default :5210)
simpod --detach -q                 Spawn in the background, print JSON, return
simpod --no-preview                Stream in the terminal, no web UI
simpod --list [-q]                 List running sessions
simpod --kill [-d <udid>]          Stop all sessions (or one device)

simpod tap <x> <y>                 Tap (normalized 0..1 coords)
simpod gesture '<json>'            Multi-step touch/pinch sequence
simpod type '<text>'               Type into the focused field (US keyboard)
simpod button [name]               home | app_switcher | lock | side_button | volume_up | volume_down | siri
simpod rotate <orientation>        portrait | portrait_upside_down | landscape_left | landscape_right
simpod rotate-left | rotate-right  Quarter-turn helpers

simpod boot <udid> | shutdown      Lifecycle
simpod appearance light|dark       Set appearance
simpod open-url <url>              Open a deep link / https URL
simpod location <lat> <lon>        Mock GPS
simpod status-bar --battery <n> --time <hh:mm> | --clear
simpod permissions <grant|revoke|reset> <service> [bundle]
simpod describe [--point <x> <y>]  Dump the accessibility tree (JSON)
simpod logs [--seconds <n>]        Tail the simulator system log

Options:
  -p, --port <port>   Preview server port (default 5210; helpers use 5400+)
      --host <host>   Bind interface (0.0.0.0 exposes on the LAN)
  -d, --device <udid> Target a specific simulator
  -q, --quiet         JSON-only output
```

### Examples

```sh
simpod                                  # auto-detect a booted sim, open preview
simpod "iPhone 16 Pro"                  # target a device by name
simpod --detach -q                      # background server, returns JSON

simpod tap 0.5 0.5                      # tap center
simpod type "Hello, world!"             # type into the focused field
simpod button home                      # go home
simpod rotate landscape_left            # rotate
simpod appearance dark                  # dark mode
simpod open-url "myapp://checkout"      # deep link
simpod describe | jq                    # inspect the UI

simpod --kill                           # stop everything
```

Coordinates are normalized `0..1`, `(0,0)` top-left. Device resolution when you
don't name one: explicit device → first booted → boot the first available.

## Agent Skill

An Agent Skill ships in
[`skills/simpod`](https://github.com/cscoderr/simpod/blob/main/skills/simpod/SKILL.md).
It teaches AI coding agents how to drive a simulator through the CLI — taps,
gestures, hardware buttons, rotation, accessibility-driven taps, device controls,
and handing the stream off to the host's preview pane. See the reference docs
under
[`skills/simpod/reference/`](https://github.com/cscoderr/simpod/tree/main/skills/simpod/reference)
for gestures, buttons & rotation, end-to-end workflows, and the HTTP/WebSocket
endpoints.

## How it works

```
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

The browser connects **directly** to a helper's WebSocket (`wsUrl`) for the live
stream and input; the CLI's preview server serves the dashboard and gates a JSON
API. State (sessions, pid files) lives under `$TMPDIR/simpod/`.

## Packages

| Package | Lang | Role |
|---|---|---|
| `packages/native` | Swift 6 | `simpod-helper-bin`: frame capture/encode, HID injection, AX tree, bezel rendering, HTTP/WS server. One process per device. |
| `packages/simpod` | Dart | The `simpod` CLI + preview server: spawns/tracks helpers, serves the dashboard, gates the HTTP API. |
| `packages/simpod_client` | Flutter web | The dashboard: renders the stream, sends input over WebSocket, calls the API. |
| `packages/simpod_core` | Dart | Shared models (`SimpodSession`, `DeviceInfo`, `AXNode`, `SimpodOrientation`, …). |

## Development

Run from source (no released binary), iterating on each layer:

```sh
# 1. Build the native helper and stage it where the CLI loads it from
swift build -c release --package-path packages/native
cp -f packages/native/.build/release/simpod-helper-bin packages/simpod/lib/bin/

# 2. Run the CLI / preview server (MUST run from the package root; boot a sim first)
cd packages/simpod && dart pub get
dart run bin/simpod.dart          # preview UI at http://127.0.0.1:5210

# 3. Iterate on the web client (separate origin → pass the debug token)
cd ../simpod_client
flutter run -d chrome --web-port=8080 --dart-define=SIMPOD_TOKEN=<token-the-cli-printed>
```

`./build.sh` (repo root) runs the full release pipeline: swift build → copy bin →
`flutter build web --wasm` → embed assets → `dart compile exe -o build/simpod`. The
output embeds the helper + web build and self-extracts on first run, so it works
from any directory.

## License

See [`LICENSE`](LICENSE).
