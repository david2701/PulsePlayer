import AVFoundation
import CoreGraphics
import Foundation

/// Generates still frames for scrub preview (progressive + many HLS assets).
@MainActor
public final class ThumbnailGenerator {
    private var generator: AVAssetImageGenerator?
    private var generation: UInt64 = 0

    public init() {}

    public func prepare(asset: AVAsset) {
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 320, height: 180)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator = gen
        generation &+= 1
    }

    public func clear() {
        generator?.cancelAllCGImageGeneration()
        generator = nil
        generation &+= 1
    }

    public func cancelPending() {
        generator?.cancelAllCGImageGeneration()
        generation &+= 1
    }

    public func image(at time: TimeInterval) async -> CGImage? {
        guard let generator else { return nil }
        generator.cancelAllCGImageGeneration()
        generation &+= 1
        let genId = generation
        let cm = CMTime(seconds: max(0, time), preferredTimescale: 600)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { cont in
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: cm)]) {
                    _, image, _, result, _ in
                    Task { @MainActor in
                        guard genId == self.generation else {
                            cont.resume(returning: nil)
                            return
                        }
                        if result == .succeeded {
                            cont.resume(returning: image)
                        } else {
                            cont.resume(returning: nil)
                        }
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, genId == self.generation else { return }
                self.cancelPending()
            }
        }
    }
}
