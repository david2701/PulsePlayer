import Foundation

@MainActor
extension PlayerSession {
    func handleProductionEngineSignal(_ signal: ProductionEngineSignal) {
        guard status != .invalidated else { return }
        switch signal {
        case .interstitialChanged(let id):
            let previous = activeInterstitialID
            if let previous, previous != id {
                emitProduction(.interstitialEnded(id: previous))
            }
            activeInterstitialID = id
            canSkipInterstitial = false
            if let id, id != previous {
                endLiveCatchUpIfNeeded()
                emitProduction(.interstitialStarted(id: id))
            }

        case .interstitialSkippable(let id, let canSkip):
            guard activeInterstitialID == id, canSkipInterstitial != canSkip else { return }
            canSkipInterstitial = canSkip
            emitProduction(.interstitialSkippable(id: id, canSkip: canSkip))

        case .persistableContentKeyStored(let assetID):
            emitProduction(.persistableContentKeyStored(assetID: assetID))

        case .diagnostic(let diagnostic):
            emitProduction(.diagnostic(diagnostic))
            if case .errorLog(let domain, let code, let comment) = diagnostic,
               code == 401 || code == 403
            {
                fail(with: .itemFailed(
                    domain: "HTTP",
                    code: code,
                    message: comment ?? "\(domain) \(code)",
                    recoverable: true
                ))
            }
        }
    }
}
