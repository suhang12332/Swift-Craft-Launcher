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
    let gameId: String?
    var onBack: () -> Void

    var body: some View {
        backButton
        //        projectIconAndTitle
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

    private var backButton: some View {
        Button(action: onBack) {
            Label("return".localized(), systemImage: "arrow.backward").help(
                "return".localized()
            )
        }
    }
}
