# Endpoints reference (HTTP API + WebSocket)

For agents that drive simpod directly instead of through the CLI. The **preview
server** (default `http://127.0.0.1:5210`) exposes the HTTP API and serves the
dashboard; each **helper** (`5400+`) owns the live stream + input WebSocket for
one device.

## Auth

`/api/*` and `/ws` are gated by a single persistent token (in
`$TMPDIR/simpod/settings.json`). The middleware accepts it three ways:

- `simpodToken` cookie (set automatically for loopback `127.0.0.1`),
- `X-Simpod-Token` header,
- `?token=<token>` query param (for `EventSource`, which can't set headers).

Loopback is auto-trusted. A LAN device pairs via the one public route
**`GET /pair?t=<token>`** (valid token → sets the cookie + `302 →/`). Get the
token, the pair link, and a scannable QR from **`simpod pair`** (`-q` for
JSON; `--reset` rotates the token). Note: token enforcement is opt-in — set
`SIMPOD_ENFORCE_AUTH=1` to turn the gate on.

## HTTP API (preview server, `:5210`)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Liveness. |
| GET | `/api/devices` | List simulators + boot state. |
| GET | `/api/session/<udid>` | Get the session; **spawns a helper on demand** if the device is booted. |
| POST | `/api/device/<udid>/boot` | Boot + attach a helper; returns the session. |
| POST | `/api/device/<udid>/shutdown` | Shut down + detach. |
| GET / POST | `/api/device/<udid>/appearance` | Read / set `{"theme":"light\|dark"}`. |
| GET / POST | `/api/device/<udid>/text-size` | Read / set Dynamic Type (`{"value":"increment\|decrement\|<size>"}`). |
| GET / POST | `/api/device/<udid>/contrast` | Read / set Increase Contrast (`{"enabled":bool}`). |
| GET / POST | `/api/device/<udid>/accessibility/<setting>` | Read / set an accessibility toggle (`{"enabled":bool}`). Settings: `reduce-motion`, `reduce-transparency`, `show-borders`. |
| POST | `/api/device/<udid>/open-url` | `{"url":"..."}`. |
| POST | `/api/device/<udid>/location` | `{"latitude":..,"longitude":..}`. |
| POST / DELETE | `/api/device/<udid>/status-bar` | Override `{batteryLevel?, time?}` / clear all overrides. |
| GET | `/api/device/<udid>/logs` | **SSE** (`text/event-stream`) of the system log; pass `?token=` for auth. |
| GET | `/api/device/<udid>/ax` | **SSE** of the accessibility tree — pushes an event only when the UI changes; pass `?token=` for auth. |
| GET | `/api/device/<udid>/ax.json` | One-shot accessibility tree snapshot (`?x=&y=` for the element under a normalized point). |
| POST | `/api/device/<udid>/permissions` | `{"action":"grant\|revoke\|reset","service":"...","bundleId"?}` (`simctl privacy`). |
| GET | `/api/device/<udid>/chrome`, `/bezel.png`, `/chrome-button/<file>` | Bezel/chrome assets (proxied from the helper). |

A `SimpodSession` (returned by `/session` and `/boot`) carries `pid`, `port`,
`device` (udid), `url` (`http://127.0.0.1:<port>`), and `wsUrl`
(`ws://127.0.0.1:<port>/ws`). Connect to **`wsUrl`** for the stream + input.

There is **no generic exec endpoint** — every device action maps to a specific
route backed by `xcrun simctl`.

## WebSocket (`helper /ws`) — text in, binary out

`ws://127.0.0.1:<helperPort>/ws?format=mjpeg|avcc`. The helper **reads only text
(JSON) frames and ignores binary**, and sends **video out as binary**.

### Inbound (control) — JSON text

`hid_input` dispatches input by `type`:

```json
{ "wsType":"hid_input", "type":"touch",       "data":{ "phase":"begin","x":0.5,"y":0.5,"edge":null } }
{ "wsType":"hid_input", "type":"pinch",       "data":{ "phase":"begin","x1":0.4,"y1":0.5,"x2":0.6,"y2":0.5 } }
{ "wsType":"hid_input", "type":"button",      "data":{ "button":"home" } }
{ "wsType":"hid_input", "type":"orientation", "data":{ "orientation":4 } }
{ "wsType":"hid_input", "type":"key",         "data":{ "event":"down","usage":4 } }
```

- coords normalized `0..1`; see `gestures.md`.
- `orientation` is the integer `SimpodOrientation.value` (1 portrait, 2 upside-down, 3 landscape_right, 4 landscape_left); see `buttons-and-rotation.md`.
- `key` carries a USB HID `usage` and an `event` of `down`/`up`.

`describe_ui` requests the accessibility tree:

```json
{ "wsType":"describe_ui", "data":{ "x":0.5, "y":0.5 } }
```

Omit `data` (or its `x`/`y`) for the whole screen; include a normalized point to
hit-test the node under it. The helper replies on the same socket with a **text**
frame containing the `AXNode` tree (`label`/`title`/`identifier`, `role`,
device-point `frame`, `children`).

### Outbound

- **Binary** frames: the live video (MJPEG or AVCC per `?format`).
- **Text** frames: AX snapshots and error objects.

## Gotchas

- `SimpodSession.streamUrl` (`.../stream.mjpeg`) is **vestigial** — there is no
  `/stream.mjpeg` route; video is the binary `/ws` output. Use `wsUrl`.
- The helper serves `/`, `/ping`, `/bezel.png`, `/chrome-button/:name`,
  `/chrome.json`, `/ax.json` (whole-screen AX tree; `?x=&y=` for the element
  under a normalized point), and `/ws`. Prefer `/ax.json` (or the preview
  server's `/api/device/<udid>/ax` SSE) over `/ws` `describe_ui` — an AX sweep
  on the WS blocks touch input for its duration.
