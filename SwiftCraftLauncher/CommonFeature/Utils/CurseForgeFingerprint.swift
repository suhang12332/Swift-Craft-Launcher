import Foundation

public enum CurseForgeFingerprint {
    // \t \n \r space
    private static let ignoredWhitespace: Set<UInt8> = [
        0x09,
        0x0A,
        0x0D,
        0x20,
    ]

    /// 计算文件的 CurseForge fingerprint
    public static func fingerprint(fileAt url: URL) throws -> UInt32 {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw GlobalError.fileSystem(
                chineseMessage: "Jar 文件为空",
                i18nKey: "error.resource.client_jar_not_found",
                level: .notification
            )
        }
        return fingerprint(data: data)
    }

    /// 计算 Data 的 CurseForge fingerprint
    public static func fingerprint(data: Data) -> UInt32 {
        let normalizedLength = computeNormalizedLength(data)
        let seed: UInt32 = 1
        let m: UInt32 = 1540483477

        var hash: UInt32 = seed ^ normalizedLength
        var chunk: UInt32 = 0
        var shift: UInt32 = 0

        for byte in data where !isWhitespaceCharacter(byte) {
            chunk |= UInt32(byte) << shift
            shift &+= 8

            if shift == 32 {
                let k1 = chunk &* m
                let k2 = (k1 ^ (k1 >> 24)) &* m
                hash = (hash &* m) ^ k2

                chunk = 0
                shift = 0
            }
        }

        if shift > 0 {
            hash = (hash ^ chunk) &* m
        }

        let h1 = (hash ^ (hash >> 13)) &* m
        return h1 ^ (h1 >> 15)
    }

    private static func computeNormalizedLength(_ data: Data) -> UInt32 {
        var count: UInt32 = 0
        for byte in data where !isWhitespaceCharacter(byte) { count &+= 1 }
        return count
    }

    private static func isWhitespaceCharacter(_ byte: UInt8) -> Bool {
        ignoredWhitespace.contains(byte)
    }
}
