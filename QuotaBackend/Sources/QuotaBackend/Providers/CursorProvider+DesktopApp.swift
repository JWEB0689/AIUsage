import Foundation
import SQLite3

// MARK: - Cursor Desktop App Session
// Cursor 应用把登录态存在 globalStorage/state.vscdb 的 ItemTable（cursorAuth/*）。
// 其中 accessToken 与 cursor.com 网页会话是同一种令牌：网页 Cookie
// WorkosCursorSessionToken = "<userId>::<accessToken>"（userId 取 JWT sub 中 "|" 之后的部分）。
// 直接读这个库即可连接应用当前登录的账号——不读浏览器 Cookie，也不会弹出钥匙串授权。

extension CursorProvider {
    public struct DesktopAppSession: Sendable {
        public let email: String?
        public let plan: String?
        public let cookieHeader: String
    }

    static func desktopStatePath(home: String) -> String {
        "\(home)/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    }

    public static func discoverDesktopAppSession(
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> DesktopAppSession? {
        let path = desktopStatePath(home: homeDirectory)
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let values = readItemTableValues(
            dbPath: path,
            keys: ["cursorAuth/accessToken", "cursorAuth/cachedEmail", "cursorAuth/stripeMembershipType"]
        )
        guard let token = trimmedValue(values["cursorAuth/accessToken"]),
              let cookieHeader = sessionCookieHeader(fromAccessToken: token) else {
            return nil
        }
        return DesktopAppSession(
            email: trimmedValue(values["cursorAuth/cachedEmail"]),
            plan: formatMembership(values["cursorAuth/stripeMembershipType"]),
            cookieHeader: cookieHeader
        )
    }

    static func sessionCookieHeader(fromAccessToken token: String) -> String? {
        guard let subject = jwtSubject(token) else { return nil }
        let userId = subject.split(separator: "|").last.map(String.init) ?? subject
        guard !userId.isEmpty else { return nil }
        return "WorkosCursorSessionToken=\(userId)%3A%3A\(token)"
    }

    private static func jwtSubject(_ token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return trimmedValue(json["sub"] as? String)
    }

    private static func trimmedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// 只读打开并按主键取值；库可能有数 GB 且被 Cursor 占用（WAL），所以不复制文件。
    private static func readItemTableValues(dbPath: String, keys: [String]) -> [String: String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return [:]
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)

        let placeholders = keys.map { _ in "?" }.joined(separator: ",")
        var statement: OpaquePointer?
        let sql = "SELECT key, value FROM ItemTable WHERE key IN (\(placeholders))"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(statement) }

        for (index, key) in keys.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }

        var values: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let keyPointer = sqlite3_column_text(statement, 0) else { continue }
            // value 列在不同版本里可能是 TEXT 或 BLOB，统一按字节读取。
            guard let bytes = sqlite3_column_blob(statement, 1) else { continue }
            let length = Int(sqlite3_column_bytes(statement, 1))
            guard length > 0 else { continue }
            values[String(cString: keyPointer)] = String(decoding: Data(bytes: bytes, count: length), as: UTF8.self)
        }
        return values
    }
}
