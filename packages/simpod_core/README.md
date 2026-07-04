# simpod_core

Shared protocol models for [Simpod](../../README.md) — the data types that the
`simpod` CLI, the native helper, and the `simpod_client` web dashboard exchange
over the HTTP/WebSocket wire. Pure Dart, no runtime dependencies, so both the CLI
and the Flutter client can depend on it.

Its job is to be the single source of truth for the wire format: JSON
(de)serialization, the integer/`snake_case` tokens the native helper expects, and
the enums shared across every layer.

## What's in it

Everything is re-exported from `package:simpod_core/simpod_core.dart`.

### Models (`src/models`)

| Type | Role |
|---|---|
| `SimpodSession` | A running helper session — `pid`, `port`, `device`, `url`, `streamUrl`, `wsUrl`, and the optional `accessToken`. Serialized to the session/pid files under `$TMPDIR/simpod/` and returned by the CLI's JSON API. |
| `DeviceInfo` / `DeviceState` | A simulator (`udid`, `name`, `runtime`) and its `booted` / `shutdown` / `unknown` state, parsed from `xcrun simctl` output. |
| `AXNode` | A node in the simulator's accessibility tree — role, label, value, identifier, frame (`x/y/width/height`), `enabled`/`focused`/`hidden` flags, depth, and children. Built from the helper's AX dump. |
| `SimpodKeyEvent` | `SimpodKeyDownEvent` / `SimpodKeyUpEvent` carrying a HID usage code, plus `buildKeysMap()` mapping characters to `(usage, shift)` for the US keyboard used by `type`. |

### Protocol (`src/protocol`)

| Type | Role |
|---|---|
| `SimpodOrientation` | `portrait` / `portraitUpsideDown` / `landscapeLeft` / `landscapeRight`, each with the integer `value` sent in the WebSocket payload and the `snake_case` `wireName` accepted by the CLI's `rotate` command. Includes `rotatedLeft` / `rotatedRight` helpers. |
| `SimpodTouchEdge` | Screen edge a touch starts from for edge-swipe gestures (e.g. bottom → Home). `value` maps to the helper's `HIDInput.TouchEdge`. |
| `AccessibilitySetting` | Boolean accessibility toggles (reduce motion, reduce transparency, show borders) with the CLI command name, label, and the `com.apple.Accessibility` defaults key the CLI writes. |

## Usage

```dart
import 'package:simpod_core/simpod_core.dart';

final session = SimpodSession.fromJson(jsonDecode(body));
final orientation = SimpodOrientation.fromWireName('landscape_left');
print(orientation?.value); // 4 — sent over the WebSocket
```

## Development

```sh
cd packages/simpod_core
dart pub get
dart test
```

## License

See [`LICENSE`](LICENSE).
