# Simpod

Stream and control a running **iOS Simulator** from your browser, terminal, or AI coding agent.

Simpod lets you remotely control a booted iOS Simulator using a simple CLI. It provides a live browser preview, touch and keyboard input, accessibility inspection, simulator controls, and automation features—all without Xcode plugins or app instrumentation.

## Features

- Low-latency browser streaming (up to 60 FPS)
- Full simulator control
  - Tap
  - Swipe
  - Pinch
  - Type
  - Hardware buttons
  - Device rotation
- Inspect the live accessibility tree
- Simulator controls
  - Light/Dark mode
  - Mock GPS location
  - Status bar overrides
  - Deep links
  - Privacy permissions
- Live simulator logs
- Access from your browser or over your local network
- Built for automation and AI coding agents

## Requirements

- macOS 14 or later
- Xcode Command Line Tools
- A booted iOS Simulator

## Installation

Activate the package:

```sh
dart pub global activate simpod
```

Start Simpod:

```sh
simpod
```

Open the browser preview:

```
http://127.0.0.1:5210
```

No additional downloads are required. The package includes the native helper and web dashboard.

## Quick Start

Launch the preview:

```sh
simpod
```

Run in the background:

```sh
simpod --detach
```

Tap the center of the screen:

```sh
simpod tap 0.5 0.5
```

Type text:

```sh
simpod type "Hello, world!"
```

Rotate the simulator:

```sh
simpod rotate landscape_left
```

Open a deep link:

```sh
simpod open-url "myapp://profile"
```

Enable Dark Mode:

```sh
simpod appearance dark
```

Inspect the accessibility tree:

```sh
simpod describe | jq
```

Stop all running sessions:

```sh
simpod --kill
```

## CLI Overview

```text
simpod [device...]                 Start the browser preview
simpod --detach                    Run in the background
simpod --no-preview                Run without opening the browser
simpod --list                      List running sessions
simpod --kill                      Stop running sessions

simpod tap <x> <y>
simpod gesture '<json>'
simpod type '<text>'

simpod button <name>
simpod rotate <orientation>

simpod appearance light|dark
simpod location <lat> <lon>
simpod open-url <url>

simpod describe
simpod logs
```

Coordinates are normalized between `0` and `1`, where `(0,0)` is the top-left corner.

## AI Agents

Simpod works well with AI coding assistants such as:

- Claude Code
- Cursor
- Codex

It also includes an Agent Skill that helps supported agents reliably interact with iOS Simulators through the CLI.


## License
This project is licensed under the Apache License, Version 2.0.

See the [LICENSE](LICENSE) file.