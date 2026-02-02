import Foundation

/// 房间码生成器
/// 生成符合 U/XXXX-XXXX-XXXX-XXXX 格式的房间码
/// 使用 34 进制编码（0-9, A-Z，排除 I 和 O）
/// 基于 Terracotta 的房间号生成机制
enum RoomCodeGenerator {
    // MARK: - Constants

    /// 字符集：34 个字符（0-9, A-Z，排除 I 和 O）
    /// 字符索引对应：0-33
    private static let chars: [Character] = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")

    /// 字符到索引的映射（0-33）
    private static let charToIndex: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (index, char) in chars.enumerated() {
            map[char] = index
        }
        return map
    }()

    /// 字符查找函数（支持字符映射：I -> 1, O -> 0）
    /// - Parameter char: 输入字符
    /// - Returns: 字符索引（0-33），如果字符无效则返回 nil
    private static func lookupChar(_ char: Character) -> Int? {
        // 字符映射：I -> 1, O -> 0
        let normalizedChar: Character
        switch char {
        case "I":
            normalizedChar = "1"
        case "O":
            normalizedChar = "0"
        default:
            normalizedChar = char
        }

        return charToIndex[normalizedChar]
    }

    // MARK: - Public Methods

    /// 生成一个新的房间码
    /// - Returns: 符合格式的房间码（U/XXXX-XXXX-XXXX-XXXX）
    static func generate() -> String {
        // 生成 16 个随机字符索引（每个在 [0, 33] 范围内）
        var charIndices = [Int]()
        for _ in 0..<16 {
            charIndices.append(Int.random(in: 0..<34))
        }

        // 步骤 3: 计算当前值的模 7
        var mod7Value = 0
        for charIndex in charIndices {
            // 使用模运算的性质：(a * 34 + b) % 7 = ((a % 7) * (34 % 7) + b) % 7
            // 34 % 7 = 6
            mod7Value = (mod7Value * 6 + charIndex) % 7
        }

        // 步骤 4: 调整为 7 的倍数（调整最后一个字符）
        if mod7Value != 0 {
            // 模7值计算：mod7Value = (baseMod * 6 + lastCharIndex) % 7
            // 其中 baseMod 是前15个字符的贡献
            // 目标：0 = (baseMod * 6 + newLastChar) % 7
            // 所以：newLastChar ≡ -baseMod * 6 (mod 7)
            // 而：baseMod * 6 ≡ mod7Value - lastCharIndex (mod 7)
            // 因此：newLastChar ≡ -(mod7Value - lastCharIndex) ≡ lastCharIndex - mod7Value (mod 7)

            let lastCharIndex = charIndices[15]
            let targetLastCharMod = (lastCharIndex - mod7Value + 7) % 7

            // 在 [0, 33] 范围内找到一个值，其模 7 等于 targetLastCharMod
            // 并且尽可能接近原来的值
            var bestNewLastChar = lastCharIndex
            var bestDistance = 34

            for candidate in 0..<34 where candidate % 7 == targetLastCharMod {
                let distance = abs(candidate - lastCharIndex)
                if distance < bestDistance {
                    bestDistance = distance
                    bestNewLastChar = candidate
                }
            }

            charIndices[15] = bestNewLastChar
        }

        // 步骤 5: 编码为字符串
        var code = "U/"
        var networkName = "scaffolding-mc-"
        var networkSecret = ""

        for i in 0..<16 {
            let char = chars[charIndices[i]]

            // 房间号编码（添加分隔符）
            if i == 4 || i == 8 || i == 12 {
                code.append("-")
            }
            code.append(char)

            // 网络名称编码（前 8 个字符）
            if i < 8 {
                if i == 4 {
                    networkName.append("-")
                }
                networkName.append(char)
            }
            // 网络密钥编码（后 8 个字符）
            else {
                if i == 12 {
                    networkSecret.append("-")
                }
                networkSecret.append(char)
            }
        }

        Logger.shared.debug("生成房间码: \(code)")
        return code
    }

    /// 验证房间码是否有效
    /// - Parameter roomCode: 房间码字符串（格式：U/XXXX-XXXX-XXXX-XXXX）
    /// - Returns: 是否有效
    static func validate(_ roomCode: String) -> Bool {
        return parse(roomCode) != nil
    }

    /// 解析房间码字符串
    /// 支持滑动窗口搜索和字符映射（I -> 1, O -> 0）
    /// - Parameter code: 房间码字符串
    /// - Returns: 解析后的房间码字符串（规范化格式），如果无效则返回 nil
    static func parse(_ code: String) -> String? {
        // 步骤 1: 规范化输入（转换为大写）
        let normalizedCode = code.uppercased()
        let codeChars = Array(normalizedCode)

        // 步骤 2: 长度检查
        // 房间号格式：U/XXXX-XXXX-XXXX-XXXX
        // 前缀：U/ = 2 字符
        // 主体：XXXX-XXXX-XXXX-XXXX = 16 字符 + 3 分隔符 = 19 字符
        // 总计：21 字符
        let targetLength = 21
        guard codeChars.count >= targetLength else {
            return nil
        }

        // 步骤 3: 滑动窗口查找
        for startIndex in 0...(codeChars.count - targetLength) {
            let window = Array(codeChars[startIndex..<(startIndex + targetLength)])

            // 步骤 4: 前缀验证
            guard window[0] == "U", window[1] == "/" else {
                continue
            }

            // 步骤 5: 解码和校验
            // 跳过前缀 "U/"（2 个字符），处理主体部分
            // 主体部分结构：XXXX-XXXX-XXXX-XXXX
            // 窗口位置：0-1(U/), 2-5(字符), 6(分隔符), 7-10(字符), 11(分隔符), 12-15(字符), 16(分隔符), 17-20(字符)
            // 分隔符位置（窗口索引）：6, 11, 16
            // 字符位置（窗口索引）：2-5, 7-10, 12-15, 17-20
            let separatorPositions = [6, 11, 16]
            let charPositions = [2, 3, 4, 5, 7, 8, 9, 10, 12, 13, 14, 15, 17, 18, 19, 20]

            // 检查分隔符
            var separatorsValid = true
            for sepPos in separatorPositions {
                if sepPos >= window.count || window[sepPos] != "-" {
                    separatorsValid = false
                    break
                }
            }

            guard separatorsValid else {
                continue  // 分隔符位置错误，尝试下一个窗口
            }

            // 提取字符并解码
            var charIndices = [Int]()
            var charsValid = true
            for charPos in charPositions {
                guard charPos < window.count else {
                    charsValid = false
                    break
                }

                guard let charIndex = lookupChar(window[charPos]) else {
                    charsValid = false
                    break
                }

                charIndices.append(charIndex)
            }

            guard charsValid && charIndices.count == 16 else {
                continue  // 字符无效或数量不足，尝试下一个窗口
            }

            // 步骤 6: 数学校验（检查是否为 7 的倍数）
            // 使用模运算的性质：(a * 34 + b) % 7 = ((a % 7) * (34 % 7) + b) % 7
            // 34 % 7 = 6
            var mod7Value = 0
            for charIndex in charIndices {
                mod7Value = (mod7Value * 6 + charIndex) % 7
            }

            if mod7Value == 0 {
                // 步骤 7: 重新编码（规范化）
                var normalizedRoomCode = "U/"
                for i in 0..<16 {
                    if i == 4 || i == 8 || i == 12 {
                        normalizedRoomCode.append("-")
                    }
                    normalizedRoomCode.append(chars[charIndices[i]])
                }
                return normalizedRoomCode
            }
        }

        return nil
    }

    /// 从房间码提取网络名称和密钥
    /// - Parameter roomCode: 房间码（格式：U/XXXX-XXXX-XXXX-XXXX）
    /// - Returns: (网络名称, 网络密钥)，如果格式无效则返回 nil
    static func extractNetworkInfo(from roomCode: String) -> (networkName: String, networkSecret: String)? {
        guard let normalizedCode = parse(roomCode) else {
            return nil
        }

        let parts = normalizedCode.replacingOccurrences(of: "U/", with: "").split(separator: "-")
        guard parts.count == 4 else {
            return nil
        }

        let n1 = String(parts[0])  // XXXX
        let n2 = String(parts[1])  // XXXX
        let s1 = String(parts[2])  // XXXX
        let s2 = String(parts[3])  // XXXX

        let networkName = "scaffolding-mc-\(n1)-\(n2)"
        let networkSecret = "\(s1)-\(s2)"

        return (networkName, networkSecret)
    }
}
