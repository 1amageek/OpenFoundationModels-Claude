import Foundation
import Testing
import OpenFoundationModels
@testable import OpenFoundationModelsClaude

@Suite("additionalProperties: false Tests")
struct AdditionalPropertiesTests {

    // MARK: - setAdditionalPropertiesFalse Unit Tests

    @Test("Sets additionalProperties false on flat object schema")
    func flatObjectSchema() {
        var schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "age": ["type": "integer"]
            ],
            "required": ["name", "age"]
        ]

        setAdditionalPropertiesFalse(&schema)

        #expect(schema["additionalProperties"] as? Bool == false)
    }

    @Test("Sets additionalProperties false on nested object schemas")
    func nestedObjectSchema() {
        var schema: [String: Any] = [
            "type": "object",
            "properties": [
                "address": [
                    "type": "object",
                    "properties": [
                        "city": ["type": "string"]
                    ]
                ] as [String: Any]
            ]
        ]

        setAdditionalPropertiesFalse(&schema)

        #expect(schema["additionalProperties"] as? Bool == false)

        let properties = schema["properties"] as? [String: Any]
        let address = properties?["address"] as? [String: Any]
        #expect(address?["additionalProperties"] as? Bool == false)
    }

    @Test("Sets additionalProperties false on object inside array items")
    func arrayItemsObjectSchema() {
        var schema: [String: Any] = [
            "type": "array",
            "items": [
                "type": "object",
                "properties": [
                    "value": ["type": "string"]
                ]
            ] as [String: Any]
        ]

        setAdditionalPropertiesFalse(&schema)

        let items = schema["items"] as? [String: Any]
        #expect(items?["additionalProperties"] as? Bool == false)
    }

    @Test("Sets additionalProperties false on objects inside anyOf")
    func anyOfObjectSchema() {
        var schema: [String: Any] = [
            "anyOf": [
                [
                    "type": "object",
                    "properties": [
                        "a": ["type": "string"]
                    ]
                ] as [String: Any],
                [
                    "type": "object",
                    "properties": [
                        "b": ["type": "integer"]
                    ]
                ] as [String: Any]
            ]
        ]

        setAdditionalPropertiesFalse(&schema)

        let anyOf = schema["anyOf"] as? [[String: Any]]
        #expect(anyOf?[0]["additionalProperties"] as? Bool == false)
        #expect(anyOf?[1]["additionalProperties"] as? Bool == false)
    }

    @Test("Does not set additionalProperties on non-object types")
    func nonObjectTypesUnchanged() {
        var stringSchema: [String: Any] = ["type": "string"]
        setAdditionalPropertiesFalse(&stringSchema)
        #expect(stringSchema["additionalProperties"] == nil)

        var arraySchema: [String: Any] = [
            "type": "array",
            "items": ["type": "string"]
        ]
        setAdditionalPropertiesFalse(&arraySchema)
        #expect(arraySchema["additionalProperties"] == nil)
    }

    @Test("Does not set additionalProperties on object without properties")
    func objectWithoutProperties() {
        var schema: [String: Any] = ["type": "object"]
        setAdditionalPropertiesFalse(&schema)
        #expect(schema["additionalProperties"] == nil)
    }

    // MARK: - OutputFormat Integration Tests

    @Test("OutputFormat schema includes additionalProperties false")
    func outputFormatAddsAdditionalProperties() throws {
        let schema = GenerationSchema(
            type: String.self,
            description: "Test",
            properties: [
                GenerationSchema.Property(name: "name", description: "Name", type: String.self, guides: []),
                GenerationSchema.Property(name: "count", description: "Count", type: Int.self, guides: [])
            ]
        )

        let outputFormat = try OutputFormat(schema: schema)
        let data = try JSONHelpers.encode(outputFormat)
        let dict = try JSONHelpers.toDictionary(data)

        let schemaDict = dict["schema"] as? [String: Any]
        #expect(schemaDict?["additionalProperties"] as? Bool == false)
    }

    @Test("OutputFormat nested object schema includes additionalProperties false")
    func outputFormatNestedAdditionalProperties() throws {
        let outerSchema = GenerationSchema(
            type: String.self,
            description: "Outer",
            properties: [
                GenerationSchema.Property(name: "inner", description: "Inner obj", type: String.self, guides: [])
            ]
        )

        let outputFormat = try OutputFormat(schema: outerSchema)
        let data = try JSONHelpers.encode(outputFormat)
        let dict = try JSONHelpers.toDictionary(data)

        let schemaDict = dict["schema"] as? [String: Any]
        #expect(schemaDict?["additionalProperties"] as? Bool == false)
    }

    // MARK: - Tool input_schema Integration Tests

    @Test("Tool input_schema includes additionalProperties false")
    func toolInputSchemaAddsAdditionalProperties() throws {
        let schema = GenerationSchema(
            type: String.self,
            description: "Weather params",
            properties: [
                GenerationSchema.Property(name: "location", description: "City", type: String.self, guides: [])
            ]
        )
        let toolDef = Transcript.ToolDefinition(
            name: "get_weather",
            description: "Get weather",
            parameters: schema
        )
        let instructions = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: "Use tools"))],
            toolDefinitions: [toolDef]
        )
        let transcript = Transcript(entries: [.instructions(instructions)])
        let tools = try TranscriptConverter.extractTools(from: transcript)

        #expect(tools?.count == 1)

        let toolData = try JSONHelpers.encode(tools![0])
        let toolDict = try JSONHelpers.toDictionary(toolData)
        let inputSchema = toolDict["input_schema"] as? [String: Any]
        #expect(inputSchema?["additionalProperties"] as? Bool == false)
    }
}
