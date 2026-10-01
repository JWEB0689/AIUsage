import Foundation
import XCTest
@testable import QuotaBackend

final class ScienceEffortHTTPTests: XCTestCase {
    /// 走实际发送链路，同时覆盖首次请求、兼容重试、流式及非默认模型路由。
    func testScienceEffortSurvivesHTTPAndTokenLimitRetry() async throws {
        for api in OpenAIUpstreamAPI.allCases {
            for streaming in [false, true] {
                let upstream = MockHTTPServer(port: try findFreePort()) { request in
                    let body = try JSONSerialization.jsonObject(with: request.body) as! [String: Any]
                    let limit = api == .responses ? "max_output_tokens" : "max_tokens"
                    if body[limit] != nil {
                        return MockHTTPResponse(status: 400, body: "{\"error\":{\"message\":\"\(limit) unsupported\"}}")
                    }
                    if streaming {
                        return MockHTTPResponse(headers: ["Content-Type": "text/event-stream"], body: "data: [DONE]\n\n")
                    }
                    if api == .responses {
                        return MockHTTPResponse(headers: ["Content-Type": "application/json"], body: #"{"id":"resp_test","object":"response","created_at":0,"model":"other","status":"completed","output":[],"usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}"#)
                    }
                    return MockHTTPResponse(headers: ["Content-Type": "application/json"], body: #"{"id":"chat_test","object":"chat.completion","created":0,"model":"other","choices":[{"index":0,"message":{"role":"assistant","content":"OK"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}"#)
                }
                try await upstream.start()
                defer { upstream.stop() }
                let config = ClaudeProxyConfiguration(enabled: true, upstreamBaseURL: upstream.baseURL().absoluteString,
                    openAIUpstreamAPI: api, upstreamAPIKey: "synthetic-test", maxOutputTokens: 32,
                    availableModels: ["default", "other"], defaultModel: "default", exposeScienceModelCatalog: true)
                let adapter = ScienceModelProtocolAdapter(upstreamModels: ["default", "other"], requestedDefault: "default")
                let service = try ClaudeProxyService(configuration: config)
                for effort in ["low", "medium", "high", "xhigh", "max"] {
                    let request = ClaudeMessageRequest(model: adapter.models[1].id,
                        messages: [ClaudeMessage(role: "user", content: .text("hello"))], maxTokens: 100,
                        stream: streaming, outputConfig: ClaudeOutputConfig(effort: effort))
                    if streaming { try await service.sendStreamingClaudeRequest(request) { _ in } }
                    else { _ = try await service.handleMessages(request: request) }
                }
                let captured = await upstream.recordedRequests()
                XCTAssertEqual(captured.count, 10)
                for (index, request) in captured.enumerated() {
                    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
                    let effort = api == .responses ? (body["reasoning"] as? [String: Any])?["effort"] : body["reasoning_effort"]
                    XCTAssertEqual(effort as? String, ["low", "medium", "high", "xhigh", "max"][index / 2])
                    XCTAssertEqual(body["model"] as? String, "other")
                    XCTAssertEqual(body["stream"] as? Bool, streaming)
                    XCTAssertEqual(body[api == .responses ? "max_output_tokens" : "max_tokens"] as? Int, index % 2 == 0 ? 32 : nil)
                }
            }
        }
    }
}
