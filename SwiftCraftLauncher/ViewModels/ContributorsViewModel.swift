import Foundation
import SwiftUI

// MARK: - Contributors View Model
@MainActor
public class ContributorsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public var contributors: [GitHubContributor] = []
    @Published public var isLoading: Bool = false
    
    // MARK: - Private Properties
    private let gitHubService = GitHubService.shared
    
    // MARK: - Initialization
    public init() {
        Task {
            await fetchContributors()
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取贡献者列表
    public func fetchContributors() async {
        isLoading = true
        
        do {
            let contributorsList = try await gitHubService.fetchContributors(perPage: 50)
            contributors = contributorsList
        } catch {
            // 静默处理错误
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    
    /// 格式化贡献数量
    public func formatContributions(_ count: Int) -> String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fk", thousands)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Extensions
extension ContributorsViewModel {
    /// 获取排序后的贡献者（按贡献数量降序）
    public var sortedContributors: [GitHubContributor] {
        contributors.sorted { $0.contributions > $1.contributions }
    }
    
    /// 获取顶级贡献者（前3名）
    public var topContributors: [GitHubContributor] {
        Array(sortedContributors.prefix(3))
    }
    
    /// 获取其他贡献者
    public var otherContributors: [GitHubContributor] {
        Array(sortedContributors.dropFirst(3))
    }
}


