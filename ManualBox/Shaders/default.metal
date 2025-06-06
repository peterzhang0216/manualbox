#include <metal_stdlib>
using namespace metal;

// 基本的Metal着色器实现，用于确保Metal库正确生成

// 一个简单的计算着色器，仅在应用需要预热Metal子系统时使用
kernel void emptyKernel(uint2 gid [[thread_position_in_grid]]) {
    // 这是一个空操作，仅用于生成Metal库文件
}

// 基本的顶点着色器
struct VertexOutput {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOutput basicVertexShader(uint vertexID [[vertex_id]],
                                     constant float2 *positions [[buffer(0)]],
                                     constant float2 *texCoords [[buffer(1)]]) {
    VertexOutput out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

// 基本的片段着色器
fragment float4 basicFragmentShader(VertexOutput in [[stage_in]],
                                   texture2d<float> texture [[texture(0)]],
                                   sampler textureSampler [[sampler(0)]]) {
    // 简单地返回纹理颜色
    return texture.sample(textureSampler, in.texCoord);
}