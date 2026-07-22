import AVFoundation
import SwiftUI

#if canImport(UIKit)
import UIKit

struct PlayerLayerRepresentable: UIViewRepresentable {
    let session: PlayerSession
    var videoGravity: PlayerVideoGravity

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = videoGravity.avGravity
        view.playerLayer.backgroundColor = UIColor.black.cgColor
        session.attachPlayerLayer(view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.videoGravity = videoGravity.avGravity
        // Re-bind when SwiftUI recycles views or pool swaps sessions.
        session.attachPlayerLayer(uiView.playerLayer)
        uiView.setNeedsLayout()
    }

    static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: ()) {
        uiView.playerLayer.player = nil
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
