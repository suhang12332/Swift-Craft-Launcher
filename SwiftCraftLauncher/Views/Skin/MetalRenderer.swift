// import Foundation
// import MetalKit
// import simd
//
// struct Uniforms {
//     var mvpMatrix: simd_float4x4
// }
//
// class MetalRenderer: NSObject, MTKViewDelegate {
//     let device: MTLDevice
//     let commandQueue: MTLCommandQueue
//     var pipelineState: MTLRenderPipelineState!
//     var depthState: MTLDepthStencilState?
//     var vertexBuffer: MTLBuffer?
//     var vertexCount: Int = 0
//     var scale: Float = 1.0
//     var rotation = SIMD2<Float>(0, 0)
//     var skinName: String = "steve-skin" { didSet { if oldValue != skinName { reloadTexture() } } }
//     var texture: MTLTexture?
//     var samplerState: MTLSamplerState?
//     var lastUniforms: Uniforms? = nil
//     var lastViewSize: CGSize = .zero
//     var lastLoadedSkin: String = ""
//     var headOnly: Bool = true // 新增参数
//
//     init(mtkView: MTKView, viewModel: MetalViewModel) {
//         self.device = mtkView.device!
//         self.commandQueue = device.makeCommandQueue()!
//         self.scale = viewModel.scale
//         self.rotation = viewModel.rotation
//         self.skinName = viewModel.skinName
//         self.headOnly = viewModel.headOnly // 赋值
//         super.init()
//         mtkView.colorPixelFormat = .bgra8Unorm_srgb
//         mtkView.depthStencilPixelFormat = .depth32Float
//         loadModel()
//         loadTexture()
//         buildPipeline(mtkView: mtkView)
//         buildSampler()
//     }
//
//     func loadModel() {
//         guard let url = Bundle.main.url(forResource: "model", withExtension: "obj") else {
//             Logger.shared.error("未找到 model.obj 文件")
//             return
//         }
//         let vertices = SimpleOBJLoader.loadOBJ(from: url, headOnly: headOnly) // 传递参数
//         vertexCount = vertices.count
//         vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<SimpleVertex>.stride * vertices.count, options: [])
//     }
//
//     func loadTexture() {
//         reloadTexture()
//     }
//
//     func reloadTexture() {
//         guard lastLoadedSkin != skinName else { return }
//         let loader = MTKTextureLoader(device: device)
//         do {
//             let tex = try loader.newTexture(name: skinName, scaleFactor: 1.0, bundle: .main, options: [MTKTextureLoader.Option.SRGB : true])
//             self.texture = tex
//             lastLoadedSkin = skinName
//         } catch {
//             Logger.shared.error("从资源加载皮肤贴图失败: \(error)")
//         }
//     }
//
//     func buildSampler() {
//         let desc = MTLSamplerDescriptor()
//         desc.minFilter = .nearest
//         desc.magFilter = .nearest
//         desc.sAddressMode = .clampToEdge
//         desc.tAddressMode = .clampToEdge
//         samplerState = device.makeSamplerState(descriptor: desc)
//     }
//
//     func buildPipeline(mtkView: MTKView) {
//         let library = device.makeDefaultLibrary()!
//         let vertexFunc = library.makeFunction(name: "vertex_main")!
//         let fragmentFunc = library.makeFunction(name: "fragment_main")!
//
//         let vertexDescriptor = MTLVertexDescriptor()
//         vertexDescriptor.attributes[0].format = .float3
//         vertexDescriptor.attributes[0].offset = 0
//         vertexDescriptor.attributes[0].bufferIndex = 0
//         vertexDescriptor.attributes[1].format = .float3
//         vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
//         vertexDescriptor.attributes[1].bufferIndex = 0
//         vertexDescriptor.attributes[2].format = .float2
//         vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2
//         vertexDescriptor.attributes[2].bufferIndex = 0
//         vertexDescriptor.layouts[0].stride = MemoryLayout<SimpleVertex>.stride
//         vertexDescriptor.layouts[0].stepRate = 1
//         vertexDescriptor.layouts[0].stepFunction = .perVertex
//
//         let pipelineDescriptor = MTLRenderPipelineDescriptor()
//         pipelineDescriptor.vertexFunction = vertexFunc
//         pipelineDescriptor.fragmentFunction = fragmentFunc
//         pipelineDescriptor.vertexDescriptor = vertexDescriptor
//         pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
//         pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
//        
//         let depthDescriptor = MTLDepthStencilDescriptor()
//         depthDescriptor.depthCompareFunction = .less
//         depthDescriptor.isDepthWriteEnabled = true
//         depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
//
//         pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
//     }
//
//     func makeUniforms(viewSize: CGSize) -> Uniforms {
//         let aspect = Float(viewSize.width / max(viewSize.height, 1))
//         let projection = float4x4(perspectivefov: .pi/4, aspect: aspect, near: 0.1, far: 100)
//         let view = float4x4(translation: [0, 0, -5])
//         let rotationX = float4x4(rotationX: rotation.x)
//         let rotationY = float4x4(rotationY: rotation.y)
//         let modelRotation = rotationY * rotationX
//         let modelScaling = float4x4(scaling: scale)
//         let modelMatrix = modelRotation * modelScaling
//         let mvp = projection * view * modelMatrix
//         return Uniforms(mvpMatrix: mvp)
//     }
//
//     func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
//         lastViewSize = size
//     }
//
//     func draw(in view: MTKView) {
//         reloadTexture()
//         let uniforms = makeUniforms(viewSize: view.drawableSize)
//         guard let drawable = view.currentDrawable,
//               let descriptor = view.currentRenderPassDescriptor,
//               let vertexBuffer = vertexBuffer,
//               let texture = texture,
//               let samplerState = samplerState,
//               let depthState = depthState else { return }
//         let commandBuffer = commandQueue.makeCommandBuffer()!
//         let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
//         encoder.setRenderPipelineState(pipelineState)
//         encoder.setDepthStencilState(depthState)
//         encoder.setCullMode(.none)
//         encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
//         encoder.setVertexBytes([uniforms], length: MemoryLayout<Uniforms>.stride, index: 1)
//         encoder.setFragmentTexture(texture, index: 0)
//         encoder.setFragmentSamplerState(samplerState, index: 0)
//         encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
//         encoder.endEncoding()
//         commandBuffer.present(drawable)
//         commandBuffer.commit()
//     }
// }
//
// // MARK: - Matrix helpers
// extension float4x4 {
//     init(perspectivefov fov: Float, aspect: Float, near: Float, far: Float) {
//         let y = 1 / tan(fov * 0.5)
//         let x = y / aspect
//         let z = far / (near - far)
//         self.init([
//             SIMD4<Float>(x, 0, 0, 0),
//             SIMD4<Float>(0, y, 0, 0),
//             SIMD4<Float>(0, 0, z, -1),
//             SIMD4<Float>(0, 0, z * near, 0)
//         ])
//     }
//
//     init(translation: SIMD3<Float>) {
//         self.init([
//             SIMD4<Float>(1, 0, 0, 0),
//             SIMD4<Float>(0, 1, 0, 0),
//             SIMD4<Float>(0, 0, 1, 0),
//             SIMD4<Float>(translation.x, translation.y, translation.z, 1)
//         ])
//     }
//
//     init(rotationX angle: Float) {
//         self.init([
//             SIMD4<Float>(1, 0, 0, 0),
//             SIMD4<Float>(0, cos(angle), sin(angle), 0),
//             SIMD4<Float>(0, -sin(angle), cos(angle), 0),
//             SIMD4<Float>(0, 0, 0, 1)
//         ])
//     }
//
//     init(rotationY angle: Float) {
//         self.init([
//             SIMD4<Float>(cos(angle), 0, -sin(angle), 0),
//             SIMD4<Float>(0, 1, 0, 0),
//             SIMD4<Float>(sin(angle), 0, cos(angle), 0),
//             SIMD4<Float>(0, 0, 0, 1)
//         ])
//     }
//
//     init(scaling s: Float) {
//         self.init([
//             SIMD4<Float>(s, 0, 0, 0),
//             SIMD4<Float>(0, s, 0, 0),
//             SIMD4<Float>(0, 0, s, 0),
//             SIMD4<Float>(0, 0, 0, 1)
//         ])
//     }
// }
// 
