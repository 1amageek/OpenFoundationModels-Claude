import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("JSONValue Tests")
struct JSONValueTests {

    // MARK: - Dictionary Conversion Tests

    @Test("JSONValue initializes from simple dictionary")
    func jsonValueInitializesFromSimpleDict() throws {
        let dict: [String: Any] = [
            "name": "test",
            "count": 42,
            "enabled": true
        ]
        let jsonValue = JSONValue(dict)
        let result = jsonValue.dictionary

        #expect(result["name"] as? String == "test")
        #expect(result["count"] as? Int == 42)
        #expect(result["enabled"] as? Bool == true)
    }

    @Test("JSONValue initializes from nested dictionary")
    func jsonValueInitializesFromNestedDict() throws {
        let dict: [String: Any] = [
            "user": [
                "name": "Alice",
                "age": 30
            ],
            "active": true
        ]
        let jsonValue = JSONValue(dict)
        let result = jsonValue.dictionary

        let user = result["user"] as? [String: Any]
        #expect(user?["name"] as? String == "Alice")
        #expect(user?["age"] as? Int == 30)
    }

    @Test("JSONValue initializes from dictionary with arrays")
    func jsonValueInitializesFromDictWithArrays() throws {
        let dict: [String: Any] = [
            "tags": ["swift", "api", "claude"],
            "numbers": [1, 2, 3]
        ]
        let jsonValue = JSONValue(dict)
        let result = jsonValue.dictionary

        let tags = result["tags"] as? [String]
        #expect(tags == ["swift", "api", "claude"])
    }

    @Test("JSONValue dictionary property returns original")
    func jsonValueDictionaryReturnsOriginal() throws {
        let original: [String: Any] = [
            "key": "value",
            "number": 123
        ]
        let jsonValue = JSONValue(original)
        let result = jsonValue.dictionary

        #expect(result["key"] as? String == "value")
        #expect(result["number"] as? Int == 123)
    }

    // MARK: - Encoding/Decoding Tests

    @Test("JSONValue roundtrip preserves structure")
    func jsonValueRoundtrip() throws {
        let original: [String: Any] = [
            "string": "hello",
            "int": 42,
            "double": 3.14,
            "bool": true,
            "nested": ["a": 1, "b": 2]
        ]
        let jsonValue = JSONValue(original)

        let data = try JSONHelpers.encode(jsonValue)
        let decoded = try JSONHelpers.decode(JSONValue.self, from: data)
        let result = decoded.dictionary

        #expect(result["string"] as? String == "hello")
        #expect(result["int"] as? Int == 42)
        #expect(result["bool"] as? Bool == true)
    }

    @Test("JSONValue handles empty dictionary")
    func jsonValueHandlesEmptyDict() throws {
        let jsonValue = JSONValue([:])
        let result = jsonValue.dictionary

        #expect(result.isEmpty)
    }

    @Test("JSONValue encodes to valid JSON")
    func jsonValueEncodesToValidJSON() throws {
        let dict: [String: Any] = ["key": "value"]
        let jsonValue = JSONValue(dict)

        let data = try JSONHelpers.encode(jsonValue)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["key"] as? String == "value")
    }

    // MARK: - JSONPrimitive Tests

    @Test("JSONPrimitive decodes Bool")
    func jsonPrimitiveDecodesBool() throws {
        let json = "true".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: json)

        #expect(decoded == .bool(true))
    }

    @Test("JSONPrimitive decodes Int")
    func jsonPrimitiveDecodesInt() throws {
        let json = "42".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: json)

        #expect(decoded == .int(42))
    }

    @Test("JSONPrimitive decodes Double")
    func jsonPrimitiveDecodesDouble() throws {
        let json = "3.14159".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: json)

        #expect(decoded == .double(3.14159))
    }

    @Test("JSONPrimitive decodes String")
    func jsonPrimitiveDecodesString() throws {
        let json = "\"hello world\"".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: json)

        #expect(decoded == .string("hello world"))
    }

    @Test("JSONPrimitive decodes Array")
    func jsonPrimitiveDecodesArray() throws {
        let json = "[1, 2, 3]".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: json)

        #expect(decoded == .array([.int(1), .int(2), .int(3)]))
    }

    @Test("JSONPrimitive decodes Dictionary")
    func jsonPrimitiveDecodesDictionary() throws {
        let json = "{\"key\": \"value\"}".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: json)

        #expect(decoded == .object(["key": .string("value")]))
    }

    @Test("JSONPrimitive decodes null")
    func jsonPrimitiveDecodesNull() throws {
        let json = "null".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: json)

        #expect(decoded == .null)
    }

    @Test("JSONPrimitive encodes Bool correctly")
    func jsonPrimitiveEncodesBool() throws {
        let data = try JSONHelpers.encode(JSONPrimitive.bool(true))
        let string = String(data: data, encoding: .utf8)

        #expect(string == "true")
    }

    @Test("JSONPrimitive encodes Int correctly")
    func jsonPrimitiveEncodesInt() throws {
        let data = try JSONHelpers.encode(JSONPrimitive.int(42))
        let string = String(data: data, encoding: .utf8)

        #expect(string == "42")
    }

    @Test("JSONPrimitive encodes String correctly")
    func jsonPrimitiveEncodesString() throws {
        let data = try JSONHelpers.encode(JSONPrimitive.string("test"))
        let string = String(data: data, encoding: .utf8)

        #expect(string == "\"test\"")
    }

    @Test("JSONPrimitive encodes Array correctly")
    func jsonPrimitiveEncodesArray() throws {
        let data = try JSONHelpers.encode(JSONPrimitive.array([.int(1), .int(2), .int(3)]))
        let decoded = try JSONSerialization.jsonObject(with: data) as? [Int]

        #expect(decoded == [1, 2, 3])
    }

    @Test("JSONPrimitive encodes Dictionary correctly")
    func jsonPrimitiveEncodesDictionary() throws {
        let data = try JSONHelpers.encode(JSONPrimitive.object(["key": .string("value")]))
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        #expect(decoded?["key"] == "value")
    }

    @Test("JSONPrimitive encodes null correctly")
    func jsonPrimitiveEncodesNull() throws {
        let data = try JSONHelpers.encode(JSONPrimitive.null)
        let string = String(data: data, encoding: .utf8)

        #expect(string == "null")
    }

    @Test("JSONPrimitive handles mixed type arrays")
    func jsonPrimitiveHandlesMixedArrays() throws {
        let json = "[1, \"two\", true, null]".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: json)

        #expect(decoded == .array([.int(1), .string("two"), .bool(true), .null]))
    }

    @Test("JSONPrimitive roundtrip preserves values")
    func jsonPrimitiveRoundtrip() throws {
        let original = JSONPrimitive.object(["name": .string("test"), "count": .int(42)])
        let data = try JSONHelpers.encode(original)
        let decoded = try JSONHelpers.decode(JSONPrimitive.self, from: data)

        #expect(decoded == original)
    }

    @Test("JSONPrimitive.from converts Any values correctly")
    func jsonPrimitiveFromAny() {
        #expect(JSONPrimitive.from(NSNull()) == .null)
        #expect(JSONPrimitive.from("hello") == .string("hello"))
        #expect(JSONPrimitive.from(42) == .int(42))
        #expect(JSONPrimitive.from(true) == .bool(true))
    }

    @Test("JSONPrimitive anyValue converts back correctly")
    func jsonPrimitiveAnyValue() {
        #expect(JSONPrimitive.null.anyValue is NSNull)
        #expect(JSONPrimitive.bool(true).anyValue as? Bool == true)
        #expect(JSONPrimitive.int(42).anyValue as? Int == 42)
        #expect(JSONPrimitive.double(3.14).anyValue as? Double == 3.14)
        #expect(JSONPrimitive.string("test").anyValue as? String == "test")
    }
}
