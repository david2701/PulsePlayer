import Foundation

package enum ProductionEngineSignal: Sendable, Equatable {
    case interstitialChanged(id: String?)
    case interstitialSkippable(id: String, canSkip: Bool)
    case persistableContentKeyStored(assetID: String)
    case diagnostic(PlaybackDiagnostic)
}
