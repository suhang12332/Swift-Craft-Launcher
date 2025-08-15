import SwiftUI

public struct AcknowledgementsView: View {
    public init() {}
    
    // 开源库列表
    private let openSourceLibraries = [
        OpenSourceLibrary(
            name: "acknowledgements.library.modrinth".localized(),
            url: "https://modrinth.com/"
        ),
        OpenSourceLibrary(
            name: "acknowledgements.library.fabric".localized(),
            url: "https://fabricmc.net/"
        ),
        OpenSourceLibrary(
            name: "acknowledgements.library.quilt".localized(),
            url: "https://quiltmc.org/"
        ),
        OpenSourceLibrary(
            name: "acknowledgements.library.neoforge".localized(),
            url: "https://neoforged.net/"
        ),
        OpenSourceLibrary(
            name: "acknowledgements.library.minecraft_forge".localized(),
            url: "https://files.minecraftforge.net/"
        ),
        OpenSourceLibrary(
            name: "acknowledgements.library.zipfoundation".localized(),
            url: "https://github.com/weichsel/ZIPFoundation"
        ),
        OpenSourceLibrary(
            name: "acknowledgements.library.markdownui".localized(),
            url: "https://github.com/gonzalezreal/swift-markdown-ui"
        ),
        OpenSourceLibrary(
            name: "acknowledgements.library.minecraftnbt".localized(),
            url: "https://github.com/ezfe/swift-nbt"
        ),
        OpenSourceLibrary(
            name: "acknowledgements.library.sparkle".localized(),
            url: "https://github.com/sparkle-project/Sparkle"
        )
    ]
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // 开源库列表
                ForEach(Array(openSourceLibraries.enumerated()), id: \.element.name) { index, library in
                    VStack(spacing: 0) {
                        HStack {
                            Text(library.name)
                                .foregroundColor(.secondary)

                            Spacer()
                            
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        // 分隔线
                        if index < openSourceLibraries.count - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }
}

// 开源库数据模型
private struct OpenSourceLibrary {
    let name: String
    let url: String
}

#Preview {
    AcknowledgementsView()
}
