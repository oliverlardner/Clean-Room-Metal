# Clean Room Metal

This is a starting point for a Metal experiment. The shell is done. Replace the prototype.

## Edit

- Change `Sources/Prototype.swift` and `Sources/Prototype.metal`.
- Leave `Sources/App.swift` alone unless the shell itself is wrong.
- Swift and Metal files added under `Sources/` compile with the target.
- `Prototype` may own textures, buffers, and extra pipelines. A simulation that remembers the last frame stays in the prototype.
- `PrototypeUniforms` in Swift and Metal is one layout. Keep the fields and the padding identical.

## Frame

`encode(into:target:frame:)` runs once per frame.

- The target is `bgra8Unorm`, sized to the window in pixels. A snapshot is 1280×720.
- `frame.time` is seconds since launch. `frame.delta` is the gap since the previous frame, capped at a tenth of a second.
- `frame.pointer` is view space, origin bottom-left, y up, both axes 0...1.
- `R` calls `reset()`.

## Check

```sh
xcodebuild -project CleanRoomMetal.xcodeproj -scheme CleanRoomMetal -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
build/Build/Products/Debug/CleanRoomMetal.app/Contents/MacOS/CleanRoomMetal --snapshot /tmp/clean-room.png
```

The process writes one PNG and quits. Open that file to see the frame.

## Copy

When duplicating the folder, change the display name and bundle id in `CleanRoomMetal.xcodeproj/project.pbxproj`:

- `INFOPLIST_KEY_CFBundleDisplayName`
- `PRODUCT_BUNDLE_IDENTIFIER`
