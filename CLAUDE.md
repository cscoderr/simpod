# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Simpod streams and remotely controls booted iOS Simulators from a browser, terminal, or AI agent. A Dart CLI spawns one native Swift helper per simulator; the helper captures the framebuffer, streams H.264 (MJPEG fallback), injects touch/keyboard input, and exposes the accessibility tree. Requires macOS 14+, Xcode CLT (`xcrun simctl`), and a booted simulator.

## Commands

```sh
flutter pub get                      # resolve the Dart workspace (run from repo root)

# Tests (run inside the package directory)
cd packages/simpod && dart test      # CLI tests
cd packages/simpod_core && dart test # shared-model tests
dart test test/services/helper_manager_test.dart          # single file
dart test -N "name substring"                             # single test by name

dart analyze packages/simpod packages/simpod_core          # lint (what CI runs)

# Native Swift helper
swift build --package-path packages/native                 # build
swift test --package-path packages/native                  # tests

# Flutter web dashboard
cd packages/simpod_client && flutter build web --wasm --release

./build.sh                           # full standalone binary -> build/simpod
```

For development you usually don't need `./build.sh`: run `dart run bin/simpod.dart` from `packages/simpod`. When embedded assets are absent it falls back to source paths — the helper binary at `packages/simpod/lib/bin/simpod-helper-bin` (produced by `swift build -c release` + copy, see build.sh steps 1–2) and the dashboard at `packages/simpod_client/build/web`.

## Architecture

Dart workspace (`pubspec.yaml` at root) with three Dart packages plus a SwiftPM package:

- **`packages/simpod`** — the CLI (`bin/simpod.dart`, commands in `lib/src/commands/`) and the preview HTTP server (`lib/src/server/simpod_http_server.dart`, shelf_router). Device discovery and control shell out to `xcrun simctl` (`lib/src/devices/`). `SimpodHelperManager` (`lib/src/services/helper_manager.dart`) spawns/kills helper processes; `SimpodSessionManager` persists per-udid session files (pid, port, urls, access token) so short-lived CLI commands can find running helpers.
- **`packages/native`** — Swift 6 executable `simpod-helper-bin` (Hummingbird HTTP/WS server, one process per simulator). Framebuffer capture via IOSurface, H.264 via VideoToolbox, JPEG encode, HID injection through private CoreSimulator/SimulatorKit interfaces, accessibility bridge, and device-bezel/chrome rendering.
- **`packages/simpod_client`** — Flutter web dashboard. Decodes H.264 with WebCodecs `VideoDecoder` (`lib/core/utils/avcc_stream_renderer.dart`), falls back to MJPEG.
- **`packages/simpod_core`** — models and protocol enums shared by CLI and client (`DeviceInfo`, `SimpodSession`, `AXNode`, orientation/touch-edge/key-event types).

### The helper protocol (the contract between all three sides)

The dashboard and CLI never touch the simulator directly — everything goes through the helper's port:

- HTTP: `GET /ping`, `/ax.json[?x=&y=]`, `/bezel.png`, `/chrome-button/:name`, `/chrome.json`.
- WS `/ws?format=&quality=&fps=&bitrate=`:
  - **outbound binary** video in a tag-length envelope (`Envelope.swift` / `avcc_stream_renderer.dart`): 4-byte BE length then tag — `0x01` avcC decoder config, `0x02` keyframe, `0x03` delta, `0x04` JPEG seed. MJPEG mode sends JPEG frames.
  - **inbound text** JSON: `{"wsType":"hid_input","type":"touch|button|pinch|key|orientation","data":{...}}` and `{"wsType":"describe_ui",...}`.

Changing this protocol means updating three places in lockstep: the Swift helper, the Flutter client, and any CLI command that speaks it.

### Embedded assets

`lib/src/gen/embedded_assets.g.dart` is a committed **stub**; `tool/embed_assets.dart` regenerates it with the real helper binary + web build gzipped inline for release compiles. Never commit the populated multi-MB version — `build.sh` restores the stub on exit via a trap.

### Helper process lifecycle gotcha

`HelperSpawnMode` matters: short-lived CLI commands must use `detached` (holding the helper's stdio pipes from a process that exits leaves them undrained and eventually blocks the helper); only the long-lived preview server may use `detachedWithLogs`.

## Conventions

- Comments: default to none. Only add comments that carry investigation context or constraints the code can't express (see `HelperSpawnMode` docs for the house style) — never narration of what the next line does.
- `docs/android-support.md` holds the plan for adding Android support (platform abstraction points, scrcpy-based helper design).
