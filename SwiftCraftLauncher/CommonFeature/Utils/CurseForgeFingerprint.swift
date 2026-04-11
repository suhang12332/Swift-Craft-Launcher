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
        let normalizedLength = try computeNormalizedLength(fileAt: url)
        guard normalizedLength > 0 else {
            throw GlobalError.fileSystem(
                chineseMessage: "Jar 文件为空",
                i18nKey: "error.resource.client_jar_not_found",
                level: .notification
            )
        }
        return try computeHash(fileAt: url, normalizedLength: normalizedLength)
    }

    /// 计算 Data 的 CurseForge fingerprint
    public static func fingerprint(data: Data) -> UInt32 {
        let normalizedLength = computeNormalizedLength(data)
        return hashFilteredBytes(normalizedLength: normalizedLength) { consume in
            for byte in data where !isWhitespaceCharacter(byte) {
                consume(byte)
            }
        }
    }

    private static func computeNormalizedLength(_ data: Data) -> UInt32 {
        var count: UInt32 = 0
        for byte in data where !isWhitespaceCharacter(byte) { count &+= 1 }
        return count
    }

    private static func computeNormalizedLength(fileAt url: URL) throws -> UInt32 {
        var count: UInt32 = 0
        try readBytes(fileAt: url) { byte in
            if !isWhitespaceCharacter(byte) {
                count &+= 1
            }
        }
        return count
    }

    private static func computeHash(fileAt url: URL, normalizedLength: UInt32) throws -> UInt32 {
        try hashFilteredBytes(normalizedLength: normalizedLength) { consume in
            try readBytes(fileAt: url) { byte in
                guard !isWhitespaceCharacter(byte) else { return }
                consume(byte)
            }
        }
    }

    private static func hashFilteredBytes(
        normalizedLength: UInt32,
        using byteProducer: (_ consume: (UInt8) -> Void) throws -> Void
    ) rethrows -> UInt32 {
        let seed: UInt32 = 1
        let m: UInt32 = 1540483477
        var hash: UInt32 = seed ^ normalizedLength
        var chunk: UInt32 = 0
        var shift: UInt32 = 0

        try byteProducer { byte in
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

    private static func readBytes(fileAt url: URL, _ handler: (UInt8) -> Void) throws {
        guard let stream = InputStream(url: url) else {
            throw GlobalError.fileSystem(
                chineseMessage: "无法读取文件",
                i18nKey: "error.resource.client_jar_not_found",
                level: .notification
            )
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                throw stream.streamError ?? GlobalError.fileSystem(
                    chineseMessage: "读取文件失败",
                    i18nKey: "error.resource.client_jar_not_found",
                    level: .notification
                )
            }
            if bytesRead == 0 {
                break
            }
            for i in 0..<bytesRead {
                handler(buffer[i])
            }
        }
    }

    private static func isWhitespaceCharacter(_ byte: UInt8) -> Bool {
        ignoredWhitespace.contains(byte)
    }
}
