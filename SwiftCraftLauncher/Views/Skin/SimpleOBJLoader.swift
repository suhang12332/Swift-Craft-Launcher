// import Foundation
// import simd
//
// struct SimpleVertex {
//     var position: SIMD3<Float>
//     var normal: SIMD3<Float>
//     var texcoord: SIMD2<Float>
// }
//
// class SimpleOBJLoader {
//     static func loadOBJ(from url: URL, headOnly: Bool = false) -> [SimpleVertex] {
//         var positions: [SIMD3<Float>] = []
//         var normals: [SIMD3<Float>] = []
//         var texcoords: [SIMD2<Float>] = []
//         var vertices: [SimpleVertex] = []
//         var currentObject: String? = nil
//         guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
//         let lines = content.components(separatedBy: .newlines)
//         for line in lines {
//             let parts = line.split(separator: " ")
//             if parts.count == 0 { continue }
//             switch parts[0] {
//             case "o":
//                 currentObject = parts.count > 1 ? String(parts[1]) : nil
//             case "v":
//                 if parts.count >= 4,
//                    let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3]) {
//                     positions.append(SIMD3<Float>(x, y, z))
//                 }
//             case "vn":
//                 if parts.count >= 4,
//                    let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3]) {
//                     normals.append(SIMD3<Float>(x, y, z))
//                 }
//             case "vt":
//                 if parts.count >= 3,
//                    let u = Float(parts[1]), let v = Float(parts[2]) {
//                     texcoords.append(SIMD2<Float>(u, 1.0 - v)) // Y轴翻转
//                 }
//             case "f":
//                 if headOnly {
//                     if currentObject != "Head" && currentObject != "HeadOut" { break }
//                 }
//                 if parts.count >= 4 {
//                     let indices = parts[1...].map { $0.split(separator: "/") }
//                     for i in 1..<(indices.count - 1) {
//                         let idxs = [0, i, i+1]
//                         var faceVerts: [SimpleVertex] = []
//                         for j in idxs {
//                             let vi = Int(indices[j][0])! - 1
//                             let ti = indices[j].count >= 2 && !indices[j][1].isEmpty ? Int(indices[j][1])! - 1 : 0
//                             let ni = indices[j].count >= 3 ? Int(indices[j][2])! - 1 : 0
//                             let v = SimpleVertex(
//                                 position: positions[vi],
//                                 normal: normals.isEmpty ? SIMD3<Float>(0,1,0) : normals[ni],
//                                 texcoord: texcoords.isEmpty ? SIMD2<Float>(0,0) : texcoords[ti]
//                             )
//                             faceVerts.append(v)
//                         }
//                         vertices.append(contentsOf: faceVerts)
//                     }
//                 }
//             default: break
//             }
//         }
//         // 居中和缩放
//         if !vertices.isEmpty {
//             var minP = vertices[0].position
//             var maxP = vertices[0].position
//             for v in vertices {
//                 minP = simd.min(minP, v.position)
//                 maxP = simd.max(maxP, v.position)
//             }
//             let center = (minP + maxP) / 2
//             let diff = maxP - minP
//             let extent = max(diff.x, diff.y, diff.z)
//             let scale = extent > 0 ? 1.0 / extent : 1.0
//             for i in 0..<vertices.count {
//                 let p = vertices[i].position
//                 vertices[i].position = (p - center) * scale
//             }
//         }
//         return vertices
//     }
// } 
