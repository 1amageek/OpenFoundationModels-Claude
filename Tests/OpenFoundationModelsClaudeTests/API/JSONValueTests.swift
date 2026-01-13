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

    // MARK: - AnyCodable Tests

    @Test("AnyCodable decodes Bool")
    func anyCodableDecodesBool() throws {
        let json = "true".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: json)

        #expect(decoded.value as? Bool == true)
    }

    @Test("AnyCodable decodes Int")
    func anyCodableDecodesInt() throws {
        let json = "42".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: json)

        #expect(decoded.value as? Int == 42)
    }

    @Test("AnyCodable decodes Double")
    func anyCodableDecodesDouble() throws {
        let json = "3.14159".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: json)

        #expect(decoded.value as? Double == 3.14159)
    }

    @Test("AnyCodable decodes String")
    func anyCodableDecodesString() throws {
        let json = "\"hello world\"".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: json)

        #expect(decoded.value as? String == "hello world")
    }

    @Test("AnyCodable decodes Array")
    func anyCodableDecodesArray() throws {
        let json = "[1, 2, 3]".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: json)

        let array = decoded.value as? [Any]
        #expect(array?.count == 3)
    }

    @Test("AnyCodable decodes Dictionary")
    func anyCodableDecodesDictionary() throws {
        let json = "{\"key\": \"value\"}".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: json)

        let dict = decoded.value as? [String: Any]
        #expect(dict?["key"] as? String == "value")
    }

    @Test("AnyCodable decodes null as NSNull")
    func anyCodableDecodesNull() throws {
        let json = "null".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: json)

        #expect(decoded.value is NSNull)
    }

    @Test("AnyCodable encodes Bool correctly")
    func anyCodableEncodesBool() throws {
        let anyCodable = AnyCodable(true)
        let data = try JSONHelpers.encode(anyCodable)
        let string = String(data: data, encoding: .utf8)

        #expect(string == "true")
    }

    @Test("AnyCodable encodes Int correctly")
    func anyCodableEncodesInt() throws {
        let anyCodable = AnyCodable(42)
        let data = try JSONHelpers.encode(anyCodable)
        let string = String(data: data, encoding: .utf8)

        #expect(string == "42")
    }

    @Test("AnyCodable encodes String correctly")
    func anyCodableEncodesString() throws {
        let anyCodable = AnyCodable("test")
        let data = try JSONHelpers.encode(anyCodable)
        let string = String(data: data, encoding: .utf8)

        #expect(string == "\"test\"")
    }

    @Test("AnyCodable encodes Array correctly")
    func anyCodableEncodesArray() throws {
        let anyCodable = AnyCodable([1, 2, 3])
        let data = try JSONHelpers.encode(anyCodable)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [Int]

        #expect(decoded == [1, 2, 3])
    }

    @Test("AnyCodable encodes Dictionary correctly")
    func anyCodableEncodesDictionary() throws {
        let anyCodable = AnyCodable(["key": "value"])
        let data = try JSONHelpers.encode(anyCodable)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        #expect(decoded?["key"] == "value")
    }

    @Test("AnyCodable encodes NSNull correctly")
    func anyCodableEncodesNSNull() throws {
        let anyCodable = AnyCodable(NSNull())
        let data = try JSONHelpers.encode(anyCodable)
        let string = String(data: data, encoding: .utf8)

        #expect(string == "null")
    }

    @Test("AnyCodable handles mixed type arrays")
    func anyCodableHandlesMixedArrays() throws {
        let json = "[1, \"two\", true, null]".data(using: .utf8)!
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: json)

        let array = decoded.value as? [Any]
        #expect(array?.count == 4)
        #expect(array?[0] as? Int == 1)
        #expect(array?[1] as? String == "two")
        #expect(array?[2] as? Bool == true)
        #expect(array?[3] is NSNull)
    }

    @Test("AnyCodable roundtrip preserves values")
    func anyCodableRoundtrip() throws {
        let original = AnyCodable(["name": "test", "count": 42])
        let data = try JSONHelpers.encode(original)
        let decoded = try JSONHelpers.decode(AnyCodable.self, from: data)

        let dict = decoded.value as? [String: Any]
        #expect(dict?["name"] as? String == "test")
        #expect(dict?["count"] as? Int == 42)
    }
}
