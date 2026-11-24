// SPDX-License-Identifier: MPL-2.0

public enum AudioSourceIdentity {
    public static let timbrBundleID = "com.timbr.app"

    /// Match the product and its embedded helpers across launches, copies and updates.
    /// Keep synthetic system sources (`timbr.system.*`) and apps with similar names.
    public static func isTimbr(_ bundleID: String?) -> Bool {
        guard let id = bundleID?.lowercased() else { return false }
        return id == timbrBundleID || id.hasPrefix(timbrBundleID + ".")
    }
}
