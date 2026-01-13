import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("ClaudeError Tests")
struct ClaudeErrorTests {

    // MARK: - Decoding Tests

    @Test("ClaudeErrorResponse decodes correctly")
    func claudeErrorResponseDecodes() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "invalid_request_error",
                "message": "Invalid API key provided"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let errorResponse = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

        #expect(errorResponse.type == "error")
        #expect(errorResponse.error.type == "invalid_request_error")
        #expect(errorResponse.error.message == "Invalid API key provided")
    }

    @Test("ClaudeErrorResponse decodes various error types")
    func claudeErrorResponseDecodesVariousTypes() throws {
        let errorTypes = [
            ("invalid_request_error", "The request was invalid"),
            ("authentication_error", "Invalid API key"),
            ("permission_error", "Access denied"),
            ("not_found_error", "Resource not found"),
            ("rate_limit_error", "Rate limit exceeded"),
            ("api_error", "Internal server error"),
            ("overloaded_error", "Server is overloaded")
        ]

        for (errorType, message) in errorTypes {
            let json: [String: Any] = [
                "type": "error",
                "error": [
                    "type": errorType,
                    "message": message
                ]
            ]
            let data = try JSONHelpers.fromDictionary(json)
            let errorResponse = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

            #expect(errorResponse.error.type == errorType)
            #expect(errorResponse.error.message == message)
        }
    }

    // MARK: - Error Description Tests

    @Test("errorDescription formats type and message")
    func errorDescriptionFormats() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "rate_limit_error",
                "message": "Too many requests"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let errorResponse = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

        let description = errorResponse.errorDescription
        #expect(description == "rate_limit_error: Too many requests")
    }

    @Test("errorDescription handles empty message")
    func errorDescriptionHandlesEmptyMessage() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "api_error",
                "message": ""
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let errorResponse = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

        let description = errorResponse.errorDescription
        #expect(description == "api_error: ")
    }

    @Test("errorDescription handles unicode message")
    func errorDescriptionHandlesUnicode() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "invalid_request_error",
                "message": "エラーが発生しました 🚫"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let errorResponse = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

        let description = errorResponse.errorDescription
        #expect(description == "invalid_request_error: エラーが発生しました 🚫")
    }

    // MARK: - Protocol Conformance Tests

    @Test("ClaudeErrorResponse conforms to Error")
    func claudeErrorResponseConformsToError() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "api_error",
                "message": "Internal error"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let errorResponse = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

        // Verify it can be used as an Error
        let error: Error = errorResponse
        #expect(error.localizedDescription.contains("api_error"))
    }

    @Test("ClaudeErrorResponse conforms to LocalizedError")
    func claudeErrorResponseConformsToLocalizedError() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "authentication_error",
                "message": "Invalid credentials"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let errorResponse = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

        // Verify LocalizedError properties
        let localizedError: LocalizedError = errorResponse
        #expect(localizedError.errorDescription == "authentication_error: Invalid credentials")
    }

    // MARK: - ErrorDetail Tests

    @Test("ErrorDetail decodes correctly")
    func errorDetailDecodes() throws {
        let json: [String: Any] = [
            "type": "test_error",
            "message": "Test message"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let errorDetail = try JSONHelpers.decode(ClaudeErrorResponse.ErrorDetail.self, from: data)

        #expect(errorDetail.type == "test_error")
        #expect(errorDetail.message == "Test message")
    }

    @Test("ErrorDetail encodes correctly")
    func errorDetailEncodes() throws {
        let errorDetail = ClaudeErrorResponse.ErrorDetail(type: "test", message: "msg")
        let data = try JSONHelpers.encode(errorDetail)
        let dict = try JSONHelpers.toDictionary(data)

        #expect(dict["type"] as? String == "test")
        #expect(dict["message"] as? String == "msg")
    }

    // MARK: - Roundtrip Tests

    @Test("ClaudeErrorResponse roundtrip preserves data")
    func claudeErrorResponseRoundtrip() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "permission_error",
                "message": "Access denied to resource"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let original = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

        let encoded = try JSONHelpers.encode(original)
        let decoded = try JSONHelpers.decode(ClaudeErrorResponse.self, from: encoded)

        #expect(decoded.type == original.type)
        #expect(decoded.error.type == original.error.type)
        #expect(decoded.error.message == original.error.message)
    }
}
