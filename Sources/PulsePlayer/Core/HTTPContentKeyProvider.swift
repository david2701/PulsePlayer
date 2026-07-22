import Foundation

/// Production-style FairPlay provider: loads the app certificate and exchanges SPC→CKC over HTTP.
///
/// This is **not a mock**. It performs real network calls. You still need:
/// 1. FairPlay certificate from Apple (FPS Deployment Package / Streaming Server SDK)
/// 2. A key server that returns CKC bytes (your KSM or multi-DRM vendor)
/// 3. Encrypted HLS with `#EXT-X-KEY:KEYFORMAT="com.apple.streamingkeydelivery"`
///
/// There is **no free public FairPlay test stream** without Apple’s FPS SDK materials.
@MainActor
public final class HTTPContentKeyProvider: ContentKeyProviding {
    public struct Configuration: Sendable {
        /// URL that returns the FairPlay application certificate (raw `.cer` / `.der` bytes).
        public var certificateURL: URL
        /// License URL that accepts SPC and returns CKC.
        public var licenseURL: URL
        /// Optional headers (auth bearer, API keys — never log these).
        public var headers: [String: String]
        /// How to send SPC to the license server.
        public var licenseBody: LicenseBodyFormat
        /// HTTP method for license (usually POST).
        public var licenseMethod: String

        public init(
            certificateURL: URL,
            licenseURL: URL,
            headers: [String: String] = [:],
            licenseBody: LicenseBodyFormat = .rawSPC,
            licenseMethod: String = "POST"
        ) {
            self.certificateURL = certificateURL
            self.licenseURL = licenseURL
            self.headers = headers
            self.licenseBody = licenseBody
            self.licenseMethod = licenseMethod
        }
    }

    public enum LicenseBodyFormat: Sendable {
        /// POST body = raw SPC bytes (`application/octet-stream`).
        case rawSPC
        /// JSON: `{"spc":"<base64>","assetId":"..."}`.
        case jsonBase64SPC
    }

    private let configuration: Configuration
    private let session: URLSession
    private var cachedCertificate: Data?

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func certificateData() async throws -> Data {
        if let cachedCertificate { return cachedCertificate }
        var request = URLRequest(url: configuration.certificateURL)
        applyHeaders(to: &request)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, context: "certificate")
        guard !data.isEmpty else {
            throw PlayerError.unknown("Empty FairPlay certificate response", recoverable: false)
        }
        cachedCertificate = data
        return data
    }

    public func contentKey(spcData: Data, assetId: String) async throws -> Data {
        var request = URLRequest(url: configuration.licenseURL)
        request.httpMethod = configuration.licenseMethod
        applyHeaders(to: &request)

        switch configuration.licenseBody {
        case .rawSPC:
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.httpBody = spcData
        case .jsonBase64SPC:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: String] = [
                "spc": spcData.base64EncodedString(),
                "assetId": assetId,
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }

        let (data, response) = try await session.data(for: request)
        try validate(response: response, context: "license")
        // Some servers wrap CKC in JSON {"ckc":"base64..."}.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let b64 = obj["ckc"] as? String ?? obj["Ckc"] as? String,
           let decoded = Data(base64Encoded: b64)
        {
            return decoded
        }
        guard !data.isEmpty else {
            throw PlayerError.unknown("Empty FairPlay CKC response", recoverable: true)
        }
        return data
    }

    private func applyHeaders(to request: inout URLRequest) {
        for (k, v) in configuration.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
    }

    private func validate(response: URLResponse, context: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw PlayerError.assetLoadFailed(
                underlying: "FairPlay \(context) HTTP \(http.statusCode)",
                recoverable: http.statusCode >= 500 || http.statusCode == 408
            )
        }
    }
}
