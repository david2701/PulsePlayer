#if canImport(UIKit)
import AVFoundation
import UIKit

/// UIKit surface: hosts `AVPlayerLayer` attached to a `PlayerSession`.
@MainActor
open class PulsePlayerViewController: UIViewController {
    public let session: PlayerSession
    public var videoGravity: PlayerVideoGravity = .resizeAspect {
        didSet { playerLayer.videoGravity = videoGravity.avGravity }
    }

    private let playerLayer = AVPlayerLayer()

    public init(session: PlayerSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Use init(session:)")
    public required init?(coder: NSCoder) {
        return nil
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        playerLayer.videoGravity = videoGravity.avGravity
        view.layer.addSublayer(playerLayer)
        session.attachPlayerLayer(playerLayer)
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer.frame = view.bounds
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.attachPlayerLayer(playerLayer)
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            // Keep session alive; only detach layer.
            if playerLayer.player != nil {
                session.attachPlayerLayer(nil)
            }
            playerLayer.player = nil
        }
    }
}
#endif
