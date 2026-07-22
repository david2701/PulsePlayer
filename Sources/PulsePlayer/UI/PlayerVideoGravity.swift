import AVFoundation

public enum PlayerVideoGravity: Sendable, Equatable {
    case resizeAspect
    case resizeAspectFill
    case resize

    var avGravity: AVLayerVideoGravity {
        switch self {
        case .resizeAspect: return .resizeAspect
        case .resizeAspectFill: return .resizeAspectFill
        case .resize: return .resize
        }
    }
}
