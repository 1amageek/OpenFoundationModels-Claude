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

    // MARK: - Helper Methods

    private func extractText(from segments: [Transcript.Segment]) -> String {
        return segments.compactMap { segment -> String? in
            if case .text(let textSegment) = segment {
                return textSegment.content
            }
            return nil
        }.joined()
    }
}
