import Foundation
import AppKit

let screens = NSScreen.screens.enumerated().map { idx, s -> [String: Any] in
    var topLeft: [String: Double] = [:]
    var topRight: [String: Double] = [:]
    var topInset: Double = 0
    if #available(macOS 12.0, *) {
        topInset = Double(s.safeAreaInsets.top)
        if let r = s.auxiliaryTopLeftArea {
            topLeft = ["x": Double(r.minX), "y": Double(r.minY), "w": Double(r.width), "h": Double(r.height)]
        }
        if let r = s.auxiliaryTopRightArea {
            topRight = ["x": Double(r.minX), "y": Double(r.minY), "w": Double(r.width), "h": Double(r.height)]
        }
    }
    let notchW: Double = (!topLeft.isEmpty && !topRight.isEmpty)
        ? (topRight["x"]! - (topLeft["x"]! + topLeft["w"]!))
        : 0
    return [
        "index": idx,
        "localizedName": s.localizedName,
        "frame": ["x": Double(s.frame.minX), "y": Double(s.frame.minY), "w": Double(s.frame.width), "h": Double(s.frame.height)],
        "visibleFrame": ["x": Double(s.visibleFrame.minX), "y": Double(s.visibleFrame.minY), "w": Double(s.visibleFrame.width), "h": Double(s.visibleFrame.height)],
        "backingScaleFactor": Double(s.backingScaleFactor),
        "safeAreaTopInset": topInset,
        "auxiliaryTopLeftArea": topLeft,
        "auxiliaryTopRightArea": topRight,
        "computedNotchWidthPt": notchW,
        "hasPhysicalNotch": topInset > 0 && notchW > 0
    ]
}
let data = try JSONSerialization.data(withJSONObject: screens, options: [.prettyPrinted, .sortedKeys])
print(String(data: data, encoding: .utf8)!)
