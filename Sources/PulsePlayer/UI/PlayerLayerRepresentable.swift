import AVFoundation
import SwiftUI

#if canImport(UIKit)
import UIKit

struct PlayerLayerRepresentable: UIViewRepresentable {
    let session: PlayerSession
    var videoGravity: PlayerVideoGravity

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = videoGravity.avGravity
        session.attachPlayerLayer(view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.videoGravity = videoGravity.avGravity
        session.attachPlayerLayer(uiView.playerLayer)
    }

    static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: ()) {
        uiView.playerLayer.player = nil
    }
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }
}
#endif
