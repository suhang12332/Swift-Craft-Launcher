import SwiftUI

public struct ContributorsView: View {
    public init() {}
    
    // 贡献者列表
    private let contributors = [
        Contributor(
            name: "contributor.name.zhang_san".localized(),
            role: "contributor.role.main_developer_architect".localized(),
            avatar: "👨‍💻",
            contributions: [.code, .design, .test],
            profileURL: "https://github.com/suhang12332",
            gitHubURL: "https://github.com/suhang12332"
        ),
        Contributor(
            name: "contributor.name.li_si".localized(),
            role: "contributor.role.main_developer".localized(),
            avatar: "👩‍💻",
            contributions: [.test, .feedback],
            profileURL: nil,
            gitHubURL: "https://github.com/alicezhang"
        ),
        Contributor(
            name: "contributor.name.wang_mazi".localized(),
            role: "contributor.role.design_contributor".localized(),
            avatar: "👨‍💻",
            contributions: [.test, .documentation],
            profileURL: nil,
            gitHubURL: "https://github.com/bobliu"
        )
    ]
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 贡献者列表
                ForEach(contributors, id: \.name) { contributor in
                    ContributorRowView(contributor: contributor)
                    
                    // 分隔线
                    if contributor.name != contributors.last?.name {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

// 贡献者数据模型
private struct Contributor {
    let name: String
    let role: String
    let avatar: String
    let contributions: [Contribution]
    let profileURL: String?
    let gitHubURL: String?
    
    enum Contribution: String, CaseIterable {
        case code = "contributor.contribution.code"
        case design = "contributor.contribution.design"
        case test = "contributor.contribution.test"
        case feedback = "contributor.contribution.feedback"
        case documentation = "contributor.contribution.documentation"
        case infra = "contributor.contribution.infra"
        
        var localizedString: String {
            return rawValue.localized()
        }
        
        var color: Color {
            switch self {
            case .code: return .blue
            case .design: return .purple
            case .test: return .green
            case .feedback: return .orange
            case .documentation: return .indigo
            case .infra: return .red
            }
        }
    }
}

// 贡献者行视图
private struct ContributorRowView: View {
    let contributor: Contributor
    
    var body: some View {
        HStack {
            userImage
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(contributor.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                HStack(spacing: 3) {
                    ForEach(contributor.contributions, id: \.self) { item in
                        tag(item)
                    }
                }
            }
            Spacer()
            HStack(alignment: .top, spacing: 8) {
                if let profileURL = contributor.profileURL {
                    ActionButton(url: profileURL, image: Image(systemName: "globe"))
                }
                if let gitHubURL = contributor.gitHubURL {
                    ActionButton(url: gitHubURL, image: Image("github-mark"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var userImage: some View {
        Text(contributor.avatar)
            .font(.title2)
            .frame(width: 32, height: 32)
            .clipShape(Circle())
    }
    
    private func tag(_ item: Contributor.Contribution) -> some View {
        Text(item.localizedString)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .foregroundColor(item.color)
            .background {
                Capsule(style: .continuous)
                    .strokeBorder(lineWidth: 1)
                    .foregroundStyle(item.color)
                    .opacity(0.8)
            }
    }
    
    private struct ActionButton: View {
        @Environment(\.openURL)
        private var openURL
        @State private var hovering = false
        
        let url: String
        let image: Image
        
        var body: some View {
            Button {
                if let url = URL(string: url) {
                    openURL(url)
                }
            } label: {
                image.resizable().frame(width: 14,height: 14)
                    .imageScale(.medium)
                    .foregroundColor(hovering ? .primary : .secondary)
                    
            }
            .buttonStyle(.plain)
            .onHover { hover in
                hovering = hover
            }
        }
    }
}

#Preview {
    ContributorsView()
} 
