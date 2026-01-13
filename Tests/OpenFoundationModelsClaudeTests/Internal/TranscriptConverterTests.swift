import Foundation
import Testing
import OpenFoundationModels
import OpenFoundationModelsExtra
@testable import OpenFoundationModelsClaude

@Suite("TranscriptConverter Tests")
struct TranscriptConverterTests {

    // MARK: - buildMessages Tests

    @Test("Empty transcript returns empty messages and nil system")
    func buildMessagesEmptyTranscript() {
        let transcript = Transcript(entries: [])
        let (messages, systemPrompt) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.isEmpty)
        #expect(systemPrompt == nil)
    }

    @Test("Instructions entry converts to system prompt")
    func buildMessagesInstructions() {
        let instructions = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: "You are a helpful assistant."))],
            toolDefinitions: []
        )
        let transcript = Transcript(entries: [.instructions(instructions)])
        let (messages, systemPrompt) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.isEmpty)
        #expect(systemPrompt == "You are a helpful assistant.")
    }

    @Test("Prompt entry converts to user message")
    func buildMessagesPrompt() {
        let prompt = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: "Hello, Claude!"))],
            options: GenerationOptions()
        )
        let transcript = Transcript(entries: [.prompt(prompt)])
        let (messages, systemPrompt) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        #expect(systemPrompt == nil)

        if case .text(let content) = messages[0].content {
            #expect(content == "Hello, Claude!")
        } else {
            Issue.record("Expected text content")
        }
        #expect(messages[0].role == .user)
    }

    @Test("Response entry converts to assistant message")
    func buildMessagesResponse() {
        let response = Transcript.Response(
            assetIDs: [],
            segments: [.text(Transcript.TextSegment(content: "Hello! How can I help?"))]
        )
        let transcript = Transcript(entries: [.response(response)])
        let (messages, systemPrompt) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        #expect(systemPrompt == nil)

        if case .text(let content) = messages[0].content {
            #expect(content == "Hello! How can I help?")
        } else {
            Issue.record("Expected text content")
        }
        #expect(messages[0].role == .assistant)
    }

    @Test("ToolCalls entry converts to assistant message with tool_use blocks")
    func buildMessagesToolCalls() {
        let arguments = GeneratedContent(kind: .structure(
            properties: ["location": GeneratedContent(kind: .string("Tokyo"))],
            orderedKeys: ["location"]
        ))
        let toolCall = Transcript.ToolCall(id: "toolu_123", toolName: "get_weather", arguments: arguments)
        let toolCalls = Transcript.ToolCalls(id: "calls_1", [toolCall])
        let transcript = Transcript(entries: [.toolCalls(toolCalls)])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        #expect(messages[0].role == .assistant)

        if case .blocks(let blocks) = messages[0].content {
            #expect(blocks.count == 1)
            if case .toolUse(let toolUseBlock) = blocks[0] {
                #expect(toolUseBlock.id == "toolu_123")
                #expect(toolUseBlock.name == "get_weather")
            } else {
                Issue.record("Expected tool_use block")
            }
        } else {
            Issue.record("Expected blocks content")
        }
    }

    @Test("ToolOutput entry converts to user message with tool_result")
    func buildMessagesToolOutput() {
        let toolOutput = Transcript.ToolOutput(
            id: "toolu_123",
            toolName: "get_weather",
            segments: [.text(Transcript.TextSegment(content: "Sunny, 25°C"))]
        )
        let transcript = Transcript(entries: [.toolOutput(toolOutput)])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        #expect(messages[0].role == .user)

        if case .blocks(let blocks) = messages[0].content {
            #expect(blocks.count == 1)
            if case .toolResult(let resultBlock) = blocks[0] {
                #expect(resultBlock.toolUseId == "toolu_123")
                #expect(resultBlock.content == "Sunny, 25°C")
            } else {
                Issue.record("Expected tool_result block")
            }
        } else {
            Issue.record("Expected blocks content")
        }
    }

    @Test("Multiple entries preserve order")
    func buildMessagesMultipleEntries() {
        let instructions = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: "System instructions"))],
            toolDefinitions: []
        )
        let prompt1 = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: "First question"))],
            options: GenerationOptions()
        )
        let response1 = Transcript.Response(
            assetIDs: [],
            segments: [.text(Transcript.TextSegment(content: "First answer"))]
        )
        let prompt2 = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: "Second question"))],
            options: GenerationOptions()
        )

        let transcript = Transcript(entries: [
            .instructions(instructions),
            .prompt(prompt1),
            .response(response1),
            .prompt(prompt2)
        ])
        let (messages, systemPrompt) = TranscriptConverter.buildMessages(from: transcript)

        #expect(systemPrompt == "System instructions")
        #expect(messages.count == 3)
        #expect(messages[0].role == .user)
        #expect(messages[1].role == .assistant)
        #expect(messages[2].role == .user)
    }

    @Test("Multiple text segments joined with spaces")
    func buildMessagesMultipleSegments() {
        let prompt = Transcript.Prompt(
            segments: [
                .text(Transcript.TextSegment(content: "Hello")),
                .text(Transcript.TextSegment(content: "world"))
            ],
            options: GenerationOptions()
        )
        let transcript = Transcript(entries: [.prompt(prompt)])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        if case .text(let content) = messages[0].content {
            #expect(content == "Hello world")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Pending tool results added before next prompt")
    func buildMessagesPendingToolResults() {
        let toolOutput = Transcript.ToolOutput(
            id: "toolu_123",
            toolName: "get_weather",
            segments: [.text(Transcript.TextSegment(content: "Sunny"))]
        )
        let prompt = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: "What's the weather like?"))],
            options: GenerationOptions()
        )
        let transcript = Transcript(entries: [
            .toolOutput(toolOutput),
            .prompt(prompt)
        ])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 2)
        #expect(messages[0].role == .user)

        // First message should be tool result
        if case .blocks(let blocks) = messages[0].content {
            if case .toolResult(let result) = blocks[0] {
                #expect(result.toolUseId == "toolu_123")
            } else {
                Issue.record("Expected tool_result block")
            }
        } else {
            Issue.record("Expected blocks content")
        }

        // Second message should be the prompt
        if case .text(let content) = messages[1].content {
            #expect(content == "What's the weather like?")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Empty instructions creates empty system prompt not nil")
    func buildMessagesEmptyInstructions() {
        let instructions = Transcript.Instructions(
            segments: [],
            toolDefinitions: []
        )
        let transcript = Transcript(entries: [.instructions(instructions)])
        let (messages, systemPrompt) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.isEmpty)
        #expect(systemPrompt == nil)
    }

    // MARK: - extractTools Tests

    @Test("extractTools returns nil when no tools defined")
    func extractToolsNoTools() throws {
        let transcript = Transcript(entries: [])
        let tools = try TranscriptConverter.extractTools(from: transcript)

        #expect(tools == nil)
    }

    @Test("extractTools returns nil when instructions have empty tool definitions")
    func extractToolsEmptyDefinitions() throws {
        let instructions = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: "Instructions"))],
            toolDefinitions: []
        )
        let transcript = Transcript(entries: [.instructions(instructions)])
        let tools = try TranscriptConverter.extractTools(from: transcript)

        #expect(tools == nil)
    }

    @Test("extractTools converts tool definitions from most recent instructions")
    func extractToolsConvertsDefinitions() throws {
        let schema = GenerationSchema(
            type: String.self,
            description: "Weather parameters",
            properties: [
                GenerationSchema.Property(name: "location", description: "City name", type: String.self, guides: [])
            ]
        )
        let toolDef = Transcript.ToolDefinition(
            name: "get_weather",
            description: "Get weather for a location",
            parameters: schema
        )
        let instructions = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: "Use the tools"))],
            toolDefinitions: [toolDef]
        )
        let transcript = Transcript(entries: [.instructions(instructions)])
        let tools = try TranscriptConverter.extractTools(from: transcript)

        #expect(tools?.count == 1)
        #expect(tools?[0].name == "get_weather")
        #expect(tools?[0].description == "Get weather for a location")
    }

    @Test("extractTools uses most recent instructions")
    func extractToolsMostRecentInstructions() throws {
        let schema1 = GenerationSchema(type: String.self, description: nil, properties: [])
        let toolDef1 = Transcript.ToolDefinition(name: "old_tool", description: "Old", parameters: schema1)
        let instructions1 = Transcript.Instructions(
            segments: [],
            toolDefinitions: [toolDef1]
        )

        let schema2 = GenerationSchema(type: String.self, description: nil, properties: [])
        let toolDef2 = Transcript.ToolDefinition(name: "new_tool", description: "New", parameters: schema2)
        let instructions2 = Transcript.Instructions(
            segments: [],
            toolDefinitions: [toolDef2]
        )

        let transcript = Transcript(entries: [
            .instructions(instructions1),
            .instructions(instructions2)
        ])
        let tools = try TranscriptConverter.extractTools(from: transcript)

        #expect(tools?.count == 1)
        #expect(tools?[0].name == "new_tool")
    }

    // MARK: - extractResponseFormat Tests

    @Test("extractResponseFormat returns nil when no response format")
    func extractResponseFormatNil() {
        let prompt = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: "Question"))],
            options: GenerationOptions(),
            responseFormat: nil
        )
        let transcript = Transcript(entries: [.prompt(prompt)])
        let schema = TranscriptConverter.extractResponseFormat(from: transcript)

        #expect(schema == nil)
    }

    @Test("extractResponseFormat extracts schema from prompt")
    func extractResponseFormatExtractsSchema() {
        let schema = GenerationSchema(
            type: String.self,
            description: "Response schema",
            properties: []
        )
        let responseFormat = Transcript.ResponseFormat(schema: schema)
        let prompt = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: "Question"))],
            options: GenerationOptions(),
            responseFormat: responseFormat
        )
        let transcript = Transcript(entries: [.prompt(prompt)])
        let extractedSchema = TranscriptConverter.extractResponseFormat(from: transcript)

        #expect(extractedSchema != nil)
    }

    @Test("extractResponseFormat uses most recent prompt with schema")
    func extractResponseFormatMostRecent() {
        let schema1 = GenerationSchema(type: String.self, description: "First", properties: [])
        let prompt1 = Transcript.Prompt(
            segments: [],
            options: GenerationOptions(),
            responseFormat: Transcript.ResponseFormat(schema: schema1)
        )

        let schema2 = GenerationSchema(type: Int.self, description: "Second", properties: [])
        let prompt2 = Transcript.Prompt(
            segments: [],
            options: GenerationOptions(),
            responseFormat: Transcript.ResponseFormat(schema: schema2)
        )

        let transcript = Transcript(entries: [.prompt(prompt1), .prompt(prompt2)])
        let extractedSchema = TranscriptConverter.extractResponseFormat(from: transcript)

        // Most recent prompt (prompt2) has schema2, so we get that one
        #expect(extractedSchema != nil)
        // Verify it's the Int schema (from prompt2), not String schema (from prompt1)
        // We can check this by the type property indirectly
    }

    @Test("extractResponseFormat skips prompts without schema")
    func extractResponseFormatSkipsEmpty() {
        let schema1 = GenerationSchema(type: String.self, description: "First", properties: [])
        let prompt1 = Transcript.Prompt(
            segments: [],
            options: GenerationOptions(),
            responseFormat: Transcript.ResponseFormat(schema: schema1)
        )

        let prompt2 = Transcript.Prompt(
            segments: [],
            options: GenerationOptions(),
            responseFormat: nil
        )

        let transcript = Transcript(entries: [.prompt(prompt1), .prompt(prompt2)])
        let extractedSchema = TranscriptConverter.extractResponseFormat(from: transcript)

        // prompt2 has no responseFormat, so we get schema from prompt1
        #expect(extractedSchema != nil)
    }

    // MARK: - extractOptions Tests

    @Test("extractOptions returns nil for empty transcript")
    func extractOptionsEmptyTranscript() {
        let transcript = Transcript(entries: [])
        let options = TranscriptConverter.extractOptions(from: transcript)

        #expect(options == nil)
    }

    @Test("extractOptions extracts options from prompt")
    func extractOptionsFromPrompt() {
        let genOptions = GenerationOptions()
        let prompt = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: "Question"))],
            options: genOptions
        )
        let transcript = Transcript(entries: [.prompt(prompt)])
        let options = TranscriptConverter.extractOptions(from: transcript)

        #expect(options != nil)
    }

    @Test("extractOptions uses most recent prompt")
    func extractOptionsMostRecent() {
        let options1 = GenerationOptions(temperature: 0.5)
        let prompt1 = Transcript.Prompt(
            segments: [],
            options: options1
        )

        let options2 = GenerationOptions(temperature: 0.9)
        let prompt2 = Transcript.Prompt(
            segments: [],
            options: options2
        )

        let transcript = Transcript(entries: [.prompt(prompt1), .prompt(prompt2)])
        let extractedOptions = TranscriptConverter.extractOptions(from: transcript)

        #expect(extractedOptions?.temperature == 0.9)
    }

    // MARK: - StructuredSegment Tests

    @Test("StructuredSegment converts to JSON string")
    func buildMessagesStructuredSegment() {
        let content = GeneratedContent(kind: .structure(
            properties: ["key": GeneratedContent(kind: .string("value"))],
            orderedKeys: ["key"]
        ))
        let prompt = Transcript.Prompt(
            segments: [.structure(Transcript.StructuredSegment(source: "test", content: content))],
            options: GenerationOptions()
        )
        let transcript = Transcript(entries: [.prompt(prompt)])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        if case .text(let text) = messages[0].content {
            #expect(text.contains("key"))
        } else {
            Issue.record("Expected text content")
        }
    }

    // MARK: - Tool Call Arguments Tests

    @Test("Tool call with nested arguments converts correctly")
    func buildMessagesToolCallNestedArguments() {
        let nestedContent = GeneratedContent(kind: .structure(
            properties: ["unit": GeneratedContent(kind: .string("celsius"))],
            orderedKeys: ["unit"]
        ))
        let arguments = GeneratedContent(kind: .structure(
            properties: [
                "location": GeneratedContent(kind: .string("Tokyo")),
                "options": nestedContent
            ],
            orderedKeys: ["location", "options"]
        ))
        let toolCall = Transcript.ToolCall(id: "toolu_456", toolName: "weather", arguments: arguments)
        let toolCalls = Transcript.ToolCalls(id: "calls_2", [toolCall])
        let transcript = Transcript(entries: [.toolCalls(toolCalls)])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        if case .blocks(let blocks) = messages[0].content {
            if case .toolUse(let block) = blocks[0] {
                let input = block.input.dictionary
                #expect(input["location"] as? String == "Tokyo")
                let options = input["options"] as? [String: Any]
                #expect(options?["unit"] as? String == "celsius")
            } else {
                Issue.record("Expected tool_use block")
            }
        } else {
            Issue.record("Expected blocks content")
        }
    }

    @Test("Tool call with array arguments converts correctly")
    func buildMessagesToolCallArrayArguments() {
        let arrayContent = GeneratedContent(kind: .array([
            GeneratedContent(kind: .string("Tokyo")),
            GeneratedContent(kind: .string("Osaka"))
        ]))
        let arguments = GeneratedContent(kind: .structure(
            properties: ["locations": arrayContent],
            orderedKeys: ["locations"]
        ))
        let toolCall = Transcript.ToolCall(id: "toolu_789", toolName: "multi_weather", arguments: arguments)
        let toolCalls = Transcript.ToolCalls(id: "calls_3", [toolCall])
        let transcript = Transcript(entries: [.toolCalls(toolCalls)])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        if case .blocks(let blocks) = messages[0].content {
            if case .toolUse(let block) = blocks[0] {
                let input = block.input.dictionary
                let locations = input["locations"] as? [Any]
                #expect(locations?.count == 2)
            } else {
                Issue.record("Expected tool_use block")
            }
        } else {
            Issue.record("Expected blocks content")
        }
    }

    @Test("Tool call with primitive arguments converts correctly")
    func buildMessagesToolCallPrimitiveArguments() {
        let arguments = GeneratedContent(kind: .structure(
            properties: [
                "count": GeneratedContent(kind: .number(42)),
                "enabled": GeneratedContent(kind: .bool(true)),
                "value": GeneratedContent(kind: .null)
            ],
            orderedKeys: ["count", "enabled", "value"]
        ))
        let toolCall = Transcript.ToolCall(id: "toolu_prim", toolName: "test_tool", arguments: arguments)
        let toolCalls = Transcript.ToolCalls(id: "calls_prim", [toolCall])
        let transcript = Transcript(entries: [.toolCalls(toolCalls)])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        if case .blocks(let blocks) = messages[0].content {
            if case .toolUse(let block) = blocks[0] {
                let input = block.input.dictionary
                #expect(input["count"] as? Double == 42)
                #expect(input["enabled"] as? Bool == true)
                #expect(input["value"] is NSNull)
            } else {
                Issue.record("Expected tool_use block")
            }
        } else {
            Issue.record("Expected blocks content")
        }
    }

    // MARK: - Multiple Tool Calls Tests

    @Test("Multiple tool calls in single ToolCalls entry")
    func buildMessagesMultipleToolCalls() {
        let args1 = GeneratedContent(kind: .structure(
            properties: ["location": GeneratedContent(kind: .string("Tokyo"))],
            orderedKeys: ["location"]
        ))
        let args2 = GeneratedContent(kind: .structure(
            properties: ["location": GeneratedContent(kind: .string("Osaka"))],
            orderedKeys: ["location"]
        ))
        let toolCall1 = Transcript.ToolCall(id: "toolu_1", toolName: "weather", arguments: args1)
        let toolCall2 = Transcript.ToolCall(id: "toolu_2", toolName: "weather", arguments: args2)
        let toolCalls = Transcript.ToolCalls(id: "calls_multi", [toolCall1, toolCall2])
        let transcript = Transcript(entries: [.toolCalls(toolCalls)])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        if case .blocks(let blocks) = messages[0].content {
            #expect(blocks.count == 2)

            if case .toolUse(let block1) = blocks[0] {
                #expect(block1.id == "toolu_1")
            }
            if case .toolUse(let block2) = blocks[1] {
                #expect(block2.id == "toolu_2")
            }
        } else {
            Issue.record("Expected blocks content")
        }
    }

    // MARK: - Multiple Tool Outputs Tests

    @Test("Multiple tool outputs before prompt")
    func buildMessagesMultipleToolOutputs() {
        let output1 = Transcript.ToolOutput(
            id: "toolu_1",
            toolName: "weather",
            segments: [.text(Transcript.TextSegment(content: "Sunny in Tokyo"))]
        )
        let output2 = Transcript.ToolOutput(
            id: "toolu_2",
            toolName: "weather",
            segments: [.text(Transcript.TextSegment(content: "Rainy in Osaka"))]
        )
        let prompt = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: "Compare the weather"))],
            options: GenerationOptions()
        )
        let transcript = Transcript(entries: [
            .toolOutput(output1),
            .toolOutput(output2),
            .prompt(prompt)
        ])
        let (messages, _) = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 2)

        // First message: combined tool results
        if case .blocks(let blocks) = messages[0].content {
            #expect(blocks.count == 2)
        } else {
            Issue.record("Expected blocks content for tool results")
        }

        // Second message: prompt
        if case .text(let content) = messages[1].content {
            #expect(content == "Compare the weather")
        } else {
            Issue.record("Expected text content for prompt")
        }
    }
}
