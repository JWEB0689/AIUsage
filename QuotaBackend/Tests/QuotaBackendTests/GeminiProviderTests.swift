import XCTest
@testable import QuotaBackend

final class GeminiProviderTests: XCTestCase {
    /// Google 停止个人账号使用 Gemini CLI 后的 403 响应：要识别出来，而不是当成令牌过期让用户反复重新登录。
    func testRecognizesIndividualTierShutdownResponse() {
        let body = Data("""
        {
          "error": {
            "code": 403,
            "message": "This client is no longer supported for Gemini Code Assist for individuals. To continue using Gemini, please migrate to the Antigravity suite of products: https://antigravity.google",
            "status": "PERMISSION_DENIED",
            "details": [{ "@type": "type.googleapis.com/google.rpc.ErrorInfo", "reason": "UNSUPPORTED_CLIENT" }]
          }
        }
        """.utf8)
        XCTAssertTrue(GeminiProvider.isIndividualTierDiscontinued(responseBody: body))
    }

    func testOtherPermissionErrorsAreNotTreatedAsShutdown() {
        let body = Data("""
        { "error": { "code": 403, "message": "Verify your account to continue.", "status": "PERMISSION_DENIED",
          "details": [{ "reason": "VALIDATION_REQUIRED" }] } }
        """.utf8)
        XCTAssertFalse(GeminiProvider.isIndividualTierDiscontinued(responseBody: body))
        XCTAssertFalse(GeminiProvider.isIndividualTierDiscontinued(responseBody: Data()))
    }
}
