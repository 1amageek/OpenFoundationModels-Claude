import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("MessagesRequest Tests")
struct MessagesRequestTests {

    // MARK: - Basic Encoding Tests

    @Test("Minimal request encodes correctly")
    func minimalRequestEncodes() throws {
        let request = MessagesRequest(
            model: "claude-sonnet-4-20250514",
            messages: [Message(role: .user, content: "Hello")],
            maxTokens: 1024
        )

        let data = try JSONHelpers.encode(request)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["model"] as? String == "claude-sonnet-4-20250514")
        #expect(dict["max_tokens"] as? Int == 1024)
        #expect(dict["messages"] != nil)
    }

    @Test("Full request with all options encodes correctly")
    func fullRequestEncodes() throws {
        let request = MessagesRequest(
            model: "claude-sonnet-4-20250514",
            messages: [Message(role: .user, content: "Hello")],
            maxTokens: 2048,
            system: "You are a helpful assistant.",
            tools: nil,
            toolChoice: nil,
            stream: true,
            temperature: 0.7,
            topK: 40,
            topP: 0.9,
            stopSequences: ["END", "STOP"],
            metadata: RequestMetadata(userId: "user_123"),
            thinking: .enabled(budgetTokens: 2048)
        )

        let data = try JSONHelpers.encode(request)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["model"] as? String == "claude-sonnet-4-20250514")
        #expect(dict["max_tokens"] as? Int == 2048)
        #expect(dict["system"] as? String == "You are a helpful assistant.")
        #expect(dict["stream"] as? Bool == true)
        #expect(dict["temperature"] as? Double == 0.7)
        #expect(dict["top_k"] as? Int == 40)
        #expect(dict["top_p"] as? Double == 0.9)

        let stopSeqs = dict["stop_sequences"] as? [String]
        #expect(stopSeqs == ["END", "STOP"])
    }

    // MARK: - CodingKeys Tests

    @Test("Snake case keys are used in JSON output")
    func snakeCaseKeys() throws {
        let request = MessagesRequest(
            model: "test",
            messages: [],
            maxTokens: 100,
            topK: 10,
            topP: 0.5,
            stopSequences: ["x"]
        )

        let data = try JSONHelpers.encode(request)
        let dict = try JSONHelpers.toDictionary(data)

        // Verify snake_case keys
        #expect(dict["max_tokens"] != nil)
        #expect(dict["top_k"] != nil)
        #expect(dict["top_p"] != nil)
        #expect(dict["stop_sequences"] != nil)

        // Verify camelCase keys are NOT present
        #expect(dict["maxTokens"] == nil)
        #expect(dict["topK"] == nil)
        #expect(dict["topP"] == nil)
        #expect(dict["stopSequences"] == nil)
    }

    // MARK: - ThinkingConfig Tests

    @Test("ThinkingConfig enabled encodes with budget_tokens")
    func thinkingConfigEnabledEncodes() throws {
        let config = ThinkingConfig.enabled(budgetTokens: 4096)
        let data = try JSONHelpers.encode(config)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "enabled")
        #expect(dict["budget_tokens"] as? Int == 4096)
    }

    @Test("ThinkingConfig disabled encodes without budget_tokens")
    func thinkingConfigDisabledEncodes() throws {
        let config = ThinkingConfig.disabled
        let data = try JSONHelpers.encode(config)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "disabled")
        #expect(dict["budget_tokens"] == nil)
    }

    @Test("ThinkingConfig decodes enabled type")
    func thinkingConfigDecodesEnabled() throws {
        let json: [String: Any] = [
            "type": "enabled",
            "budget_tokens": 2048
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let config = try JSONHelpers.decode(ThinkingConfig.self, from: data)

        if case .enabled(let tokens) = config {
            #expect(tokens == 2048)
        } else {
            Issue.record("Expected enabled config")
        }
    }

    @Test("ThinkingConfig decodes disabled type")
    func thinkingConfigDecodesDisabled() throws {
        let json: [String: Any] = ["type": "disabled"]
        let data = try JSONHelpers.fromDictionary(json)
        let config = try JSONHelpers.decode(ThinkingConfig.self, from: data)

        if case .disabled = config {
            // Success
        } else {
            Issue.record("Expected disabled config")
        }
    }

    @Test("ThinkingConfig throws for unknown type")
    func thinkingConfigThrowsForUnknownType() throws {
        let json: [String: Any] = ["type": "unknown"]
        let data = try JSONHelpers.fromDictionary(json)

        #expect(throws: DecodingError.self) {
            _ = try JSONHelpers.decode(ThinkingConfig.self, from: data)
        }
    }

    // MARK: - RequestMetadata Tests

    @Test("RequestMetadata encodes user_id correctly")
    func requestMetadataEncodes() throws {
        let metadata = RequestMetadata(userId: "user_abc123")
        let data = try JSONHelpers.encode(metadata)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["user_id"] as? String == "user_abc123")
        #expect(dict["userId"] == nil) // Should not have camelCase
    }

    @Test("RequestMetadata with nil userId")
    func requestMetadataNilUserId() throws {
        let metadata = RequestMetadata(userId: nil)
        let data = try JSONHelpers.encode(metadata)
        let dict = try JSONHelpers.toDictionary(data)

        // nil values should be omitted or null
        #expect(dict["user_id"] == nil || dict["user_id"] is NSNull)
    }

    // MARK: - Edge Cases

    @Test("Request with empty messages array")
    func requestEmptyMessages() throws {
        let request = MessagesRequest(
            model: "test",
            messages: [],
            maxTokens: 100
        )

        let data = try JSONHelpers.encode(request)
        let dict = try JSONHelpers.toDictionary(data)

        let messages = dict["messages"] as? [Any]
        #expect(messages?.isEmpty == true)
    }

    @Test("Request roundtrip preserves values")
    func requestRoundtrip() throws {
        let original = MessagesRequest(
            model: "claude-sonnet-4-20250514",
            messages: [Message(role: .user, content: "Test")],
            maxTokens: 500,
            temperature: 0.5
        )

        let data = try JSONHelpers.encode(original)
        let decoded = try JSONHelpers.decode(MessagesRequest.self, from: data)

        #expect(decoded.model == original.model)
        #expect(decoded.maxTokens == original.maxTokens)
        #expect(decoded.temperature == original.temperature)
    }
}
