import Foundation

/// Sendable cookie value for public API. Converted at `AssetFactory` boundary.
public struct HTTPCookieValue: Sendable, Equatable, Hashable {
    public var name: String
    public var value: String
    public var domain: String
    public var path: String
    public var isSecure: Bool
    public var expiresDate: Date?

    public init(
        name: String,
        value: String,
        domain: String,
        path: String = "/",
        isSecure: Bool = true,
        expiresDate: Date? = nil
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.isSecure = isSecure
        self.expiresDate = expiresDate
    }
}
