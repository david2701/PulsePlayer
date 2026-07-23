import AVFoundation
import SwiftUI

#if canImport(UIKit)
import UIKit

struct PlayerLayerRepresentable: UIViewRepresentable {
    let session: PlayerSession
    var videoGravity: PlayerVideoGravity

    @MainActor
    final class Coordinator {
        weak var session: PlayerSession?
        weak var layer: AVPlayerLayer?

        func bind(session: PlayerSession, layer: AVPlayerLayer) {
            guard self.session !== session || self.layer !== layer else { return }
            if self.layer?.player != nil {
                self.session?.attachPlayerLayer(nil)
            }
            self.layer?.player = nil
            self.session = session
            self.layer = layer
            session.attachPlayerLayer(layer)
        }

        func detach() {
            // A fullscreen or recycled surface may already own the session. Only
            // detach if this coordinator's layer is still the attached layer.
            if layer?.player != nil {
                session?.attachPlayerLayer(nil)
            }
            layer?.player = nil
            session = nil
            layer = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = videoGravity.avGravity
        view.playerLayer.backgroundColor = UIColor.black.cgColor
        context.coordinator.bind(session: session, layer: view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.videoGravity = videoGravity.avGravity
        context.coordinator.bind(session: session, layer: uiView.playerLayer)
        uiView.setNeedsLayout()
    }

    static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: Coordinator) {
        coordinator.detach()
    }
}

/// UIView that always keeps `AVPlayerLayer` bounds = view bounds (fixes black/empty feed cells).
final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
#endif
