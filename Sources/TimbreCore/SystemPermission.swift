// SPDX-License-Identifier: MPL-2.0
import Foundation

public enum SystemPermission: Sendable {
    case systemAudio
    case accessibility
    case bluetooth

    public var settingsURL: URL {
        let anchor: String
        switch self {
        case .systemAudio: anchor = "Privacy_AudioCapture"
        case .accessibility: anchor = "Privacy_Accessibility"
        case .bluetooth: anchor = "Privacy_Bluetooth"
        }
        // System Settings maps this legacy bundle identifier to its exact permission list.
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?" + anchor)!
    }
}
