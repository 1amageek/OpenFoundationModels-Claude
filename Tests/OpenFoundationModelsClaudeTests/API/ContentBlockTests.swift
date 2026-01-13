import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("ContentBlock Tests")
struct ContentBlockTests {

    // MARK: - TextBlock Tests

    @Test("TextBlock encodes with type text")
    func textBlockEncodes() throws {
        let block = TextBlock(text: "Hello, world!")
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "text")
        #expect(dict["text"] as? String == "Hello, world!")
    }

    @Test("TextBlock decodes correctly")
    func textBlockDecodes() throws {
        let json: [String: Any] = [
            "type": "text",
            "text": "Test message"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(TextBlock.self, from: data)

        #expect(block.type == "text")
        #expect(block.text == "Test message")
    }

    @Test("TextBlock with empty text")
    func textBlockEmptyText() throws {
        let block = TextBlock(text: "")
        let data = try JSONHelpers.encode(block)
        let decoded = try JSONHelpers.decode(TextBlock.self, from: data)

        #expect(decoded.text == "")
    }

    @Test("TextBlock with unicode text")
    func textBlockUnicode() throws {
        let block = TextBlock(text: "日本語テスト 🎉")
        let data = try JSONHelpers.encode(block)
        let decoded = try JSONHelpers.decode(TextBlock.self, from: data)

        #expect(decoded.text == "日本語テスト 🎉")
    }

    // MARK: - ToolUseBlock Tests

    @Test("ToolUseBlock encodes with JSONValue input")
    func toolUseBlockEncodes() throws {
        let input: [String: Any] = ["location": "Tokyo", "units": "celsius"]
        let block = ToolUseBlock(id: "toolu_123", name: "get_weather", input: JSONValue(input))

        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "tool_use")
        #expect(dict["id"] as? String == "toolu_123")
        #expect(dict["name"] as? String == "get_weather")

        let inputDict = dict["input"] as? [String: Any]
        #expect(inputDict?["location"] as? String == "Tokyo")
        #expect(inputDict?["units"] as? String == "celsius")
    }

    @Test("ToolUseBlock decodes correctly")
    func toolUseBlockDecodes() throws {
        let json: [String: Any] = [
            "type": "tool_use",
            "id": "toolu_456",
            "name": "search",
            "input": ["query": "Swift programming"]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ToolUseBlock.self, from: data)

        #expect(block.id == "toolu_456")
        #expect(block.name == "search")
        #expect(block.input.dictionary["query"] as? String == "Swift programming")
    }

    // MARK: - ToolResultBlock Tests

    @Test("ToolResultBlock encodes with tool_use_id")
    func toolResultBlockEncodes() throws {
        let block = ToolResultBlock(toolUseId: "toolu_123", content: "Success", isError: nil)
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "tool_result")
        #expect(dict["tool_use_id"] as? String == "toolu_123")
        #expect(dict["content"] as? String == "Success")
    }

    @Test("ToolResultBlock encodes is_error when true")
    func toolResultBlockEncodesIsErrorTrue() throws {
        let block = ToolResultBlock(toolUseId: "toolu_123", content: "Failed", isError: true)
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["is_error"] as? Bool == true)
    }

    @Test("ToolResultBlock encodes is_error when false")
    func toolResultBlockEncodesIsErrorFalse() throws {
        let block = ToolResultBlock(toolUseId: "toolu_123", content: "OK", isError: false)
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["is_error"] as? Bool == false)
    }

    @Test("ToolResultBlock omits is_error when nil")
    func toolResultBlockOmitsIsErrorWhenNil() throws {
        let block = ToolResultBlock(toolUseId: "toolu_123", content: "OK", isError: nil)
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        // nil should be omitted or be null
        #expect(dict["is_error"] == nil || dict["is_error"] is NSNull)
    }

    @Test("ToolResultBlock decodes correctly")
    func toolResultBlockDecodes() throws {
        let json: [String: Any] = [
            "type": "tool_result",
            "tool_use_id": "toolu_789",
            "content": "Result data",
            "is_error": false
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ToolResultBlock.self, from: data)

        #expect(block.toolUseId == "toolu_789")
        #expect(block.content == "Result data")
        #expect(block.isError == false)
    }

    // MARK: - ThinkingBlock Tests

    @Test("ThinkingBlock encodes with signature")
    func thinkingBlockEncodesWithSignature() throws {
        let block = ThinkingBlock(thinking: "Let me analyze...", signature: "sig_123")
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "thinking")
        #expect(dict["thinking"] as? String == "Let me analyze...")
        #expect(dict["signature"] as? String == "sig_123")
    }

    @Test("ThinkingBlock encodes without signature")
    func thinkingBlockEncodesWithoutSignature() throws {
        let block = ThinkingBlock(thinking: "Thinking...", signature: "")
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "thinking")
        #expect(dict["thinking"] as? String == "Thinking...")
    }

    @Test("ThinkingBlock decodes correctly")
    func thinkingBlockDecodes() throws {
        let json: [String: Any] = [
            "type": "thinking",
            "thinking": "Processing request...",
            "signature": "abc123"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ThinkingBlock.self, from: data)

        #expect(block.thinking == "Processing request...")
        #expect(block.signature == "abc123")
    }

    // MARK: - RedactedThinkingBlock Tests

    @Test("RedactedThinkingBlock encodes data field")
    func redactedThinkingBlockEncodes() throws {
        let block = RedactedThinkingBlock(data: "redacted_content")
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "redacted_thinking")
        #expect(dict["data"] as? String == "redacted_content")
    }

    @Test("RedactedThinkingBlock decodes correctly")
    func redactedThinkingBlockDecodes() throws {
        let json: [String: Any] = [
            "type": "redacted_thinking",
            "data": "hidden_data"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(RedactedThinkingBlock.self, from: data)

        #expect(block.data == "hidden_data")
    }

    // MARK: - ContentBlock Enum Tests

    @Test("ContentBlock decodes text type")
    func contentBlockDecodesText() throws {
        let json: [String: Any] = [
            "type": "text",
            "text": "Hello"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ContentBlock.self, from: data)

        if case .text(let textBlock) = block {
            #expect(textBlock.text == "Hello")
        } else {
            Issue.record("Expected text block")
        }
    }

    @Test("ContentBlock decodes tool_use type")
    func contentBlockDecodesToolUse() throws {
        let json: [String: Any] = [
            "type": "tool_use",
            "id": "toolu_test",
            "name": "test_tool",
            "input": [:]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ContentBlock.self, from: data)

        if case .toolUse(let toolUseBlock) = block {
            #expect(toolUseBlock.name == "test_tool")
        } else {
            Issue.record("Expected tool_use block")
        }
    }

    @Test("ContentBlock decodes tool_result type")
    func contentBlockDecodesToolResult() throws {
        let json: [String: Any] = [
            "type": "tool_result",
            "tool_use_id": "toolu_test",
            "content": "result"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let block = try JSONHelpers.decode(ContentBlock.self, from: data)

        if case .toolResult(let resultBlock) = block {
            #expect(resultBlock.content == "result")
        } else {
            Issue.record("Expected tool_result block")
        }
    }

    @Test("ContentBlock throws for unknown type")
    func contentBlockThrowsForUnknownType() throws {
        let json: [String: Any] = [
            "type": "invalid_type",
            "data": "some data"
        ]
        let data = try JSONHelpers.fromDictionary(json)

        #expect(throws: DecodingError.self) {
            _ = try JSONHelpers.decode(ContentBlock.self, from: data)
        }
    }

    @Test("ContentBlock encodes text type correctly")
    func contentBlockEncodesText() throws {
        let block = ContentBlock.text(TextBlock(text: "Test"))
        let data = try JSONHelpers.encode(block)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "text")
        #expect(dict["text"] as? String == "Test")
    }

    @Test("ContentBlock roundtrip preserves content")
    func contentBlockRoundtrip() throws {
        let original = ContentBlock.text(TextBlock(text: "Roundtrip test"))
        let data = try JSONHelpers.encode(original)
        let decoded = try JSONHelpers.decode(ContentBlock.self, from: data)

        if case .text(let textBlock) = decoded {
            #expect(textBlock.text == "Roundtrip test")
        } else {
            Issue.record("Expected text block")
        }
    }
}
