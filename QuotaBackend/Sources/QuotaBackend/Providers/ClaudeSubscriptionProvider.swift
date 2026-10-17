import Foundation

public struct ClaudeSubscriptionProvider: CredentialAcceptingProvider {
    public let id = "claude-subscription"
    public let displayName = "Claude Subscription"
    public let description = "Official Claude Code subscription quota snapshots"
    public let supportedAuthMethods: [AuthMethod] = [.auto]
    private let store: ClaudeSubscriptionStore

    public init(store: ClaudeSubscriptionStore = .init()) { self.store = store }

    public func fetchUsage() async throws -> ProviderUsage {
        throw ProviderError("not_logged_in", "Connect an official Claude Code configuration directory.")
    }

    public func fetchUsage(with credential: AccountCredential) async throws -> ProviderUsage {
        guard credential.authMethod == .auto, credential.metadata["sourceKind"] == "claude-cli-profile" else {
            throw ProviderError("invalid_profile", "Claude subscription monitoring requires a configuration reference, not a token.")
        }
        let expected = ClaudeSubscriptionProfile(configDirectory: credential.credential, name: "")
        let profile = try store.loadProfile(id: expected.id)
        var usage = ProviderUsage(provider: id, label: displayName, accountId: profile.id)
        usage.accountName = profile.email ?? profile.name
        usage.accountEmail = profile.email
        usage.accountPlan = ClaudeAuthStatus.planLabel(profile.subscriptionType)
        usage.source = SourceInfo(mode: "local", type: "claude-code-statusline")
        usage.extra["profileDirectory"] = AnyCodable(profile.configDirectory)
        usage.extra["identityState"] = AnyCodable(profile.email == nil ? "unverified" : "cli-reported")
        if let organization = profile.organizationName { usage.extra["organizationName"] = AnyCodable(organization) }
        let settingsURL = URL(fileURLWithPath: profile.configDirectory).appendingPathComponent("settings.json")
        let settings = (try? JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL))) as? [String: Any]
        let statusLine = settings?["statusLine"] as? [String: Any]
        guard profile.installedCommand != nil, statusLine?["command"] as? String == profile.installedCommand else {
            usage.fetchedAt = ""
            usage.extra["snapshotState"] = AnyCodable("disconnected")
            return usage
        }
        guard let sample = try store.latestSnapshot(for: profile) else {
            usage.fetchedAt = ""
            // 代理会话永远不会带订阅额度，直接说明原因，而不是让用户一直等。
            let routed = ClaudeSubscriptionConnection.routesThroughAPI(directory: profile.configDirectory)
            usage.extra["snapshotState"] = AnyCodable(routed ? "api-routed" : "waiting")
            return usage
        }
        usage.fetchedAt = SharedFormatters.iso8601String(from: sample.observedAt)
        usage.extra["receivedAt"] = AnyCodable(SharedFormatters.iso8601String(from: sample.receivedAt))
        func window(_ value: ClaudeSubscriptionSnapshot.Window?) -> RawQuotaWindow? {
            guard let value, value.usedPercent.isFinite, (0...100).contains(value.usedPercent) else { return nil }
            var result = RawQuotaWindow()
            // 已过重置时间的窗口额度已回满，但新窗口要等下一条 Code 消息才开始计时；
            // 显示满额而不是隐藏，避免用户以为 5h 窗口丢了。
            guard value.resetAt > Date() else {
                result.usedPercent = 0
                result.remainingPercent = 100
                result.resetDescription = "Starts with next message"
                return result
            }
            result.usedPercent = value.usedPercent
            result.remainingPercent = 100 - value.usedPercent
            result.resetAt = SharedFormatters.iso8601String(from: value.resetAt)
            return result
        }
        usage.primary = window(sample.fiveHour)
        usage.secondary = window(sample.sevenDay)
        let live = [sample.fiveHour, sample.sevenDay].contains { ($0?.resetAt ?? .distantPast) > Date() }
        let state = !live ? "reset" : Date().timeIntervalSince(sample.observedAt) > 300 ? "stale" : "snapshot"
        usage.extra["snapshotState"] = AnyCodable(state)
        return usage
    }
}
