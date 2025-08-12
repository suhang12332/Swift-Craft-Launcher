import SwiftUI

/// 关于页面视图
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDetailView = false
    @State private var selectedView: DetailViewType? = nil
    
    // MARK: - Enums
    private enum DetailViewType: String, CaseIterable {
        case acknowledgements = "acknowledgements"
        case contributors = "contributors"
        
        var title: String { 
            switch self {
            case .acknowledgements:
                return "about.acknowledgements".localized()
            case .contributors:
                return "about.contributors".localized()
            }
        }
    }
    
    // MARK: - Constants
    private enum Constants {
        static let iconSizeNormal: CGFloat = 128
        static let iconSizeCompact: CGFloat = 64
        static let animationDuration: Double = 0.3
        static let buttonAreaOffset: CGFloat = -30
        static let versionOffset: CGFloat = -10
        static let windowWidth: CGFloat = 280
        static let titleFontSize: CGFloat = 26
        static let titleFontWeight: Font.Weight = .bold
        static let titleMinimumScaleFactor: CGFloat = 0.5
        static let versionFontSize: CGFloat = 11
        static let versionFontWeight: Font.Weight = .regular
        static let spacing: CGFloat = 12
        static let headerPadding: CGFloat = 24
        static let compactHeaderPadding: CGFloat = 14
        static let buttonSpacing: CGFloat = 8
        static let footerSpacing: CGFloat = 10
        static let versionTopPadding: CGFloat = 4
    }
    
    // MARK: - Computed Properties
    private var appName: String { Bundle.main.appName }
    private var appVersion: String { Bundle.main.appVersion }
    private var buildNumber: String { Bundle.main.buildNumber }
    private var copyright: String { Bundle.main.copyright }
    
    private var currentIconSize: CGFloat {
        showDetailView ? Constants.iconSizeCompact : Constants.iconSizeNormal
    }
    
    private var currentIconPadding: (top: CGFloat, bottom: CGFloat) {
        showDetailView ? (8, 4) : (16, 8)
    }
    
    private var displayTitle: String {
        showDetailView ? (selectedView?.title ?? "") : appName
    }
    
    private var shouldShowChevron: Bool { showDetailView }
    
    private var headerBottomPadding: CGFloat {
        showDetailView ? Constants.headerPadding - Constants.compactHeaderPadding : Constants.headerPadding
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: Constants.spacing) {
            headerSection
            contentSection
        }
        .frame(width: Constants.windowWidth)
        .fixedSize(horizontal: true, vertical: false)
        .animation(.easeInOut(duration: Constants.animationDuration), value: showDetailView)
        .animation(.easeInOut(duration: Constants.animationDuration), value: selectedView)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            appIconView
            titleSection
        }
        .padding([.top, .leading, .trailing], Constants.headerPadding)
        .padding(.bottom, headerBottomPadding)
    }
    
    private var appIconView: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .matchedGeometryEffect(id: "appIcon", in: namespace)
            .frame(width: currentIconSize, height: currentIconSize)
            .padding(.top, currentIconPadding.top)
            .padding(.bottom, currentIconPadding.bottom)
    }
    
    private var titleSection: some View {
        VStack(spacing: 0) {
            titleButton
            versionInfo
        }
        .matchedGeometryEffect(
            id: "title",
            in: namespace,
            properties: [.position, .size],
            anchor: .center
        )
        .padding(.horizontal)
    }
    
    private var titleButton: some View {
        Button(action: handleTitleButtonTap) {
            HStack {
                if shouldShowChevron {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
                Text(displayTitle)
                    .foregroundColor(.primary)
                    .font(.system(size: Constants.titleFontSize, weight: Constants.titleFontWeight))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(Constants.titleMinimumScaleFactor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .drawingGroup()
    }
    
    private var versionInfo: some View {
        Text(String(format: "about.version.format".localized(), appVersion, buildNumber))
            .foregroundColor(Color(.tertiaryLabelColor))
            .font(.body)
            .padding(.top, Constants.versionTopPadding)
            .offset(y: showDetailView ? Constants.versionOffset : 0)
            .opacity(showDetailView ? 0 : 1)
            .drawingGroup()
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack {
            if showDetailView {
                detailView
            } else {
                buttonSection
                footerSection
            }
        }
        .matchedGeometryEffect(id: "titleBar", in: namespace, properties: [.position, .size], anchor: .top)
        .offset(y: showDetailView ? Constants.buttonAreaOffset : 0)
        .padding(.horizontal)
    }
    
    private var detailView: some View {
        VStack(spacing: 0) {
            if let selectedView = selectedView {
                switch selectedView {
                case .acknowledgements:
                    AcknowledgementsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom)
                case .contributors:
                    ContributorsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom)
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
    
    private var buttonSection: some View {
        VStack(spacing: Constants.buttonSpacing) {
            ForEach(DetailViewType.allCases, id: \.self) { viewType in
                detailButton(for: viewType)
            }
        }
        .padding()
    }
    
    private func detailButton(for viewType: DetailViewType) -> some View {
        Button(action: { showDetailView(viewType) }) {
            Text(viewType.title)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .foregroundStyle(.gray.opacity(0.2))
    }
    
    private var footerSection: some View {
        HStack(spacing: Constants.footerSpacing) {
            Text(copyright)
                .font(.system(size: Constants.versionFontSize, weight: Constants.versionFontWeight))
                .foregroundColor(Color(.tertiaryLabelColor))
        }
        .padding()
    }
    
    // MARK: - Actions
    private func handleTitleButtonTap() {
        if showDetailView {
            hideDetailView()
        }
    }
    
    private func showDetailView(_ viewType: DetailViewType) {
        selectedView = viewType
        withAnimation(.easeInOut(duration: Constants.animationDuration)) {
            showDetailView = true
        }
    }
    
    private func hideDetailView() {
        withAnimation(.easeInOut(duration: Constants.animationDuration)) {
            showDetailView = false
            selectedView = nil
        }
    }
    
    // MARK: - Namespace
    @Namespace private var namespace
}

#Preview {
    AboutView()
} 
