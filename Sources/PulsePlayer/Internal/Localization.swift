import Foundation

enum PulsePlayerLocalization {
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    static func format(
        _ key: String.LocalizationValue,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
