// //
// //  MinecraftSkinRender.swift
// //  SwiftCraftLauncher
// //
// //  Created by su on 2025/6/20.
// //
// import SwiftUI
//
// struct MinecraftSkinRenderView: View {
//     @StateObject var viewModel = MetalViewModel()
//     var skinName: String?
//
//     var body: some View {
//         MetalView(viewModel: viewModel)
//             .onChange(of: skinName) { oldValue, newValue in
//                 if let name = newValue {
//                     viewModel.skinName = name + "-skin"
//                 }
//             }
//             .onAppear {
//                 if let name = skinName {
//                     viewModel.skinName = name + "-skin"
//                 }
//             }
//     }
// }
