# simpod_client

The [Simpod](../../README.md) web dashboard — a Flutter web app that renders the
live simulator stream, sends input over a WebSocket, and drives device controls
through the CLI's HTTP API. It's the UI the `simpod` CLI serves at
`http://127.0.0.1:5210`, and the page users load when a shared session is
tunneled to them.

## What it does

- **Renders the live stream.** Decodes the helper's H.264/AVCC frames with the
  browser `VideoDecoder` (WebCodecs) onto a canvas (`AvccStreamRenderer`), with an
  MJPEG fallback. Stream format (auto/AVCC/MJPEG), FPS, bitrate, and quality are
  adjustable at runtime.
- **Sends input.** Forwards taps, swipes, pinches, hardware buttons, orientation,
  and keystrokes to the helper as `touch` / `pinch` / `button` / `orientation` /
  `key` WebSocket messages (`WebSocketService`).
- **Device controls.** Appearance, mock location, status-bar overrides, deep
  links, permissions, and accessibility toggles via the CLI HTTP API
  (`SimulatorControlService`).
- **Accessibility inspection.** Streams the live AX tree (`AxStreamService`) and
  draws an overlay that highlights element frames on top of the stream.
- **Device chrome.** Renders device bezels/chrome so the stream looks like real
  hardware.
- **Device selection & pairing.** Lists booted simulators, and gates LAN access
  behind a pairing/token auth flow (loopback is auto-trusted).

## Architecture

Clean-architecture layering, [Riverpod](https://riverpod.dev) for state, and
`go_router` for navigation:

| Layer | Path | Contents |
|---|---|---|
| Core | `lib/core` | Theme, shared widgets, services (`web_socket_service`, `simulator_control_service`, `ax_stream_service`), and utils (`ApiConfig`, `AvccStreamRenderer`, `SimulatorInputController`). |
| Data | `lib/data` | Remote data source, repository implementations, and models (`SimulatorChromeConfig`, `SimulatorDefinition`, `FingerIndicators`). |
| Domain | `lib/domain` | Repository interfaces and use cases (get devices, session, device/chrome definitions). |
| Presentation | `lib/presentation` | Feature screens — `home` (the simulator view + controls sidebar), `device_selection`, and `pairing` — each with its own notifiers/providers and widgets. |

Shared wire models (`SimpodSession`, `DeviceInfo`, `AXNode`,
`SimpodOrientation`, …) come from [`simpod_core`](../simpod_core).

## How it connects

`ApiConfig` resolves endpoints from the page origin. The dashboard calls the
CLI's JSON API on the preview port for control/device data, and opens a WebSocket
**directly to the helper** (`wsUrl`) for the live stream and input. In debug mode
it targets `:5210` and reads a token from `--dart-define=SIMPOD_TOKEN=...`; in a
release build it uses the served origin and port.

## Development

This is normally built and embedded by the repo's `./build.sh`. To iterate on it
standalone against a running CLI:

```sh
# Start the CLI/preview server first (from packages/simpod), then note the
# token it prints. From this package:
cd packages/simpod_client
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=SIMPOD_TOKEN=<token-the-cli-printed>
```

Running on a separate origin (`:8080`) from the CLI (`:5210`) is why the debug
token is required — it authenticates the cross-origin requests.

```sh
flutter test   # run the widget/unit tests
```

## License

See [`LICENSE`](LICENSE).
