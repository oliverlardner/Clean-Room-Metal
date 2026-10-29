#include <metal_stdlib>
using namespace metal;

// Placeholder picture. Replace prototypeFragment when an experiment starts.
// uv matches ExperimentFrame.pointer: origin bottom-left, y up, 0...1 on screen.

struct PrototypeVarying {
    float4 position [[position]];
    float2 uv;
};

// Layout shared with PrototypeUniforms in Prototype.swift. Keep the fields and padding identical.
struct PrototypeUniforms {
    float time;
    float pad0;
    float2 pointer;
    float2 resolution;
    float pointerDown;
    float pad1;
};

vertex PrototypeVarying prototypeVertex(uint id [[vertex_id]]) {
    float2 corner = float2(float((id << 1u) & 2u), float(id & 2u));
    PrototypeVarying out;
    out.position = float4(corner * 2.0 - 1.0, 0.0, 1.0);
    out.uv = corner;
    return out;
}

fragment float4 prototypeFragment(PrototypeVarying in [[stage_in]], constant PrototypeUniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 q = uv - uniforms.pointer;
    float radius = 0.075 + 0.012 * sin(uniforms.time * 1.7);
    float ring = smoothstep(0.012, 0.0, abs(length(q) - radius));
    float drift = 0.5 + 0.5 * sin(uniforms.time * 0.7 + uv.x * 5.0);
    float3 base = mix(float3(0.07, 0.08, 0.09), float3(0.15, 0.17, 0.19), uv.y);
    float3 ink = mix(float3(0.35, 0.55, 0.62), float3(0.85, 0.92, 0.95), uniforms.pointerDown);
    float3 color = base + 0.02 * drift + ink * ring * (0.35 + 0.65 * uniforms.pointerDown);
    return float4(color, 1.0);
}
