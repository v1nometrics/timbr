// SPDX-License-Identifier: MPL-2.0
// Which app does an audio process belong to?
//
// Core Audio reports the process that renders audio, which is often a helper:
//   - Chromium/Electron apps play every tab and web app through one "Helper" audio-service process;
//   - WebKit apps (Safari, Raycast, Mail, any WKWebView app) play through "com.apple.WebKit.GPU",
//     a system XPC service shared by name across all of them;
//   - some apps use XPC audio services inside their bundle.
// Guessing from the bundle-ID string mislabels these (e.g. Raycast's WebKit audio showed as Safari).
// Resolution order, most to least reliable:
//   1. the process the system holds responsible for it (what Activity Monitor and TCC use);
//   2. the outermost .app bundle that contains the executable;
//   3. the parent process chain;
//   4. the bundle ID Core Audio reported.
import Foundation
import AppKit
import Darwin
import TimbreCore

public enum AudioProcessAttribution {
    public struct Owner: Equatable, Sendable {
        public let pid: pid_t
        public let bundleID: String
        public let name: String
    }

    private typealias ResponsibleFn = @convention(c) (pid_t) -> pid_t
    /// `responsibility_get_pid_responsible_for_pid` lives in libSystem but has no public header.
    /// Looked up at runtime; if Apple ever removes it we fall back to the bundle path.
    private static let responsible: ResponsibleFn? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let sym = dlsym(handle, "responsibility_get_pid_responsible_for_pid") else { return nil }
        return unsafeBitCast(sym, to: ResponsibleFn.self)
    }()

    public static func owner(of pid: pid_t, reportedBundleID: String?, runningApps: [pid_t: NSRunningApplication]) -> Owner {
        func appOwner(_ p: pid_t) -> Owner? {
            guard let app = runningApps[p] ?? NSRunningApplication(processIdentifier: p),
                  app.activationPolicy != .prohibited, let bid = app.bundleIdentifier else { return nil }
            return Owner(pid: p, bundleID: bid, name: app.localizedName ?? bid)
        }

        // 0. macOS daemons with no app (system sounds, Siri, calls…) → a friendly group.
        let path = executablePath(pid)
        if let client = SystemAudioClient.classify(reportedBundleID: reportedBundleID, executablePath: path) {
            return Owner(pid: pid, bundleID: client.rawValue, name: client.defaultName)
        }

        // 1. Responsible process.
        if let responsible, case let r = responsible(pid), r > 0, let o = appOwner(r) { return o }

        // 2. Outermost .app bundle containing the executable (Chromium/Electron helpers live inside it).
        if let path, let range = path.range(of: ".app/") {
            let appPath = String(path[..<range.lowerBound]) + ".app"
            if let bundle = Bundle(path: appPath), let bid = bundle.bundleIdentifier {
                if let running = runningApps.values.first(where: { $0.bundleIdentifier == bid }), let o = appOwner(running.processIdentifier) {
                    return o
                }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                if !appPath.hasPrefix("/System/") { return Owner(pid: pid, bundleID: bid, name: name) }
            }
        }

        // 3. Parent chain (a few hops; stops at launchd).
        var p = pid
        for _ in 0..<4 {
            let parent = parentPID(p)
            guard parent > 1 else { break }
            if let o = appOwner(parent) { return o }
            p = parent
        }

        // 4. What Core Audio said.
        if let o = appOwner(pid) { return o }
        if SystemAudioClient.isSystemExecutable(path) {
            let c = SystemAudioClient.otherSystem
            return Owner(pid: pid, bundleID: c.rawValue, name: c.defaultName)
        }
        let bid = reportedBundleID ?? runningApps[pid]?.bundleIdentifier ?? "pid.\(pid)"
        let name = runningApps[pid]?.localizedName ?? bid.components(separatedBy: ".").last ?? bid
        return Owner(pid: pid, bundleID: bid, name: name)
    }

    static func executablePath(_ pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let n = proc_pidpath(pid, &buf, UInt32(buf.count))
        guard n > 0 else { return nil }
        return String(cString: buf)
    }

    static func parentPID(_ pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let n = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        return n == Int32(MemoryLayout<proc_bsdinfo>.size) ? pid_t(info.pbi_ppid) : 0
    }
}
