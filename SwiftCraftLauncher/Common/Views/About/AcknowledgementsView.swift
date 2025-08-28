import SwiftUI

public struct AcknowledgementsView: View {
    public init() {}

    // 项目使用的开源库列表
    private let allLibraries = [
        OpenSourceLibrary(
            name: "Modrinth",
            url: "https://modrinth.com/"
        ),
        OpenSourceLibrary(
            name: "Fabric",
            url: "https://fabricmc.net/"
        ),
        OpenSourceLibrary(
            name: "Quilt".localized(),
            url: "https://quiltmc.org/"
        ),
        OpenSourceLibrary(
            name: "Neoforge".localized(),
            url: "https://neoforged.net/"
        ),
        OpenSourceLibrary(
            name: "MinecraftForge".localized(),
            url: "https://files.minecraftforge.net/"
        ),
        OpenSourceLibrary(
            name: "GzipSwift",
            url: "https://github.com/1024jp/GzipSwift"
        ),
        OpenSourceLibrary(
            name: "NetworkImage",
            url: "https://github.com/gonzalezreal/NetworkImage"
        ),
        OpenSourceLibrary(
            name: "Sparkle",
            url: "https://github.com/sparkle-project/Sparkle"
        ),
        OpenSourceLibrary(
            name: "swift-cmark",
            url: "https://github.com/swiftlang/swift-cmark"
        ),
        OpenSourceLibrary(
            name: "swift-collections",
            url: "https://github.com/apple/swift-collections"
        ),
        OpenSourceLibrary(
            name: "swift-markdown-ui",
            url: "https://github.com/gonzalezreal/swift-markdown-ui"
        ),
        OpenSourceLibrary(
            name: "swift-nbt",
            url: "https://github.com/ezfe/swift-nbt"
        ),
        OpenSourceLibrary(
            name: "ZIPFoundation",
            url: "https://github.com/weichsel/ZIPFoundation"
        ),
    ]

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // 开源库列表
                ForEach(Array(allLibraries.enumerated()), id: \.element.name) {
                    index,
                    library in
                    VStack(spacing: 0) {
                        Link(destination: URL(string: library.url)!) {
                            HStack {
                                Text(library.name)
                                    .foregroundColor(.primary)

                                Spacer()

                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }

                        // 分隔线
                        if index < allLibraries.count - 1 {
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
