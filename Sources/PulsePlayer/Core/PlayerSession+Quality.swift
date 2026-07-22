import CoreGraphics
import Foundation

@MainActor
extension PlayerSession {
    public var selectedQuality: StreamQuality {
        if selectedQualityId == StreamQuality.auto.id { return .auto }
        return availableQualities.first { $0.id == selectedQualityId } ?? .auto
    }

    func refreshQualities(for source: MediaSource) async {
        availableQualities = []
        selectedQualityId = StreamQuality.auto.id
        let path = source.url.path.lowercased()
        let isHLS = path.hasSuffix(".m3u8") || source.url.absoluteString.contains(".m3u8")
        guard isHLS else { return }
        do {
            let qualities = try await HLSMasterParser.fetchQualities(from: source.url)
            availableQualities = qualities
            emit(.qualitiesUpdated(count: qualities.count))
        } catch {
            emit(.warning(URLSanitizer.sanitizeMessage(error.localizedDescription)))
        }
    }

    public func setQuality(_ quality: StreamQuality) {
        selectedQualityId = quality.id
        if quality.id == StreamQuality.auto.id {
            engine.setPreferredPeakBitRate(0)
            engine.setPreferredMaximumResolution(.zero)
        } else {
            engine.setPreferredPeakBitRate(Double(quality.bandwidth))
            if let w = quality.width, let h = quality.height {
                engine.setPreferredMaximumResolution(CGSize(width: w, height: h))
            } else if let h = quality.height {
                engine.setPreferredMaximumResolution(CGSize(width: h * 16 / 9, height: h))
            }
        }
        emit(.qualityChanged(id: quality.id))
    }

    public func setQualityAuto() {
        setQuality(.auto)
    }
}
