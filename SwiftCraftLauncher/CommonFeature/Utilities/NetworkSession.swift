import Foundation

enum NetworkSession {
    static let sharedConfiguration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.httpMaximumConnectionsPerHost = 16
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return configuration
    }()

    static func makeSession(
        delegate: URLSessionDelegate? = nil,
        configure: ((URLSessionConfiguration) -> Void)? = nil
    ) -> URLSession {
        let configuration = newConfiguration()
        configure?(configuration)
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    private static func newConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = sharedConfiguration.timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = sharedConfiguration.timeoutIntervalForResource
        configuration.httpMaximumConnectionsPerHost = sharedConfiguration.httpMaximumConnectionsPerHost
        configuration.waitsForConnectivity = sharedConfiguration.waitsForConnectivity
        configuration.requestCachePolicy = sharedConfiguration.requestCachePolicy
        return configuration
    }
}
