# OpenFoundationModels-Claude

Claude API backend for [OpenFoundationModels](https://github.com/1amageek/OpenFoundationModels) - Use Anthropic Claude with Apple Foundation Models compatible interface.

## Overview

OpenFoundationModels-Claude provides a seamless integration between the [Anthropic Claude API](https://www.anthropic.com/api) and the OpenFoundationModels framework. This allows you to use Claude models through the same `LanguageModel` protocol interface as Apple's on-device Foundation Models, enabling:

- **Unified API**: Write code once, run with Claude API or Apple's on-device models
- **Streaming Support**: Real-time token streaming with `AsyncThrowingStream`
- **Tool Calling**: Full support for Claude's tool use capabilities
- **Multi-turn Conversations**: Maintain conversation context through `Transcript`
- **Structured Generation**: Generate typed responses using `Generable` types

## Requirements

- **Swift 6.2+**
- **macOS 15.0+** / **iOS 18.0+** / **tvOS 18.0+** / **watchOS 11.0+** / **visionOS 2.0+**
- **Anthropic API Key**

### Build Note for Swift 6.2.x

When using Swift 6.2.x from [swift.org](https://swift.org) or [swiftly](https://github.com/swift-server/swiftly), you may encounter a compiler crash due to a [known issue](https://github.com/apple/swift-configuration/issues/128). Use Xcode's bundled Swift toolchain instead:

```bash
# Use Xcode's Swift (recommended)
/usr/bin/xcrun swift build
/usr/bin/xcrun swift test

# Check your Swift version
swift --version
# If it shows "+assertions", use xcrun instead
```

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/OpenFoundationModels-Claude.git", from: "1.0.0")
]
```

Then add `OpenFoundationModelsClaude` to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "OpenFoundationModelsClaude", package: "OpenFoundationModels-Claude")
    ]
)
```

## Quick Start

### Basic Usage

```swift
import OpenFoundationModels
import OpenFoundationModelsClaude

// Create configuration
let config = ClaudeConfiguration(apiKey: "your-api-key")

// Create model instance
let model = ClaudeLanguageModel.sonnet4(configuration: config)

// Create a transcript with your prompt
let transcript = Transcript(entries: [
    .prompt(Transcript.Prompt(
        segments: [.text(Transcript.TextSegment(content: "Hello! How are you?"))],
        options: GenerationOptions()
    ))
])

// Generate response
let entry = try await model.generate(transcript: transcript, options: nil)

if case .response(let response) = entry {
    for segment in response.segments {
        if case .text(let text) = segment {
            print(text.content)
        }
    }
}
```

### Using Environment Variables

OpenFoundationModels-Claude uses [swift-configuration](https://github.com/apple/swift-configuration) for secure environment variable handling:

```swift
// Set environment variable: ANTHROPIC_API_KEY=sk-ant-...
guard let config = ClaudeConfiguration.fromEnvironment() else {
    fatalError("ANTHROPIC_API_KEY not set")
}

let model = ClaudeLanguageModel.sonnet4(configuration: config)
```

Supported environment variables:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | - | API key for authentication |
| `ANTHROPIC_BASE_URL` | No | `https://api.anthropic.com` | Custom API endpoint |
| `ANTHROPIC_TIMEOUT` | No | `120.0` | Request timeout in seconds |
| `ANTHROPIC_API_VERSION` | No | `2023-06-01` | API version header |

## Configuration

### ClaudeConfiguration

```swift
let config = ClaudeConfiguration(
    apiKey: "your-api-key",
    baseURL: URL(string: "https://api.anthropic.com")!,
    timeout: 120.0,
    apiVersion: "2023-06-01"
)
```

### Available Models

| Constant | Model ID | Description |
|----------|----------|-------------|
| `opus4_5` | `claude-opus-4-5-20251101` | Premium model with maximum intelligence |
| `sonnet4_5` | `claude-sonnet-4-5-20250929` | Best for real-world agents and coding |
| `sonnet4` | `claude-sonnet-4-20250514` | High-performance with extended thinking |
| `opus4` | `claude-opus-4-20250514` | Most capable model |
| `haiku4_5` | `claude-haiku-4-5-20251001` | Fast responses with extended thinking |
| `sonnet3_7` | `claude-3-7-sonnet-20250219` | High-performance (legacy) |
| `haiku3_5` | `claude-3-5-haiku-20241022` | Fastest, most compact |
| `sonnet3_5` | `claude-3-5-sonnet-20241022` | Balanced performance (legacy) |

```swift
// Using factory methods
let opus = ClaudeLanguageModel.opus4_5(configuration: config)
let sonnet = ClaudeLanguageModel.sonnet4(configuration: config)
let haiku = ClaudeLanguageModel.haiku3_5(configuration: config)

// Or using model identifiers directly
let custom = ClaudeLanguageModel(
    configuration: config,
    modelName: "claude-sonnet-4-20250514",
    defaultMaxTokens: 8192
)
```

## Usage Examples

### System Instructions

```swift
let transcript = Transcript(entries: [
    .instructions(Transcript.Instructions(
        segments: [.text(Transcript.TextSegment(
            content: "You are a helpful assistant that responds in haiku format."
        ))],
        toolDefinitions: []
    )),
    .prompt(Transcript.Prompt(
        segments: [.text(Transcript.TextSegment(content: "Describe Swift programming."))],
        options: GenerationOptions()
    ))
])

let entry = try await model.generate(transcript: transcript, options: nil)
```

### Streaming Responses

```swift
let transcript = Transcript(entries: [
    .prompt(Transcript.Prompt(
        segments: [.text(Transcript.TextSegment(content: "Write a short story about a robot."))],
        options: GenerationOptions()
    ))
])

for try await entry in model.stream(transcript: transcript, options: nil) {
    if case .response(let response) = entry {
        for segment in response.segments {
            if case .text(let text) = segment {
                print(text.content, terminator: "")
            }
        }
    }
}
```

### Multi-turn Conversations

```swift
// First turn
var transcript = Transcript(entries: [
    .prompt(Transcript.Prompt(
        segments: [.text(Transcript.TextSegment(content: "My name is Alice."))],
        options: GenerationOptions()
    ))
])

let entry1 = try await model.generate(transcript: transcript, options: nil)
guard case .response(let response1) = entry1 else { return }

// Add response and continue conversation
transcript = Transcript(entries: [
    .prompt(Transcript.Prompt(
        segments: [.text(Transcript.TextSegment(content: "My name is Alice."))],
        options: GenerationOptions()
    )),
    .response(response1),
    .prompt(Transcript.Prompt(
        segments: [.text(Transcript.TextSegment(content: "What is my name?"))],
        options: GenerationOptions()
    ))
])

let entry2 = try await model.generate(transcript: transcript, options: nil)
// Response will remember "Alice"
```

### Using with LanguageModelSession

For a higher-level API, use `LanguageModelSession` from OpenFoundationModels:

```swift
import OpenFoundationModels
import OpenFoundationModelsClaude

let config = ClaudeConfiguration.fromEnvironment()!
let model = ClaudeLanguageModel.sonnet4(configuration: config)

let session = LanguageModelSession(
    model: model,
    instructions: "You are a helpful coding assistant."
)

// Simple text response
let response = try await session.respond(to: "Explain Swift optionals")
print(response.content)

// Streaming response
let stream = session.streamResponse(to: "Write a function to sort an array")
for try await snapshot in stream {
    print(snapshot.content, terminator: "")
}
```

### Tool Calling

Define tools using the OpenFoundationModels `Tool` protocol:

```swift
struct WeatherTool: Tool {
    typealias Arguments = WeatherArguments
    typealias Output = String

    let name = "get_weather"
    let description = "Get current weather for a location"

    var parameters: GenerationSchema {
        GenerationSchema(
            type: WeatherArguments.self,
            description: "Weather lookup arguments",
            properties: [
                .init(name: "location", description: "City name", type: String.self, guides: [])
            ]
        )
    }

    func call(arguments: WeatherArguments) async throws -> String {
        return "Sunny, 72°F in \(arguments.location)"
    }
}

@Generable
struct WeatherArguments {
    let location: String
}

// Use with session
let session = LanguageModelSession(
    model: model,
    tools: [WeatherTool()],
    instructions: "Help users check the weather."
)

let response = try await session.respond(to: "What's the weather in Tokyo?")
```

### Structured Output with Generable

Generate typed responses using the `@Generable` macro:

```swift
@Generable(description: "A recipe")
struct Recipe {
    @Guide(description: "Name of the recipe")
    let name: String

    @Guide(description: "List of ingredients", .minimumCount(1))
    let ingredients: [String]

    @Guide(description: "Step-by-step instructions")
    let instructions: [String]

    @Guide(description: "Cooking time in minutes", .range(1...480))
    let cookingTime: Int
}

let session = LanguageModelSession(model: model)
let response = try await session.respond(
    to: "Give me a recipe for chocolate chip cookies",
    generating: Recipe.self
)

print("Recipe: \(response.content.name)")
print("Cooking time: \(response.content.cookingTime) minutes")
for ingredient in response.content.ingredients {
    print("- \(ingredient)")
}
```

### Generation Options

Control generation behavior with `GenerationOptions`:

```swift
var options = GenerationOptions()
options.temperature = 0.7
options.maximumResponseTokens = 2048

let entry = try await model.generate(transcript: transcript, options: options)
```

## Architecture

```
OpenFoundationModelsClaude/
├── ClaudeLanguageModel.swift     # Main entry point, implements LanguageModel
├── ClaudeConfiguration.swift     # API configuration with environment support
├── HTTP/
│   └── ClaudeHTTPClient.swift    # HTTP client with streaming support
├── Internal/
│   └── TranscriptConverter.swift # Converts Transcript to Claude API format
└── API/
    ├── Message.swift             # Message types
    ├── ContentBlock.swift        # Content blocks (text, tool_use, etc.)
    ├── MessagesRequest.swift     # API request structure
    ├── MessagesResponse.swift    # API response parsing
    ├── StreamingEvent.swift      # SSE streaming events
    ├── Tool.swift                # Tool definitions
    ├── JSONValue.swift           # Dynamic JSON handling
    └── ClaudeError.swift         # Error types
```

### Data Flow

```
User Code
    │
    ▼
LanguageModelSession (OpenFoundationModels)
    │
    ▼
ClaudeLanguageModel.generate() / stream()
    │
    ▼
TranscriptConverter (Transcript → MessagesRequest)
    │
    ▼
ClaudeHTTPClient (HTTP/SSE)
    │
    ▼
Claude API (api.anthropic.com)
    │
    ▼
Response → Transcript.Entry
```

## Error Handling

```swift
do {
    let entry = try await model.generate(transcript: transcript, options: nil)
} catch let error as ClaudeHTTPError {
    switch error {
    case .statusError(let code, let data):
        print("HTTP \(code): \(String(data: data ?? Data(), encoding: .utf8) ?? "")")
    case .networkError(let underlying):
        print("Network error: \(underlying)")
    case .decodingError(let underlying):
        print("Decoding error: \(underlying)")
    case .streamError(let message):
        print("Stream error: \(message)")
    }
}
```

## Testing

```bash
# Run all tests
/usr/bin/xcrun swift test

# Run unit tests only
/usr/bin/xcrun swift test --filter OpenFoundationModelsClaudeTests

# Run integration tests (requires ANTHROPIC_API_KEY)
ANTHROPIC_API_KEY=sk-ant-... /usr/bin/xcrun swift test --filter IntegrationTests
```

## Dependencies

- [OpenFoundationModels](https://github.com/1amageek/OpenFoundationModels) - Apple Foundation Models compatible framework
- [swift-configuration](https://github.com/apple/swift-configuration) - Environment variable management

## License

MIT License

## Related Projects

- [OpenFoundationModels](https://github.com/1amageek/OpenFoundationModels) - The core framework providing Apple Foundation Models compatible API
- [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels) - Apple's official on-device LLM framework
