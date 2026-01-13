import Foundation

/// Request for /v1/messages endpoint
struct MessagesRequest: Codable, Sendable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let system: String?
    let tools: [Tool]?
    let toolChoice: ToolChoice?
    let stream: Bool?
    let temperature: Double?
    let topK: Int?
    let topP: Double?
    let stopSequences: [String]?
    let metadata: RequestMetadata?
    let thinking: ThinkingConfig?
    let outputFormat: OutputFormat?

    init(
        model: String,
        messages: [Message],
        maxTokens: Int = 4096,
        system: String? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        stream: Bool? = nil,
        temperature: Double? = nil,
        topK: Int? = nil,
        topP: Double? = nil,
        stopSequences: [String]? = nil,
        metadata: RequestMetadata? = nil,
        thinking: ThinkingConfig? = nil,
        outputFormat: OutputFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.system = system
        self.tools = tools
        self.toolChoice = toolChoice
        self.stream = stream
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.stopSequences = stopSequences
        self.metadata = metadata
        self.thinking = thinking
        self.outputFormat = outputFormat
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, system, tools, stream, temperature, metadata, thinking
        case maxTokens = "max_tokens"
        case toolChoice = "tool_choice"
        case topK = "top_k"
        case topP = "top_p"
        case stopSequences = "stop_sequences"
        case outputFormat = "output_format"
    }
}

/// Output format for structured outputs
struct OutputFormat: Codable, Sendable {
    let type: String
    let schema: JSONSchema

    init(schema: JSONSchema) {
        self.type = "json_schema"
        self.schema = schema
    }
}

/// JSON Schema for structured outputs
struct JSONSchema: Codable, Sendable {
    let type: String
    let properties: [String: JSONSchemaProperty]?
    let required: [String]?
    let additionalProperties: Bool?
    let items: JSONSchemaProperty?
    let description: String?

    init(
        type: String,
        properties: [String: JSONSchemaProperty]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = false,
        items: JSONSchemaProperty? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
        self.items = items
        self.description = description
    }
}

/// JSON Schema property definition
struct JSONSchemaProperty: Codable, Sendable {
    let type: String?
    let description: String?
    let items: JSONSchemaPropertyBox?
    let properties: [String: JSONSchemaProperty]?
    let required: [String]?
    let additionalProperties: Bool?
    let `enum`: [String]?

    init(
        type: String? = nil,
        description: String? = nil,
        items: JSONSchemaProperty? = nil,
        properties: [String: JSONSchemaProperty]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.items = items.map { JSONSchemaPropertyBox($0) }
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
        self.enum = enumValues
    }

    enum CodingKeys: String, CodingKey {
        case type, description, items, properties, required, additionalProperties
        case `enum` = "enum"
    }
}

/// Box wrapper to handle recursive JSONSchemaProperty
final class JSONSchemaPropertyBox: Codable, @unchecked Sendable {
    let value: JSONSchemaProperty

    init(_ value: JSONSchemaProperty) {
        self.value = value
    }

    required init(from decoder: Decoder) throws {
        self.value = try JSONSchemaProperty(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

/// Request metadata
struct RequestMetadata: Codable, Sendable {
    let userId: String?

    init(userId: String? = nil) {
        self.userId = userId
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

/// Extended thinking configuration
enum ThinkingConfig: Codable, Sendable {
    case enabled(budgetTokens: Int)
    case disabled

    enum CodingKeys: String, CodingKey {
        case type
        case budgetTokens = "budget_tokens"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "enabled":
            let budgetTokens = try container.decode(Int.self, forKey: .budgetTokens)
            self = .enabled(budgetTokens: budgetTokens)
        case "disabled":
            self = .disabled
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown thinking config type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .enabled(let budgetTokens):
            try container.encode("enabled", forKey: .type)
            try container.encode(budgetTokens, forKey: .budgetTokens)
        case .disabled:
            try container.encode("disabled", forKey: .type)
        }
    }
}
