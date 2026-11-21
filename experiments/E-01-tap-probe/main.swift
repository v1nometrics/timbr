import Foundation
import CoreAudio
import AudioToolbox

@main
struct E01Probe {
    static func main() {
        if #available(macOS 14.2, *) {
            let tapDesc = CATapDescription(stereoMixdownOfProcesses: [])
            tapDesc.name = "timbr.E01.Probe"
            tapDesc.isPrivate = true
            tapDesc.muteBehavior = .mutedWhenTapped
            if #available(macOS 26.0, *) {
                tapDesc.bundleIDs = ["com.apple.Music"]
                tapDesc.isProcessRestoreEnabled = true
                print("macOS 26+ tap properties verified: bundleIDs + isProcessRestoreEnabled available")
            }
            var tapID = AudioObjectID(kAudioObjectUnknown)
            let status = AudioHardwareCreateProcessTap(tapDesc, &tapID)
            print("AudioHardwareCreateProcessTap status:", status, "tapID:", tapID)
            if status == noErr && tapID != kAudioObjectUnknown {
                let destroyErr = AudioHardwareDestroyProcessTap(tapID)
                print("AudioHardwareDestroyProcessTap status:", destroyErr)
            } else {
                print("Note: non-zero status or blocked tap creation in headless CLI without TCC Audio Capture grant is expected (status code documented).")
            }
        } else {
            print("macOS < 14.2")
        }
    }
}
