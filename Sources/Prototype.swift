import Metal

// Experiment surface. Replace this file and Prototype.metal.
// The window, drawable, clock, and pointer live in App.swift.
// Drawable pixel format: bgra8Unorm.
// pointer is view space: origin bottom-left, y up, both axes 0...1.
// R calls reset().

struct ExperimentFrame {
    var time: Float
    var delta: Float
    var drawableSize: SIMD2<Float>
    var pointer: SIMD2<Float>
    var pointerDown: Bool
}

struct PrototypeUniforms {
    var time: Float
    var pad0: Float
    var pointer: SIMD2<Float>
    var resolution: SIMD2<Float>
    var pointerDown: Float
    var pad1: Float
}

final class Prototype {
    let name = "Clean Room Metal"

    private let pipeline: MTLRenderPipelineState
    private var epoch: Float = 0

    init(device: MTLDevice) throws {
        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertex = library.makeFunction(name: "prototypeVertex"),
              let fragment = library.makeFunction(name: "prototypeFragment")
        else { throw PrototypeError.missingShader }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func reset() {
        epoch = 0
    }

    func encode(into buffer: MTLCommandBuffer, target: MTLTexture, frame: ExperimentFrame) {
        epoch += frame.delta
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }

        var uniforms = PrototypeUniforms(
            time: epoch,
            pad0: 0,
            pointer: frame.pointer,
            resolution: frame.drawableSize,
            pointerDown: frame.pointerDown ? 1 : 0,
            pad1: 0
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<PrototypeUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}

enum PrototypeError: Error {
    case missingShader
}
