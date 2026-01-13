import Testing
import Foundation
@testable import OpenFoundationModelsClaude
import OpenFoundationModels

@Suite("ClaudeConfiguration Tests")
struct ClaudeConfigurationTests {

    @Test("Configuration initializes with default values")
    func configurationDefaults() {
        let config = ClaudeConfiguration(apiKey: "test-key")

        #expect(config.apiKey == "test-key")
        #expect(config.baseURL == URL(string: "https://api.anthropic.com")!)
        #expect(config.timeout == 120.0)
        #expect(config.apiVersion == "2023-06-01")
    }

    @Test("Configuration initializes with custom values")
    func configurationCustom() {
        let customURL = URL(string: "https://custom.api.example.com")!
        let config = ClaudeConfiguration(
            apiKey: "custom-key",
            baseURL: customURL,
            timeout: 60.0,
            apiVersion: "2024-01-01"
        )

        #expect(config.apiKey == "custom-key")
        #expect(config.baseURL == customURL)
        #expect(config.timeout == 60.0)
        #expect(config.apiVersion == "2024-01-01")
    }

    @Test("Configuration is Sendable")
    func configurationSendable() async {
        let config = ClaudeConfiguration(apiKey: "test-key")

        await Task {
            #expect(config.apiKey == "test-key")
        }.value
    }
}

@Suite("ClaudeLanguageModel Tests")
struct ClaudeLanguageModelTests {

    @Test("Model initializes correctly")
    func modelInitialization() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel(
            configuration: config,
            modelName: "claude-sonnet-4-20250514"
        )

        #expect(model.isAvailable == true)
        #expect(model.modelName == "claude-sonnet-4-20250514")
        #expect(model.defaultMaxTokens == 4096)
    }

    @Test("Model initializes with custom max tokens")
    func modelCustomMaxTokens() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel(
            configuration: config,
            modelName: "claude-sonnet-4-20250514",
            defaultMaxTokens: 8192
        )

        #expect(model.defaultMaxTokens == 8192)
    }

    @Test("Model supports all locales")
    func modelSupportsLocales() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel(
            configuration: config,
            modelName: "claude-sonnet-4-20250514"
        )

        #expect(model.supports(locale: Locale(identifier: "en_US")) == true)
        #expect(model.supports(locale: Locale(identifier: "ja_JP")) == true)
        #expect(model.supports(locale: Locale(identifier: "de_DE")) == true)
        #expect(model.supports(locale: Locale(identifier: "fr_FR")) == true)
        #expect(model.supports(locale: Locale(identifier: "zh_CN")) == true)
    }

    @Test("Model is always available")
    func modelAlwaysAvailable() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel(
            configuration: config,
            modelName: "any-model"
        )

        #expect(model.isAvailable == true)
    }

    // MARK: - Model Identifier Tests

    @Test("All convenience model identifiers are correct")
    func allModelIdentifiers() {
        #expect(ClaudeLanguageModel.opus4_5 == "claude-opus-4-5-20251101")
        #expect(ClaudeLanguageModel.sonnet4_5 == "claude-sonnet-4-5-20250929")
        #expect(ClaudeLanguageModel.sonnet4 == "claude-sonnet-4-20250514")
        #expect(ClaudeLanguageModel.opus4 == "claude-opus-4-20250514")
        #expect(ClaudeLanguageModel.haiku4_5 == "claude-haiku-4-5-20251001")
        #expect(ClaudeLanguageModel.sonnet3_7 == "claude-3-7-sonnet-20250219")
        #expect(ClaudeLanguageModel.haiku3_5 == "claude-3-5-haiku-20241022")
        #expect(ClaudeLanguageModel.sonnet3_5 == "claude-3-5-sonnet-20241022")
    }

    // MARK: - Factory Method Tests

    @Test("Factory method opus4_5 creates correct model")
    func factoryOpus45() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel.opus4_5(configuration: config)

        #expect(model.modelName == ClaudeLanguageModel.opus4_5)
        #expect(model.defaultMaxTokens == 4096)
    }

    @Test("Factory method sonnet4_5 creates correct model")
    func factorySonnet45() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel.sonnet4_5(configuration: config)

        #expect(model.modelName == ClaudeLanguageModel.sonnet4_5)
    }

    @Test("Factory method sonnet4 creates correct model")
    func factorySonnet4() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel.sonnet4(configuration: config)

        #expect(model.modelName == ClaudeLanguageModel.sonnet4)
    }

    @Test("Factory method opus4 creates correct model")
    func factoryOpus4() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel.opus4(configuration: config)

        #expect(model.modelName == ClaudeLanguageModel.opus4)
    }

    @Test("Factory method haiku4_5 creates correct model")
    func factoryHaiku45() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel.haiku4_5(configuration: config)

        #expect(model.modelName == ClaudeLanguageModel.haiku4_5)
    }

    @Test("Factory method sonnet3_7 creates correct model")
    func factorySonnet37() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel.sonnet3_7(configuration: config)

        #expect(model.modelName == ClaudeLanguageModel.sonnet3_7)
    }

    @Test("Factory method haiku3_5 creates correct model")
    func factoryHaiku35() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel.haiku3_5(configuration: config)

        #expect(model.modelName == ClaudeLanguageModel.haiku3_5)
    }

    @Test("Factory method sonnet3_5 creates correct model")
    func factorySonnet35() {
        let config = ClaudeConfiguration(apiKey: "test-key")
        let model = ClaudeLanguageModel.sonnet3_5(configuration: config)

        #expect(model.modelName == ClaudeLanguageModel.sonnet3_5)
    }

    @Test("Factory methods accept custom max tokens")
    func factoryCustomMaxTokens() {
        let config = ClaudeConfiguration(apiKey: "test-key")

        let model1 = ClaudeLanguageModel.opus4_5(configuration: config, defaultMaxTokens: 16384)
        #expect(model1.defaultMaxTokens == 16384)

        let model2 = ClaudeLanguageModel.sonnet4(configuration: config, defaultMaxTokens: 2048)
        #expect(model2.defaultMaxTokens == 2048)
    }

    // MARK: - ClaudeOptions Tests

    @Test("GenerationOptions converts to ClaudeOptions with temperature")
    func generationOptionsTemperature() {
        let options = GenerationOptions(temperature: 0.7)
        let claudeOptions = options.toClaudeOptions()

        #expect(claudeOptions.temperature == 0.7)
    }

    @Test("GenerationOptions converts to ClaudeOptions without temperature")
    func generationOptionsNoTemperature() {
        let options = GenerationOptions()
        let claudeOptions = options.toClaudeOptions()

        #expect(claudeOptions.temperature == nil)
    }
}

@Suite("API Types Tests")
struct APITypesTests {

    @Test("Message encodes with text content")
    func messageTextEncoding() throws {
        let message = Message(role: .user, content: "Hello, Claude!")

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["role"] as? String == "user")
        #expect(json?["content"] as? String == "Hello, Claude!")
    }

    @Test("MessagesRequest encodes correctly")
    func messagesRequestEncoding() throws {
        let request = MessagesRequest(
            model: "claude-sonnet-4-20250514",
            messages: [Message(role: .user, content: "Test")],
            maxTokens: 1024,
            system: "You are a helpful assistant."
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["model"] as? String == "claude-sonnet-4-20250514")
        #expect(json?["max_tokens"] as? Int == 1024)
        #expect(json?["system"] as? String == "You are a helpful assistant.")
    }

    @Test("Tool definition encodes correctly")
    func toolEncoding() throws {
        let tool = Tool(
            name: "get_weather",
            description: "Get the current weather",
            inputSchema: [
                "type": "object",
                "properties": [
                    "location": [
                        "type": "string",
                        "description": "The city name"
                    ]
                ],
                "required": ["location"]
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(tool)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["name"] as? String == "get_weather")
        #expect(json?["description"] as? String == "Get the current weather")
        #expect(json?["input_schema"] != nil)
    }
}
