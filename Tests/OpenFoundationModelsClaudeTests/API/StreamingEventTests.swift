import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("StreamingEvent Tests")
struct StreamingEventTests {

    // MARK: - MessageStartEvent Tests

    @Test("MessageStartEvent decodes partial message")
    func messageStartEventDecodes() throws {
        let json: [String: Any] = [
            "type": "message_start",
            "message": [
                "id": "msg_123",
                "type": "message",
                "role": "assistant",
                "model": "claude-sonnet-4-20250514"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageStartEvent.self, from: data)

        #expect(event.type == "message_start")
        #expect(event.message.id == "msg_123")
        #expect(event.message.role == "assistant")
        #expect(event.message.model == "claude-sonnet-4-20250514")
    }

    @Test("MessageStartEvent decodes with usage")
    func messageStartEventDecodesWithUsage() throws {
        let json: [String: Any] = [
            "type": "message_start",
            "message": [
                "id": "msg_456",
                "type": "message",
                "role": "assistant",
                "model": "claude-sonnet-4-20250514",
                "usage": [
                    "input_tokens": 100,
                    "output_tokens": 0
                ]
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageStartEvent.self, from: data)

        #expect(event.message.usage?.inputTokens == 100)
        #expect(event.message.usage?.outputTokens == 0)
    }

    // MARK: - ContentBlockStartEvent Tests

    @Test("ContentBlockStartEvent decodes text block")
    func contentBlockStartEventDecodesText() throws {
        let json: [String: Any] = [
            "type": "content_block_start",
            "index": 0,
            "content_block": [
                "type": "text",
                "text": ""
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockStartEvent.self, from: data)

        #expect(event.type == "content_block_start")
        #expect(event.index == 0)

        if case .text(let block) = event.contentBlock {
            #expect(block.text == "")
        } else {
            Issue.record("Expected text block")
        }
    }

    @Test("ContentBlockStartEvent decodes tool_use block")
    func contentBlockStartEventDecodesToolUse() throws {
        let json: [String: Any] = [
            "type": "content_block_start",
            "index": 1,
            "content_block": [
                "type": "tool_use",
                "id": "toolu_123",
                "name": "get_weather"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockStartEvent.self, from: data)

        #expect(event.index == 1)

        if case .toolUse(let block) = event.contentBlock {
            #expect(block.id == "toolu_123")
            #expect(block.name == "get_weather")
        } else {
            Issue.record("Expected tool_use block")
        }
    }

    @Test("ContentBlockStartEvent decodes thinking block")
    func contentBlockStartEventDecodesThinking() throws {
        let json: [String: Any] = [
            "type": "content_block_start",
            "index": 0,
            "content_block": [
                "type": "thinking",
                "thinking": ""
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockStartEvent.self, from: data)

        if case .thinking(let block) = event.contentBlock {
            #expect(block.thinking == "")
        } else {
            Issue.record("Expected thinking block")
        }
    }

    @Test("ContentBlockStartEvent throws for unknown block type")
    func contentBlockStartEventThrowsForUnknown() throws {
        let json: [String: Any] = [
            "type": "content_block_start",
            "index": 0,
            "content_block": [
                "type": "unknown_type"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)

        #expect(throws: DecodingError.self) {
            _ = try JSONHelpers.decode(ContentBlockStartEvent.self, from: data)
        }
    }

    // MARK: - ContentBlockDeltaEvent Tests

    @Test("Delta decodes text_delta")
    func deltaDecodesTextDelta() throws {
        let json: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "text_delta",
                "text": "Hello"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockDeltaEvent.self, from: data)

        #expect(event.type == "content_block_delta")
        #expect(event.index == 0)

        if case .textDelta(let delta) = event.delta {
            #expect(delta.text == "Hello")
        } else {
            Issue.record("Expected text_delta")
        }
    }

    @Test("Delta decodes input_json_delta with partial_json")
    func deltaDecodesInputJSONDelta() throws {
        let json: [String: Any] = [
            "type": "content_block_delta",
            "index": 1,
            "delta": [
                "type": "input_json_delta",
                "partial_json": "{\"location\":"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockDeltaEvent.self, from: data)

        if case .inputJSONDelta(let delta) = event.delta {
            #expect(delta.partialJson == "{\"location\":")
        } else {
            Issue.record("Expected input_json_delta")
        }
    }

    @Test("Delta decodes thinking_delta")
    func deltaDecodesThinkingDelta() throws {
        let json: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "thinking_delta",
                "thinking": "Let me think..."
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockDeltaEvent.self, from: data)

        if case .thinkingDelta(let delta) = event.delta {
            #expect(delta.thinking == "Let me think...")
        } else {
            Issue.record("Expected thinking_delta")
        }
    }

    @Test("Delta decodes signature_delta")
    func deltaDecodesSignatureDelta() throws {
        let json: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "signature_delta",
                "signature": "sig_abc123"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockDeltaEvent.self, from: data)

        if case .signatureDelta(let delta) = event.delta {
            #expect(delta.signature == "sig_abc123")
        } else {
            Issue.record("Expected signature_delta")
        }
    }

    @Test("Delta throws for unknown delta type")
    func deltaThrowsForUnknownType() throws {
        let json: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "unknown_delta"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)

        #expect(throws: DecodingError.self) {
            _ = try JSONHelpers.decode(ContentBlockDeltaEvent.self, from: data)
        }
    }

    // MARK: - ContentBlockStopEvent Tests

    @Test("ContentBlockStopEvent decodes index")
    func contentBlockStopEventDecodes() throws {
        let json: [String: Any] = [
            "type": "content_block_stop",
            "index": 0
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockStopEvent.self, from: data)

        #expect(event.type == "content_block_stop")
        #expect(event.index == 0)
    }

    // MARK: - MessageDeltaEvent Tests

    @Test("MessageDeltaEvent decodes stop_reason")
    func messageDeltaEventDecodesStopReason() throws {
        let json: [String: Any] = [
            "type": "message_delta",
            "delta": [
                "stop_reason": "end_turn"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageDeltaEvent.self, from: data)

        #expect(event.type == "message_delta")
        #expect(event.delta.stopReason == "end_turn")
    }

    @Test("MessageDeltaEvent decodes stop_sequence")
    func messageDeltaEventDecodesStopSequence() throws {
        let json: [String: Any] = [
            "type": "message_delta",
            "delta": [
                "stop_reason": "stop_sequence",
                "stop_sequence": "END"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageDeltaEvent.self, from: data)

        #expect(event.delta.stopReason == "stop_sequence")
        #expect(event.delta.stopSequence == "END")
    }

    @Test("MessageDeltaEvent decodes usage")
    func messageDeltaEventDecodesUsage() throws {
        let json: [String: Any] = [
            "type": "message_delta",
            "delta": [
                "stop_reason": "end_turn"
            ],
            "usage": [
                "input_tokens": 50,
                "output_tokens": 100
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageDeltaEvent.self, from: data)

        #expect(event.usage?.inputTokens == 50)
        #expect(event.usage?.outputTokens == 100)
    }

    // MARK: - MessageStopEvent Tests

    @Test("MessageStopEvent decodes type")
    func messageStopEventDecodes() throws {
        let json: [String: Any] = [
            "type": "message_stop"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageStopEvent.self, from: data)

        #expect(event.type == "message_stop")
    }

    // MARK: - ErrorEvent Tests

    @Test("ErrorEvent decodes error info")
    func errorEventDecodesErrorInfo() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "overloaded_error",
                "message": "Server is temporarily overloaded"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ErrorEvent.self, from: data)

        #expect(event.type == "error")
        #expect(event.error.type == "overloaded_error")
        #expect(event.error.message == "Server is temporarily overloaded")
    }

    @Test("ErrorEvent decodes various error types")
    func errorEventDecodesVariousTypes() throws {
        let errorTypes = [
            "invalid_request_error",
            "authentication_error",
            "permission_error",
            "not_found_error",
            "rate_limit_error",
            "api_error",
            "overloaded_error"
        ]

        for errorType in errorTypes {
            let json: [String: Any] = [
                "type": "error",
                "error": [
                    "type": errorType,
                    "message": "Error message"
                ]
            ]
            let data = try JSONHelpers.fromDictionary(json)
            let event = try JSONHelpers.decode(ErrorEvent.self, from: data)

            #expect(event.error.type == errorType)
        }
    }
}
