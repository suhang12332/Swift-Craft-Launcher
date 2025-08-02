//#include <metal_stdlib>
//using namespace metal;
//
//struct VertexIn {
//    float3 position [[attribute(0)]];
//    float3 normal [[attribute(1)]];
//    float2 texcoord [[attribute(2)]];
//};
//
//struct VertexOut {
//    float4 position [[position]];
//    float2 texcoord;
//};
//
//struct Uniforms {
//    float4x4 mvpMatrix;
//};
//
//vertex VertexOut vertex_main(VertexIn in [[stage_in]], constant Uniforms& uniforms [[buffer(1)]]) {
//    VertexOut out;
//    out.position = uniforms.mvpMatrix * float4(in.position, 1.0);
//    out.texcoord = in.texcoord;
//    return out;
//}
//
//fragment float4 fragment_main(VertexOut in [[stage_in]],
//                             texture2d<float> tex [[texture(0)]],
//                             sampler samp [[sampler(0)]]) {
//    float4 color = tex.sample(samp, in.texcoord);
//    if (color.a < 0.1) discard_fragment();
//    return color;
//} 
