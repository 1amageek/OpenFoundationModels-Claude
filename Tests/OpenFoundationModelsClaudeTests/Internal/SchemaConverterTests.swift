import Foundation
import Testing
import OpenFoundationModels
@testable import OpenFoundationModelsClaude

@Suite("SchemaConverter Tests")
struct SchemaConverterTests {

    // MARK: - Test Schema Types

    @Generable
    struct PersonSchema {
        var name: String
        var age: Int
    }

    @Generable
    struct ItemListSchema {
        var items: [String]
    }

    @Generable
    struct NestedSchema {
        var user: UserInfo
    }

    @Generable
    struct UserInfo {
        var name: String
        var email: String
    }

    @Generable
    struct MixedSchema {
        var name: String
        var active: Bool
        var count: Int
    }

    // MARK: - parseJSONWithSchema

    @Test("parseJSONWithSchema parses object with string and number")
    func parseObjectWithPrimitives() {
        let schema = PersonSchema.generationSchema
        let result = SchemaConverter.parseJSONWithSchema("{\"name\":\"Alice\",\"age\":30}", schema: schema)

        #expect(result != nil)
        if case .structure(let props, _) = result?.kind {
            #expect(props["name"]?.kind == .string("Alice"))
            #expect(props["age"]?.kind == .number(30))
        } else {
            Issue.record("Expected structure kind")
        }
    }

    @Test("parseJSONWithSchema returns nil for invalid JSON")
    func parseInvalidJSON() {
        let schema = PersonSchema.generationSchema
        let result = SchemaConverter.parseJSONWithSchema("not json", schema: schema)

        #expect(result == nil)
    }

    @Test("parseJSONWithSchema parses array schema")
    func parseArraySchema() {
        let schema = ItemListSchema.generationSchema

        // ItemListSchema has an "items" property that is an array of strings
        let result = SchemaConverter.parseJSONWithSchema("{\"items\":[\"a\",\"b\",\"c\"]}", schema: schema)

        #expect(result != nil)
        if case .structure(let props, _) = result?.kind {
            if case .array(let elements) = props["items"]?.kind {
                #expect(elements.count == 3)
                #expect(elements[0].kind == .string("a"))
            } else {
                Issue.record("Expected array kind for items property")
            }
        } else {
            Issue.record("Expected structure kind")
        }
    }

    @Test("parseJSONWithSchema handles Claude empty array bug ({} for [])")
    func parseEmptyArrayBug() {
        let schema = ItemListSchema.generationSchema

        // Claude may return {"items": {}} instead of {"items": []}
        let result = SchemaConverter.parseJSONWithSchema("{\"items\":{}}", schema: schema)

        #expect(result != nil)
        if case .structure(let props, _) = result?.kind {
            if case .array(let elements) = props["items"]?.kind {
                #expect(elements.isEmpty)
            } else {
                Issue.record("Expected empty array from {} with array schema")
            }
        } else {
            Issue.record("Expected structure kind")
        }
    }

    @Test("parseJSONWithSchema handles boolean values")
    func parseBooleanValues() {
        let schema = MixedSchema.generationSchema
        let result = SchemaConverter.parseJSONWithSchema("{\"name\":\"test\",\"active\":true,\"count\":5}", schema: schema)

        #expect(result != nil)
        if case .structure(let props, _) = result?.kind {
            #expect(props["active"]?.kind == .bool(true))
            #expect(props["name"]?.kind == .string("test"))
        } else {
            Issue.record("Expected structure kind")
        }
    }

    @Test("parseJSONWithSchema returns nil for empty string")
    func parseEmptyString() {
        let schema = PersonSchema.generationSchema
        let result = SchemaConverter.parseJSONWithSchema("", schema: schema)

        #expect(result == nil)
    }

    // MARK: - isArraySchema / isObjectSchema

    @Test("isArraySchema returns true for array type")
    func isArraySchemaTrue() {
        let schema: [String: Any] = ["type": "array", "items": ["type": "string"]]
        #expect(SchemaConverter.isArraySchema(schema) == true)
    }

    @Test("isArraySchema returns false for object type")
    func isArraySchemaFalse() {
        let schema: [String: Any] = ["type": "object"]
        #expect(SchemaConverter.isArraySchema(schema) == false)
    }

    @Test("isObjectSchema returns true for object type")
    func isObjectSchemaTrue() {
        let schema: [String: Any] = ["type": "object", "properties": [:]]
        #expect(SchemaConverter.isObjectSchema(schema) == true)
    }

    @Test("isObjectSchema returns false for string type")
    func isObjectSchemaFalse() {
        let schema: [String: Any] = ["type": "string"]
        #expect(SchemaConverter.isObjectSchema(schema) == false)
    }

    @Test("isArraySchema handles type as array of strings")
    func isArraySchemaWithTypeArray() {
        let schema: [String: Any] = ["type": ["array", "null"]]
        #expect(SchemaConverter.isArraySchema(schema) == true)
    }

    @Test("isObjectSchema handles type as array of strings")
    func isObjectSchemaWithTypeArray() {
        let schema: [String: Any] = ["type": ["object", "null"]]
        #expect(SchemaConverter.isObjectSchema(schema) == true)
    }

    // MARK: - convertPrimitiveToGeneratedContent

    @Test("convertPrimitiveToGeneratedContent converts string")
    func convertPrimitiveString() {
        let result = SchemaConverter.convertPrimitiveToGeneratedContent("hello")
        #expect(result.kind == .string("hello"))
    }

    @Test("convertPrimitiveToGeneratedContent converts number")
    func convertPrimitiveNumber() {
        let result = SchemaConverter.convertPrimitiveToGeneratedContent(42 as NSNumber)
        #expect(result.kind == .number(42))
    }

    @Test("convertPrimitiveToGeneratedContent converts boolean")
    func convertPrimitiveBool() {
        let result = SchemaConverter.convertPrimitiveToGeneratedContent(true as NSNumber)
        #expect(result.kind == .bool(true))
    }

    @Test("convertPrimitiveToGeneratedContent converts NSNull")
    func convertPrimitiveNull() {
        let result = SchemaConverter.convertPrimitiveToGeneratedContent(NSNull())
        #expect(result.kind == .null)
    }

    @Test("convertPrimitiveToGeneratedContent converts array")
    func convertPrimitiveArray() {
        let result = SchemaConverter.convertPrimitiveToGeneratedContent(["a", "b"] as [Any])
        if case .array(let elements) = result.kind {
            #expect(elements.count == 2)
            #expect(elements[0].kind == .string("a"))
        } else {
            Issue.record("Expected array kind")
        }
    }

    @Test("convertPrimitiveToGeneratedContent converts dictionary")
    func convertPrimitiveDict() {
        let result = SchemaConverter.convertPrimitiveToGeneratedContent(["key": "value"] as [String: Any])
        if case .structure(let props, _) = result.kind {
            #expect(props["key"]?.kind == .string("value"))
        } else {
            Issue.record("Expected structure kind")
        }
    }

    // MARK: - convertToGeneratedContent with schema

    @Test("convertToGeneratedContent converts array with items schema")
    func convertArrayWithItemsSchema() {
        let schemaDict: [String: Any] = [
            "type": "array",
            "items": ["type": "object", "properties": ["name": ["type": "string"]]]
        ]
        let value: [Any] = [["name": "Alice"], ["name": "Bob"]]

        let result = SchemaConverter.convertToGeneratedContent(value, schemaDict: schemaDict)

        if case .array(let elements) = result.kind {
            #expect(elements.count == 2)
            if case .structure(let props, _) = elements[0].kind {
                #expect(props["name"]?.kind == .string("Alice"))
            } else {
                Issue.record("Expected structure in array element")
            }
        } else {
            Issue.record("Expected array kind")
        }
    }

    @Test("convertToGeneratedContent with object schema produces ordered keys")
    func convertObjectWithOrderedKeys() {
        let schemaDict: [String: Any] = [
            "type": "object",
            "properties": [
                "beta": ["type": "string"],
                "alpha": ["type": "string"]
            ]
        ]
        let value: [String: Any] = ["alpha": "a", "beta": "b"]

        let result = SchemaConverter.convertToGeneratedContent(value, schemaDict: schemaDict)

        if case .structure(_, let orderedKeys) = result.kind {
            // Keys should be sorted alphabetically
            #expect(orderedKeys == ["alpha", "beta"])
        } else {
            Issue.record("Expected structure kind")
        }
    }

    @Test("convertToGeneratedContent with empty object for array schema returns empty array")
    func convertEmptyObjectForArraySchema() {
        let schemaDict: [String: Any] = [
            "type": "array",
            "items": ["type": "string"]
        ]
        // Claude returns {} for empty arrays
        let value: [String: Any] = [:]

        let result = SchemaConverter.convertToGeneratedContent(value, schemaDict: schemaDict)

        if case .array(let elements) = result.kind {
            #expect(elements.isEmpty)
        } else {
            Issue.record("Expected empty array from empty dict with array schema")
        }
    }

    @Test("convertToGeneratedContent with NSNull on array schema returns null")
    func convertNSNullForArraySchema() {
        let schemaDict: [String: Any] = [
            "type": "array",
            "items": ["type": "string"]
        ]

        let result = SchemaConverter.convertToGeneratedContent(NSNull(), schemaDict: schemaDict)

        #expect(result.kind == .null)
    }
}
