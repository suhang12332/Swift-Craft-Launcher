import SwiftUI

public struct AboutView: View {
    @State private var showingAcknowledgements: Bool
    
    public init(showingAcknowledgements: Bool = true) {
        self._showingAcknowledgements = State(initialValue: showingAcknowledgements)
    }
    
    // MARK: - Computed Properties
    private var appName: String { Bundle.main.appName }
    private var appVersion: String { Bundle.main.appVersion }
    private var buildNumber: String { Bundle.main.buildNumber }
    private var copyright: String { Bundle.main.copyright }
    
    public var body: some View {
        VStack(spacing: 12) {
            headerSection
            contentSection
            footerSection
        }
//        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 280,height: 600)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            appIconView
            titleSection
        }
        
        
        
    }
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text(copyright)
                .foregroundColor(.primary)
                .font(.system(size: 10))
        }
        
        
        
    }
    private var appIconView: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .frame(width: 64, height: 64)
    }
    
    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(appName)
                .font(.system(size: 14, weight: .bold))
                .multilineTextAlignment(.center)
            
            Text(String(format: "about.version.format".localized(), appVersion, buildNumber))
                .foregroundColor(.primary)
                .font(.system(size: 10))
        }
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 0) {
            if showingAcknowledgements {
                AcknowledgementsView()
            } else {
                ContributorsView()
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    AboutView()
}
