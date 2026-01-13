import Foundation

/// Type-erased JSON value for handling dynamic JSON structures
struct JSONValue: Codable, Sendable {
    private let data: Data

    init(_ dictionary: [String: Any]) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary) {
            self.data = jsonData
        } else {
            self.data = Data()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let dict = try? container.decode([String: AnyCodable].self) {
            let convertedDict = dict.mapValues { $0.value }
            if let jsonData = try? JSONSerialization.data(withJSONObject: convertedDict) {
                self.data = jsonData
            } else {
                self.data = Data()
            }
        } else {
            self.data = Data()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let json = try? JSONSerialization.jsonObject(with: data),
           let dict = json as? [String: Any] {
            let codableDict = dict.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        } else {
            try container.encode([String: AnyCodable]())
        }
    }

    var dictionary: [String: Any] {
        if data.isEmpty { return [:] }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        } catch {}
        return [:]
    }
}

/// Helper type for encoding/decoding Any values
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode(String(describing: value))
        }
    }
}
