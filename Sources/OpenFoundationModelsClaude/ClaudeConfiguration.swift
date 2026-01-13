import Foundation
import Configuration

/// Configuration for Claude API
public struct ClaudeConfiguration: Sendable {
    /// API key for authentication
    public let apiKey: String

    /// Base URL for Claude API (default: https://api.anthropic.com)
    public let baseURL: URL

    /// Request timeout in seconds
    public let timeout: TimeInterval

    /// API version (default: 2023-06-01)
    public let apiVersion: String

    /// Initialize Claude configuration
    /// - Parameters:
    ///   - apiKey: API key for authentication
    ///   - baseURL: Base URL for Claude API
    ///   - timeout: Request timeout in seconds
    ///   - apiVersion: API version header value
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        timeout: TimeInterval = 120.0,
        apiVersion: String = "2023-06-01"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = timeout
        self.apiVersion = apiVersion
    }
}

// MARK: - Convenience Initializers
extension ClaudeConfiguration {
    /// Initialize with API key from environment variables using swift-configuration
    ///
    /// Reads the following environment variables:
    /// - `ANTHROPIC_API_KEY`: API key for authentication (required)
    /// - `ANTHROPIC_BASE_URL`: Base URL for Claude API (optional, default: https://api.anthropic.com)
    /// - `ANTHROPIC_TIMEOUT`: Request timeout in seconds (optional, default: 120.0)
    /// - `ANTHROPIC_API_VERSION`: API version (optional, default: 2023-06-01)
    ///
    /// The API key is marked as a secret and will be redacted in debug output.
    ///
    /// - Returns: Configuration if API key is found, nil otherwise
    public static func fromEnvironment() -> ClaudeConfiguration? {
        let config = ConfigReader(provider: EnvironmentVariablesProvider(
            secretsSpecifier: .specific(["ANTHROPIC_API_KEY"])
        ))

        // API key is required
        guard let apiKey = config.string(forKey: "anthropic.api-key") else {
            return nil
        }

        // Optional: base URL
        let baseURL: URL
        if let urlString = config.string(forKey: "anthropic.base-url"),
           let url = URL(string: urlString) {
            baseURL = url
        } else {
            baseURL = URL(string: "https://api.anthropic.com")!
        }

        // Optional: timeout
        let timeout = config.double(forKey: "anthropic.timeout") ?? 120.0

        // Optional: API version
        let apiVersion = config.string(forKey: "anthropic.api-version") ?? "2023-06-01"

        return ClaudeConfiguration(
            apiKey: apiKey,
            baseURL: baseURL,
            timeout: timeout,
            apiVersion: apiVersion
        )
    }
}
