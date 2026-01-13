import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("Tool Tests")
struct ToolTests {

    // MARK: - Tool Encoding Tests

    @Test("Tool encodes name and description")
    func toolEncodesNameAndDescription() throws {
        let tool = Tool(
            name: "get_weather",
            description: "Get weather for a location",
            inputSchema: ["type": "object", "properties": [:]]
        )

        let data = try JSONHelpers.encode(tool)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["name"] as? String == "get_weather")
        #expect(dict["description"] as? String == "Get weather for a location")
    }

    @Test("Tool encodes input_schema from JSONValue")
    func toolEncodesInputSchema() throws {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "location": ["type": "string"],
                "units": ["type": "string", "enum": ["celsius", "fahrenheit"]]
            ],
            "required": ["location"]
        ]
        let tool = Tool(name: "get_weather", description: "Get weather", inputSchema: schema)

        let data = try JSONHelpers.encode(tool)
        let dict = try JSONHelpers.toDictionary(data)

        let inputSchema = dict["input_schema"] as? [String: Any]
        #expect(inputSchema?["type"] as? String == "object")

        let properties = inputSchema?["properties"] as? [String: Any]
        #expect(properties?["location"] != nil)
    }

    @Test("Tool encodes cache_control when present")
    func toolEncodesCacheControl() throws {
        let tool = Tool(
            name: "test_tool",
            description: nil,
            inputSchema: [:],
            cacheControl: .fiveMinutes
        )

        let data = try JSONHelpers.encode(tool)
        let dict = try JSONHelpers.toDictionary(data)

        let cacheControl = dict["cache_control"] as? [String: Any]
        #expect(cacheControl?["type"] as? String == "ephemeral")
        #expect(cacheControl?["ttl"] as? String == "5m")
    }

    @Test("Tool omits cache_control when nil")
    func toolOmitsCacheControlWhenNil() throws {
        let tool = Tool(
            name: "test_tool",
            description: nil,
            inputSchema: [:],
            cacheControl: nil
        )

        let data = try JSONHelpers.encode(tool)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["cache_control"] == nil || dict["cache_control"] is NSNull)
    }

    @Test("Tool decodes correctly")
    func toolDecodes() throws {
        let json: [String: Any] = [
            "name": "search",
            "description": "Search the web",
            "input_schema": [
                "type": "object",
                "properties": ["query": ["type": "string"]]
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let tool = try JSONHelpers.decode(Tool.self, from: data)

        #expect(tool.name == "search")
        #expect(tool.description == "Search the web")
    }

    // MARK: - ToolChoice Tests

    @Test("ToolChoice auto encodes without disable flag by default")
    func toolChoiceAutoEncodesDefault() throws {
        let choice = ToolChoice.auto()
        let data = try JSONHelpers.encode(choice)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "auto")
        #expect(dict["disable_parallel_tool_use"] == nil)
    }

    @Test("ToolChoice auto encodes with disable flag when true")
    func toolChoiceAutoEncodesWithDisableFlag() throws {
        let choice = ToolChoice.auto(disableParallelToolUse: true)
        let data = try JSONHelpers.encode(choice)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "auto")
        #expect(dict["disable_parallel_tool_use"] as? Bool == true)
    }

    @Test("ToolChoice any encodes correctly")
    func toolChoiceAnyEncodes() throws {
        let choice = ToolChoice.any()
        let data = try JSONHelpers.encode(choice)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "any")
    }

    @Test("ToolChoice any encodes with disable flag when true")
    func toolChoiceAnyEncodesWithDisableFlag() throws {
        let choice = ToolChoice.any(disableParallelToolUse: true)
        let data = try JSONHelpers.encode(choice)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "any")
        #expect(dict["disable_parallel_tool_use"] as? Bool == true)
    }

    @Test("ToolChoice none encodes correctly")
    func toolChoiceNoneEncodes() throws {
        let choice = ToolChoice.none
        let data = try JSONHelpers.encode(choice)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "none")
        #expect(dict["disable_parallel_tool_use"] == nil)
    }

    @Test("ToolChoice tool encodes with name")
    func toolChoiceToolEncodesWithName() throws {
        let choice = ToolChoice.tool(name: "get_weather")
        let data = try JSONHelpers.encode(choice)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "tool")
        #expect(dict["name"] as? String == "get_weather")
    }

    @Test("ToolChoice tool encodes with disable flag when true")
    func toolChoiceToolEncodesWithDisableFlag() throws {
        let choice = ToolChoice.tool(name: "search", disableParallelToolUse: true)
        let data = try JSONHelpers.encode(choice)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "tool")
        #expect(dict["name"] as? String == "search")
        #expect(dict["disable_parallel_tool_use"] as? Bool == true)
    }

    @Test("ToolChoice decodes auto variant")
    func toolChoiceDecodesAuto() throws {
        let json: [String: Any] = ["type": "auto"]
        let data = try JSONHelpers.fromDictionary(json)
        let choice = try JSONHelpers.decode(ToolChoice.self, from: data)

        if case .auto(let disableParallel) = choice {
            #expect(disableParallel == false)
        } else {
            Issue.record("Expected auto choice")
        }
    }

    @Test("ToolChoice decodes auto with disable flag")
    func toolChoiceDecodesAutoWithDisable() throws {
        let json: [String: Any] = [
            "type": "auto",
            "disable_parallel_tool_use": true
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let choice = try JSONHelpers.decode(ToolChoice.self, from: data)

        if case .auto(let disableParallel) = choice {
            #expect(disableParallel == true)
        } else {
            Issue.record("Expected auto choice")
        }
    }

    @Test("ToolChoice decodes any variant")
    func toolChoiceDecodesAny() throws {
        let json: [String: Any] = ["type": "any"]
        let data = try JSONHelpers.fromDictionary(json)
        let choice = try JSONHelpers.decode(ToolChoice.self, from: data)

        if case .any = choice {
            // Success
        } else {
            Issue.record("Expected any choice")
        }
    }

    @Test("ToolChoice decodes none variant")
    func toolChoiceDecodesNone() throws {
        let json: [String: Any] = ["type": "none"]
        let data = try JSONHelpers.fromDictionary(json)
        let choice = try JSONHelpers.decode(ToolChoice.self, from: data)

        if case .none = choice {
            // Success
        } else {
            Issue.record("Expected none choice")
        }
    }

    @Test("ToolChoice decodes tool variant")
    func toolChoiceDecodesTool() throws {
        let json: [String: Any] = [
            "type": "tool",
            "name": "specific_tool"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let choice = try JSONHelpers.decode(ToolChoice.self, from: data)

        if case .tool(let name, let disableParallel) = choice {
            #expect(name == "specific_tool")
            #expect(disableParallel == false)
        } else {
            Issue.record("Expected tool choice")
        }
    }

    @Test("ToolChoice throws for unknown type")
    func toolChoiceThrowsForUnknownType() throws {
        let json: [String: Any] = ["type": "invalid"]
        let data = try JSONHelpers.fromDictionary(json)

        #expect(throws: DecodingError.self) {
            _ = try JSONHelpers.decode(ToolChoice.self, from: data)
        }
    }

    // MARK: - CacheControlEphemeral Tests

    @Test("CacheControlEphemeral default has no ttl")
    func cacheControlDefaultHasNoTTL() throws {
        let cache = CacheControlEphemeral.default
        let data = try JSONHelpers.encode(cache)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "ephemeral")
        #expect(dict["ttl"] == nil || dict["ttl"] is NSNull)
    }

    @Test("CacheControlEphemeral fiveMinutes has 5m ttl")
    func cacheControlFiveMinutes() throws {
        let cache = CacheControlEphemeral.fiveMinutes
        let data = try JSONHelpers.encode(cache)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "ephemeral")
        #expect(dict["ttl"] as? String == "5m")
    }

    @Test("CacheControlEphemeral oneHour has 1h ttl")
    func cacheControlOneHour() throws {
        let cache = CacheControlEphemeral.oneHour
        let data = try JSONHelpers.encode(cache)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "ephemeral")
        #expect(dict["ttl"] as? String == "1h")
    }

    @Test("CacheControlEphemeral decodes correctly")
    func cacheControlDecodes() throws {
        let json: [String: Any] = [
            "type": "ephemeral",
            "ttl": "1h"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let cache = try JSONHelpers.decode(CacheControlEphemeral.self, from: data)

        #expect(cache.type == "ephemeral")
        #expect(cache.ttl == "1h")
    }
}
