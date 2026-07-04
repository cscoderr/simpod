# Gestures reference

## Contents

- Coordinate system
- The `hid_input` envelope
- Single-touch shape
- Multi-touch (pinch) shape
- Edge values (system edge gestures)
- Common recipes
- Why `tap` is preferred over `gesture` for taps

## Coordinate system

All coordinates are normalized floats in `[0, 1]`:

- `(0.0, 0.0)` = top-left of the display
- `(1.0, 1.0)` = bottom-right
- `(0.5, 0.5)` = center

The helper compensates for the device's current orientation, so after
`simpod rotate landscape_left` you still describe the **logical** screen from the
user's perspective — don't rotate coordinates yourself.

To turn AX-tree device points into normalized coords, divide a node's
`frame` center by the device screen size (the AX root node's frame). See
`workflows.md` → "Tap a UI element by accessibility label".

## The `hid_input` envelope

Live input travels over the helper WebSocket (`/ws`) as JSON **text** frames.
The CLI builds these for you; an agent talking to the socket directly sends:

```json
{ "wsType": "hid_input", "type": "touch", "data": { "phase": "begin", "x": 0.5, "y": 0.5, "edge": null } }
```

`type` ∈ `touch | pinch | button | orientation | key`. The accessibility tree is
requested with a separate `describe_ui` frame (see `endpoints.md`).

## Single-touch shape

```json
{ "wsType": "hid_input", "type": "touch",
  "data": { "phase": "begin", "x": 0.5, "y": 0.5, "edge": null } }
```

| Field | Type | Required | Values |
|---|---|---|---|
| `phase` | string | yes | `"begin"`, `"move"`, `"end"` |
| `x` | number | yes | `0.0`–`1.0` |
| `y` | number | yes | `0.0`–`1.0` |
| `edge` | integer\|null | no | see Edge values |

A complete touch is `begin` → 0+ `move` → `end`. For a plain tap use
`simpod tap <x> <y>` — it issues begin+end as one tight sequence.

## Multi-touch (pinch) shape

```json
{ "wsType": "hid_input", "type": "pinch",
  "data": { "phase": "begin", "x1": 0.4, "y1": 0.5, "x2": 0.6, "y2": 0.5 } }
```

| Field | Type | Required | Values |
|---|---|---|---|
| `phase` | string | yes | `"begin"`, `"move"`, `"end"` |
| `x1`, `y1` | number | yes | first finger `0.0`–`1.0` |
| `x2`, `y2` | number | yes | second finger `0.0`–`1.0` |

Use it for pinch-zoom and two-finger gestures. Multi-touch has no `edge`.

## Edge values

`edge` flags a touch as a screen-edge **system** gesture (iOS treats edge
swipes specially — e.g. bottom-edge swipe-to-home on Face ID devices). Omit it
(or send `null`) for ordinary interior touches.

| Value | Edge | Effect |
|---|---|---|
| `null`/`0` | none | Regular touch (default) |
| `1` | left | Left-edge swipe (in-app back gesture) |
| `2` | top | Top-edge pull (Notification Center / Control Center) |
| `3` | bottom | Bottom-edge swipe (swipe-to-home on Face ID devices) |
| `4` | right | Right-edge swipe |

For a swipe-to-home on a Face ID device, prefer `simpod button home` — it does
the right thing without choreographing an edge drag.

## Common recipes

### Tap (use `tap`, not `gesture`)

```bash
simpod tap 0.5 0.5
```

### Vertical scroll / drag (single sequence)

```bash
simpod gesture '{"type":"touch","data":{"phase":"begin","x":0.5,"y":0.2}}'
simpod gesture '{"type":"touch","data":{"phase":"move","x":0.5,"y":0.5}}'
simpod gesture '{"type":"touch","data":{"phase":"move","x":0.5,"y":0.8}}'
simpod gesture '{"type":"touch","data":{"phase":"end","x":0.5,"y":0.8}}'
```

For reliable real-time drags, drive the `/ws` socket directly so the whole
sequence shares one connection (see `endpoints.md`).

### Pinch to zoom in

```bash
simpod gesture '{"type":"pinch","data":{"phase":"begin","x1":0.4,"y1":0.5,"x2":0.6,"y2":0.5}}'
simpod gesture '{"type":"pinch","data":{"phase":"move","x1":0.25,"y1":0.5,"x2":0.75,"y2":0.5}}'
simpod gesture '{"type":"pinch","data":{"phase":"end","x1":0.25,"y1":0.5,"x2":0.75,"y2":0.5}}'
```

### Pull down Notification Center (top edge)

```bash
simpod gesture '{"type":"touch","data":{"phase":"begin","x":0.5,"y":0.02,"edge":2}}'
simpod gesture '{"type":"touch","data":{"phase":"move","x":0.5,"y":0.4,"edge":2}}'
simpod gesture '{"type":"touch","data":{"phase":"end","x":0.5,"y":0.4,"edge":2}}'
```

## Why `tap` is preferred

A complete touch must be a `begin`/`end` pair delivered close together. If you
split them across two slow, separately-connected `gesture` calls, the dwell time
can exceed the simulator's long-press threshold (~100ms) and register a
long-press instead of a tap. `simpod tap` issues both over one connection with
negligible latency, producing a true tap every time. Only reach for `gesture`
for drags, swipes, and multi-step sequences.
