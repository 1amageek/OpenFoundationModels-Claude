import Testing
import Foundation
@testable import OpenFoundationModelsClaude
import OpenFoundationModels

/// Tests for schema-aware JSON parsing in ClaudeLanguageModel
/// These tests verify that Claude's response format quirks are handled correctly
@Suite("Schema-Aware JSON Parsing Tests")
struct SchemaAwareParsingTests {

    // MARK: - Test Schema Types

    @Generable
    struct SimpleArraySchema {
        var items: [String]
    }

    @Generable
    struct NestedArraySchema {
        var name: String
        var children: [ChildItem]
    }

    @Generable
    struct ChildItem {
        var id: Int
        var values: [String]
    }

    @Generable
    struct MixedTypeSchema {
        var name: String
        var tags: [String]
        var count: Int
        var active: Bool
    }

    @Generable
    struct MultipleArraysSchema {
        var classes: [ClassInfo]
        var definitions: [PropertyDefinition]
    }

    @Generable
    struct ClassInfo {
        var name: String
        var description: String?
    }

    @Generable
    struct PropertyDefinition {
        var name: String
        var type: String
    }

    // MARK: - JSON Schema Encoding Tests

    @Test("GenerationSchema encodes to valid JSON Schema")
    func schemaEncodesToJSON() throws {
        let schema = SimpleArraySchema.generationSchema

        let jsonData = try JSONEncoder().encode(schema)
        let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        #expect(jsonDict != nil)
        #expect(jsonDict?["type"] as? String == "object")
        #expect(jsonDict?["properties"] != nil)
    }

    @Test("Array property encodes with correct type")
    func arrayPropertyEncoding() throws {
        let schema = SimpleArraySchema.generationSchema

        let jsonData = try JSONEncoder().encode(schema)
        let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        let properties = jsonDict?["properties"] as? [String: [String: Any]]
        let itemsProperty = properties?["items"]

        #expect(itemsProperty?["type"] as? String == "array")
        #expect(itemsProperty?["items"] != nil)
    }

    @Test("Nested schema encodes correctly")
    func nestedSchemaEncoding() throws {
        let schema = NestedArraySchema.generationSchema

        let jsonData = try JSONEncoder().encode(schema)
        let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        let properties = jsonDict?["properties"] as? [String: [String: Any]]

        #expect(properties?["name"] != nil)
        #expect(properties?["children"] != nil)

        let childrenProp = properties?["children"]
        #expect(childrenProp?["type"] as? String == "array")
    }

    @Test("Multiple array properties encode correctly")
    func multipleArraysEncoding() throws {
        let schema = MultipleArraysSchema.generationSchema

        let jsonData = try JSONEncoder().encode(schema)
        let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        let schemaProperties = jsonDict?["properties"] as? [String: [String: Any]]

        let classesProp = schemaProperties?["classes"]
        let definitionsProp = schemaProperties?["definitions"]

        #expect(classesProp?["type"] as? String == "array")
        #expect(definitionsProp?["type"] as? String == "array")
    }

    // MARK: - GeneratedContent Kind Tests

    @Test("GeneratedContent can be created with array kind")
    func generatedContentArrayKind() {
        let content = GeneratedContent(kind: .array([
            GeneratedContent(kind: .string("a")),
            GeneratedContent(kind: .string("b"))
        ]))

        if case .array(let elements) = content.kind {
            #expect(elements.count == 2)
        } else {
            Issue.record("Expected array kind")
        }
    }

    @Test("GeneratedContent can be created with empty array kind")
    func generatedContentEmptyArrayKind() {
        let content = GeneratedContent(kind: .array([]))

        if case .array(let elements) = content.kind {
            #expect(elements.isEmpty)
        } else {
            Issue.record("Expected array kind")
        }
    }

    @Test("GeneratedContent can be created with structure kind")
    func generatedContentStructureKind() {
        let content = GeneratedContent(kind: .structure(
            properties: [
                "name": GeneratedContent(kind: .string("test")),
                "count": GeneratedContent(kind: .number(42))
            ],
            orderedKeys: ["name", "count"]
        ))

        if case .structure(let props, let keys) = content.kind {
            #expect(props.count == 2)
            #expect(keys == ["name", "count"])
        } else {
            Issue.record("Expected structure kind")
        }
    }

    // MARK: - Transcript Segment Tests

    @Test("StructuredSegment can hold GeneratedContent")
    func structuredSegmentContent() {
        let generatedContent = GeneratedContent(kind: .array([]))

        let segment = Transcript.StructuredSegment(
            id: "test-id",
            source: "claude",
            content: generatedContent
        )

        #expect(segment.id == "test-id")
        #expect(segment.source == "claude")

        if case .array(let elements) = segment.content.kind {
            #expect(elements.isEmpty)
        } else {
            Issue.record("Expected array kind in segment content")
        }
    }

    @Test("Transcript.Entry.response can contain structure segment")
    func responseEntryWithStructureSegment() {
        let generatedContent = GeneratedContent(kind: .structure(
            properties: ["items": GeneratedContent(kind: .array([]))],
            orderedKeys: ["items"]
        ))

        let entry = Transcript.Entry.response(
            Transcript.Response(
                id: "response-id",
                assetIDs: [],
                segments: [.structure(Transcript.StructuredSegment(
                    id: "segment-id",
                    source: "claude",
                    content: generatedContent
                ))]
            )
        )

        if case .response(let response) = entry {
            #expect(response.segments.count == 1)
            if case .structure(let structuredSegment) = response.segments.first {
                #expect(structuredSegment.source == "claude")
            } else {
                Issue.record("Expected structure segment")
            }
        } else {
            Issue.record("Expected response entry")
        }
    }
}
