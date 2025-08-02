import SwiftUI

public struct AcknowledgementsView: View {
    @State private var showModding = true
    @State private var showResource = false
    @State private var showOther = false
    @State private var showContributors = false

    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                

                DisclosureGroup("🧱 Minecraft Modding 平台", isExpanded: $showModding) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        OpenSourceRow(
                            name: "Minecraft Forge",
                            url: "https://files.minecraftforge.net/",
                            description: "最早的 Minecraft Modding 平台，为数千个 Mod 提供支持。"
                        )
                        OpenSourceRow(
                            name: "NeoForge",
                            url: "https://neoforged.net/",
                            description: "Forge 的现代化社区驱动分支，保持活跃维护与进化。"
                        )
                        OpenSourceRow(
                            name: "Quilt",
                            url: "https://quiltmc.org/",
                            description: "Fabric 的社区驱动衍生项目，强调模块化与开放性。"
                        )
                        OpenSourceRow(
                            name: "Fabric",
                            url: "https://fabricmc.net/",
                            description: "轻量级、高性能的 Modding 平台，支持快速迭代。"
                        )
                    }
                    .padding(.top, 8)
                }

                DisclosureGroup("🧱 Mod资源平台", isExpanded: $showResource) {
                    HStack(alignment: .top, spacing: 20) {
                        OpenSourceRow(
                            name: "Modrinth",
                            url: "https://modrinth.com/",
                            description: "modrinth平台"
                        )
                        OpenSourceRow(
                            name: "CurseForge",
                            url: "https://www.curseforge.com/",
                            description: "curseforge平台"
                        )
                    }
                    .padding(.top, 8)
                }

                DisclosureGroup("🧱 其他资源平台", isExpanded: $showOther) {
                    OpenSourceRow(
                        name: "BMCLAPI",
                        url: "https://bmclapidoc.bangbang93.com/",
                        description: "BMCLAPI"
                    )
                    .padding(.top, 8)
                }

                Divider()

                DisclosureGroup("👨‍💻 参与人员", isExpanded: $showContributors) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "代码提供人员")
                        Text("• su hang（主开发）")
                        SectionHeader(title: "参与测试")
                        Text("• Alice Zhang\n• Bob Liu")
                    }
                    .padding(.top, 8)
                }

                Divider()
                Text("本项目建立在多个优秀开源 Minecraft Modding 平台之上，感谢这些社区为开发者提供了坚实的基础。")
                    .font(.headline)
                Text("© 2025 Swift Craft Launcher. Powered by Su.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2)
            .bold()
            .padding(.top, 10)
    }
}

struct OpenSourceRow: View {
    let name: String
    let url: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Link(destination: URL(string: url)!) {
                Text(name)
                    .font(.headline)
            }
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AcknowledgementsView()
}
