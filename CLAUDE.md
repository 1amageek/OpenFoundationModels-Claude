# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenFoundationModels-Claude is a Swift package that provides a Claude API integration for OpenFoundationModels. It implements the `LanguageModel` protocol from OpenFoundationModels, allowing Claude models to be used with the OpenFoundationModels framework.

## Build and Test Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a specific test suite
swift test --filter ClaudeLanguageModelTests

# Run a specific test
swift test --filter "ClaudeLanguageModelTests/modelInitialization"
```

## Architecture

### Core Components

- **ClaudeLanguageModel** (`Sources/OpenFoundationModelsClaude/ClaudeLanguageModel.swift`): Main entry point implementing `LanguageModel` protocol. Provides `generate()` and `stream()` methods for interacting with Claude API. Contains static model identifiers (`opus4_6`, `sonnet4_5`, `haiku4_5`, etc.) and factory methods.

- **ClaudeConfiguration** (`Sources/OpenFoundationModelsClaude/ClaudeConfiguration.swift`): Configuration struct holding API key, base URL, timeout, and API version. Supports initialization from environment variables via `fromEnvironment()`.

- **ClaudeHTTPClient** (`Sources/OpenFoundationModelsClaude/HTTP/ClaudeHTTPClient.swift`): Actor handling HTTP communication with Claude API. Implements both synchronous requests and SSE streaming.

- **TranscriptConverter** (`Sources/OpenFoundationModelsClaude/Internal/TranscriptConverter.swift`): Internal utility converting OpenFoundationModels `Transcript` to Claude API message format. Handles tool definitions, tool calls/results, and response format extraction.

### API Layer (`Sources/OpenFoundationModelsClaude/API/`)

- `Message.swift`: User/assistant message types
- `ContentBlock.swift`: Text, tool_use, tool_result content blocks
- `MessagesRequest.swift`: Request structure for /v1/messages endpoint
- `MessagesResponse.swift`: Response parsing
- `StreamingEvent.swift`: SSE event types for streaming
- `Tool.swift`: Tool definition and ToolChoice types
- `JSONValue.swift`: Dynamic JSON value handling
- `ClaudeError.swift`: API error responses

### Data Flow

1. User creates `Transcript` with prompts/instructions via OpenFoundationModels
2. `ClaudeLanguageModel.generate()` or `stream()` is called
3. `TranscriptConverter` converts `Transcript` → `MessagesRequest`
4. `ClaudeHTTPClient` sends request to Claude API
5. Response is converted back to `Transcript.Entry`

## Environment Variables

For integration tests or running with real API:
- `ANTHROPIC_API_KEY` (required): API key for authentication
- `ANTHROPIC_BASE_URL` (optional): Custom API endpoint
- `ANTHROPIC_TIMEOUT` (optional): Request timeout in seconds
- `ANTHROPIC_API_VERSION` (optional): API version header

## Dependencies

- **OpenFoundationModels**: Local dependency at `../OpenFoundationModels` - provides the `LanguageModel` protocol and `Transcript` types
- **swift-configuration**: Environment variable and configuration management

## Platform Requirements

- Swift 6.2+
- macOS 26+, iOS 26+, tvOS 26+, watchOS 26+, visionOS 26+
