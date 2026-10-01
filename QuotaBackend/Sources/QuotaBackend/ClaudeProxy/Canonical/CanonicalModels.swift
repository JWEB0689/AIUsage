import Foundation

public typealias CanonicalJSONMap = [String: AnyCodable]

public struct CanonicalVendorExtension: Sendable {
    public let vendor: String
    public let key: String
    public let value: AnyCodable

    public init(vendor: String, key: String, value: AnyCodable) {
        self.vendor = vendor
        self.key = key
        self.value = value
    }
}

public enum CanonicalRole: Sendable {
    case system
    case user
    case assistant
    case tool
    case developer
    case unknown(String)

    public var value: String {
        switch self {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        case .tool: return "tool"
        case .developer: return "developer"
        case .unknown(let raw): return raw
        }
    }
}

public enum CanonicalPhase: Sendable {
    case commentary
    case finalAnswer
    case unknown(String)

    public var value: String {
        switch self {
        case .commentary: return "commentary"
        case .finalAnswer: return "final_answer"
        case .unknown(let raw): return raw
        }
    }
}

public enum CanonicalStopReason: Sendable {
    case endTurn
    case toolUse
    case maxTokens
    case pauseTurn
    case refusal
    case modelContextWindowExceeded
    case error
    case unknown(String)

    public var value: String {
        switch self {
        case .endTurn: return "end_turn"
        case .toolUse: return "tool_use"
        case .maxTokens: return "max_tokens"
        case .pauseTurn: return "pause_turn"
        case .refusal: return "refusal"
        case .modelContextWindowExceeded: return "model_context_window_exceeded"
        case .error: return "error"
        case .unknown(let raw): return raw
        }
    }
}

public struct CanonicalStop: Sendable {
    public let reason: CanonicalStopReason
    public let sequence: String?

    public init(reason: CanonicalStopReason, sequence: String? = nil) {
        self.reason = reason
        self.sequence = sequence
    }
}

public struct CanonicalGenerationConfig: Sendable {
    public let reasoningEffort: String?
    public let maxOutputTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let stopSequences: [String]
    public let stream: Bool?

    public init(
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String] = [],
        stream: Bool? = nil,
        reasoningEffort: String? = nil
    ) {
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
        self.stream = stream
        self.reasoningEffort = reasoningEffort
    }
}

public enum CanonicalToolDefinitionKind: Sendable {
    case function
    case hosted
    case custom
    case unknown(String)
}

public enum CanonicalToolExecution: Sendable {
    case client
    case server
    case hosted
    case unknown(String)
}

public struct CanonicalToolDefinitionFlags: Sendable {
    public let eagerInputStreaming: Bool?
    public let strict: Bool?

    public init(eagerInputStreaming: Bool? = nil, strict: Bool? = nil) {
        self.eagerInputStreaming = eagerInputStreaming
        self.strict = strict
    }
}

public struct CanonicalToolDefinition: Sendable {
    public let kind: CanonicalToolDefinitionKind
    public let name: String?
    public let description: String?
    public let inputSchema: CanonicalJSONMap?
    public let execution: CanonicalToolExecution
    public let vendorType: String?
    public let flags: CanonicalToolDefinitionFlags
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        kind: CanonicalToolDefinitionKind,
        name: String?,
        description: String?,
        inputSchema: CanonicalJSONMap?,
        execution: CanonicalToolExecution,
        vendorType: String? = nil,
        flags: CanonicalToolDefinitionFlags = CanonicalToolDefinitionFlags(),
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.kind = kind
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.execution = execution
        self.vendorType = vendorType
        self.flags = flags
        self.rawExtensions = rawExtensions
    }
}

public enum CanonicalToolChoice: Sendable {
    case none
    case auto
    case required
    case specific(String)
    case allowed([String])
    case hosted(String)
    case custom(String)
    case unknown(String)
}

public struct CanonicalToolConfig: Sendable {
    public let choice: CanonicalToolChoice?
    public let parallelCallsAllowed: Bool?

    public init(choice: CanonicalToolChoice? = nil, parallelCallsAllowed: Bool? = nil) {
        self.choice = choice
        self.parallelCallsAllowed = parallelCallsAllowed
    }
}

public struct CanonicalRequest: Sendable {
    public let modelHint: String
    public let system: [CanonicalContentPart]
    public let items: [CanonicalConversationItem]
    public let tools: [CanonicalToolDefinition]
    public let toolConfig: CanonicalToolConfig?
    public let generationConfig: CanonicalGenerationConfig
    public let metadata: CanonicalJSONMap
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        modelHint: String,
        system: [CanonicalContentPart],
        items: [CanonicalConversationItem],
        tools: [CanonicalToolDefinition],
        toolConfig: CanonicalToolConfig?,
        generationConfig: CanonicalGenerationConfig,
        metadata: CanonicalJSONMap = [:],
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.modelHint = modelHint
        self.system = system
        self.items = items
        self.tools = tools
        self.toolConfig = toolConfig
        self.generationConfig = generationConfig
        self.metadata = metadata
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalResponse: Sendable {
    public let id: String?
    public let model: String?
    public let items: [CanonicalConversationItem]
    public let stop: CanonicalStop
    public let usage: CanonicalUsage?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        id: String?,
        model: String?,
        items: [CanonicalConversationItem],
        stop: CanonicalStop,
        usage: CanonicalUsage?,
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.id = id
        self.model = model
        self.items = items
        self.stop = stop
        self.usage = usage
        self.rawExtensions = rawExtensions
    }
}

public enum CanonicalConversationItem: Sendable {
    case message(CanonicalMessage)
    case toolCall(CanonicalToolCall)
    case toolResult(CanonicalToolResult)
    case reasoning(CanonicalReasoningItem)
    case compaction(CanonicalCompactionItem)
    case hostedToolEvent(CanonicalHostedToolEvent)
}

public struct CanonicalMessage: Sendable {
    public let role: CanonicalRole
    public let phase: CanonicalPhase?
    public let parts: [CanonicalContentPart]
    public let name: String?
    public let metadata: CanonicalJSONMap
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        role: CanonicalRole,
        phase: CanonicalPhase? = nil,
        parts: [CanonicalContentPart],
        name: String? = nil,
        metadata: CanonicalJSONMap = [:],
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.role = role
        self.phase = phase
        self.parts = parts
        self.name = name
        self.metadata = metadata
        self.rawExtensions = rawExtensions
    }
}

public enum CanonicalContentPart: Sendable {
    case text(CanonicalTextPart)
    case image(CanonicalImagePart)
    case document(CanonicalDocumentPart)
    case fileRef(CanonicalFileReference)
    case reasoningText(CanonicalReasoningTextPart)
    case refusal(CanonicalRefusalPart)
    case unknown(CanonicalUnknownPart)
}

public struct CanonicalTextPart: Sendable {
    public let text: String
    public let rawExtensions: [CanonicalVendorExtension]

    public init(text: String, rawExtensions: [CanonicalVendorExtension] = []) {
        self.text = text
        self.rawExtensions = rawExtensions
    }
}

public enum CanonicalImageSource: Sendable {
    case base64
    case url
    case fileID
    case unknown(String)
}

public struct CanonicalImagePart: Sendable {
    public let source: CanonicalImageSource
    public let data: String
    public let mediaType: String?
    public let detail: String?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        source: CanonicalImageSource,
        data: String,
        mediaType: String? = nil,
        detail: String? = nil,
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.source = source
        self.data = data
        self.mediaType = mediaType
        self.detail = detail
        self.rawExtensions = rawExtensions
    }
}

public enum CanonicalDocumentSource: Sendable {
    case inlineText(String)
    case contentParts([CanonicalContentPart])
    case url(String)
    case base64(data: String, mediaType: String?)
    case fileID(String)
    case unknown(AnyCodable)
}

public struct CanonicalDocumentPart: Sendable {
    public let source: CanonicalDocumentSource
    public let title: String?
    public let context: String?
    public let citations: AnyCodable?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        source: CanonicalDocumentSource,
        title: String? = nil,
        context: String? = nil,
        citations: AnyCodable? = nil,
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.source = source
        self.title = title
        self.context = context
        self.citations = citations
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalFileReference: Sendable {
    public let fileID: String?
    public let filename: String?
    public let mimeType: String?
    public let downloadable: Bool?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        fileID: String?,
        filename: String? = nil,
        mimeType: String? = nil,
        downloadable: Bool? = nil,
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.fileID = fileID
        self.filename = filename
        self.mimeType = mimeType
        self.downloadable = downloadable
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalReasoningTextPart: Sendable {
    public let text: String
    public let rawExtensions: [CanonicalVendorExtension]

    public init(text: String, rawExtensions: [CanonicalVendorExtension] = []) {
        self.text = text
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalRefusalPart: Sendable {
    public let text: String
    public let rawExtensions: [CanonicalVendorExtension]

    public init(text: String, rawExtensions: [CanonicalVendorExtension] = []) {
        self.text = text
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalUnknownPart: Sendable {
    public let type: String
    public let payload: AnyCodable?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(type: String, payload: AnyCodable? = nil, rawExtensions: [CanonicalVendorExtension] = []) {
        self.type = type
        self.payload = payload
        self.rawExtensions = rawExtensions
    }
}

public enum CanonicalItemStatus: Sendable {
    case inProgress
    case completed
    case incomplete
    case failed
    case unknown(String)

    public var value: String {
        switch self {
        case .inProgress: return "in_progress"
        case .completed: return "completed"
        case .incomplete: return "incomplete"
        case .failed: return "failed"
        case .unknown(let raw): return raw
        }
    }
}

public struct CanonicalToolCall: Sendable {
    public let id: String
    public let name: String
    public let inputJSON: String
    public let status: CanonicalItemStatus
    public let partial: Bool
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        id: String,
        name: String,
        inputJSON: String,
        status: CanonicalItemStatus = .completed,
        partial: Bool = false,
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.id = id
        self.name = name
        self.inputJSON = inputJSON
        self.status = status
        self.partial = partial
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalToolResult: Sendable {
    public let toolCallID: String
    public let isError: Bool?
    public let parts: [CanonicalContentPart]
    public let rawTextFallback: String?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        toolCallID: String,
        isError: Bool? = nil,
        parts: [CanonicalContentPart] = [],
        rawTextFallback: String? = nil,
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.toolCallID = toolCallID
        self.isError = isError
        self.parts = parts
        self.rawTextFallback = rawTextFallback
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalReasoningItem: Sendable {
    public let summaryText: String?
    public let fullText: String?
    public let encryptedContent: String?
    public let signature: String?
    public let redacted: Bool?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        summaryText: String? = nil,
        fullText: String? = nil,
        encryptedContent: String? = nil,
        signature: String? = nil,
        redacted: Bool? = nil,
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.summaryText = summaryText
        self.fullText = fullText
        self.encryptedContent = encryptedContent
        self.signature = signature
        self.redacted = redacted
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalCompactionItem: Sendable {
    public let id: String?
    public let encryptedContent: String?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(id: String? = nil, encryptedContent: String? = nil, rawExtensions: [CanonicalVendorExtension] = []) {
        self.id = id
        self.encryptedContent = encryptedContent
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalHostedToolEvent: Sendable {
    public let vendorType: String
    public let callID: String?
    public let status: CanonicalItemStatus
    public let payload: AnyCodable?
    public let rawExtensions: [CanonicalVendorExtension]

    public init(
        vendorType: String,
        callID: String? = nil,
        status: CanonicalItemStatus = .unknown("unknown"),
        payload: AnyCodable? = nil,
        rawExtensions: [CanonicalVendorExtension] = []
    ) {
        self.vendorType = vendorType
        self.callID = callID
        self.status = status
        self.payload = payload
        self.rawExtensions = rawExtensions
    }
}

public struct CanonicalUsage: Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let reasoningTokens: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        reasoningTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.reasoningTokens = reasoningTokens
    }
}
