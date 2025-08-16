import SwiftUI

// MARK: - Constants
private enum Constants {
    static let iconSize: CGFloat = 22
    static let cornerRadius: CGFloat = 6
    static let spacing: CGFloat = 8
    static let pageSize: Int = 20
}

// MARK: - ProjectDetailHeaderView
struct ModrinthProjectDetailToolbarView: View {
    let projectDetail: ModrinthProjectDetail?
    @Binding var selectedTab: Int
    @Binding var versionCurrentPage: Int
    @Binding var versionTotal: Int
    let gameId: String?
    var onBack: () -> Void

    var body: some View {
        backButton
        
        if selectedTab == 1 {
            Spacer()
            versionPaginationControls
        }
        Spacer()
//        projectIconAndTitle
//        Spacer()
        
        tabPicker
    }
    
//    // MARK: - UI Components
//    private var projectIconAndTitle: some View {
//        Group {
//            if let project = projectDetail {
//                HStack(spacing: Constants.spacing) {
//                    projectIcon
//                    Text(project.title)
//                        .font(.headline)
//                }
//            } else {
//                ProgressView()
//                    .controlSize(.small)
//            }
//        }
//    }
//    
//    private var projectIcon: some View {
//        Group {
//            if let project = projectDetail,
//               let iconUrl = project.iconUrl,
//               let url = URL(string: iconUrl) {
//                AsyncImage(url: url) { phase in
//                    switch phase {
//                    case .empty:
//                        Color.gray.opacity(0.2)
//                    case .success(let image):
//                        image
//                            .resizable()
//                            .aspectRatio(contentMode: .fill)
//                    case .failure:
//                        Image(systemName: "photo")
//                            .foregroundColor(.secondary)
//                    @unknown default:
//                        EmptyView()
//                    }
//                }
//                .frame(width: Constants.iconSize, height: Constants.iconSize)
//                .cornerRadius(Constants.cornerRadius)
//                .clipped()
//            } else {
//                Image(systemName: "photo")
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: Constants.iconSize, height: Constants.iconSize)
//                    .foregroundColor(.secondary)
//            }
//        }
//    }
//
    
    
    private var versionPaginationControls: some View {
        HStack(spacing: Constants.spacing) {
            Button(action: { versionCurrentPage -= 1 }) {
                Label("pagination.help".localized(),systemImage: "chevron.left")
            }
            .disabled(versionCurrentPage <= 1)
            
            HStack(spacing: Constants.spacing) {
                Text(
                    String(
                        format: "pagination.current".localized(),
                        versionCurrentPage
                    )
                )
                Divider().frame(height: 16)
                Text(String(format: "pagination.total".localized(), versionTotalPages))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            Button(action: { versionCurrentPage += 1 }) {
                Label("pagination.help".localized(),systemImage: "chevron.right")
            }
            .disabled(versionCurrentPage == versionTotalPages)
        }.help("pagination.help".localized())
    }
    
    private var backButton: some View {
        Button(action: onBack) {
            Label("return".localized(),systemImage: "return").help("return".localized())
        }
    }
    
    private var tabPicker: some View {
        Picker("view.mode.title".localized(), selection: $selectedTab) {
            Label("view.mode.details".localized(), systemImage: "doc.text")
                .tag(0)
            if gameId == nil {
                Label("view.mode.downloads".localized(), systemImage: "arrow.down.circle")
                    .tag(1)
                Label("view.mode.downloads".localized(), systemImage: "rectangle.2.swap")
                    .tag(2)
            }
        }
        .help("view.mode.title".localized())
        .pickerStyle(.segmented)
        .background(.clear)
    }
    
    // MARK: - Computed Properties
    private var versionTotalPages: Int {
        max(1, Int(ceil(Double(versionTotal) / Double(Constants.pageSize))))
    }
}
