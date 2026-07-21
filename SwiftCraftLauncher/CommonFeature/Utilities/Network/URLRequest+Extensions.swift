//
//  URLRequest+Extensions.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension URLRequest {
    func headers(_ headers: [String: String]?) -> URLRequest {
        var request = self
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    func methods(_ method: String) -> URLRequest {
        var request = self
        request.httpMethod = method
        return request
    }

    func bodys(_ body: Data?) -> URLRequest {
        var request = self
        request.httpBody = body
        return request
    }
}
