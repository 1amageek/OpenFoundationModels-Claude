import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("MessagesResponse Tests")
struct MessagesResponseTests {

    // MARK: - Basic Decoding Tests

    @Test("Response decodes all required fields")
    func responseDecodesRequiredFields() throws {
        let json = TestData.makeMessagesResponseJSON()
        let data = try JSONHelpers.fromDictionary(json)
        let response = try JSONHelpers.decode(MessagesResponse.self, from: data)

        #expect(response.id == "msg_123")
        #expect(response.type == "message")
        #expect(response.role == "assistant")
        #expect(response.model == "claude-sonnet-4-20250514")
        #expect(response.content.count == 1)
    }

    @Test("Response decodes optional fields when present")
    func responseDecodesOptionalFields() throws {
        var json = TestData.makeMessagesResponseJSON()
        json["stop_reason"] = "end_turn"
        json["stop_sequence"] = "END"
        json["service_tier"] = "standard"

        let data = try JSONHelpers.fromDictionary(json)
        let response = try JSONHelpers.decode(MessagesResponse.self, from: data)

        #expect(response.stopReason == "end_turn")
        #expect(response.stopSequence == "END")
        #expect(response.serviceTier == .standard)
    }

    @Test("Response handles missing optional fields")
    func responseHandlesMissingOptionalFields() throws {
        let json: [String: Any] = [
            "id": "msg_123",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "Hi"]],
            "model": "claude-sonnet-4-20250514",
            "usage": ["input_tokens": 10, "output_tokens": 5]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let response = try JSONHelpers.decode(MessagesResponse.self, from: data)

        #expect(response.stopReason == nil)
        #expect(response.stopSequence == nil)
        #expect(response.serviceTier == nil)
    }

    // MARK: - Usage Tests

    @Test("Usage decodes basic token counts")
    func usageDecodesBasicCounts() throws {
        let json: [String: Any] = [
            "input_tokens": 100,
            "output_tokens": 50
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let usage = try JSONHelpers.decode(Usage.self, from: data)

        #expect(usage.inputTokens == 100)
        #expect(usage.outputTokens == 50)
    }

    @Test("Usage decodes cache-related fields")
    func usageDecodesCacheFields() throws {
        let json: [String: Any] = [
            "input_tokens": 100,
            "output_tokens": 50,
            "cache_creation_input_tokens": 20,
            "cache_read_input_tokens": 30,
            "cache_creation": [
                "ephemeral_5m_input_tokens": 15,
                "ephemeral_1h_input_tokens": 5
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let usage = try JSONHelpers.decode(Usage.self, from: data)

        #expect(usage.cacheCreationInputTokens == 20)
        #expect(usage.cacheReadInputTokens == 30)
        #expect(usage.cacheCreation?.ephemeral5mInputTokens == 15)
        #expect(usage.cacheCreation?.ephemeral1hInputTokens == 5)
    }

    // MARK: - ServiceTier Tests

    @Test("ServiceTier decodes standard")
    func serviceTierDecodesStandard() throws {
        let data = "\"standard\"".data(using: .utf8)!
        let tier = try JSONHelpers.decode(ServiceTier.self, from: data)
        #expect(tier == .standard)
    }

    @Test("ServiceTier decodes priority")
    func serviceTierDecodesPriority() throws {
        let data = "\"priority\"".data(using: .utf8)!
        let tier = try JSONHelpers.decode(ServiceTier.self, from: data)
        #expect(tier == .priority)
    }

    @Test("ServiceTier decodes batch")
    func serviceTierDecodesBatch() throws {
        let data = "\"batch\"".data(using: .utf8)!
        let tier = try JSONHelpers.decode(ServiceTier.self, from: data)
        #expect(tier == .batch)
    }

    // MARK: - ResponseContentBlock Tests

    @Test("ResponseContentBlock decodes text type")
    func responseContentBlockDecodesText() throws {
        let json: [String: Any] = [
            "type": "text",
            "text": "Hello, world!"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ResponseContentBlock.self, from: data)

        if case .text(let textBlock) = block {
            #expect(textBlock.text == "Hello, world!")
        } else {
            Issue.record("Expected text block")
        }
    }

    @Test("ResponseContentBlock decodes tool_use type")
    func responseContentBlockDecodesToolUse() throws {
        let json: [String: Any] = [
            "type": "tool_use",
            "id": "toolu_123",
            "name": "get_weather",
            "input": ["location": "Tokyo"]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ResponseContentBlock.self, from: data)

        if case .toolUse(let toolUseBlock) = block {
            #expect(toolUseBlock.id == "toolu_123")
            #expect(toolUseBlock.name == "get_weather")
        } else {
            Issue.record("Expected tool_use block")
        }
    }

    @Test("ResponseContentBlock decodes thinking type")
    func responseContentBlockDecodesThinking() throws {
        let json: [String: Any] = [
            "type": "thinking",
            "thinking": "Let me think about this...",
            "signature": "sig_abc"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ResponseContentBlock.self, from: data)

        if case .thinking(let thinkingBlock) = block {
            #expect(thinkingBlock.thinking == "Let me think about this...")
            #expect(thinkingBlock.signature == "sig_abc")
        } else {
            Issue.record("Expected thinking block")
        }
    }

    @Test("ResponseContentBlock decodes redacted_thinking type")
    func responseContentBlockDecodesRedactedThinking() throws {
        let json: [String: Any] = [
            "type": "redacted_thinking",
            "data": "redacted_data_here"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ResponseContentBlock.self, from: data)

        if case .redactedThinking(let redactedBlock) = block {
            #expect(redactedBlock.data == "redacted_data_here")
        } else {
            Issue.record("Expected redacted_thinking block")
        }
    }

    @Test("ResponseContentBlock throws for unknown type")
    func responseContentBlockThrowsForUnknownType() throws {
        let json: [String: Any] = [
            "type": "unknown_type",
            "data": "some data"
        ]
        let data = try JSONHelpers.fromDictionary(json)

        #expect(throws: DecodingError.self) {
            _ = try JSONHelpers.decode(ResponseContentBlock.self, from: data)
        }
    }

    // MARK: - CacheCreation Tests

    @Test("CacheCreation decodes all fields")
    func cacheCreationDecodesAllFields() throws {
        let json: [String: Any] = [
            "ephemeral_5m_input_tokens": 100,
            "ephemeral_1h_input_tokens": 50
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let cache = try JSONHelpers.decode(CacheCreation.self, from: data)

        #expect(cache.ephemeral5mInputTokens == 100)
        #expect(cache.ephemeral1hInputTokens == 50)
    }

    @Test("CacheCreation handles missing fields")
    func cacheCreationHandlesMissingFields() throws {
        let json: [String: Any] = [:]
        let data = try JSONHelpers.fromDictionary(json)
        let cache = try JSONHelpers.decode(CacheCreation.self, from: data)

        #expect(cache.ephemeral5mInputTokens == nil)
        #expect(cache.ephemeral1hInputTokens == nil)
    }
}
