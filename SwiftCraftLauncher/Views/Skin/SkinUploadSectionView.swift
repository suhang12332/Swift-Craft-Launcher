import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SkinRenderKit

struct SkinUploadSectionView: View {
    @Binding var currentModel: PlayerSkinService.PublicSkinInfo.SkinModel
    @Binding var showingFileImporter: Bool
    @Binding var selectedSkinImage: NSImage?
    @Binding var selectedSkinPath: String?
    @Binding var currentSkinRenderImage: NSImage?
    @Binding var selectedCapeLocalPath: String?
    @Binding var showingSkinPreview: Bool

    let onSkinDropped: (NSImage) -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("skin.upload".localized()).font(.headline)

            skinRenderArea

            VStack(alignment: .leading, spacing: 4) {
                Text("Drop skin file here or click to select")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("PNG 64×64 or legacy 64×32")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private var skinRenderArea: some View {
        let playerModel = convertToPlayerModel(currentModel)

        return ZStack {
            Group {
                if let image = selectedSkinImage ?? currentSkinRenderImage {
                    SkinRenderView(
                        skinImage: image,
                        capeImage: nil,
                        playerModel: playerModel,
                        rotationDuration: 12.0,
                        backgroundColor: .clear,
                        onSkinDropped: { dropped in
                            onSkinDropped(dropped)
                        },
                        onCapeDropped: { _ in }
                    )
                } else if let skinPath = selectedSkinPath {
                    SkinRenderView(
                        texturePath: skinPath,
                        capeTexturePath: selectedCapeLocalPath,
                        playerModel: playerModel,
                        rotationDuration: 12.0,
                        backgroundColor: .clear,
                        onSkinDropped: { dropped in
                            onSkinDropped(dropped)
                        },
                        onCapeDropped: { _ in }
                    )
                } else {
                    Color.clear
                }
            }
            .frame(height: 220)
            .background(Color.gray.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundColor(.gray.opacity(0.35))
            )
            .cornerRadius(10)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .onTapGesture { showingFileImporter = true }
        .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil, perform: onDrop)
    }

    private func convertToPlayerModel(_ skinModel: PlayerSkinService.PublicSkinInfo.SkinModel) -> PlayerModel {
        switch skinModel {
        case .classic:
            return .steve
        case .slim:
            return .alex
        }
    }
}
