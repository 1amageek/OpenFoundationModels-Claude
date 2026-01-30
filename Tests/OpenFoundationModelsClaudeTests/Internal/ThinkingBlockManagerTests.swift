import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("ThinkingBlockManager Tests")
struct ThinkingBlockManagerTests {

    // MARK: - Take

    @Test("take returns empty array initially")
    func takeReturnsEmptyInitially() {
        let manager = ThinkingBlockManager()
        let blocks = manager.take()

        #expect(blocks.isEmpty)
    }

    @Test("take returns stored blocks and clears them")
    func takeReturnsAndClears() {
        let manager = ThinkingBlockManager()
        let thinkingBlock = ResponseContentBlock.thinking(
            ThinkingBlock(thinking: "reasoning here", signature: "sig1")
        )
        manager.store([thinkingBlock])

        let first = manager.take()
        #expect(first.count == 1)

        let second = manager.take()
        #expect(second.isEmpty)
    }

    // MARK: - Store from Response Content

    @Test("store(from:) filters only thinking and redactedThinking blocks")
    func storeFromFilters() {
        let manager = ThinkingBlockManager()
        let content: [ResponseContentBlock] = [
            .text(TextBlock(text: "Hello")),
            .thinking(ThinkingBlock(thinking: "reasoning", signature: "sig")),
            .toolUse(ToolUseBlock(id: "t1", name: "test", input: JSONValue([:]))),
            .redactedThinking(RedactedThinkingBlock(data: "redacted_data"))
        ]

        manager.store(from: content)
        let stored = manager.take()

        #expect(stored.count == 2)

        // Verify first is thinking
        if case .thinking(let tb) = stored[0] {
            #expect(tb.thinking == "reasoning")
        } else {
            Issue.record("Expected thinking block at index 0")
        }

        // Verify second is redactedThinking
        if case .redactedThinking(let rb) = stored[1] {
            #expect(rb.data == "redacted_data")
        } else {
            Issue.record("Expected redactedThinking block at index 1")
        }
    }

    @Test("store(from:) ignores content with no thinking blocks")
    func storeFromIgnoresNonThinking() {
        let manager = ThinkingBlockManager()
        let content: [ResponseContentBlock] = [
            .text(TextBlock(text: "Hello")),
            .toolUse(ToolUseBlock(id: "t1", name: "test", input: JSONValue([:])))
        ]

        manager.store(from: content)
        let stored = manager.take()

        #expect(stored.isEmpty)
    }

    // MARK: - Store Directly

    @Test("store directly replaces previous blocks")
    func storeDirectlyReplaces() {
        let manager = ThinkingBlockManager()

        let first = [ResponseContentBlock.thinking(ThinkingBlock(thinking: "first", signature: nil))]
        manager.store(first)

        let second = [ResponseContentBlock.thinking(ThinkingBlock(thinking: "second", signature: nil))]
        manager.store(second)

        let stored = manager.take()
        #expect(stored.count == 1)
        if case .thinking(let tb) = stored[0] {
            #expect(tb.thinking == "second")
        } else {
            Issue.record("Expected thinking block")
        }
    }

    // MARK: - Inject

    @Test("inject prepends thinking blocks to last assistant message")
    func injectPrepends() {
        let messages = [
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "Hi there"),
            Message(role: .user, content: "Follow up")
        ]

        let thinkingBlocks: [ResponseContentBlock] = [
            .thinking(ThinkingBlock(thinking: "Let me think...", signature: "sig"))
        ]

        let result = ThinkingBlockManager.inject(thinkingBlocks, into: messages)

        #expect(result.count == 3)

        // The assistant message (index 1) should now have blocks
        let assistantMsg = result[1]
        if case .blocks(let blocks) = assistantMsg.content {
            #expect(blocks.count == 2) // thinking + original text
            if case .thinking(let tb) = blocks[0] {
                #expect(tb.thinking == "Let me think...")
            } else {
                Issue.record("Expected thinking block first")
            }
            if case .text(let textBlock) = blocks[1] {
                #expect(textBlock.text == "Hi there")
            } else {
                Issue.record("Expected text block second")
            }
        } else {
            Issue.record("Expected blocks content after injection")
        }
    }

    @Test("inject with no assistant message returns messages unchanged")
    func injectNoAssistant() {
        let messages = [
            Message(role: .user, content: "Hello")
        ]

        let thinkingBlocks: [ResponseContentBlock] = [
            .thinking(ThinkingBlock(thinking: "thinking...", signature: nil))
        ]

        let result = ThinkingBlockManager.inject(thinkingBlocks, into: messages)

        #expect(result.count == 1)
        #expect(result[0].role == .user)
    }

    @Test("inject targets the LAST assistant message")
    func injectTargetsLastAssistant() {
        let messages = [
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "First response"),
            Message(role: .user, content: "Second"),
            Message(role: .assistant, content: "Second response"),
            Message(role: .user, content: "Third")
        ]

        let thinkingBlocks: [ResponseContentBlock] = [
            .thinking(ThinkingBlock(thinking: "injected", signature: nil))
        ]

        let result = ThinkingBlockManager.inject(thinkingBlocks, into: messages)

        // First assistant (index 1) should be unchanged
        if case .text(let text) = result[1].content {
            #expect(text == "First response")
        } else {
            Issue.record("First assistant should remain text")
        }

        // Last assistant (index 3) should have thinking blocks injected
        if case .blocks(let blocks) = result[3].content {
            #expect(blocks.count == 2)
            if case .thinking(let tb) = blocks[0] {
                #expect(tb.thinking == "injected")
            } else {
                Issue.record("Expected thinking block")
            }
        } else {
            Issue.record("Last assistant should have blocks")
        }
    }

    @Test("inject handles assistant message that already has blocks content")
    func injectWithExistingBlocks() {
        let existingBlocks: [ContentBlock] = [
            .text(TextBlock(text: "response")),
            .toolUse(ToolUseBlock(id: "t1", name: "tool", input: JSONValue([:])))
        ]
        let messages = [
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: existingBlocks)
        ]

        let thinkingBlocks: [ResponseContentBlock] = [
            .thinking(ThinkingBlock(thinking: "thinking...", signature: "sig"))
        ]

        let result = ThinkingBlockManager.inject(thinkingBlocks, into: messages)

        if case .blocks(let blocks) = result[1].content {
            // thinking + existing 2 blocks = 3
            #expect(blocks.count == 3)
            if case .thinking = blocks[0] {
                // OK
            } else {
                Issue.record("Expected thinking block prepended")
            }
            if case .text = blocks[1] {
                // OK
            } else {
                Issue.record("Expected original text block")
            }
            if case .toolUse = blocks[2] {
                // OK
            } else {
                Issue.record("Expected original toolUse block")
            }
        } else {
            Issue.record("Expected blocks content")
        }
    }

    @Test("inject with redactedThinking block")
    func injectRedactedThinking() {
        let messages = [
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "Response")
        ]

        let thinkingBlocks: [ResponseContentBlock] = [
            .thinking(ThinkingBlock(thinking: "visible thinking", signature: "sig1")),
            .redactedThinking(RedactedThinkingBlock(data: "redacted_data"))
        ]

        let result = ThinkingBlockManager.inject(thinkingBlocks, into: messages)

        if case .blocks(let blocks) = result[1].content {
            #expect(blocks.count == 3) // thinking + redacted + text
            if case .thinking = blocks[0] {
                // OK
            } else {
                Issue.record("Expected thinking block")
            }
            if case .redactedThinking = blocks[1] {
                // OK
            } else {
                Issue.record("Expected redactedThinking block")
            }
        } else {
            Issue.record("Expected blocks content")
        }
    }
}
