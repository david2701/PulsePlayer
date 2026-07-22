import AVKit
import SwiftUI

#if canImport(UIKit)
import UIKit

/// System AirPlay route picker button.
public struct AirPlayRoutePicker: UIViewRepresentable {
    public var activeTint: UIColor = .white
    public var tint: UIColor = .white

    public init(activeTint: UIColor = .white, tint: UIColor = .white) {
        self.activeTint = activeTint
        self.tint = tint
    }

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = activeTint
        view.tintColor = tint
        view.prioritizesVideoDevices = true
        return view
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.activeTintColor = activeTint
        uiView.tintColor = tint
    }
}
#endif
