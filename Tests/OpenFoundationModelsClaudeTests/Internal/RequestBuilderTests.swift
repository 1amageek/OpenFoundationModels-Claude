import Foundation
import Testing
import OpenFoundationModels
@testable import OpenFoundationModelsClaude

@Suite("RequestBuilder Tests")
struct RequestBuilderTests {

    // MARK: - Basic Build

    @Test("Build creates request with correct model name")
    func buildSetsModelName() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.model == "claude-sonnet-4-20250514")
    }

    @Test("Build sets stream flag correctly")
    func buildSetsStreamFlag() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let nonStreaming = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )
        #expect(nonStreaming.request.stream == false)

        let streaming = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: true
        )
        #expect(streaming.request.stream == true)
    }

    @Test("Build uses default max tokens when none specified")
    func buildUsesDefaultMaxTokens() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 8192,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.maxTokens == 8192)
    }

    @Test("Build uses explicit max tokens from options")
    func buildUsesExplicitMaxTokens() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let options = GenerationOptions(maximumResponseTokens: 2048)

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: options,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.maxTokens == 2048)
    }

    // MARK: - Thinking Parameters

    @Test("Build without thinking budget has nil thinking config")
    func buildWithoutThinking() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.thinking == nil)
        #expect(result.request.maxTokens == 4096)
    }

    @Test("Build with thinking budget sets thinking config and adjusts max tokens")
    func buildWithThinking() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: 10000,
            pendingThinkingBlocks: [],
            stream: false
        )

        // maxTokens = budget + textTokens = 10000 + 4096 = 14096
        #expect(result.request.maxTokens == 14096)

        // temperature and topK should be nil when thinking is enabled
        #expect(result.request.temperature == nil)
        #expect(result.request.topK == nil)
    }

    @Test("Build with thinking nullifies temperature")
    func buildWithThinkingNullifiesTemperature() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let options = GenerationOptions(temperature: 0.8)

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: options,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: 5000,
            pendingThinkingBlocks: [],
            stream: false
        )

        // Temperature must be nil when thinking is enabled
        #expect(result.request.temperature == nil)
    }

    // MARK: - Response Schema / Beta Headers

    @Test("Build without schema has nil beta headers")
    func buildWithoutSchema() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.betaHeaders == nil)
        #expect(result.responseSchema == nil)
        #expect(result.request.outputFormat == nil)
    }

    // MARK: - Thinking Block Injection

    @Test("Build with empty pending thinking blocks does not modify messages")
    func buildWithEmptyThinkingBlocks() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.messages.count == 1)
        #expect(result.request.messages[0].role == .user)
    }

    @Test("Build with pending thinking blocks injects them into assistant message")
    func buildInjectsThinkingBlocks() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))])),
            .response(Transcript.Response(
                id: "resp1",
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(content: "Hi there"))]
            )),
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Follow up"))]))
        ])

        let thinkingBlocks: [ResponseContentBlock] = [
            .thinking(ThinkingBlock(thinking: "Let me think...", signature: "sig123"))
        ]

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: 5000,
            pendingThinkingBlocks: thinkingBlocks,
            stream: false
        )

        // The assistant message should now have thinking blocks prepended
        let assistantMsg = result.request.messages[1]
        #expect(assistantMsg.role == .assistant)
        if case .blocks(let blocks) = assistantMsg.content {
            #expect(blocks.count == 2) // thinking + text
            if case .thinking(let tb) = blocks[0] {
                #expect(tb.thinking == "Let me think...")
            } else {
                Issue.record("Expected thinking block at index 0")
            }
        } else {
            Issue.record("Expected blocks content for assistant message with injected thinking")
        }
    }

    // MARK: - Tool Choice

    @Test("Build sets tool choice auto when tools are present")
    func buildSetsToolChoiceForTools() throws {
        let schema = GenerationSchema(
            type: String.self,
            description: "Tool parameters",
            properties: [
                GenerationSchema.Property(name: "location", description: "City name", type: String.self, guides: [])
            ]
        )
        let transcript = Transcript(entries: [
            .instructions(Transcript.Instructions(
                segments: [.text(Transcript.TextSegment(content: "You are helpful"))],
                toolDefinitions: [
                    Transcript.ToolDefinition(
                        name: "get_weather",
                        description: "Get weather",
                        parameters: schema
                    )
                ]
            )),
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Weather in Tokyo?"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.tools != nil)
        #expect(result.request.toolChoice != nil)
    }

    @Test("Build encodes tool input_schema with additionalProperties false")
    func buildToolSchemaHasAdditionalPropertiesFalse() throws {
        let schema = GenerationSchema(
            type: String.self,
            description: "Tool parameters",
            properties: [
                GenerationSchema.Property(name: "query", description: "Search query", type: String.self, guides: []),
                GenerationSchema.Property(name: "limit", description: "Max results", type: Int.self, guides: [])
            ]
        )
        let transcript = Transcript(entries: [
            .instructions(Transcript.Instructions(
                segments: [.text(Transcript.TextSegment(content: "Use tools"))],
                toolDefinitions: [
                    Transcript.ToolDefinition(
                        name: "search",
                        description: "Search the web",
                        parameters: schema
                    )
                ]
            )),
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Search for Swift"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        let tools = result.request.tools
        #expect(tools != nil)
        #expect(tools?.count == 1)

        let toolData = try JSONHelpers.encode(tools![0])
        let toolDict = try JSONHelpers.toDictionary(toolData)
        let inputSchema = toolDict["input_schema"] as? [String: Any]
        #expect(inputSchema?["type"] as? String == "object")
        #expect(inputSchema?["additionalProperties"] as? Bool == false)
    }

    @Test("Build encodes output_format schema with additionalProperties false")
    func buildOutputFormatSchemaHasAdditionalPropertiesFalse() throws {
        let responseSchema = GenerationSchema(
            type: String.self,
            description: "Response",
            properties: [
                GenerationSchema.Property(name: "answer", description: "The answer", type: String.self, guides: []),
                GenerationSchema.Property(name: "confidence", description: "Confidence", type: Int.self, guides: [])
            ]
        )
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "Question"))],
                options: GenerationOptions(),
                responseFormat: Transcript.ResponseFormat(schema: responseSchema)
            ))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.outputFormat != nil)
        #expect(result.betaHeaders != nil)

        let formatData = try JSONHelpers.encode(result.request.outputFormat!)
        let formatDict = try JSONHelpers.toDictionary(formatData)
        let schemaDict = formatDict["schema"] as? [String: Any]
        #expect(schemaDict?["type"] as? String == "object")
        #expect(schemaDict?["additionalProperties"] as? Bool == false)
    }

    @Test("Build sets nil tool choice when no tools")
    func buildNilToolChoiceWithoutTools() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.tools == nil)
        #expect(result.request.toolChoice == nil)
    }

    // MARK: - System Prompt

    @Test("Build extracts system prompt from instructions")
    func buildExtractsSystemPrompt() throws {
        let transcript = Transcript(entries: [
            .instructions(Transcript.Instructions(
                segments: [.text(Transcript.TextSegment(content: "You are a helpful assistant"))],
                toolDefinitions: []
            )),
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))]))
        ])

        let result = try RequestBuilder.build(
            transcript: transcript,
            options: nil,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 4096,
            thinkingBudgetTokens: nil,
            pendingThinkingBlocks: [],
            stream: false
        )

        #expect(result.request.system == "You are a helpful assistant")
    }
}
