import SQLite3
import XCTest
@testable import QuotaBackend

/// 连接弹窗「先识别本机登录」依赖的本地发现逻辑：Cursor 桌面应用会话与 Kimi Code CLI 配置。
final class LocalLoginDiscoveryTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("aiusage-local-login-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    // MARK: - Cursor

    func testCursorSessionCookieUsesUserIdAfterProviderPrefix() {
        let token = Self.jwt(claims: ["sub": "auth0|user_01ABC", "exp": 4_102_444_800])
        XCTAssertEqual(
            CursorProvider.sessionCookieHeader(fromAccessToken: token),
            "WorkosCursorSessionToken=user_01ABC%3A%3A\(token)"
        )
    }

    func testCursorSessionCookieKeepsSubjectWithoutPrefix() {
        let token = Self.jwt(claims: ["sub": "user_02XYZ"])
        XCTAssertEqual(
            CursorProvider.sessionCookieHeader(fromAccessToken: token),
            "WorkosCursorSessionToken=user_02XYZ%3A%3A\(token)"
        )
    }

    func testCursorSessionCookieRejectsTokensWithoutSubject() {
        XCTAssertNil(CursorProvider.sessionCookieHeader(fromAccessToken: "not-a-jwt"))
        XCTAssertNil(CursorProvider.sessionCookieHeader(fromAccessToken: Self.jwt(claims: ["email": "a@b.c"])))
    }

    func testCursorDesktopSessionReadsSignedInAccount() throws {
        let token = Self.jwt(claims: ["sub": "google-oauth2|user_03DEF"])
        try writeCursorState([
            "cursorAuth/accessToken": token,
            "cursorAuth/cachedEmail": "dev@example.com",
            "cursorAuth/stripeMembershipType": "pro_plus",
            "unrelated/key": "ignored"
        ])

        let session = try XCTUnwrap(CursorProvider.discoverDesktopAppSession(homeDirectory: home.path))
        XCTAssertEqual(session.email, "dev@example.com")
        XCTAssertEqual(session.plan, "Pro Plus")
        XCTAssertEqual(session.cookieHeader, "WorkosCursorSessionToken=user_03DEF%3A%3A\(token)")
    }

    func testCursorDesktopSessionIsNilWhenSignedOut() throws {
        try writeCursorState(["cursorAuth/cachedEmail": "dev@example.com"])
        XCTAssertNil(CursorProvider.discoverDesktopAppSession(homeDirectory: home.path))
        XCTAssertNil(CursorProvider.discoverDesktopAppSession(homeDirectory: home.appendingPathComponent("missing").path))
    }

    // MARK: - Kimi

    func testKimiDiscoversKeysFromBothCLIConfigLocations() throws {
        try writeFile(".kimi-code/config.toml", """
        [providers."managed:kimi-code"]
        type = "kimi"
        api_key = "sk-kimi-new"
        base_url = "https://api.kimi.com/coding/v1"
        """)
        try writeFile(".kimi/config.toml", """
        [providers.kimi]
        type = "kimi"
        api_key = "sk-kimi-old"
        """)

        let credentials = KimiProvider.discoverLocalCredentials(homeDirectory: home.path)
        XCTAssertEqual(credentials.map(\.apiKey), ["sk-kimi-new", "sk-kimi-old"])
        XCTAssertEqual(credentials.first?.sourcePath, home.appendingPathComponent(".kimi-code/config.toml").path)
    }

    func testKimiIgnoresOAuthLoginWithEmptyKey() throws {
        try writeFile(".kimi-code/config.toml", """
        [providers."managed:kimi-code"]
        type = "kimi"
        api_key = ""
        base_url = "https://api.kimi.com/coding/v1"

        [providers."managed:kimi-code".oauth]
        storage = "file"
        key = "oauth/kimi-code"
        """)

        XCTAssertTrue(KimiProvider.discoverLocalCredentials(homeDirectory: home.path).isEmpty)
    }

    // MARK: - Helpers

    private func writeFile(_ relativePath: String, _ contents: String) throws {
        let url = home.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeCursorState(_ values: [String: String]) throws {
        let path = CursorProvider.desktopStatePath(home: home.path)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB)", nil, nil, nil), SQLITE_OK)
        for (key, value) in values {
            var statement: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(db, "INSERT INTO ItemTable (key, value) VALUES (?, ?)", -1, &statement, nil), SQLITE_OK)
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, key, -1, transient)
            sqlite3_bind_text(statement, 2, value, -1, transient)
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
            sqlite3_finalize(statement)
        }
    }

    private static func jwt(claims: [String: Any]) -> String {
        func segment(_ object: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(segment(["alg": "HS256", "typ": "JWT"])).\(segment(claims)).signature"
    }
}
