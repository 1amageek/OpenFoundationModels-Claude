import Foundation
import Testing
import OpenFoundationModels
@testable import OpenFoundationModelsClaude

/// Integration tests that require a valid ANTHROPIC_API_KEY environment variable.
/// These tests are skipped when the API key is not available.
@Suite("Integration Tests", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
struct IntegrationTests {

    // MARK: - Configuration Tests

    @Test("fromEnvironment reads API key from environment")
    func fromEnvironmentReadsAPIKey() throws {
        let config = ClaudeConfiguration.fromEnvironment()

        #expect(config != nil, "ANTHROPIC_API_KEY should be set")
        #expect(config?.apiKey.isEmpty == false)
    }

    // MARK: - Simple Generation Tests

    @Test("Simple text generation returns response")
    func simpleTextGeneration() async throws {
        guard let config = ClaudeConfiguration.fromEnvironment() else {
            Issue.record("ANTHROPIC_API_KEY not set")
            return
        }

        let model = ClaudeLanguageModel.sonnet4(configuration: config)
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "Say hello in Japanese. Reply with only the greeting."))],
                options: GenerationOptions()
            ))
        ])

        let entry = try await model.generate(transcript: transcript, options: nil)

        if case .response(let response) = entry {
            let text = extractText(from: response.segments)
            #expect(!text.isEmpty, "Response should contain text")
            print("Response: \(text)")
        } else {
            Issue.record("Expected response entry, got: \(entry)")
        }
    }

    @Test("Generation with system instructions")
    func generationWithSystemInstructions() async throws {
        guard let config = ClaudeConfiguration.fromEnvironment() else {
            Issue.record("ANTHROPIC_API_KEY not set")
            return
        }

        let model = ClaudeLanguageModel.sonnet4(configuration: config)
        let transcript = Transcript(entries: [
            .instructions(Transcript.Instructions(
                segments: [.text(Transcript.TextSegment(content: "You are a helpful assistant that responds in haiku format."))],
                toolDefinitions: []
            )),
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "Describe Swift programming."))],
                options: GenerationOptions()
            ))
        ])

        let entry = try await model.generate(transcript: transcript, options: nil)

        if case .response(let response) = entry {
            let text = extractText(from: response.segments)
            #expect(!text.isEmpty, "Response should contain text")
            print("Haiku Response: \(text)")
        } else {
            Issue.record("Expected response entry")
        }
    }

    // MARK: - Streaming Tests

    @Test("Streaming text generation yields deltas")
    func streamingTextGeneration() async throws {
        guard let config = ClaudeConfiguration.fromEnvironment() else {
            Issue.record("ANTHROPIC_API_KEY not set")
            return
        }

        let model = ClaudeLanguageModel.sonnet4(configuration: config)
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "Count from 1 to 5 slowly."))],
                options: GenerationOptions()
            ))
        ])

        var accumulatedText = ""
        var deltaCount = 0

        for try await entry in model.stream(transcript: transcript, options: nil) {
            if case .response(let response) = entry {
                let text = extractText(from: response.segments)
                accumulatedText += text
                deltaCount += 1
            }
        }

        #expect(deltaCount > 0, "Should receive multiple deltas")
        #expect(!accumulatedText.isEmpty, "Should accumulate text")
        print("Streamed text (\(deltaCount) deltas): \(accumulatedText)")
    }

    // MARK: - Multi-turn Conversation Tests

    @Test("Multi-turn conversation maintains context")
    func multiTurnConversation() async throws {
        guard let config = ClaudeConfiguration.fromEnvironment() else {
            Issue.record("ANTHROPIC_API_KEY not set")
            return
        }

        let model = ClaudeLanguageModel.sonnet4(configuration: config)

        // First turn
        let transcript1 = Transcript(entries: [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "My name is Alice. Remember this."))],
                options: GenerationOptions()
            ))
        ])

        let entry1 = try await model.generate(transcript: transcript1, options: nil)
        guard case .response(let response1) = entry1 else {
            Issue.record("Expected response entry")
            return
        }

        // Second turn with context
        let transcript2 = Transcript(entries: [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "My name is Alice. Remember this."))],
                options: GenerationOptions()
            )),
            .response(response1),
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "What is my name?"))],
                options: GenerationOptions()
            ))
        ])

        let entry2 = try await model.generate(transcript: transcript2, options: nil)

        if case .response(let response2) = entry2 {
            let text = extractText(from: response2.segments)
            #expect(text.lowercased().contains("alice"), "Response should remember the name 'Alice'")
            print("Second turn response: \(text)")
        } else {
            Issue.record("Expected response entry")
        }
    }

    // MARK: - Tool Call Tests

    @Test("Tool call is returned when tools are defined", .timeLimit(.minutes(1)))
    func toolCallReturned() async throws {
        guard let config = ClaudeConfiguration.fromEnvironment() else {
            Issue.record("ANTHROPIC_API_KEY not set")
            return
        }

        let model = ClaudeLanguageModel.sonnet4(configuration: config)

        let toolSchema = GenerationSchema(
            type: String.self,
            description: "Weather parameters",
            properties: [
                GenerationSchema.Property(name: "location", description: "City name", type: String.self, guides: [])
            ]
        )

        let transcript = Transcript(entries: [
            .instructions(Transcript.Instructions(
                segments: [.text(Transcript.TextSegment(content: "You have a get_weather tool. Always use it when asked about weather."))],
                toolDefinitions: [
                    Transcript.ToolDefinition(
                        name: "get_weather",
                        description: "Get the current weather for a location",
                        parameters: toolSchema
                    )
                ]
            )),
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "What is the weather in Tokyo?"))],
                options: GenerationOptions()
            ))
        ])

        let entry = try await model.generate(transcript: transcript, options: nil)

        if case .toolCalls(let toolCalls) = entry {
            #expect(!toolCalls.isEmpty, "Should contain at least one tool call")
            let firstCall = toolCalls.first!
            #expect(firstCall.toolName == "get_weather")
            print("Tool call: \(firstCall.toolName), args: \(firstCall.arguments.jsonString)")
        } else {
            Issue.record("Expected toolCalls entry, got: \(entry)")
        }
    }

    @Test("Structured output with additionalProperties works", .timeLimit(.minutes(1)))
    func structuredOutputWorks() async throws {
        guard let config = ClaudeConfiguration.fromEnvironment() else {
            Issue.record("ANTHROPIC_API_KEY not set")
            return
        }

        // Structured output requires sonnet4_5 or later
        let model = ClaudeLanguageModel.sonnet4_5(configuration: config)

        let responseSchema = GenerationSchema(
            type: String.self,
            description: "A greeting response",
            properties: [
                GenerationSchema.Property(name: "greeting", description: "A greeting message", type: String.self, guides: []),
                GenerationSchema.Property(name: "language", description: "The language of the greeting", type: String.self, guides: [])
            ]
        )

        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "Say hello in Japanese. Respond in the required JSON format."))],
                options: GenerationOptions(),
                responseFormat: Transcript.ResponseFormat(schema: responseSchema)
            ))
        ])

        let entry = try await model.generate(transcript: transcript, options: nil)

        if case .response(let response) = entry {
            // Structured output may return as text or structured segment
            let text = extractText(from: response.segments)
            let structuredContent = extractStructuredContent(from: response.segments)

            let hasContent = !text.isEmpty || structuredContent != nil
            #expect(hasContent, "Response should contain structured output")

            if let content = structuredContent {
                let jsonString = content.jsonString
                #expect(jsonString.contains("greeting"), "Structured content should contain 'greeting' field")
                print("Structured response (structured): \(jsonString)")
            } else {
                #expect(text.contains("greeting"), "Text response should contain 'greeting' field")
                print("Structured response (text): \(text)")
            }
        } else {
            Issue.record("Expected response entry, got: \(entry)")
        }
    }

    // MARK: - Helper Methods

    private func extractText(from segments: [Transcript.Segment]) -> String {
        return segments.compactMap { segment -> String? in
            if case .text(let textSegment) = segment {
                return textSegment.content
            }
            return nil
        }.joined()
    }

    private func extractStructuredContent(from segments: [Transcript.Segment]) -> GeneratedContent? {
        for segment in segments {
            if case .structure(let structuredSegment) = segment {
                return structuredSegment.content
            }
        }
        return nil
    }
}
