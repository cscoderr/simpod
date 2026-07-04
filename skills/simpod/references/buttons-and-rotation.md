# Buttons and rotation reference

## Contents

- Valid button names
- Button behavior details
- Valid orientations
- Rotation gotchas

## Valid button names

These are the values the helper's HID layer accepts for `simpod button <name>`
(the `button` field of an `hid_input` frame, `type: "button"`). Anything else is
ignored by the helper.

| Name | Effect |
|---|---|
| `home` | Single Home-button press (down + up). On Face ID devices this triggers the home action via SpringBoard. |
| `app_switcher` | Synthesized as a **double-home** press — opens the multitasking switcher. |
| `lock` | Power / Sleep-Wake press (down + up). Locks the device; press again to wake. |
| `side_button` | Single side-button press. On iPhone 15 Pro / iPad Pro this is the **Action button**. |
| `siri` | **Hold** the side button (~long press). A single short press is ignored by iOS — the CLI issues the hold for you. |

Volume buttons are **not supported**: CoreSimulator does not route hardware
volume events (Simulator.app, idb, and Appium don't expose them on simulators
either). Adjust volume in-simulator via Control Center instead.

Button presses dispatch a `down` then `up` direction internally. (Direction `0`
is never sent — it crashes `backboardd` on iOS 17+.)

### `home` vs `app_switcher`

- `home` returns to the Home screen.
- `app_switcher` is a double-home recipe; it depends on the simulator exposing
  the private button symbol. If it no-ops on an older Xcode, fall back to a
  bottom-edge drag-and-hold gesture (see `gestures.md`).

### `siri` requires the hold

Tapping the side button briefly does **not** invoke Siri. `simpod button siri`
holds automatically — you don't script the timing.

### Lock-screen capture

`simpod button lock` → wait → `simpod button lock` again wakes the device into
the lock screen, handy for testing widgets and lock-screen UI.

## Valid orientations

These are the only values accepted by `simpod rotate <orientation>` — the
`wireName`s of `SimpodOrientation`:

| Value | Internal int | Description |
|---|---|---|
| `portrait` | 1 | Home indicator / Home button at the bottom |
| `portrait_upside_down` | 2 | Home indicator at the top |
| `landscape_right` | 3 | Device rotated so its left side is up; status bar on the right |
| `landscape_left` | 4 | Device rotated so its right side is up; status bar on the left |

The CLI takes the `wireName` (string); the underlying `hid_input` frame
(`type: "orientation"`) carries the **integer** `value`. `simpod rotate-left` /
`simpod rotate-right` are quarter-turn helpers that step through these in order.

## Rotation gotchas

- **`portrait_upside_down` is often not honored.** Apple's HIG discourages it and
  most apps lock it out in `Info.plist`. The event still dispatches; the app may
  not visibly rotate.
- **`landscape_*` requires app support.** If the app declares only
  `UIInterfaceOrientationPortrait`, the device rotates internally but the app
  keeps its portrait layout.
- **Touch coordinates auto-compensate after rotation.** The helper tracks the
  last-set orientation. Keep thinking in `(0,0)=top-left` of the screen as the
  user sees it; you don't rotate coordinates manually.
- **The device must be booted and streaming.** Rotation is delivered through the
  live session; rotate after the helper is attached (`simpod` is running for that
  device), not against a shut-down simulator.
