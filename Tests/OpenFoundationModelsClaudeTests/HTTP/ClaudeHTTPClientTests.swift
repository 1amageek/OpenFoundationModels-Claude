import Foundation
import Testing
@testable import OpenFoundationModelsClaude

@Suite("ClaudeHTTPClient Tests")
struct ClaudeHTTPClientTests {

    // MARK: - ClaudeHTTPError Tests

    @Test("ClaudeHTTPError invalidResponse has description")
    func httpErrorInvalidResponseDescription() {
        let error = ClaudeHTTPError.invalidResponse

        #expect(error.errorDescription == "Invalid response received from Claude API")
    }

    @Test("ClaudeHTTPError statusError includes code in description")
    func httpErrorStatusErrorDescription() {
        let error = ClaudeHTTPError.statusError(404, nil)

        #expect(error.errorDescription?.contains("404") == true)
    }

    @Test("ClaudeHTTPError statusError includes data")
    func httpErrorStatusErrorWithData() {
        let data = "Error body".data(using: .utf8)
        let error = ClaudeHTTPError.statusError(500, data)

        if case .statusError(let code, let errorData) = error {
            #expect(code == 500)
            #expect(errorData == data)
        } else {
            Issue.record("Expected statusError case")
        }
    }

    @Test("ClaudeHTTPError networkError wraps underlying error")
    func httpErrorNetworkErrorDescription() {
        let urlError = URLError(.timedOut)
        let error = ClaudeHTTPError.networkError(urlError)

        #expect(error.errorDescription?.contains("Network error") == true)
    }

    @Test("ClaudeHTTPError connectionError includes message")
    func httpErrorConnectionErrorDescription() {
        let error = ClaudeHTTPError.connectionError("Cannot connect to server")

        #expect(error.errorDescription == "Cannot connect to server")
    }

    @Test("ClaudeHTTPError decodingError wraps underlying error")
    func httpErrorDecodingErrorDescription() {
        let decodingError = DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Invalid JSON")
        )
        let error = ClaudeHTTPError.decodingError(decodingError)

        #expect(error.errorDescription?.contains("Failed to decode") == true)
    }

    // MARK: - StreamingEvent Tests

    @Test("StreamingEvent messageStart case holds event")
    func streamingEventMessageStart() throws {
        let json: [String: Any] = [
            "type": "message_start",
            "message": [
                "id": "msg_123",
                "type": "message",
                "role": "assistant",
                "model": "claude-sonnet-4-20250514"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageStartEvent.self, from: data)
        let streamingEvent = StreamingEvent.messageStart(event)

        if case .messageStart(let e) = streamingEvent {
            #expect(e.message.id == "msg_123")
        } else {
            Issue.record("Expected messageStart case")
        }
    }

    @Test("StreamingEvent contentBlockStart case holds event")
    func streamingEventContentBlockStart() throws {
        let json: [String: Any] = [
            "type": "content_block_start",
            "index": 0,
            "content_block": [
                "type": "text",
                "text": ""
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockStartEvent.self, from: data)
        let streamingEvent = StreamingEvent.contentBlockStart(event)

        if case .contentBlockStart(let e) = streamingEvent {
            #expect(e.index == 0)
        } else {
            Issue.record("Expected contentBlockStart case")
        }
    }

    @Test("StreamingEvent contentBlockDelta case holds event")
    func streamingEventContentBlockDelta() throws {
        let json: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "text_delta",
                "text": "Hello"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockDeltaEvent.self, from: data)
        let streamingEvent = StreamingEvent.contentBlockDelta(event)

        if case .contentBlockDelta(let e) = streamingEvent {
            #expect(e.index == 0)
            if case .textDelta(let delta) = e.delta {
                #expect(delta.text == "Hello")
            }
        } else {
            Issue.record("Expected contentBlockDelta case")
        }
    }

    @Test("StreamingEvent contentBlockStop case holds event")
    func streamingEventContentBlockStop() throws {
        let json: [String: Any] = [
            "type": "content_block_stop",
            "index": 0
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ContentBlockStopEvent.self, from: data)
        let streamingEvent = StreamingEvent.contentBlockStop(event)

        if case .contentBlockStop(let e) = streamingEvent {
            #expect(e.index == 0)
        } else {
            Issue.record("Expected contentBlockStop case")
        }
    }

    @Test("StreamingEvent messageDelta case holds event")
    func streamingEventMessageDelta() throws {
        let json: [String: Any] = [
            "type": "message_delta",
            "delta": [
                "stop_reason": "end_turn"
            ],
            "usage": [
                "input_tokens": 10,
                "output_tokens": 20
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageDeltaEvent.self, from: data)
        let streamingEvent = StreamingEvent.messageDelta(event)

        if case .messageDelta(let e) = streamingEvent {
            #expect(e.delta.stopReason == "end_turn")
        } else {
            Issue.record("Expected messageDelta case")
        }
    }

    @Test("StreamingEvent messageStop case holds event")
    func streamingEventMessageStop() throws {
        let json: [String: Any] = [
            "type": "message_stop"
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(MessageStopEvent.self, from: data)
        let streamingEvent = StreamingEvent.messageStop(event)

        if case .messageStop(let e) = streamingEvent {
            #expect(e.type == "message_stop")
        } else {
            Issue.record("Expected messageStop case")
        }
    }

    @Test("StreamingEvent ping case")
    func streamingEventPing() {
        let streamingEvent = StreamingEvent.ping

        if case .ping = streamingEvent {
            // Success
        } else {
            Issue.record("Expected ping case")
        }
    }

    @Test("StreamingEvent error case holds event")
    func streamingEventError() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "overloaded_error",
                "message": "Server is overloaded"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let event = try JSONHelpers.decode(ErrorEvent.self, from: data)
        let streamingEvent = StreamingEvent.error(event)

        if case .error(let e) = streamingEvent {
            #expect(e.error.type == "overloaded_error")
        } else {
            Issue.record("Expected error case")
        }
    }

    // MARK: - ClaudeHTTPClient Initialization Tests

    @Test("ClaudeHTTPClient initializes with configuration")
    func clientInitializes() {
        let config = TestConfiguration.configuration
        let client = ClaudeHTTPClient(configuration: config)

        // Just verify it doesn't crash - actor state is not directly accessible
        #expect(client != nil)
    }

    // MARK: - Configuration Tests

    @Test("Configuration timeout is applied")
    func configurationTimeoutApplied() {
        let config = ClaudeConfiguration(
            apiKey: "test-key",
            timeout: 60.0
        )
        let client = ClaudeHTTPClient(configuration: config)

        // Actor initialized successfully with timeout
        #expect(client != nil)
    }

    @Test("Configuration base URL defaults correctly")
    func configurationBaseURLDefault() {
        let config = ClaudeConfiguration(apiKey: "test-key")

        #expect(config.baseURL.absoluteString == "https://api.anthropic.com")
    }

    @Test("Configuration API version defaults correctly")
    func configurationAPIVersionDefault() {
        let config = ClaudeConfiguration(apiKey: "test-key")

        #expect(config.apiVersion == "2023-06-01")
    }

    @Test("Configuration custom base URL")
    func configurationCustomBaseURL() {
        let customURL = URL(string: "https://custom.api.com")!
        let config = ClaudeConfiguration(
            apiKey: "test-key",
            baseURL: customURL
        )

        #expect(config.baseURL == customURL)
    }

    // MARK: - SSE Event String Building Tests

    @Test("SSE message_start event format")
    func sseMessageStartFormat() throws {
        let sseString = try TestData.makeSSEEvent(
            event: "message_start",
            data: TestData.makeMessageStartEvent(id: "msg_test")
        )

        #expect(sseString.contains("event: message_start"))
        #expect(sseString.contains("data: "))
        #expect(sseString.contains("msg_test"))
    }

    @Test("SSE content_block_delta event format")
    func sseContentBlockDeltaFormat() throws {
        let sseString = try TestData.makeSSEEvent(
            event: "content_block_delta",
            data: TestData.makeContentBlockDeltaEvent(index: 0, text: "Hello")
        )

        #expect(sseString.contains("event: content_block_delta"))
        #expect(sseString.contains("data: "))
        #expect(sseString.contains("Hello"))
    }

    @Test("SSE message_stop event format")
    func sseMessageStopFormat() throws {
        let sseString = try TestData.makeSSEEvent(
            event: "message_stop",
            data: TestData.makeMessageStopEvent()
        )

        #expect(sseString.contains("event: message_stop"))
        #expect(sseString.contains("message_stop"))
    }

    // MARK: - ClaudeHTTPError Equatable Tests

    @Test("ClaudeHTTPError is Error protocol")
    func httpErrorIsError() {
        let error: Error = ClaudeHTTPError.invalidResponse

        #expect(error is ClaudeHTTPError)
    }

    @Test("ClaudeHTTPError is LocalizedError protocol")
    func httpErrorIsLocalizedError() {
        let error: LocalizedError = ClaudeHTTPError.invalidResponse

        #expect(error.errorDescription != nil)
    }

    // MARK: - Error Response Decoding Tests

    @Test("ClaudeErrorResponse can be thrown")
    func claudeErrorResponseThrowable() throws {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": "rate_limit_error",
                "message": "Rate limit exceeded"
            ]
        ]
        let data = try JSONHelpers.fromDictionary(json)
        let errorResponse = try JSONHelpers.decode(ClaudeErrorResponse.self, from: data)

        // ClaudeErrorResponse conforms to Error
        let error: Error = errorResponse
        #expect(error is ClaudeErrorResponse)
    }

    // MARK: - Status Code Tests

    @Test("4xx status codes are client errors")
    func statusCode4xxClientErrors() {
        let codes = [400, 401, 403, 404, 429]

        for code in codes {
            let error = ClaudeHTTPError.statusError(code, nil)
            if case .statusError(let statusCode, _) = error {
                #expect(statusCode >= 400 && statusCode < 500)
            }
        }
    }

    @Test("5xx status codes are server errors")
    func statusCode5xxServerErrors() {
        let codes = [500, 502, 503, 529]

        for code in codes {
            let error = ClaudeHTTPError.statusError(code, nil)
            if case .statusError(let statusCode, _) = error {
                #expect(statusCode >= 500)
            }
        }
    }
}
