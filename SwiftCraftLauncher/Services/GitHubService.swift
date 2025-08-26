import Foundation

// MARK: - GitHub Service
@MainActor
public class GitHubService: ObservableObject {
    public static let shared = GitHubService()
    
    private let session = URLSession.shared
    private let baseURL = "https://api.github.com"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 获取仓库贡献者列表
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - page: 页码（默认1）
    ///   - perPage: 每页数量（默认30，最大100）
    /// - Returns: 贡献者列表
    public func fetchContributors(
        owner: String,
        repo: String,
        page: Int = 1,
        perPage: Int = 30
    ) async throws -> [GitHubContributor] {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contributors")!
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        
        guard let finalURL = components.url else {
            throw GitHubError.invalidURL
        }
        
        var request = URLRequest(url: finalURL)
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.addValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let contributors = try JSONDecoder().decode([GitHubContributor].self, from: data)
                return contributors
            case 404:
                throw GitHubError.repositoryNotFound
            case 403:
                throw GitHubError.rateLimitExceeded
            default:
                throw GitHubError.apiError(httpResponse.statusCode)
            }
        } catch {
            if error is GitHubError {
                throw error
            }
            throw GitHubError.networkError(error)
        }
    }
    
    /// 获取仓库信息
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    /// - Returns: 仓库信息
    public func fetchRepository(owner: String, repo: String) async throws -> GitHubRepository {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)")!
        
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.addValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let repository = try JSONDecoder().decode(GitHubRepository.self, from: data)
                return repository
            case 404:
                throw GitHubError.repositoryNotFound
            case 403:
                throw GitHubError.rateLimitExceeded
            default:
                throw GitHubError.apiError(httpResponse.statusCode)
            }
        } catch {
            if error is GitHubError {
                throw error
            }
            throw GitHubError.networkError(error)
        }
    }
}

// MARK: - GitHub Error Types
public enum GitHubError: LocalizedError {
    case invalidURL
    case invalidResponse
    case repositoryNotFound
    case rateLimitExceeded
    case apiError(Int)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub URL"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .repositoryNotFound:
            return "Repository not found"
        case .rateLimitExceeded:
            return "GitHub API rate limit exceeded"
        case .apiError(let statusCode):
            return "GitHub API error: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .repositoryNotFound:
            return "Please check the repository owner and name"
        case .rateLimitExceeded:
            return "Please try again later"
        case .networkError:
            return "Please check your internet connection"
        default:
            return nil
        }
    }
}


