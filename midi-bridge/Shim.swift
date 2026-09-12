import Foundation

/// TapSide normally lives in GestureConfig.swift beside the whole GUI config
/// model. The bridge needs only this much of it.
enum TapSide: String, CaseIterable {
    case left
    case right

    var displayName: String { rawValue.capitalized }
}
