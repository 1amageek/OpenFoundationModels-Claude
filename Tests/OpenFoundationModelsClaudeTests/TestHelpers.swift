import Foundation
import Testing
@testable import OpenFoundationModelsClaude

// MARK: - Test Configuration

enum TestConfiguration {
    static let testAPIKey = "test-api-key-12345"
    static let testBaseURL = URL(string: "https://api.anthropic.com")!
    static let testAPIVersion = "2023-06-01"
    static let testTimeout: TimeInterval = 30.0

    static var configuration: ClaudeConfiguration {
        ClaudeConfiguration(
            apiKey: testAPIKey,
            baseURL: testBaseURL,
            timeout: testTimeout,
            apiVersion: testAPIVersion
        )
    }
}

// MARK: - JSON Helpers

enum JSONHelpers {
    /// Encode a Codable value to JSON Data
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    /// Decode JSON Data to a Codable type
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    /// Convert JSON Data to dictionary
    static func toDictionary(_ data: Data) throws -> [String: Any] {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestError.invalidJSON
        }
        return dict
    }

    /// Create JSON Data from dictionary
    static func fromDictionary(_ dict: [String: Any]) throws -> Data {
        return try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    }

    /// Create JSON string from dictionary
    static func jsonString(_ dict: [String: Any]) throws -> String {
        let data = try fromDictionary(dict)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Test Error

enum TestError: Error {
    case invalidJSON
    case unexpectedValue
    case missingKey(String)
}

// MARK: - Test Data Builders

enum TestData {
    // MARK: - MessagesResponse

    static func makeMessagesResponseJSON(
        id: String = "msg_123",
        content: String = "Hello, world!",
        model: String = "claude-sonnet-4-20250514",
        stopReason: String? = "end_turn",
        inputTokens: Int = 10,
        outputTokens: Int = 20
    ) -> [String: Any] {
        var response: [String: Any] = [
            "id": id,
            "type": "message",
            "role": "assistant",
            "content": [
                ["type": "text", "text": content]
            ],
            "model": model,
            "usage": [
                "input_tokens": inputTokens,
                "output_tokens": outputTokens
            ]
        ]
        if let stopReason = stopReason {
            response["stop_reason"] = stopReason
        }
        return response
    }

    static func makeMessagesResponseData(
        id: String = "msg_123",
        content: String = "Hello, world!",
        model: String = "claude-sonnet-4-20250514",
        stopReason: String? = "end_turn",
        inputTokens: Int = 10,
        outputTokens: Int = 20
    ) throws -> Data {
        let json = makeMessagesResponseJSON(
            id: id,
            content: content,
            model: model,
            stopReason: stopReason,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
        return try JSONHelpers.fromDictionary(json)
    }

    // MARK: - Streaming Events

    static func makeSSEEvent(event: String, data: [String: Any]) throws -> String {
        let jsonData = try JSONHelpers.fromDictionary(data)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        return "event: \(event)\ndata: \(jsonString)\n\n"
    }

    static func makeMessageStartEvent(
        id: String = "msg_123",
        model: String = "claude-sonnet-4-20250514"
    ) -> [String: Any] {
        return [
            "type": "message_start",
            "message": [
                "id": id,
                "type": "message",
                "role": "assistant",
                "model": model
            ]
        ]
    }

    static func makeContentBlockStartEvent(index: Int, text: String = "") -> [String: Any] {
        return [
            "type": "content_block_start",
            "index": index,
            "content_block": [
                "type": "text",
                "text": text
            ]
        ]
    }

    static func makeContentBlockDeltaEvent(index: Int, text: String) -> [String: Any] {
        return [
            "type": "content_block_delta",
            "index": index,
            "delta": [
                "type": "text_delta",
                "text": text
            ]
        ]
    }

    static func makeContentBlockStopEvent(index: Int) -> [String: Any] {
        return [
            "type": "content_block_stop",
            "index": index
        ]
    }

    static func makeMessageDeltaEvent(stopReason: String = "end_turn") -> [String: Any] {
        return [
            "type": "message_delta",
            "delta": [
                "stop_reason": stopReason
            ],
            "usage": [
                "input_tokens": 10,
                "output_tokens": 20
            ]
        ]
    }

    static func makeMessageStopEvent() -> [String: Any] {
        return [
            "type": "message_stop"
        ]
    }

    // MARK: - Tool Use

    static func makeToolUseContentBlock(
        id: String = "toolu_123",
        name: String = "get_weather",
        input: [String: Any] = ["location": "Tokyo"]
    ) -> [String: Any] {
        return [
            "type": "tool_use",
            "id": id,
            "name": name,
            "input": input
        ]
    }

    static func makeToolResultContentBlock(
        toolUseId: String = "toolu_123",
        content: String = "Sunny, 25°C",
        isError: Bool? = nil
    ) -> [String: Any] {
        var block: [String: Any] = [
            "type": "tool_result",
            "tool_use_id": toolUseId,
            "content": content
        ]
        if let isError = isError {
            block["is_error"] = isError
        }
        return block
    }
}

// MARK: - Assertion Helpers

/// Assert that two JSON dictionaries are equal (deep comparison)
func assertJSONEqual(
    _ actual: [String: Any],
    _ expected: [String: Any],
    file: StaticString = #file,
    line: UInt = #line
) {
    do {
        let actualData = try JSONSerialization.data(withJSONObject: actual, options: [.sortedKeys])
        let expectedData = try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys])
        let actualString = String(data: actualData, encoding: .utf8) ?? ""
        let expectedString = String(data: expectedData, encoding: .utf8) ?? ""
        #expect(actualString == expectedString)
    } catch {
        Issue.record("JSON comparison failed: \(error)")
    }
}

/// Assert that encoded JSON contains expected key-value pairs
func assertJSONContains<T: Encodable>(
    _ value: T,
    key: String,
    equals expected: Any,
    file: StaticString = #file,
    line: UInt = #line
) throws {
    let data = try JSONHelpers.encode(value)
    let dict = try JSONHelpers.toDictionary(data)

    guard let actual = dict[key] else {
        Issue.record("Missing key '\(key)' in JSON")
        return
    }

    // Compare based on type
    switch (actual, expected) {
    case (let a as String, let e as String):
        #expect(a == e)
    case (let a as Int, let e as Int):
        #expect(a == e)
    case (let a as Double, let e as Double):
        #expect(a == e)
    case (let a as Bool, let e as Bool):
        #expect(a == e)
    default:
        // For complex types, compare JSON strings
        let actualJSON = try? JSONSerialization.data(withJSONObject: actual, options: [.sortedKeys])
        let expectedJSON = try? JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys])
        #expect(actualJSON == expectedJSON)
    }
}

/// Assert that encoded JSON does not contain a specific key
func assertJSONMissingKey<T: Encodable>(
    _ value: T,
    key: String,
    file: StaticString = #file,
    line: UInt = #line
) throws {
    let data = try JSONHelpers.encode(value)
    let dict = try JSONHelpers.toDictionary(data)
    #expect(dict[key] == nil, "Expected key '\(key)' to be missing")
}
