# Workflows reference

End-to-end recipes that compose the primitives in the other reference files.

## Contents

- Workflow 1: Tap a UI element by accessibility label
- Workflow 2: Deep-link into an app and verify the screen
- Workflow 3: Status-bar + appearance for a clean screenshot
- Workflow 4: Show the simulator stream in the host's preview
- Workflow 5: Reset and re-test (clean slate)
- Workflow 6: Drive a multi-step gesture reliably

## Workflow 1: Tap a UI element by accessibility label

Pixel-hunting is fragile across device sizes. Drive taps from the accessibility
tree instead.

```sh
# 1. Read the AX tree (whole frontmost app)
TREE=$(simpod describe)

# 2. Find the node whose label matches (adapt the jq query to your tree shape)
TARGET=$(echo "$TREE" | jq 'recurse(.children[]?) | select(.label == "Submit")')

# Guard: if nothing matched, FAIL — never tap a guessed coordinate.
if [ -z "$TARGET" ] || [ "$TARGET" = "null" ]; then
  echo "ERROR: no element labeled 'Submit' in the accessibility tree" >&2
  exit 2
fi

# 3. Node frames are in DEVICE POINTS. Normalize the frame center against the
#    device screen size (the root node's frame), then tap.
ROOT=$(echo "$TREE" | jq '{w: .frame.width, h: .frame.height}')
W=$(echo "$ROOT" | jq '.w'); H=$(echo "$ROOT" | jq '.h')
CX=$(echo "$TARGET" | jq '.frame.x + .frame.width/2')
CY=$(echo "$TARGET" | jq '.frame.y + .frame.height/2')
NX=$(echo "scale=4; $CX/$W" | bc); NY=$(echo "scale=4; $CY/$H" | bc)

simpod tap "$NX" "$NY"
```

Inspect with `simpod describe | jq` first and adapt the query — tree shape
varies by app.

## Workflow 2: Deep-link into an app and verify the screen

```sh
simpod open-url "myapp://products/42"      # open the deep link
sleep 1                                     # let the app route
simpod describe | jq 'recurse(.children[]?) | select(.label | test("Product #42"))'
```

If the `select` returns nothing, the screen didn't render — report it rather
than proceeding.

## Workflow 3: Status-bar + appearance for a clean screenshot

```sh
simpod appearance dark
simpod status-bar --battery 100 --time 9:41   # marketing-clean status bar
simpod screenshot -o out.png                  # capture the framed shot
simpod status-bar --clear                     # restore real status bar
```

## Workflow 4: Show the simulator stream in the host's preview

The skill can make a URL exist; the host knows how to render it. The agent is the
glue — detect which side is available.

```sh
# 1. Start detached and capture the JSON
JSON=$(simpod --detach -q)
URL=$(echo "$JSON" | jq -r '.url')      # http://127.0.0.1:5210

# 2. Always surface the URL plainly as a manual fallback
echo "Simulator stream: $URL"
```

3. Hand off **only if** a preview/URL tool exists in the current session:
   - **Claude Code**: call `preview_start` (or `mcp__Claude_Preview__preview_start`) with `{ url: "$URL" }`.
   - A generic `browser_open` / `open_url` tool: pass the URL.
   - **No such tool** (Cursor, Codex CLI, …): print the URL and tell the user to open it in their browser / built-in browser pane.
4. **Never invent a tool name.** If nothing matches, fall back to printing.

The stream stays alive until `simpod --kill`; multiple clients can view at once.

## Workflow 5: Reset and re-test (clean slate)

```sh
simpod --kill                                  # stop sessions + detached servers
xcrun simctl terminate booted com.acme.MyApp   # drop the app

# Optional, DESTRUCTIVE — only when the user explicitly asks (wipes app data):
# xcrun simctl shutdown <UDID> && xcrun simctl erase <UDID> && xcrun simctl boot <UDID>

simpod --detach -q                             # restart the stream
```

## Workflow 6: Drive a multi-step gesture reliably

For a long drag or multi-finger choreography, a chain of separate `simpod
gesture` calls is unreliable — each may open a fresh connection. Drive one
persistent WebSocket so the whole sequence shares it.

```js
import WebSocket from "ws";

// wsUrl comes from the session JSON (simpod --list -q / --detach -q)
const ws = new WebSocket("ws://127.0.0.1:5400/ws?format=mjpeg");
await new Promise((r) => ws.once("open", r));

const send = (type, data) => ws.send(JSON.stringify({ wsType: "hid_input", type, data }));

send("touch", { phase: "begin", x: 0.5, y: 0.2 });
for (let i = 1; i <= 30; i++) {
  send("touch", { phase: "move", x: 0.5, y: 0.2 + (0.6 * i) / 30 });
  await new Promise((r) => setTimeout(r, 16));   // ~60 Hz
}
send("touch", { phase: "end", x: 0.5, y: 0.8 });
ws.close();
```

The frame shape is documented in `endpoints.md`; coordinates in `gestures.md`.
