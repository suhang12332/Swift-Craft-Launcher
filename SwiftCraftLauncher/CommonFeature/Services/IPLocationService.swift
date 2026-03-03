import Foundation

/// IP地理位置服务
/// 检测用户 IP 所在国家/地区
@MainActor
class IPLocationService: ObservableObject {
    static let shared = IPLocationService()

    private init() {}

    /// 检查是否为国外IP（静默版本）
    /// - Returns: 是否为国外IP，如果检测失败则返回false（允许添加离线账户）
    func isForeignIP() async -> Bool {
        do {
            return try await isForeignIPThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("检测IP地理位置失败: \(globalError.chineseMessage)")
            // 静默失败，返回false（允许添加离线账户）
            return false
        }
    }

    /// 检查是否为国外IP（抛出异常版本）
    /// - Returns: 是否为国外IP
    /// - Throws: GlobalError 当检测失败时
    func isForeignIPThrowing() async throws -> Bool {
        // 请求地理位置信息
        let url = URLConfig.API.IPLocation.currentLocation
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0

        // 使用 performRequestWithResponse 来获取完整的响应信息，包括状态码
        let (data, httpResponse) = try await APIClient.performRequestWithResponse(request: request)

        // 即使状态码不是200，也尝试解析响应（因为某些API可能返回429但仍在响应体中包含数据）
        let locationResponse: IPLocationResponse
        do {
            locationResponse = try JSONDecoder().decode(IPLocationResponse.self, from: data)
        } catch {
            // 如果解析失败，记录状态码以便调试
            Logger.shared.error("解析IP地理位置响应失败: HTTP \(httpResponse.statusCode), error: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.shared.error("响应内容: \(responseString)")
            }
            throw GlobalError.validation(
                chineseMessage: "解析IP地理位置响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.ip_location_parse_failed",
                level: .notification
            )
        }

        // 如果状态码不是200，记录警告但继续处理（因为可能仍然有有效数据）
        if httpResponse.statusCode != 200 {
            Logger.shared.warning("IP地理位置API返回非200状态码: \(httpResponse.statusCode)")
        }

        // 检查请求是否成功
        guard locationResponse.isSuccess else {
            let errorMessage = locationResponse.reason ?? "IP地理位置检测失败"
            Logger.shared.error("IP地理位置检测失败: \(errorMessage), 国家代码: \(locationResponse.countryCode ?? "未知")")
            throw GlobalError.network(
                chineseMessage: errorMessage,
                i18nKey: "error.network.ip_location_failed",
                level: .notification
            )
        }

        Logger.shared.debug("IP地理位置检测完成: 国家代码 = \(locationResponse.countryCode ?? "未知"), 是否为国外 = \(locationResponse.isForeign)")

        return locationResponse.isForeign
    }
}
