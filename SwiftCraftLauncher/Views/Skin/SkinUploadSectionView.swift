import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit
import SkinRenderKit

struct SkinUploadSectionView: View {
    @Binding var currentModel: PlayerSkinService.PublicSkinInfo.SkinModel
    @Binding var showingFileImporter: Bool
    @Binding var selectedSkinImage: NSImage?
    @Binding var selectedSkinPath: String?
    @Binding var currentSkinRenderImage: NSImage?
    @Binding var selectedCapeLocalPath: String?
    @Binding var selectedCapeImage: NSImage?
    @Binding var selectedCapeImageURL: String?
    @Binding var isCapeLoading: Bool
    @Binding var capeLoadCompleted: Bool
    @Binding var showingSkinPreview: Bool

    let onSkinDropped: (NSImage) -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("skin.upload".localized()).font(.headline)

            skinRenderArea

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drop skin file here or click to select")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("PNG 64×64 or legacy 64×32")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                Spacer()
                Button {
                    openSkinPreviewWindow()
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .disabled(selectedSkinImage == nil && currentSkinRenderImage == nil && selectedSkinPath == nil)
            }
        }
    }

    private var skinRenderArea: some View {
        let playerModel = convertToPlayerModel(currentModel)
        // 判断是否有 SkinRenderView 显示（已有皮肤时，SkinRenderView 会处理拖拽）
        // 这里只根据是否有皮肤数据来判断，而不依赖 capeLoadCompleted，
        // 避免在披风加载期间误认为没有渲染视图，从而导致视图结构来回切换。
        let hasSkinRenderView = (selectedSkinImage != nil || currentSkinRenderImage != nil || selectedSkinPath != nil)

        return skinRenderContent(playerModel: playerModel)
            .frame(height: 220)
            .onTapGesture { showingFileImporter = true }
            .conditionalDrop(isEnabled: !hasSkinRenderView, perform: onDrop)
    }

    @ViewBuilder
    private func skinRenderContent(playerModel: PlayerModel) -> some View {
        ZStack {
            // 底层始终根据皮肤数据决定是否渲染角色，
            // 不再因为披风加载状态来回切换视图类型，避免 SceneKit 视图被销毁重建。
            Group {
                if let image = selectedSkinImage ?? currentSkinRenderImage {
                    SkinRenderView(
                        skinImage: image,
                        // 披风更新流程：
                        // 1. selectedCapeImage @Binding 变化（用户操作/初始化）
                        // 2. SwiftUI body 重新评估，创建/更新 SceneKitCharacterViewRepresentable
                        // 3. updateNSViewController 被调用
                        // 4. 检查 capeImage 是否存在，调用 updateCapeTexture(image:) 或 removeCapeTexture()
                        // 5. applyCapeUpdate 检查实例是否相同 (!==)，如果不同则更新并调用 rebuildCharacter()
                        // 6. 重建或增量更新角色节点，包含新的披风纹理
                        // 7. SceneKit 渲染新的角色模型
                        capeImage: $selectedCapeImage,
                        playerModel: playerModel,
                        rotationDuration: 0,
                        backgroundColor: NSColor.clear,
                        onSkinDropped: { dropped in
                            onSkinDropped(dropped)
                        },
                        onCapeDropped: { _ in }
                    )
                } else if let skinPath = selectedSkinPath {
                    SkinRenderView(
                        texturePath: skinPath,
                        // 披风更新流程同上：selectedCapeImage 变化 → SwiftUI 重新评估 → SkinRenderView 内部处理更新
                        capeImage: $selectedCapeImage,
                        playerModel: playerModel,
                        rotationDuration: 0,
                        backgroundColor: NSColor.clear,
                        onSkinDropped: { dropped in
                            onSkinDropped(dropped)
                        },
                        onCapeDropped: { _ in }
                    )
                } else {
                    Color.clear
                }
            }
        }
    }

    private func convertToPlayerModel(_ skinModel: PlayerSkinService.PublicSkinInfo.SkinModel) -> PlayerModel {
        switch skinModel {
        case .classic:
            return .steve
        case .slim:
            return .alex
        }
    }

    /// 打开皮肤预览窗口
    private func openSkinPreviewWindow() {
        let playerModel = convertToPlayerModel(currentModel)
        // 存储到 WindowDataStore
        WindowDataStore.shared.skinPreviewData = SkinPreviewData(
            skinImage: selectedSkinImage ?? currentSkinRenderImage,
            skinPath: selectedSkinPath,
            capeImage: selectedCapeImage,
            playerModel: playerModel
        )
        // 打开窗口
        WindowManager.shared.openWindow(id: .skinPreview)
    }
}

// MARK: - View Extension for Conditional Drop
extension View {
    /// 条件性地应用拖拽处理修饰符
    @ViewBuilder
    func conditionalDrop(isEnabled: Bool, perform: @escaping ([NSItemProvider]) -> Bool) -> some View {
        if isEnabled {
            self.onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil, perform: perform)
        } else {
            self
        }
    }
}
