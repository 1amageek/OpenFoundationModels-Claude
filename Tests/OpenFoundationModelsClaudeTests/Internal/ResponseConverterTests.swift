import Foundation
import Testing
import OpenFoundationModels
@testable import OpenFoundationModelsClaude

@Suite("ResponseConverter Tests")
struct ResponseConverterTests {

    // MARK: - Test Schema Types

    @Generable
    struct PersonSchema {
        var name: String
        var age: Int
    }

    // MARK: - Text Response Entry

    @Test("createTextResponseEntry creates valid entry with content")
    func textResponseEntry() {
        let entry = ResponseConverter.createTextResponseEntry(content: "Hello, world!")

        if case .response(let response) = entry {
            #expect(response.segments.count == 1)
            if case .text(let textSegment) = response.segments[0] {
                #expect(textSegment.content == "Hello, world!")
            } else {
                Issue.record("Expected text segment")
            }
        } else {
            Issue.record("Expected response entry")
        }
    }

    @Test("createTextResponseEntry handles empty content")
    func textResponseEntryEmpty() {
        let entry = ResponseConverter.createTextResponseEntry(content: "")

        if case .response(let response) = entry {
            if case .text(let textSegment) = response.segments[0] {
                #expect(textSegment.content == "")
            } else {
                Issue.record("Expected text segment")
            }
        } else {
            Issue.record("Expected response entry")
        }
    }

    // MARK: - Response Entry from MessagesResponse

    @Test("createResponseEntry extracts text from response")
    func responseEntryFromResponse() throws {
        let data = try TestData.makeMessagesResponseData(content: "Test response")
        let response = try JSONHelpers.decode(MessagesResponse.self, from: data)

        let entry = ResponseConverter.createResponseEntry(from: response)

        if case .response(let resp) = entry {
            if case .text(let textSegment) = resp.segments[0] {
                #expect(textSegment.content == "Test response")
            } else {
                Issue.record("Expected text segment")
            }
        } else {
            Issue.record("Expected response entry")
        }
    }

    @Test("createResponseEntry handles empty content blocks")
    func responseEntryEmptyContent() throws {
        let json: [String: Any] = [
            "id": "msg_empty",
            "type": "message",
            "role": "assistant",
            "content": [],
            "model": "claude-sonnet-4-20250514",
            "usage": ["input_tokens": 5, "output_tokens": 0]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let response = try JSONHelpers.decode(MessagesResponse.self, from: data)

        let entry = ResponseConverter.createResponseEntry(from: response)

        if case .response(let resp) = entry {
            if case .text(let textSegment) = resp.segments[0] {
                #expect(textSegment.content == "")
            } else {
                Issue.record("Expected text segment")
            }
        } else {
            Issue.record("Expected response entry")
        }
    }

    // MARK: - Response Entry from Text with Schema

    @Test("createResponseEntry fromText returns structured entry for valid JSON")
    func responseEntryFromTextValid() {
        let schema = PersonSchema.generationSchema
        let entry = ResponseConverter.createResponseEntry(fromText: "{\"name\":\"Bob\",\"age\":25}", schema: schema)

        #expect(entry != nil)
        if case .response(let resp) = entry {
            if case .structure(let seg) = resp.segments[0] {
                if case .structure(let props, _) = seg.content.kind {
                    #expect(props["name"]?.kind == .string("Bob"))
                    #expect(props["age"]?.kind == .number(25))
                } else {
                    Issue.record("Expected structure kind")
                }
            } else {
                Issue.record("Expected structured segment")
            }
        }
    }

    @Test("createResponseEntry fromText returns nil for invalid JSON")
    func responseEntryFromTextInvalid() {
        let schema = PersonSchema.generationSchema
        let entry = ResponseConverter.createResponseEntry(fromText: "not json", schema: schema)

        #expect(entry == nil)
    }

    // MARK: - Response Entry with Schema

    @Test("createResponseEntry with schema parses structured output")
    func responseEntryWithSchema() throws {
        let schema = PersonSchema.generationSchema
        let jsonContent = "{\"name\":\"Alice\",\"age\":30}"

        let json: [String: Any] = [
            "id": "msg_schema",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": jsonContent]],
            "model": "claude-sonnet-4-20250514",
            "usage": ["input_tokens": 10, "output_tokens": 20]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let response = try JSONHelpers.decode(MessagesResponse.self, from: data)

        let entry = ResponseConverter.createResponseEntry(from: response, schema: schema)

        if case .response(let resp) = entry {
            if case .structure(let structuredSegment) = resp.segments[0] {
                if case .structure(let props, _) = structuredSegment.content.kind {
                    #expect(props["name"]?.kind == .string("Alice"))
                } else {
                    Issue.record("Expected structure kind")
                }
            } else {
                Issue.record("Expected structured segment")
            }
        } else {
            Issue.record("Expected response entry")
        }
    }

    @Test("createResponseEntry with schema falls back to text for invalid JSON")
    func responseEntryWithSchemaFallback() throws {
        let schema = PersonSchema.generationSchema

        let json: [String: Any] = [
            "id": "msg_invalid",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "not json at all"]],
            "model": "claude-sonnet-4-20250514",
            "usage": ["input_tokens": 10, "output_tokens": 20]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let response = try JSONHelpers.decode(MessagesResponse.self, from: data)

        let entry = ResponseConverter.createResponseEntry(from: response, schema: schema)

        // Should fall back to text entry
        if case .response(let resp) = entry {
            if case .text(let textSegment) = resp.segments[0] {
                #expect(textSegment.content == "not json at all")
            } else {
                Issue.record("Expected text segment fallback")
            }
        } else {
            Issue.record("Expected response entry")
        }
    }

    // MARK: - Tool Calls Entry from ToolUseBlock

    @Test("createToolCallsEntry from ToolUseBlock array")
    func toolCallsEntryFromBlocks() throws {
        let toolUse = ToolUseBlock(
            id: "toolu_123",
            name: "get_weather",
            input: JSONValue(["location": "Tokyo"])
        )

        let entry = ResponseConverter.createToolCallsEntry(from: [toolUse])

        if case .toolCalls(let toolCalls) = entry {
            #expect(toolCalls._calls.count == 1)
            #expect(toolCalls._calls[0].id == "toolu_123")
            #expect(toolCalls._calls[0].toolName == "get_weather")
        } else {
            Issue.record("Expected toolCalls entry")
        }
    }

    @Test("createToolCallsEntry from multiple ToolUseBlocks")
    func toolCallsEntryFromMultipleBlocks() throws {
        let tool1 = ToolUseBlock(
            id: "toolu_1",
            name: "get_weather",
            input: JSONValue(["location": "Tokyo"])
        )
        let tool2 = ToolUseBlock(
            id: "toolu_2",
            name: "get_time",
            input: JSONValue(["timezone": "JST"])
        )

        let entry = ResponseConverter.createToolCallsEntry(from: [tool1, tool2])

        if case .toolCalls(let toolCalls) = entry {
            #expect(toolCalls._calls.count == 2)
            #expect(toolCalls._calls[0].toolName == "get_weather")
            #expect(toolCalls._calls[1].toolName == "get_time")
        } else {
            Issue.record("Expected toolCalls entry")
        }
    }

    // MARK: - Tool Calls Entry from Streaming Data

    @Test("createToolCallsEntry from streaming tuples")
    func toolCallsEntryFromStreamingTuples() {
        let toolCalls: [(id: String, name: String, input: String)] = [
            (id: "toolu_s1", name: "search", input: "{\"query\":\"Swift\"}")
        ]

        let entry = ResponseConverter.createToolCallsEntry(from: toolCalls)

        if case .toolCalls(let calls) = entry {
            #expect(calls._calls.count == 1)
            #expect(calls._calls[0].id == "toolu_s1")
            #expect(calls._calls[0].toolName == "search")
        } else {
            Issue.record("Expected toolCalls entry")
        }
    }

    @Test("createToolCallsEntry from streaming with invalid JSON treats as partial string")
    func toolCallsEntryStreamingInvalidJSON() {
        let toolCalls: [(id: String, name: String, input: String)] = [
            (id: "toolu_bad", name: "test", input: "not-json")
        ]

        let entry = ResponseConverter.createToolCallsEntry(from: toolCalls)

        if case .toolCalls(let calls) = entry {
            #expect(calls._calls.count == 1)
            // GeneratedContent(json:) treats "not-json" as partial raw string, not a throw
            // So the do block succeeds and we get a string kind
            #expect(calls._calls[0].arguments.kind == .string("not-json"))
        } else {
            Issue.record("Expected toolCalls entry")
        }
    }

    @Test("createToolCallsEntry from streaming with empty JSON object")
    func toolCallsEntryStreamingEmptyJSON() {
        let toolCalls: [(id: String, name: String, input: String)] = [
            (id: "toolu_empty", name: "no_args", input: "{}")
        ]

        let entry = ResponseConverter.createToolCallsEntry(from: toolCalls)

        if case .toolCalls(let calls) = entry {
            #expect(calls._calls.count == 1)
            if case .structure(let props, _) = calls._calls[0].arguments.kind {
                #expect(props.isEmpty)
            } else {
                Issue.record("Expected empty structure")
            }
        } else {
            Issue.record("Expected toolCalls entry")
        }
    }
}
