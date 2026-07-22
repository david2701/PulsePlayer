import AVFoundation
import AVKit
import Foundation

/// Thin wrapper around `AVPictureInPictureController` with session-friendly events.
@MainActor
public final class PictureInPictureController: NSObject {
    public private(set) var isPossible = false
    public private(set) var isActive = false

    public var onEvent: ((PiPEvent) -> Void)?

    private var controller: AVPictureInPictureController?
    private weak var playerLayer: AVPlayerLayer?

    public override init() {
        super.init()
    }

    public func attach(playerLayer: AVPlayerLayer?) {
        self.playerLayer = playerLayer
        tearDownController()

        guard let playerLayer,
              AVPictureInPictureController.isPictureInPictureSupported()
        else {
            isPossible = false
            return
        }

        let pip = AVPictureInPictureController(playerLayer: playerLayer)
        pip?.delegate = self
        #if os(iOS)
        if #available(iOS 14.2, *) {
            pip?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        #endif
        controller = pip
        isPossible = pip != nil
    }

    public func start() {
        guard let controller, controller.isPictureInPicturePossible else { return }
        controller.startPictureInPicture()
    }

    public func stop() {
        guard let controller, controller.isPictureInPictureActive else { return }
        controller.stopPictureInPicture()
    }

    public func tearDown() {
        tearDownController()
        playerLayer = nil
        isPossible = false
        isActive = false
    }

    private func tearDownController() {
        controller?.delegate = nil
        if controller?.isPictureInPictureActive == true {
            controller?.stopPictureInPicture()
        }
        controller = nil
    }
}

extension PictureInPictureController: AVPictureInPictureControllerDelegate {
    public nonisolated func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.onEvent?(.willStart)
        }
    }

    public nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.isActive = true
            self.onEvent?(.didStart)
        }
    }

    public nonisolated func pictureInPictureControllerWillStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.onEvent?(.willStop)
        }
    }

    public nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.isActive = false
            self.onEvent?(.didStop)
        }
    }

    public nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // Call completion immediately; UI restore is best-effort via event.
        completionHandler(true)
        Task { @MainActor in
            self.onEvent?(.restoreUI)
        }
    }
}
