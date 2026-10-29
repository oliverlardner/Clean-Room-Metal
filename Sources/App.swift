import AppKit
import ImageIO
import Metal
import QuartzCore
import UniformTypeIdentifiers

@main
enum AppMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let window: NSWindow
    private let view: MetalView

    override init() {
        view = MetalView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = view
        window.minSize = NSSize(width: 480, height: 320)
        window.title = "Clean Room Metal"
        window.backgroundColor = NSColor(srgbRed: 0.07, green: 0.08, blue: 0.09, alpha: 1)
        window.acceptsMouseMovedEvents = true
        super.init()
        view.snapshotURL = Self.snapshotURL(from: CommandLine.arguments)
        view.onTitle = { [weak window] title in
            window?.title = title
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        if view.snapshotURL == nil {
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            NSApp.activate(ignoringOtherApps: true)
        }
        view.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func installMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Clean Room Metal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu

        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        let fullScreen = NSMenuItem(
            title: "Enter Full Screen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(fullScreen)
        viewItem.submenu = viewMenu
        NSApp.mainMenu = main
    }

    private static func snapshotURL(from arguments: [String]) -> URL? {
        guard let flag = arguments.firstIndex(of: "--snapshot") else { return nil }
        let next = arguments.index(after: flag)
        guard next < arguments.endIndex else {
            fputs("Clean Room Metal: --snapshot needs a PNG path\n", stderr)
            exit(EXIT_FAILURE)
        }
        return URL(fileURLWithPath: arguments[next])
    }
}

final class MetalView: NSView {
    var onTitle: ((String) -> Void)?
    var snapshotURL: URL?

    private let metalLayer = CAMetalLayer()
    private var displayLink: CADisplayLink?
    private var queue: MTLCommandQueue?
    private var prototype: Prototype?
    private var startedAt = CACurrentMediaTime()
    private var previousAt = CACurrentMediaTime()
    private var fpsStamp = CACurrentMediaTime()
    private var frameCount = 0
    private var pointer = SIMD2<Float>(0.5, 0.5)
    private var pointerDown = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func makeBackingLayer() -> CALayer { metalLayer }

    override var acceptsFirstResponder: Bool { true }

    func start() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue()
        else {
            onTitle?("Clean Room Metal — no Metal device")
            return
        }
        self.queue = queue
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.isOpaque = true
        do {
            prototype = try Prototype(device: device)
        } catch {
            fputs("Clean Room Metal failed: \(error)\n", stderr)
            onTitle?("Clean Room Metal — shader failed")
            return
        }
        onTitle?(prototype?.name ?? "Clean Room Metal")
        if let snapshotURL {
            renderSnapshot(to: snapshotURL)
            return
        }
        displayLink = displayLink(target: self, selector: #selector(step(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func renderSnapshot(to url: URL) {
        guard let device = metalLayer.device, let queue, let prototype else {
            fputs("Clean Room Metal snapshot failed: Metal is unavailable\n", stderr)
            exit(EXIT_FAILURE)
        }
        let width = 1280
        let height = 720
        let bytesPerRow = ((width * 4 + 255) / 256) * 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private
        guard let texture = device.makeTexture(descriptor: descriptor),
              let readback = device.makeBuffer(length: bytesPerRow * height, options: .storageModeShared),
              let buffer = queue.makeCommandBuffer()
        else {
            fputs("Clean Room Metal snapshot failed: could not allocate\n", stderr)
            exit(EXIT_FAILURE)
        }
        let frame = ExperimentFrame(
            time: 1.0 / 60.0,
            delta: 1.0 / 60.0,
            drawableSize: SIMD2(Float(width), Float(height)),
            pointer: SIMD2(0.5, 0.5),
            pointerDown: false
        )
        prototype.encode(into: buffer, target: texture, frame: frame)
        guard let blit = buffer.makeBlitCommandEncoder() else {
            fputs("Clean Room Metal snapshot failed: could not read the frame\n", stderr)
            exit(EXIT_FAILURE)
        }
        blit.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: readback,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: bytesPerRow * height
        )
        blit.endEncoding()
        buffer.commit()
        buffer.waitUntilCompleted()
        if buffer.status != .completed {
            fputs("Clean Room Metal snapshot failed: GPU error\n", stderr)
            exit(EXIT_FAILURE)
        }
        do {
            try Self.writePNG(readback.contents(), width: width, height: height, bytesPerRow: bytesPerRow, to: url)
        } catch {
            fputs("Clean Room Metal snapshot failed: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
        print(url.path)
        fflush(stdout)
        exit(EXIT_SUCCESS)
    }

    private static func writePNG(_ bytes: UnsafeMutableRawPointer, width: Int, height: Int, bytesPerRow: Int, to url: URL) throws {
        let bitmap = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
        guard let context = CGContext(
            data: bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmap.rawValue
        ), let image = context.makeImage() else {
            throw CocoaError(.fileWriteUnknown)
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let queue, let prototype else { return }
        let scale = window?.backingScaleFactor ?? 1
        metalLayer.frame = bounds
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        guard let drawable = metalLayer.nextDrawable(),
              let buffer = queue.makeCommandBuffer()
        else { return }

        let now = CACurrentMediaTime()
        let delta = Float(min(now - previousAt, 0.1))
        previousAt = now
        let frame = ExperimentFrame(
            time: Float(now - startedAt),
            delta: delta,
            drawableSize: SIMD2(Float(drawable.texture.width), Float(drawable.texture.height)),
            pointer: pointer,
            pointerDown: pointerDown
        )
        prototype.encode(into: buffer, target: drawable.texture, frame: frame)
        buffer.present(drawable)
        buffer.commit()

        frameCount += 1
        if now - fpsStamp >= 0.5 {
            let fps = Double(frameCount) / (now - fpsStamp)
            frameCount = 0
            fpsStamp = now
            onTitle?(String(format: "%@  —  %.0f fps", prototype.name, fps))
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        pointerDown = true
        track(event)
    }

    override func mouseUp(with event: NSEvent) {
        pointerDown = false
        track(event)
    }

    override func mouseDragged(with event: NSEvent) { track(event) }

    override func mouseMoved(with event: NSEvent) { track(event) }

    override func keyDown(with event: NSEvent) {
        guard event.charactersIgnoringModifiers?.lowercased() == "r" else {
            super.keyDown(with: event)
            return
        }
        startedAt = CACurrentMediaTime()
        previousAt = startedAt
        prototype?.reset()
    }

    private func track(_ event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        pointer = SIMD2(
            Float(min(max(local.x / width, 0), 1)),
            Float(min(max(local.y / height, 0), 1))
        )
    }
}
