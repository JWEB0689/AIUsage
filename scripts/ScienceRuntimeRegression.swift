import Foundation

// 编译生产文件，只替换应用设置依赖，不复制认证实现。
final class AppSettings {
    static let shared = AppSettings()
    func t(_ en: String, _ zh: String) -> String { en }
}
enum ScienceSandboxPaths {
    static let scienceBinary = "/Applications/Claude Science.app/Contents/Resources/bin/claude-science"
}

@main
struct ScienceRuntimeRegression {
    static func main() async throws {
        let args = CommandLine.arguments
        if args.count == 3, args[1] == "prepare" {
            let dir = args[2] + "/.claude-science"
            _ = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: args[2])
            _ = try ScienceVirtualLogin.localFetchPreload(authDir: dir, sandboxRoot: args[2])
            print("ISOLATED_LOGIN_READY")
            return
        }
        if args.count == 4, args[1] == "serve-proxy" {
            let daemonPort = Int(args[3])!
            try await ScienceAuthProxy.shared.start(listenPort: daemonPort + 1, upstreamPort: daemonPort, previewPort: daemonPort + 2, nativePreviewPort: daemonPort + 4, dataDir: args[2])
            print("AUTH_PROXY_READY")
            fflush(stdout)
            while !Task.isCancelled { try await Task.sleep(nanoseconds: 1_000_000_000) }
            return
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("science-login-regression-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let dir = root.appendingPathComponent(".claude-science").path
        let result = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: root.path)
        assert(!ScienceVirtualLogin.hasAuthorizedLogin(authDir: dir))
        let keyText = try String(contentsOfFile: dir + "/encryption.key", encoding: .utf8)
        let key = String(keyText.split(separator: "\n").first { $0.hasPrefix("OAUTH_ENCRYPTION_KEY=") }!.dropFirst("OAUTH_ENCRYPTION_KEY=".count))
        let data = try ScienceVirtualLogin.decryptTokenV2(String(contentsOfFile: result.encFile, encoding: .utf8), oauthKeyB64: key)
        var blob = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard blob["provider"] as? String == ScienceVirtualLogin.localProvider,
              blob["access_token"] as? String == ScienceVirtualLogin.localBearer else { fatalError("Local identity must not imply cloud authorization") }
        let intact = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: root.path)
        guard intact.action == .reused else { fatalError("Local identity should be reusable") }
        // 旧版本本地身份迁移保留账户、组织与会话路径。
        blob["provider"] = "claude_ai"
        blob["access_token"] = "sk-ant-virtual-legacy-test"
        try ScienceVirtualLogin.encryptTokenV2(JSONSerialization.data(withJSONObject: blob), oauthKeyB64: key)
            .write(toFile: result.encFile, atomically: true, encoding: .utf8)
        let migrated = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: root.path)
        guard migrated.action == .repaired, migrated.accountUUID == result.accountUUID,
              migrated.orgUUID == result.orgUUID else { fatalError("Migration changed the local account or organization") }
        blob["provider"] = "claude_ai"
        blob["access_token"] = "synthetic-real-test-token"
        blob["email"] = "authorized@example.com"
        blob["token_expires_at"] = "2020-01-01T00:00:00.000Z"
        blob["refresh_token"] = "synthetic-test-refresh-token"
        let encrypted = try ScienceVirtualLogin.encryptTokenV2(JSONSerialization.data(withJSONObject: blob), oauthKeyB64: key)
        try encrypted.write(toFile: result.encFile, atomically: true, encoding: .utf8)
        let before = try Data(contentsOf: URL(fileURLWithPath: result.encFile))
        _ = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: root.path)
        guard ScienceVirtualLogin.hasAuthorizedLogin(authDir: dir), before == (try Data(contentsOf: URL(fileURLWithPath: result.encFile))) else {
            throw NSError(domain: "ScienceRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: "Authorized credentials were overwritten"])
        }
        // 丢失组织指针时仅恢复指针，不重写真实 token。
        try FileManager.default.removeItem(atPath: dir + "/active-org.json")
        _ = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: root.path)
        guard before == (try Data(contentsOf: URL(fileURLWithPath: result.encFile))) else { fatalError("Missing organization overwrote token") }
        let differentOrg = try JSONSerialization.data(withJSONObject: ["org_uuid": UUID().uuidString.lowercased()])
        try differentOrg.write(to: URL(fileURLWithPath: dir + "/active-org.json"))
        do {
            _ = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: root.path)
            fatalError("Inconsistent organization must fail closed")
        } catch ScienceLoginError.preservedAuthorization {}
        guard before == (try Data(contentsOf: URL(fileURLWithPath: result.encFile))) else { fatalError("Different organization overwrote token") }
        // 真实账号旁残留虚拟账号时拒绝猜测，避免 daemon 选中错误凭证。
        let activeOrg = try JSONSerialization.data(withJSONObject: ["org_uuid": result.orgUUID])
        try activeOrg.write(to: URL(fileURLWithPath: dir + "/active-org.json"))
        var virtualBlob = blob
        virtualBlob["email"] = "test@local.invalid"
        virtualBlob["access_token"] = "sk-ant-virtual-legacy-test"
        let extraToken = dir + "/.oauth-tokens/" + UUID().uuidString + ".enc"
        try ScienceVirtualLogin.encryptTokenV2(JSONSerialization.data(withJSONObject: virtualBlob), oauthKeyB64: key)
            .write(toFile: extraToken, atomically: true, encoding: .utf8)
        do {
            _ = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: root.path)
            fatalError("Multiple accounts must fail closed")
        } catch ScienceLoginError.preservedAuthorization {}
        guard before == (try Data(contentsOf: URL(fileURLWithPath: result.encFile))) else { fatalError("Multiple accounts overwrote token") }
        try FileManager.default.removeItem(atPath: extraToken)
        // 密钥损坏时也不能默认为虚拟账号并重造密钥。
        try "invalid-key".write(toFile: dir + "/encryption.key", atomically: true, encoding: .utf8)
        do {
            _ = try ScienceVirtualLogin.ensure(authDir: dir, email: "test@local.invalid", sandboxRoot: root.path)
            fatalError("Unreadable authorization must fail closed")
        } catch ScienceLoginError.preservedAuthorization {}
        guard before == (try Data(contentsOf: URL(fileURLWithPath: result.encFile))) else { fatalError("Corrupt key overwrote token") }
        print("Authorized credential preservation passed: expired token, missing/different organization, multiple accounts, corrupt key.")
    }
}
