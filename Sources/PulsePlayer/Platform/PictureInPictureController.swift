import AVFoundation
import AVKit
import Foundation

/// Thin wrapper around `AVPictureInPictureController` with session-friendly events.
@MainActor
public final class PictureInPictureController: NSObject {
    public private(set) var isPossible = false
    public private(set) var isActive = false

    public var onEvent: ((PiPEvent) -> Void)?
    public var restoreUserInterface: (@MainActor @Sendable () async -> Bool)?

    private var controller: AVPictureInPictureController?
    private weak var playerLayer: AVPlayerLayer?
    private var possibleObservation: NSKeyValueObservation?

    public override init() {
        super.init()
    }

    public func attach(playerLayer: AVPlayerLayer?) {
        if self.playerLayer === playerLayer,
           (playerLayer == nil || controller != nil)
        {
            updatePossibility()
            return
        }
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
        possibleObservation = pip?.observe(
            \.isPictureInPicturePossible,
            options: [.initial, .new]
        ) { [weak self] controller, _ in
            let possible = controller.isPictureInPicturePossible
            Task { @MainActor in
                self?.isPossible = possible
            }
        }
        updatePossibility()
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
        possibleObservation?.invalidate()
        possibleObservation = nil
        controller?.delegate = nil
        if controller?.isPictureInPictureActive == true {
            controller?.stopPictureInPicture()
        }
        controller = nil
        isPossible = false
        isActive = false
    }

    private func updatePossibility() {
        isPossible = controller?.isPictureInPicturePossible == true
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
        let completion = PiPRestoreCompletion(completionHandler)
        Task { @MainActor in
            self.onEvent?(.restoreUI)
            let restored = await self.restoreUserInterface?() ?? false
            completion.call(restored)
        }
    }
}

/// AVKit's delegate callback predates Sendable annotations. The callback is immutable
/// and invoked exactly once from the main actor.
private final class PiPRestoreCompletion: @unchecked Sendable {
    private let callback: (Bool) -> Void

    init(_ callback: @escaping (Bool) -> Void) {
        self.callback = callback
    }

    func call(_ restored: Bool) {
        callback(restored)
    }
}
