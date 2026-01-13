import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("Message Tests")
struct MessageTests {

    // MARK: - Role Tests

    @Test("Role user encodes correctly")
    func roleUserEncodes() throws {
        let role = Role.user
        let data = try JSONHelpers.encode(role)
        let string = String(data: data, encoding: .utf8)
        #expect(string == "\"user\"")
    }

    @Test("Role assistant encodes correctly")
    func roleAssistantEncodes() throws {
        let role = Role.assistant
        let data = try JSONHelpers.encode(role)
        let string = String(data: data, encoding: .utf8)
        #expect(string == "\"assistant\"")
    }

    @Test("Role decodes from string")
    func roleDecodes() throws {
        let userJSON = "\"user\"".data(using: .utf8)!
        let assistantJSON = "\"assistant\"".data(using: .utf8)!

        let user = try JSONHelpers.decode(Role.self, from: userJSON)
        let assistant = try JSONHelpers.decode(Role.self, from: assistantJSON)

        #expect(user == .user)
        #expect(assistant == .assistant)
    }

    // MARK: - Message with Text Content Tests

    @Test("Message with text content encodes as string")
    func messageTextContentEncodesAsString() throws {
        let message = Message(role: .user, content: "Hello, Claude!")
        let data = try JSONHelpers.encode(message)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["role"] as? String == "user")
        #expect(dict["content"] as? String == "Hello, Claude!")
    }

    @Test("Message with text content decodes from string")
    func messageTextContentDecodesFromString() throws {
        let json: [String: Any] = [
            "role": "assistant",
            "content": "Hello, human!"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let message = try JSONHelpers.decode(Message.self, from: data)

        #expect(message.role == .assistant)
        if case .text(let text) = message.content {
            #expect(text == "Hello, human!")
        } else {
            Issue.record("Expected text content")
        }
    }

    // MARK: - Message with Blocks Content Tests

    @Test("Message with blocks encodes as array")
    func messageBlocksContentEncodesAsArray() throws {
        let blocks: [ContentBlock] = [
            .text(TextBlock(text: "Here is the result:")),
            .toolResult(ToolResultBlock(toolUseId: "toolu_123", content: "Success", isError: nil))
        ]
        let message = Message(role: .user, content: blocks)
        let data = try JSONHelpers.encode(message)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["role"] as? String == "user")

        guard let contentArray = dict["content"] as? [[String: Any]] else {
            Issue.record("Expected content to be an array")
            return
        }

        #expect(contentArray.count == 2)
        #expect(contentArray[0]["type"] as? String == "text")
        #expect(contentArray[1]["type"] as? String == "tool_result")
    }

    @Test("Message with blocks decodes from array")
    func messageBlocksContentDecodesFromArray() throws {
        let json: [String: Any] = [
            "role": "user",
            "content": [
                ["type": "text", "text": "Check this:"],
                ["type": "tool_result", "tool_use_id": "toolu_456", "content": "Done"]
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let message = try JSONHelpers.decode(Message.self, from: data)

        #expect(message.role == .user)
        if case .blocks(let blocks) = message.content {
            #expect(blocks.count == 2)
        } else {
            Issue.record("Expected blocks content")
        }
    }

    // MARK: - Edge Cases

    @Test("Message with empty text")
    func messageEmptyText() throws {
        let message = Message(role: .user, content: "")
        let data = try JSONHelpers.encode(message)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["content"] as? String == "")
    }

    @Test("Message with unicode text")
    func messageUnicodeText() throws {
        let message = Message(role: .user, content: "こんにちは 🌸")
        let data = try JSONHelpers.encode(message)
        let decoded = try JSONHelpers.decode(Message.self, from: data)

        if case .text(let text) = decoded.content {
            #expect(text == "こんにちは 🌸")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Message roundtrip preserves content")
    func messageRoundtrip() throws {
        let original = Message(role: .assistant, content: "Test message")
        let data = try JSONHelpers.encode(original)
        let decoded = try JSONHelpers.decode(Message.self, from: data)

        #expect(decoded.role == original.role)
        if case .text(let text) = decoded.content {
            #expect(text == "Test message")
        } else {
            Issue.record("Expected text content")
        }
    }
}
