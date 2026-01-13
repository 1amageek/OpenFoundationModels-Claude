import Foundation
import OpenFoundationModels

// MARK: - Claude Options
internal struct ClaudeOptions: Sendable {
    let temperature: Double?
    let topK: Int?
    let topP: Double?
}

// MARK: - GenerationOptions Extension
internal extension GenerationOptions {
    func toClaudeOptions() -> ClaudeOptions {
        // Note: SamplingMode internals cannot be easily extracted
        // Users should use temperature directly
        return ClaudeOptions(
            temperature: temperature,
            topK: nil,
            topP: nil
        )
    }
}

/// Claude Language Model Provider for OpenFoundationModels
public final class ClaudeLanguageModel: LanguageModel, Sendable {

    // MARK: - Properties
    internal let httpClient: ClaudeHTTPClient
    internal let modelName: String
    internal let configuration: ClaudeConfiguration

    /// Default max tokens for responses
    public let defaultMaxTokens: Int

    // MARK: - LanguageModel Protocol Compliance
    public var isAvailable: Bool { true }

    // MARK: - Initialization

    /// Initialize with configuration and model name
    /// - Parameters:
    ///   - configuration: Claude configuration
    ///   - modelName: Name of the model (e.g., "claude-sonnet-4-20250514", "claude-3-5-haiku-20241022")
    ///   - defaultMaxTokens: Default max tokens for responses (default: 4096)
    public init(
        configuration: ClaudeConfiguration,
        modelName: String,
        defaultMaxTokens: Int = 4096
    ) {
        self.configuration = configuration
        self.modelName = modelName
        self.defaultMaxTokens = defaultMaxTokens
        self.httpClient = ClaudeHTTPClient(configuration: configuration)
    }

    // MARK: - LanguageModel Protocol Implementation

    public func generate(transcript: Transcript, options: GenerationOptions?) async throws -> Transcript.Entry {
        // Convert Transcript to Claude format
        let (messages, systemPrompt) = TranscriptConverter.buildMessages(from: transcript)
        let tools = try TranscriptConverter.extractTools(from: transcript)

        // Use the options from the transcript if not provided
        let finalOptions = options ?? TranscriptConverter.extractOptions(from: transcript)
        let claudeOptions = finalOptions?.toClaudeOptions() ?? ClaudeOptions(temperature: nil, topK: nil, topP: nil)

        // Determine max tokens
        let maxTokens = finalOptions?.maximumResponseTokens ?? defaultMaxTokens

        // Check for response format (structured output)
        let responseFormat = TranscriptConverter.extractResponseFormat(from: transcript)

        // Convert GenerationSchema to Claude OutputFormat if present
        let outputFormat = responseFormat.flatMap { convertToOutputFormat($0) }
        let betaHeaders: [String]? = outputFormat != nil ? ["structured-outputs-2025-11-13"] : nil

        // Build request
        let request = MessagesRequest(
            model: modelName,
            messages: messages,
            maxTokens: maxTokens,
            system: systemPrompt,
            tools: tools,
            toolChoice: tools != nil ? .auto() : nil,
            stream: false,
            temperature: claudeOptions.temperature,
            topK: claudeOptions.topK,
            topP: claudeOptions.topP,
            outputFormat: outputFormat
        )

        let response: MessagesResponse = try await httpClient.send(request, to: "/v1/messages", betaHeaders: betaHeaders)

        // Check for tool calls
        let toolUseBlocks = response.content.compactMap { block -> ToolUseBlock? in
            if case .toolUse(let toolUse) = block {
                return toolUse
            }
            return nil
        }

        if !toolUseBlocks.isEmpty {
            return createToolCallsEntry(from: toolUseBlocks)
        }

        // Convert response to Transcript.Entry
        return createResponseEntry(from: response)
    }

    public func stream(transcript: Transcript, options: GenerationOptions?) -> AsyncThrowingStream<Transcript.Entry, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Convert Transcript to Claude format
                    let (messages, systemPrompt) = TranscriptConverter.buildMessages(from: transcript)
                    let tools = try TranscriptConverter.extractTools(from: transcript)

                    // Use the options from the transcript if not provided
                    let finalOptions = options ?? TranscriptConverter.extractOptions(from: transcript)
                    let claudeOptions = finalOptions?.toClaudeOptions() ?? ClaudeOptions(temperature: nil, topK: nil, topP: nil)

                    // Determine max tokens
                    let maxTokens = finalOptions?.maximumResponseTokens ?? defaultMaxTokens

                    // Check for response format
                    let responseFormat = TranscriptConverter.extractResponseFormat(from: transcript)

                    // Convert GenerationSchema to Claude OutputFormat if present
                    let outputFormat = responseFormat.flatMap { self.convertToOutputFormat($0) }
                    let betaHeaders: [String]? = outputFormat != nil ? ["structured-outputs-2025-11-13"] : nil

                    // Build request
                    let request = MessagesRequest(
                        model: modelName,
                        messages: messages,
                        maxTokens: maxTokens,
                        system: systemPrompt,
                        tools: tools,
                        toolChoice: tools != nil ? .auto() : nil,
                        stream: true,
                        temperature: claudeOptions.temperature,
                        topK: claudeOptions.topK,
                        topP: claudeOptions.topP,
                        outputFormat: outputFormat
                    )

                    let streamResponse = await httpClient.stream(request, to: "/v1/messages", betaHeaders: betaHeaders)

                    var accumulatedText = ""
                    var accumulatedToolCalls: [(id: String, name: String, input: String)] = []
                    var currentToolCallIndex: Int? = nil
                    var hasYieldedContent = false

                    for try await event in streamResponse {
                        switch event {
                        case .messageStart:
                            break

                        case .contentBlockStart(let startEvent):
                            switch startEvent.contentBlock {
                            case .text:
                                break
                            case .toolUse(let toolUseStart):
                                currentToolCallIndex = accumulatedToolCalls.count
                                accumulatedToolCalls.append((
                                    id: toolUseStart.id,
                                    name: toolUseStart.name,
                                    input: ""
                                ))
                            case .thinking:
                                break
                            }

                        case .contentBlockDelta(let deltaEvent):
                            switch deltaEvent.delta {
                            case .textDelta(let textDelta):
                                accumulatedText += textDelta.text
                                // Yield accumulated content for structured output support
                                let entry = createResponseEntry(content: accumulatedText)
                                continuation.yield(entry)
                                hasYieldedContent = true

                            case .inputJSONDelta(let jsonDelta):
                                if let index = currentToolCallIndex {
                                    accumulatedToolCalls[index].input += jsonDelta.partialJson
                                }

                            case .thinkingDelta:
                                break

                            case .signatureDelta:
                                break
                            }

                        case .contentBlockStop:
                            currentToolCallIndex = nil

                        case .messageDelta:
                            break

                        case .messageStop:
                            // If we accumulated tool calls, yield them
                            if !accumulatedToolCalls.isEmpty {
                                let entry = createToolCallsEntry(from: accumulatedToolCalls)
                                continuation.yield(entry)
                            }

                            // Handle empty response case
                            if !hasYieldedContent && accumulatedToolCalls.isEmpty {
                                let entry = createResponseEntry(content: "")
                                continuation.yield(entry)
                            }

                            continuation.finish()
                            return

                        case .error(let errorEvent):
                            throw ClaudeHTTPError.statusError(
                                500,
                                errorEvent.error.message.data(using: .utf8)
                            )

                        case .ping:
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func supports(locale: Locale) -> Bool {
        // Claude models support multiple languages
        return true
    }

    // MARK: - Private Helper Methods

    /// Create response entry from MessagesResponse
    private func createResponseEntry(from response: MessagesResponse) -> Transcript.Entry {
        var textContent = ""

        for block in response.content {
            if case .text(let textBlock) = block {
                textContent += textBlock.text
            }
        }

        return createResponseEntry(content: textContent)
    }

    /// Create tool calls entry from ToolUseBlocks
    private func createToolCallsEntry(from toolUseBlocks: [ToolUseBlock]) -> Transcript.Entry {
        let transcriptToolCalls = toolUseBlocks.map { toolUse in
            let argumentsContent: GeneratedContent

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: toolUse.input.dictionary, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                argumentsContent = try GeneratedContent(json: jsonString)
            } catch {
                argumentsContent = try! GeneratedContent(json: "{}")
            }

            return Transcript.ToolCall(
                id: toolUse.id,
                toolName: toolUse.name,
                arguments: argumentsContent
            )
        }

        return .toolCalls(
            Transcript.ToolCalls(
                id: UUID().uuidString,
                transcriptToolCalls
            )
        )
    }

    /// Create tool calls entry from accumulated streaming data
    private func createToolCallsEntry(from toolCalls: [(id: String, name: String, input: String)]) -> Transcript.Entry {
        let transcriptToolCalls = toolCalls.map { toolCall in
            let argumentsContent: GeneratedContent

            do {
                argumentsContent = try GeneratedContent(json: toolCall.input)
            } catch {
                argumentsContent = try! GeneratedContent(json: "{}")
            }

            return Transcript.ToolCall(
                id: toolCall.id,
                toolName: toolCall.name,
                arguments: argumentsContent
            )
        }

        return .toolCalls(
            Transcript.ToolCalls(
                id: UUID().uuidString,
                transcriptToolCalls
            )
        )
    }

    /// Create response entry from content string
    private func createResponseEntry(content: String) -> Transcript.Entry {
        return .response(
            Transcript.Response(
                id: UUID().uuidString,
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(
                    id: UUID().uuidString,
                    content: content
                ))]
            )
        )
    }

    /// Convert GenerationSchema to Claude's native OutputFormat for structured outputs
    private func convertToOutputFormat(_ schema: GenerationSchema) -> OutputFormat? {
        // GenerationSchema is Encodable, so we can serialize it to JSON
        // and then convert to Claude's JSONSchema format
        guard let jsonData = try? JSONEncoder().encode(schema),
              let schemaDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        // Convert the serialized schema to Claude's JSONSchema format
        let jsonSchema = convertDictToJSONSchema(schemaDict)
        return OutputFormat(schema: jsonSchema)
    }

    /// Convert a dictionary representation of GenerationSchema to JSONSchema
    private func convertDictToJSONSchema(_ dict: [String: Any]) -> JSONSchema {
        var properties: [String: JSONSchemaProperty] = [:]
        var requiredFields: [String] = []

        // Extract properties from the schema dictionary
        // GenerationSchema encodes properties as a dictionary { "name": { schema } }
        if let propsDict = dict["properties"] as? [String: [String: Any]] {
            for (name, propDict) in propsDict {
                let prop = convertDictToJSONSchemaProperty(propDict)
                properties[name] = prop
            }
        }

        // Extract required fields
        if let required = dict["required"] as? [String] {
            requiredFields = required
        } else {
            // If no required array, assume all properties are required
            requiredFields = Array(properties.keys)
        }

        return JSONSchema(
            type: "object",
            properties: properties.isEmpty ? nil : properties,
            required: requiredFields.isEmpty ? nil : requiredFields,
            additionalProperties: false,
            description: dict["description"] as? String
        )
    }

    /// Convert a property dictionary to JSONSchemaProperty
    private func convertDictToJSONSchemaProperty(_ dict: [String: Any]) -> JSONSchemaProperty {
        let typeName = dict["type"] as? String ?? "object"
        let description = dict["description"] as? String

        // Handle arrays with items
        if typeName == "array" {
            if let itemsDict = dict["items"] as? [String: Any] {
                let itemProp = convertDictToJSONSchemaProperty(itemsDict)
                return JSONSchemaProperty(
                    type: "array",
                    description: description,
                    items: itemProp
                )
            } else {
                // Array without items schema
                return JSONSchemaProperty(
                    type: "array",
                    description: description,
                    items: JSONSchemaProperty(type: "string")
                )
            }
        }

        // Handle nested objects with properties
        if typeName == "object" {
            if let nestedPropsDict = dict["properties"] as? [String: [String: Any]] {
                var nested: [String: JSONSchemaProperty] = [:]
                for (name, propDict) in nestedPropsDict {
                    nested[name] = convertDictToJSONSchemaProperty(propDict)
                }
                let nestedRequired = dict["required"] as? [String] ?? Array(nested.keys)
                return JSONSchemaProperty(
                    type: "object",
                    description: description,
                    properties: nested.isEmpty ? nil : nested,
                    required: nestedRequired.isEmpty ? nil : nestedRequired,
                    additionalProperties: false
                )
            }
        }

        // Simple types: string, number, integer, boolean
        return JSONSchemaProperty(
            type: typeName,
            description: description
        )
    }

    /// Map Swift type names to JSON Schema types
    private func mapSwiftTypeToJSONType(_ swiftType: String) -> String {
        let lowercased = swiftType.lowercased()
        if lowercased.contains("string") {
            return "string"
        } else if lowercased.contains("int") {
            return "integer"
        } else if lowercased.contains("double") || lowercased.contains("float") {
            return "number"
        } else if lowercased.contains("bool") {
            return "boolean"
        } else if lowercased.contains("array") || swiftType.hasPrefix("[") {
            return "array"
        }
        return "object"
    }
}

// MARK: - Convenience Model Constants

extension ClaudeLanguageModel {
    // MARK: - Model Identifiers

    /// Claude Opus 4.5 - Premium model combining maximum intelligence with practical performance
    public static let opus4_5 = "claude-opus-4-5-20251101"

    /// Claude Sonnet 4.5 - Best model for real-world agents and coding
    public static let sonnet4_5 = "claude-sonnet-4-5-20250929"

    /// Claude Sonnet 4 - High-performance model with extended thinking
    public static let sonnet4 = "claude-sonnet-4-20250514"

    /// Claude Opus 4 - Most capable model
    public static let opus4 = "claude-opus-4-20250514"

    /// Claude Haiku 4.5 - Hybrid model, capable of near-instant responses and extended thinking
    public static let haiku4_5 = "claude-haiku-4-5-20251001"

    /// Claude 3.7 Sonnet - High-performance model with early extended thinking
    public static let sonnet3_7 = "claude-3-7-sonnet-20250219"

    /// Claude 3.5 Haiku - Fastest and most compact model for near-instant responsiveness
    public static let haiku3_5 = "claude-3-5-haiku-20241022"

    /// Claude 3.5 Sonnet model identifier (legacy)
    public static let sonnet3_5 = "claude-3-5-sonnet-20241022"

    // MARK: - Factory Methods

    /// Create Claude Opus 4.5 model
    public static func opus4_5(configuration: ClaudeConfiguration, defaultMaxTokens: Int = 4096) -> ClaudeLanguageModel {
        return ClaudeLanguageModel(configuration: configuration, modelName: opus4_5, defaultMaxTokens: defaultMaxTokens)
    }

    /// Create Claude Sonnet 4.5 model
    public static func sonnet4_5(configuration: ClaudeConfiguration, defaultMaxTokens: Int = 4096) -> ClaudeLanguageModel {
        return ClaudeLanguageModel(configuration: configuration, modelName: sonnet4_5, defaultMaxTokens: defaultMaxTokens)
    }

    /// Create Claude Sonnet 4 model
    public static func sonnet4(configuration: ClaudeConfiguration, defaultMaxTokens: Int = 4096) -> ClaudeLanguageModel {
        return ClaudeLanguageModel(configuration: configuration, modelName: sonnet4, defaultMaxTokens: defaultMaxTokens)
    }

    /// Create Claude Opus 4 model
    public static func opus4(configuration: ClaudeConfiguration, defaultMaxTokens: Int = 4096) -> ClaudeLanguageModel {
        return ClaudeLanguageModel(configuration: configuration, modelName: opus4, defaultMaxTokens: defaultMaxTokens)
    }

    /// Create Claude Haiku 4.5 model
    public static func haiku4_5(configuration: ClaudeConfiguration, defaultMaxTokens: Int = 4096) -> ClaudeLanguageModel {
        return ClaudeLanguageModel(configuration: configuration, modelName: haiku4_5, defaultMaxTokens: defaultMaxTokens)
    }

    /// Create Claude 3.7 Sonnet model
    public static func sonnet3_7(configuration: ClaudeConfiguration, defaultMaxTokens: Int = 4096) -> ClaudeLanguageModel {
        return ClaudeLanguageModel(configuration: configuration, modelName: sonnet3_7, defaultMaxTokens: defaultMaxTokens)
    }

    /// Create Claude 3.5 Haiku model
    public static func haiku3_5(configuration: ClaudeConfiguration, defaultMaxTokens: Int = 4096) -> ClaudeLanguageModel {
        return ClaudeLanguageModel(configuration: configuration, modelName: haiku3_5, defaultMaxTokens: defaultMaxTokens)
    }

    /// Create Claude 3.5 Sonnet model (legacy)
    public static func sonnet3_5(configuration: ClaudeConfiguration, defaultMaxTokens: Int = 4096) -> ClaudeLanguageModel {
        return ClaudeLanguageModel(configuration: configuration, modelName: sonnet3_5, defaultMaxTokens: defaultMaxTokens)
    }
}
