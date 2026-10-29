# Clean Room Metal

This is a clean room for agentic development of Metal shaders.

A small macOS app: one window, one Metal drawable, a clock, and the pointer. New experiments replace `Sources/Prototype.swift` and `Sources/Prototype.metal`. The shell in `Sources/App.swift` stays put.

This repository is MIT.

## Run

macOS 14 or later, Xcode 16 or later. Open `CleanRoomMetal.xcodeproj` and run it.

Or from this folder:

```sh
xcodebuild -project CleanRoomMetal.xcodeproj -scheme CleanRoomMetal -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
open build/Build/Products/Debug/CleanRoomMetal.app
```

To check a frame without watching the window, render one 1280×720 PNG and quit. The pointer is centered, the button is up, and the clock is one sixtieth of a second:

```sh
build/Build/Products/Debug/CleanRoomMetal.app/Contents/MacOS/CleanRoomMetal --snapshot /tmp/clean-room.png
```

The window title shows frames per second. Drag to set `pointerDown`. Press `R` to call `reset()`.

## New experiment

1. Duplicate this folder, or edit in place.
2. Replace the body of `Prototype` and the functions in `Prototype.metal`.
3. Leave `App.swift` alone unless the shell itself is wrong.

`Prototype` may own textures, buffers, and extra pipelines. A simulation that remembers the last frame stays there. `PrototypeUniforms` in the Swift file and the Metal file is one layout: keep the fields and the padding identical.

In a copy, change the display name and bundle id in `CleanRoomMetal.xcodeproj/project.pbxproj`:

- `INFOPLIST_KEY_CFBundleDisplayName`
- `PRODUCT_BUNDLE_IDENTIFIER`

Each frame the shell calls `encode(into:target:frame:)`.

- The target is `bgra8Unorm`, sized to the window in pixels.
- `frame.time` is seconds since launch. `frame.delta` is the gap since the previous frame, capped at a tenth of a second.
- `frame.pointer` is in view space, origin at the bottom-left, `y` up, both axes 0...1.
- `reset()` runs when `R` is pressed. The placeholder uses it to zero the clock it owns; do whatever the experiment needs.

Files you drop in `Sources/` are compiled with the target. Swift and Metal both.

## What the placeholder shows

A quiet field and a ring under the pointer, so a fresh checkout proves the drawable, the clock, and the mouse before any research code exists.
