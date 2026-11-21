# Capturing, routing and controlling audio per app and per browser tab on macOS (as of Nov 2026: macOS 26 Tahoe / macOS 27 Golden Gate)

Scope note: these notes cover the foundation layer, meaning how a third-party app gets every app's audio into its own processing pipeline and back out to one or more real devices. EQ/DSP quality, device-configuration UI, lyrics and music recognition are out of scope. Repo metrics (stars, license, last push) were pulled from the GitHub API on 2026-11-21. Anything dated before 2026 is labelled as such.

---

## 1. Core Audio Process Taps (macOS 14.2+): what they can and cannot do

### Takeaway
Process taps are Apple's sanctioned, driver-free way to intercept other apps' output. With `muteBehavior = .mutedWhenTapped`, a private aggregate device and an IOProc, a tap can silence an app's original output and replace it with processed audio. That covers both per-app volume and per-app EQ, and it is the mechanism every 2025-2026 open-source per-app mixer uses (FineTune, Atoll, PerAppVolume, MixBar and others). The costs:
- about one extra I/O buffer of latency (roughly 10-13 ms reported)
- a TCC "system audio recording" grant with a non-hideable purple indicator
- a stereo-mixdown/Float32 path that is not bit-perfect
- a growing list of real-world bugs on macOS 26.x: zero-buffer stalls, a start-of-playback "blast" before the tap engages, multichannel attenuation, conflicts between taps, and double audio in screen sharing

### Cited Findings

**API surface (primary: Apple docs)**
- `AudioHardwareCreateProcessTap(_:_:)` creates a tap from a `CATapDescription` and returns an `AudioObjectID`. Apple lists its availability as **macOS 14.2+**. — [Apple: AudioHardwareCreateProcessTap](https://developer.apple.com/documentation/coreaudio/audiohardwarecreateprocesstap(_:_:))
- Apple's sample "Capturing system audio with Core Audio taps" says a tap is used "as an input in a HAL aggregate device, just like a microphone." Taps can be "public (visible to all users), or private (only visible inside the process that created the tap)," and "Taps can also mute the process output so that the process will no longer play to the speaker or selected audio device, and all process output will go to the tap." — [Apple sample article](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- The sample configures `name`, `processes`, `isPrivate`, `muteBehavior`, `isMixdown`, `isMono`, `isExclusive`, `deviceUID` and `stream`, then adds the tap's UID to an aggregate device through `kAudioAggregateDevicePropertyTapList`. It requires macOS 14.2 or later and `NSAudioCaptureUsageDescription` in Info.plist. "The first time you start recording from an aggregate device that contains a tap, the system prompts you to grant the app system audio recording permission." — [Apple sample article](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- Developers have flagged a likely error in Apple's tap-list sample code: the sample reads the tap list with `tapID` instead of the aggregate device ID. — [Apple Dev Forums: "Potential Documentation Error in kAudioAggregateDevicePropertyTapList Sample Code"](https://developer.apple.com/forums/thread/798941). The inconsistency is visible in the sample itself, which calls `AudioObjectGetPropertyDataSize(self.id, …)` and then `AudioObjectGetPropertyData(tapID, …)`.
- `CATapDescription` initializers:
  - `init(stereoMixdownOfProcesses:)`
  - `init(monoMixdownOfProcesses:)`
  - `init(stereoGlobalTapButExcludeProcesses:)`
  - `init(monoGlobalTapButExcludeProcesses:)`
  - `init(processes:deviceUID:stream:)`, which taps processes only on a specific device/stream
  - `init(excludingProcesses:deviceUID:stream:)`
  
  Properties: `bundleIDs`, `deviceUID`, `isExclusive`, `isMixdown`, `isMono`, `isPrivate`, `isProcessRestoreEnabled`, `muteBehavior`, `name`, `processes`, `stream`, `uuid`. — [Apple: CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
- `CATapMuteBehavior` has three cases:
  - **unmuted** (the default): "Audio is captured by the tap and also sent to the audio hardware"
  - **muted**: "Audio is captured by the tap but no audio is sent from the process to the audio hardware"
  - **mutedWhenTapped**: "Audio is captured by the tap and also sent to the audio hardware until the tap is read by another audio client. For the duration of the read activity on the tap no audio is sent to the audio hardware."
  
  — [Apple: CATapMuteBehavior](https://developer.apple.com/documentation/coreaudio/catapmutebehavior)
- **New in macOS 26.0:**
  - `CATapDescription.bundleIDs`: "An Array of Strings where each String holds the bundle ID of a process to tap or exclude." — [Apple: bundleIDs](https://developer.apple.com/documentation/coreaudio/catapdescription/bundleids)
  - `isProcessRestoreEnabled`: "True if this tap should save tapped processes by bundle ID when they exit, and restore them to the tap when they start up again." — [Apple: isProcessRestoreEnabled](https://developer.apple.com/documentation/coreaudio/catapdescription/isprocessrestoreenabled)
- **macOS 27 SDK:** a third-party SDK-diff summary lists only three new Core Audio symbols (a "suggested reference device" property, `kAudioDevicePropertySuggestedReferenceDevice`, plus its scope/element), with no tap changes and no deprecations. — [miniswift "What's new in CoreAudio — iOS & macOS 27 SDK"](https://miniswift.run/whats-new/coreaudio/). **Unverified:** the page refused connection when fetched, so this comes from the search snippet only.
- Apple's metadata gives odd availability values for the class (`CATapDescription` shows macOS 12.0, `CATapMuteBehavior` shows macOS 13.0), but the function that creates taps is 14.2+. — [Apple: CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription); [Apple: CATapMuteBehavior](https://developer.apple.com/documentation/coreaudio/catapmutebehavior)
- **Version conflict:** AudioCap (2024) says "With macOS 14.4, Apple introduced new API in CoreAudio…" — [insidegui/AudioCap](https://github.com/insidegui/AudioCap). Apple's docs say 14.2. A 2026 write-up recommends a 14.4+ deployment target because earlier versions "land in different TCC categories and the prompt copy diverges." — [DGR Labs, Apr 2026](https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html)

**Recipe for per-app volume/EQ (convergent across independent implementations)**
- FavTray (2026) uses the following pattern. Lookup goes through `kAudioHardwarePropertyProcessObjectList` and `kAudioProcessPropertyIsRunningOutput`. — [FavTray blog](https://favtray.com/blog/per-app-volume-mac-without-driver)
  - `CATapDescription(stereoMixdownOfProcesses:)` with `.mutedWhenTapped`
  - a private aggregate device whose main sub-device is the current output, plus `kAudioAggregateDeviceTapAutoStartKey` and `kAudioAggregateDeviceIsPrivateKey`
  - an IOProc that reads tapped frames, applies gain and writes to the output
  - no allocation or locks on the real-time thread
  - a 10 ms gain ramp
  - teardown when the slider returns to 100%
- FavTray on `mutedWhenTapped`: "the speakers get the audio until someone reads the tap, then nothing for as long as the read lasts". If the mixer crashes, the app's sound returns. — [FavTray blog](https://favtray.com/blog/per-app-volume-mac-without-driver)
- Atoll's merged per-app volume PR (a notch app, Sep 2026): "`muteBehavior = .mutedWhenTapped` is what makes this work at all — without it you would hear the app twice." It uses one tap plus a "private stacked aggregate device" per (bundle id, output device) pair, and creates a tap only when volume ≠ 1.0 or the app is muted. Gain is ramped with `vDSP_vrampmul`. Helper-process bundle IDs "need mapping back to the parent app." — [Ebullioscopic/Atoll PR #805](https://github.com/Ebullioscopic/Atoll/pull/805)
- PerAppVolume (Nov 2026) takes the alternative topology. — [GabrielSabadinn/PerAppVolume](https://github.com/GabrielSabadinn/PerAppVolume)
  - "One tap per app, one aggregate device for all": each app group gets a `CATapDescription` covering all its processes with `mutedWhenTapped`.
  - "All taps join a single private aggregate device whose clock is the real output device, with drift compensation enabled."
  - Adding or removing an app updates the tap list live, and a full rebuild happens only on output-device change.
  - Apps are tapped "the moment it starts emitting sound, at gain 1.0", so slider moves never change latency mid-playback.
- per-app-audio (Sep 2026): `kAudioSubTapDriftCompensationKey` on the tap "adapts the tap's rate into [the device timebase] upstream of the IOProc — so a tap/device sample-rate mismatch is handled by the HAL." — [mavericksxx/per-app-audio](https://github.com/mavericksxx/per-app-audio)
- A tap cannot feed an IOProc directly. It must be wrapped in an aggregate device, together with the real output device. — [Recall.ai blog](https://www.recall.ai/blog/core-audio-taps)
- Tap callbacks fire only while some process is rendering, so there are none at idle. — [Apple Dev Forums thread 848578 (Sep 2026, macOS 27)](https://developer.apple.com/forums/thread/848578)

**Format / channels**
- FavTray's tap is "a stereo mixdown," so multichannel output folds to two channels. Apps playing to a non-default device stay at 100% in its design. — [FavTray blog](https://favtray.com/blog/per-app-volume-mac-without-driver)
- The tap stream format is read with `kAudioTapPropertyFormat` (an AudioStreamBasicDescription). — [insidegui/AudioCap](https://github.com/insidegui/AudioCap)
- **Multichannel attenuation (Nov 2025 report, no Apple reply):** on an RME Fireface with 8 outs (4 stereo pairs), tapped audio arrives at **−12.04 dB** (= 20·log10(4)), versus ~0 dB on 2-channel devices. The attenuation depends on whether the source app targets the Default Output or the device directly. — [Apple Dev Forums thread 806799](https://developer.apple.com/forums/thread/806799)
- FineTune hit the same class of bug: an 8-channel Topping E2x2 OTG and a Scarlett 18i8 got quieter while FineTune ran (macOS 26.3). v1.4.0 fixed it by correcting "the process-tap channel mapping for multichannel devices and adds a stereo fallback." — [FineTune issue #105](https://github.com/ronitsingh10/FineTune/issues/105)

**Latency**
- FineTune's maintainer reports about **10-13 ms** added to tapped apps: "one I/O buffer hop (~10-11ms at 48kHz/512 samples). This is inherent to the API… FineTune's own processing… adds zero additional latency." A user's browser reaction-time test claiming ~100 ms was disputed as methodologically noisy. — [FineTune issue #98](https://github.com/ronitsingh10/FineTune/issues/98)
- **Bluetooth (Dec 2024 thread):** tapped audio arrived 300-400 ms late when the system output was AirPods. An Apple engineer replied: "Are you including the Bluetooth device in the same aggregate device as your tap? If so, it would be expected for the tap's latency to increase." — [Apple Dev Forums thread 770218](https://developer.apple.com/forums/thread/770218)
- DGR Labs observed IOProc callbacks every 100 ms (4,800 frames at 48 kHz) in a capture-only setup. That is callback cadence, not an end-to-end latency figure. — [DGR Labs](https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html)

**Permission (TCC) and UX**
- Info.plist needs `NSAudioCaptureUsageDescription`, and Xcode's dropdown does not list it. "There's no public API to request audio recording permission or to check if the app has that permission." AudioCap uses private TCC SPI behind a build flag. — [insidegui/AudioCap](https://github.com/insidegui/AudioCap)
- The grant appears under System Settings › Privacy & Security as "System Audio Recording Only," separate from Screen Recording and from the microphone. Without the grant, FavTray creates no tap, because "a tap that can't be read would just silence the app." — [FavTray blog](https://favtray.com/blog/per-app-volume-mac-without-driver)
- Apple's help: Privacy & Security › "Screen & System Audio Recording"… "You can allow apps to record both your screen and audio, or just your audio." — [Apple Support: Control access to screen and system audio recording](https://support.apple.com/guide/mac-help/control-access-to-screen-and-system-audio-recording-mchld6aa7d23/mac)
- FineTune's onboarding asks users to grant "Screen & System Audio Recording". — [FineTune README](https://github.com/ronitsingh10/FineTune)
- A purple dot in the menu bar shows while system audio is captured, and "it is not possible" to hide it, because Apple controls it. — [Rogue Amoeba KB: ARK capture details](https://rogueamoeba.com/support/knowledgebase/?showArticle=Misc-ARK-Plugin-Audio-Capture-Details&product=SoundSource)
- Denial is silent: TCC "denies system audio capture silently and hands back zero-filled buffers." — [mavericksxx/per-app-audio](https://github.com/mavericksxx/per-app-audio)
- Taps "require a stable signing identity", and unsigned builds don't get the prompt. Reset for testing with `tccutil reset SystemAudioCaptureRequests <bundle-id>`. — [DGR Labs](https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html)
- **Sandbox, conflicting reports:**
  - A Sep 2026 forum post (macOS 27) says the tap path "works inside the App Sandbox with com.apple.security.device.audio-input; no microphone usage string is required for a tap." — [Apple Dev Forums 848578](https://developer.apple.com/forums/thread/848578)
  - DGR Labs disabled the sandbox because "CATap behavior under sandbox is fragile." — [DGR Labs](https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html)

**Known bugs and gotchas (mostly macOS 26.x)**
- **Zero-buffer stalls (macOS 26.5 beta, May 2026):** after several minutes "every PCM sample is exactly 0.0f — while the system is producing audible output". The IOProc keeps firing. Only a full teardown (stop → destroy IOProc → destroy aggregate → destroy tap → recreate) recovers reliably. No Apple reply. — [Apple Dev Forums 825780](https://developer.apple.com/forums/thread/825780)
- per-app-audio ships a "zero-buffer watchdog" that rebuilds a stalled route, capped at one rebuild per 30 s and three strikes, and lists this as a macOS 26 tap bug. — [mavericksxx/per-app-audio](https://github.com/mavericksxx/per-app-audio)
- MiniMeters reports a "Core Audio Tap bug introduced in macOS Tahoe 26.1". Its workarounds "have not been total fixes." — [MiniMeters help: macOS Tahoe issues](https://minimeters.app/help/macos-tahoe-issues/); [MiniMeters v1.0.25 devlog](https://directmusic.itch.io/minimeters/devlog/1419853/minimeters-v1025-macos-tahoe-fix-bug-fixes)
- On macOS 26, passing a nil dispatch queue to the IOProc block API "silently fails to register the block". — [DGR Labs](https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html)
- **Two taps from different processes on the same device interfere:** "AudioDeviceStart blocks until the other tap is torn down" (macOS 27.0). — [Apple Dev Forums 848578](https://developer.apple.com/forums/thread/848578)
- **Start-of-playback leak / "blast":** the first 200-500 ms of audio play unprocessed before the tap engages. One root cause was the device starting before saved gain/EQ were applied. Another was that "the HAL can hand back one stale buffer when audio resumes after long silence"; the fix added a 40 ms fade. Users still report it on FineTune 1.9.0 (macOS 26.6.2, Firefox). Short-lived helpers such as QuickLookUIService make it worse. — [FineTune #170](https://github.com/ronitsingh10/FineTune/issues/170); [FineTune #268](https://github.com/ronitsingh10/FineTune/issues/268)
- **Double audio or echo:** OBS, Discord/FaceTime/Meet screen share and CleanShot capture desktop audio twice while FineTune runs. Still open. — [FineTune #118](https://github.com/ronitsingh10/FineTune/issues/118); [FineTune #292](https://github.com/ronitsingh10/FineTune/issues/292)
- **Apps that don't tolerate taps:** "audio processors, DAWs, VoIP tools… Audio Hijack, Loopback, and other Rogue Amoeba apps… FaceTime, WhatsApp… (tapping can break echo cancellation, causing volume ducking)". FineTune's mitigation is a per-app "ignore" that tears down the tap. — [FineTune troubleshooting](https://github.com/ronitsingh10/FineTune/blob/main/guide/troubleshooting.md)
- **Device-switch desync:** after a new headphone or Bluetooth device becomes the default, apps keep playing to the old device until manual re-selection or a coreaudiod restart (macOS 26.4.1-26.5.1). — [FineTune #255](https://github.com/ronitsingh10/FineTune/issues/255)
- **Helper processes:** "Some apps use helper processes to play audio rather than the main app process, so the slider you see might be controlling the wrong process." — [FineTune troubleshooting](https://github.com/ronitsingh10/FineTune/blob/main/guide/troubleshooting.md)

### Inferences
- `mutedWhenTapped` combined with re-rendering in an IOProc is the confirmed, documented way to "mute the original and replace it." The design choice is (a) one aggregate per (app, device), as in Atoll, which is simple and allows per-app output routing, or (b) one aggregate per device holding N taps, as in PerAppVolume, which means one IOProc, one clock and cheaper mixing. For a pipeline that also needs a global parametric EQ, (b) is the natural shape: per-app gain and EQ, then sum, then device EQ, then out.
- The start-of-playback leak is structural when taps are created lazily on `IsRunningOutput`. For an audiophile EQ product, a leak of the un-EQ'd signal is very audible. Options:
  - tap eagerly at gain 1.0, as PerAppVolume does
  - use the macOS 26 `bundleIDs` + `isProcessRestoreEnabled` so the tap pre-exists the process
  - for "system EQ" only, use one global tap (`stereoGlobalTapButExcludeProcesses:` excluding our own process) with `mutedWhenTapped`
  
  The last two are inferences from the API docs and need prototyping.
- The tap path is a stereo (or mono) Float mixdown. Native multichannel and bit-exact paths are not preserved by default. See section 7.
- Taps conflicting with taps (forum 848578, Rogue Amoeba apps in FineTune's ignore list) mean the app must expect coexistence problems with SoundSource, Loopback, Audio Hijack, OBS and screen recorders.

### Gaps
- No Apple engineer statement found on the zero-buffer stall, the multichannel attenuation rule, or tap-versus-tap blocking. All three are unanswered forum threads.
- No Apple-published latency figure for taps. The 10-13 ms comes from a single developer.
- I could not confirm Apple-documented changes to taps in macOS 15 specifically, or any WWDC25/WWDC26 session dedicated to taps. Only macOS 26's `bundleIDs`/`isProcessRestoreEnabled` are confirmed from Apple docs.
- The macOS 27 SDK diff (miniswift) is unverified because the page failed to load.
- No primary source confirms whether macOS 15+ periodic "continue to allow" re-authorization prompts apply to audio-only grants.

---

## 2. Virtual audio drivers (AudioServerPlugIn / HAL plug-ins): BackgroundMusic, eqMac, BlackHole, Loopback-style

### Takeaway
A user-space AudioServerPlugIn (`.driver` in `/Library/Audio/Plug-Ins/HAL`, loaded by root `coreaudiod`) is still Apple's recommended model for virtual devices. AudioDriverKit is for physical hardware only. The pattern works the same way across these apps:
- install a virtual device and make it the system default
- the driver sees each client and can apply per-client volume
- a companion app reads the device's mix and "plays through" to the real device

It works on every macOS, including before 14.2, and can expose arbitrary channel counts and sample rates. It needs an admin installer that restarts coreaudiod, cannot ship through the Mac App Store, changes the user's default device (fragile), and shows the microphone indicator. The leading open-source drivers (BackgroundMusic, eqMac) are moving to taps or adding them.

### Cited Findings
- **Apple's guidance:** an Apple engineer replied (Mar 2025): "When creating a virtual device, best practice is to use an Audio Server Driver Plug-in instead… AudioDriverKit only supports physical audio devices." The engineer also suggested Core Audio taps for system-audio loopback. — [Apple Dev Forums 775341](https://developer.apple.com/forums/thread/775341)
- **Installation costs (developer's description, 2025):** "HAL plugins require an installer, and the installer has to kill coreaudiod in a post-install script. You have to turn off SIP to debug them." — [Apple Dev Forums 775341](https://developer.apple.com/forums/thread/775341)
- **Mixer limits of taps:** the same developer notes that a tap can mix but has no volume control, and that cascading aggregate devices fails because the first-level aggregate is "off-line" to the second. — [Apple Dev Forums 775341](https://developer.apple.com/forums/thread/775341)
- Apple's sample installs the `.driver` bundle into `/Library/Audio/Plug-Ins/HAL` and reboots. HAL plug-ins are loaded by `coreaudiod`, which runs as root. (Archival/2021 sources, still structurally valid.) — [theevilbit: Beyond the good ol' LaunchAgents – Audio Plugins](https://theevilbit.github.io/beyond/beyond_0013); [Apple: Creating an Audio Server Driver Plug-in](https://developer.apple.com/tutorials/data/documentation/coreaudio/creating-an-audio-server-driver-plug-in.md)
- An AudioServerPlugIn developer reported in Jun 2026 that `Plugin_StartIO` was never called from an AUHAL input client, even though the device received `WriteMix` data. No reply. — [Apple Dev Forums 835816](https://developer.apple.com/forums/thread/835816)
- **BackgroundMusic (GPL-2.0, ~19.4k stars, v0.5.0 released 2026-06-10, "still in alpha"):**
  - features: per-app volume, auto-pause of the music player, system-audio recording
  - `build_and_install.sh` "restarts the system audio process (coreaudiod) at the end of the installation"
  - per-app volume lives in the driver (BGMDriver `DeviceClients/BGM_Clients`, `BGM_ClientMap`) plus `BGMAppVolumes` in the app
  
  — [kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic)
- **BackgroundMusic v0.5.0 notes:**
  - "Improved per-app volume support for Safari, Google Chrome, Microsoft Edge, Brave, Arc Browser, NAVER Whale and Discord"
  - "Background Music now stops processing audio when nothing is playing, so macOS won't show the microphone indicator. It still shows while audio is playing."
  - "Fix a theoretical crash (use-after-free) in audio playthrough"
  
  — [BackgroundMusic v0.5.0 release](https://github.com/kyleneideck/BackgroundMusic/releases/tag/v0.5.0)
- **eqMac (Apache-2.0 on GitHub, ~6.8k stars):**
  - Its driver is a "System Audio loopback/passthrough device based on Apple's Null Audio Server Driver Plug-in… grabs the system audio stream and sends it to the app through a secure memory tunnel… runs in User space instead of Kernel like the previous drivers (i.e SoundFlower)." Credits Pancake for Swift HAL plug-in work. — [bitgapp/eqMac README](https://github.com/bitgapp/eqMac)
  - v1.9.1 (2026-09-13): "Completely removed Helper which caused issues on macOS 27", "Experimental AirPlay support (macOS 14.2+ only)".
  - v1.9.2 (2026-09-19): "Allowing to select which Capture method to use per device (macOS 14.2+ only)", which means taps sit alongside the driver.
  
  — [eqMac releases](https://github.com/bitgapp/eqMac/releases)
  - The default branch shows no code commits since Feb 2023; the latest commits are README and issue-template edits from Nov 2025. The open-source tree therefore does not appear to reflect the 1.9.x binaries. — [eqMac commits (GitHub API)](https://github.com/bitgapp/eqMac/commits)
- **BlackHole (~20.1k stars, last push 2026-11-07):**
  - "The BlackHole source code is licensed under the GNU General Public License v3.0", and "A license is required for all non-GPLv3 projects" (dual license). Official binaries are copyright Existential Audio.
  - Features: "Zero additional driver latency", 8 kHz to 768 kHz sample rates, customizable channel counts (2/16/64ch).
  - Manual uninstall requires `sudo killall -9 coreaudiod`.
  
  — [ExistentialAudio/BlackHole](https://github.com/ExistentialAudio/BlackHole)
- BlackHole's developers chose 32-bit float because Core Audio natively uses 32-bit at the system level, which they say is lossless for up to 24-bit integer. — [ExistentialAudio/BlackHole](https://github.com/ExistentialAudio/BlackHole) (via search summary)
- **libASPL (MIT, 91 stars, last push 2025-08-17):** a C++17 "thin shim between Audio Server and your code" for AudioServerPlug-In drivers, with typed getters/setters, default property implementations and tracing. The README has sections on thread/realtime safety and sandboxing. — [gavv/libASPL](https://github.com/gavv/libASPL)
- **Pancake (Apache-2.0, 63 stars, last push 2019-08-27):** a Swift AudioServerPlugIn framework. Stale. — [0bmxa/Pancake](https://github.com/0bmxa/Pancake)
- **Atoll's characterization:** BackgroundMusic is "a whole extra audio app, and in BackgroundMusic's case a kernel-level virtual device". This is imprecise, since BGMDriver is a user-space HAL plug-in. — [Atoll PR #805](https://github.com/Ebullioscopic/Atoll/pull/805)

### Inferences
- **Clock drift in the driver approach:** the virtual device and the real device run on independent clocks, so the companion app's playthrough must resample or drift-correct. BGM's "playthrough" code is the reference to study. This is inference from the architecture; I found no 2026 write-up quantifying BGM/eqMac drift handling.
- **Mac App Store:** a HAL plug-in must be installed into root-owned `/Library/Audio/Plug-Ins/HAL` with an admin installer. That is incompatible with Mac App Store distribution, so Developer ID plus notarized pkg is the only route. Inference from the install requirements; I found no Apple statement explicitly banning it.
- **Microphone indicator:** the driver approach triggers the microphone indicator because the companion app reads the virtual device's input (confirmed for BGM). The tap approach triggers the purple system-audio indicator instead.
- The driver approach remains necessary for things taps cannot do. These include presenting a named virtual output that other apps can select explicitly (Loopback-style), multichannel virtual buses, and pre-14.2 support.

### Gaps
- No primary source found on how BGM or eqMac measure or correct drift between their virtual device and the real output.
- No Apple statement found on whether an AudioServerPlugIn can be distributed inside a Mac App Store app (believed not possible).
- eqMac's tap-based capture code does not appear to be published, so I could not verify its implementation.

---

## 3. Rogue Amoeba (commercial benchmark): ACE → ARK; SoundSource 6, Audio Hijack, Loopback

### Takeaway
Rogue Amoeba retired ACE, its legacy injection/extension-based "Audio Capture Engine" that needed Startup Security Policy changes on Apple Silicon. On macOS 14.5+ it uses **ARK (Audio Routing Kit)**, built with Apple after Apple said in summer 2023 that "changes coming later to MacOS 14" would let them move past ACE. Rogue Amoeba never names the API publicly. However, coreaudiod logs captured with SoundSource 6.0.6 on macOS 26.5 show ARK operating through Core Audio's tap machinery (`HALS_MultiTap … register_meta_device`, `AddMuter: Process … muted by com.rogueamoeba.ARK`), alongside an admin-installed "ARK plugin" for SoundSource and Loopback. In practice the benchmark is a **hybrid of process taps (with muting) and a HAL plug-in**.

### Cited Findings
- ACE "enabled capture of audio from applications on the Mac". It was used by older Airfoil, Audio Hijack, Loopback, Piezo and SoundSource, and licensed to third parties. Installing it on Apple Silicon involved changing Mac security settings. "As of MacOS 15 (Sequoia), ACE is fully deprecated." ARK is used in place of ACE on macOS 14+ and "provides the same audio capture and routing capabilities as ACE, without requiring the complex installation process." (Historical, but current KB.) — [Rogue Amoeba KB: ACE Legacy](https://rogueamoeba.com/support/knowledgebase/?showArticle=ACE-Legacy&product=SoundSource)
- **Blog, Dec 2024:**
  - Apple told Rogue Amoeba in summer 2023 that "changes coming later to MacOS 14 would, at long last, allow us to move past ACE"; the ACE exception "was needed all the way through MacOS 14."
  - Airfoil, Audio Hijack and Piezo need no installer: users "Approve the necessary System Audio Access permission on first launch."
  - Loopback and SoundSource use "a new ARK plugin, which installs with just your Administrator password," because they do more complex routing.
  - The transition involved "reporting bugs to Apple, and waiting for MacOS updates to fix them."
  - ARK is licensable as ARK-SDK.
  
  — [Rogue Amoeba blog: The Developers Who Came In From the Cold (2024-12-13)](https://weblog.rogueamoeba.com/2024/12/13/the-developers-who-came-in-from-the-cold/)
- **ARK rollout (2024):** ARK debuted in Loopback 2.4.0 (June 2024), which requires macOS 14.5+, then reached Audio Hijack 4.4 and SoundSource (Sep 2024). — [Loopback release notes](https://rogueamoeba.com/loopback/releasenotes.php) (via search summary)
- Current KB: on macOS 14.5+ SoundSource "uses new technology to capture audio". ARK "must be installed to use SoundSource"; users must enable "both System Audio Access permission and Microphone Access permission for ARK". The purple capture indicator can't be hidden. — [Rogue Amoeba KB: SoundSource audio handling on macOS 14+](https://rogueamoeba.com/support/knowledgebase/?showArticle=Misc-ARK-Plugin-Audio-Capture-Details&product=SoundSource)
- ARK-SDK is offered for licensing and "underpins several of our most popular products, including Audio Hijack and Loopback." — [Rogue Amoeba Licensing](https://www.rogueamoeba.com/licensing/)
- **Evidence of a tap-based implementation (Apr 2026, macOS 26.5, SoundSource 6.0.6, "Rogue Amoeba ARK driver installed"):** coreaudiod logs show `HALS_MultiTap.cpp:222 register_meta_device`, `HALS_Client.cpp:1573 AddMuter: Process codex_chronicle (...) muted by com.rogueamoeba.ARK...` and `unregister_meta_device`. Churn from a screen recorder drove coreaudiod to 100-130% CPU. — [openai/codex issue #19126](https://github.com/openai/codex/issues/19126)
- **SoundSource release history (from the official notes):** — [SoundSource release notes](https://rogueamoeba.com/support/releasenotes/?product=SoundSource)
  - 5.8.0 (Mar 2025, ARK 12.2): "hog" mode warning, coreaudiod hang mitigation, fixes for an OS sleep bug on macOS 15.2+
  - 5.8.6 (Sep 2025): initial macOS 26 support, with capture failing when sample rates differ
  - 5.8.7: sample-rate auto-adjust setting
  - 5.8.8: FaceTime/WhatsApp/Phone call audio "could be lost" on Tahoe; alternate capture added
  - 5.8.9: DriverKit USB devices on Tahoe
  - 5.8.10 (Nov 2025): full Tahoe support
  - **6.0.0 (Dec 3, 2025, ARK 13):** Output Groups (send audio to several devices at once), Quick Configs, AirPlay ("route a single app to AirPlay while everything else stays local"), per-app volume shortcuts, per-app Headphone EQ
  - 6.0.6: works around "a bug in MacOS" degrading AirPods/Beats head-tracking audio
  - 6.1.0 (Jul 2026, ARK 13.5): Game Mode handling; removed drift correction for Bluetooth
  - **6.1.2 (Aug 26, 2026): macOS 27 Golden Gate support**
  - 6.1.6 (Oct 2026): installer hardening
  - **6.2.0 (Nov 11, 2026, ARK 13.6):** Wine/CrossOver sources; CPU and memory reduction
- SoundSource 6.2 (Nov 2026): ARK 13.6 "substantially improved its efficiency", including Game Mode and AirPods head tracking behavior. — [TidBITS Talk: SoundSource 6.2](https://talk.tidbits.com/t/soundsource-6-2/34685)
- SoundSource 6.1.6 (Oct 2026) lists ARK installer hardening; secondary coverage describes it as closing a potential privilege-escalation bug. — [SoundSource release notes](https://rogueamoeba.com/support/releasenotes/?product=SoundSource); [TidBITS watchlist (via search summary)](https://tidbits.com/watchlist/soundsource-6-1-6/)
- ARK 12.2.2 worked around a macOS crash that could occur when installing or updating the plug-in. — [TidBITS (via search summary)](https://tidbits.com/?p=70069)

### Inferences
- The two permissions ARK asks for (System Audio Access, i.e. the tap TCC, plus Microphone Access), the admin-installed plug-in, and the `HALS_MultiTap`/`AddMuter` logs together indicate the following. SoundSource uses Apple process taps with muting to intercept each app, and an ARK HAL plug-in for routing and virtual devices: Loopback's virtual devices, possibly SoundSource's output plumbing and "meta devices". The Microphone permission is plausibly needed to read from the plug-in's virtual input devices. Rogue Amoeba does not confirm any of this.
- Even the best-resourced vendor has shipped a long series of point releases to work around macOS bugs in this area: sleep, sample-rate mismatch, call apps, AirPods, Bluetooth drift, coreaudiod hangs. An open-source project should budget for the same.
- SoundSource's feature set is the target to match: per-app volume, per-app output device, per-app effects/AU plus Headphone EQ, Output Groups for multiple outputs, and system-wide effects.

### Gaps
- Rogue Amoeba has published no technical description of ARK, and nothing official confirms that it uses `AudioHardwareCreateProcessTap`. The log evidence is from a third-party bug report.
- I didn't find how SoundSource handles per-browser-tab audio (no evidence that it does), or its measured added latency.
- The SoundSource release-note fetch was truncated before 5.7.x. The ARK version for 5.9.0 is inconsistent in the notes (13.0.3 vs 13.1.3).

---

## 4. Per-browser-tab audio control: OS level vs browser extension

### Takeaway
Per-tab control is **not achievable with OS-level taps alone** in Chromium browsers or Safari, because tabs do not output audio from separate processes:
- Chromium routes all renderer audio through one sandboxed "Audio Service" utility process.
- Safari plays media through the shared `com.apple.WebKit.GPU` process.

Per-tab volume therefore requires a **browser extension** that talks to the native app over native messaging or a localhost socket. Every existing Mac product that offers it pairs an app with an extension: Earmix, and PerAppVolume (whose license is noncommercial).

### Cited Findings
- **Chromium:** "the audio service runs in a separate process on Windows, Mac (sandboxed) and Linux (unsandboxed)". The service "can be accessed from trusted processes only (the browser process and certain utility processes)". Renderers use `media::AudioOutputDevice`, which goes through IPC. — [Chromium services/audio README](https://chromium.googlesource.com/chromium/src/+/798e59c5275d4131797e8ea2e96e6c6000256b58/services/audio/README.md); [content/browser/audio/audio_service.cc](https://chromium.googlesource.com/chromium/src/+/main/content/browser/audio/audio_service.cc) (launched as "Audio Service" with sandbox type kAudio; the README revision is older)
- **Safari/WebKit:** media and audio run in the GPU process. Killing `com.apple.WebKit.GPU` removes Safari from Now Playing. WebKit bugs track audio playback and capture inside the GPUProcess on macOS. — [Apple Community thread](https://discussions-jp-prz.apple.com/thread/256074226); [WebKit bug 223060 "[MacOS] Reenable Audio Capture in GPUProcess by default"](https://bugs.webkit.org/show_bug.cgi?id=223060)
- Browser audio "may come from renderer, helper, or GPU processes", and "the process responsible for meeting audio varies depending on the browser and meeting platform." — [Recall.ai](https://www.recall.ai/blog/core-audio-taps)
- **Tap-based mixers group tabs:** tapmix creates one tap per app rather than per process, "since a browser's tabs share one slider." — [Sakuleta/tapmix](https://github.com/Sakuleta/tapmix) (via search summary). PerAppVolume says "Chrome, Slack and WebKit content processes collapse into one row." — [PerAppVolume](https://github.com/GabrielSabadinn/PerAppVolume)
- **PerAppVolume (Nov 2026):** "At the browser level a Safari web extension takes control of the media elements inside each tab." The extension talks to the app over a token-authenticated "WebSocket on 127.0.0.1" and uses "element.volume interception". It requires macOS 26+. **License: PolyForm Noncommercial** (not OSI open source). — [GabrielSabadinn/PerAppVolume](https://github.com/GabrielSabadinn/PerAppVolume)
- **Earmix:** a commercial macOS per-app mixer with a Firefox extension that talks to the app through "Firefox's native messaging", only on the Mac. Tabs that play sound show up under Firefox in the Mac mixer. Boost above 100% and tab recording are Chrome-only "because Firefox doesn't offer tab capture." — [Earmix Tabs (Firefox Add-ons)](https://addons.mozilla.org/firefox/addon/earmix-tabs/)
- **Chrome `tabCapture`:**
  - gives a MediaStream of the tab's audio, and once captured "audio in that tab will no longer be played to the user". To keep it audible you route it through an AudioContext to the destination, which is the hook for gain or EQ.
  - "can only be called after the user invokes an extension, such as by clicking the extension's action button"
  - since Chrome 116 a stream ID from the service worker can be used in an offscreen document (MV3)
  - stream IDs are single-use and expire in seconds
  
  — [Chrome Developers: chrome.tabCapture](https://developer.chrome.com/docs/extensions/reference/api/tabCapture)
- Standalone per-tab extensions exist, for example Per-Tab Volume Control (Firefox), which offers up to 500%, a compressor and mono/balance. — [Per-Tab Volume Control](https://addons.mozilla.org/en-US/firefox/addon/per-tab-volume-control-xpi/)
- Several Chrome extensions use only the `tabCapture` + `storage` permissions for per-tab volume. — [Chrome Web Store: Tab Volume Control](https://chromewebstore.google.com/detail/agaenaadackldmmgbfpcibdjmjcfncab) (via search summary)
- BackgroundMusic v0.5.0 needed specific fixes for per-app volume on Safari, Chrome, Edge, Brave, Arc, Whale and Discord, which shows how hard it is to map browser helper processes to apps. — [BGM v0.5.0](https://github.com/kyleneideck/BackgroundMusic/releases/tag/v0.5.0)

### Inferences
- **Architecture for the notch app:** OS-level taps give per-browser (per-app) control and system EQ. Per-tab control needs one extension per browser engine: a Safari Web Extension shipped inside the app bundle, a Chromium MV3 extension covering Chrome/Arc/Brave/Edge, and a Firefox WebExtension. Each talks to the app over native messaging or a localhost socket.
- **Content-script `element.volume`** is simple and needs no capture permission, but it can only attenuate (≤100%), misses Web Audio API graphs, and needs per-frame injection. **tabCapture + Web Audio** can boost or EQ a tab, but it is Chromium-only, needs a user gesture per capture, and replaces the browser's own output path.
- Per-tab routing to a different output device from an extension would require `setSinkId` inside the page or offscreen doc (Chromium). This is not verified in this research.

### Gaps
- I found no primary source for Firefox's macOS audio process model (whether audio output comes from content processes or a single process). Firefox per-tab control via OS taps is unconfirmed either way.
- No source confirms that Arc specifically keeps the stock Chromium Audio Service (presumed, since Arc is Chromium-based).
- No open-source (OSI-licensed) app + extension per-tab project for macOS was found. PerAppVolume is source-available under a noncommercial license.

---

## 5. Simultaneous multiple outputs: Multi-Output Device, aggregate devices, drift correction, app A → headphones and app B → speakers

### Takeaway
macOS provides aggregate and Multi-Output devices with a clock-source device and per-subdevice drift correction (resampling). Tap-based mixers achieve "app A to headphones, app B to speakers" with separate tap + private-aggregate pairs per destination device, each clocked by its real device. "Same app to several devices at once" uses either multiple aggregates or one aggregate containing several sub-devices with drift correction. Bluetooth in an aggregate raises latency, and drift correction on Bluetooth caused enough trouble that SoundSource removed it in 2026. FineTune and SoundSource 6 (Output Groups) both ship multi-device output today.

### Cited Findings
- **Apple guidance:** for hardware-synced devices, choose the hardware clock master as Clock Source and leave Drift Correction unchecked. Otherwise, "choose the device with the most reliable clock from the Clock Source pop-up menu. Then select the Drift Correction checkbox for each device" that isn't hardware-synchronized. Sub-device sample rates should match the clock source. — [Apple Support: Set aggregate device settings in Audio MIDI Setup](https://support.apple.com/guide/audio-midi-setup/ams094c7edb4/mac)
- Users report Multi-Output devices with wireless speakers that won't stay in sync, with intermittent drift (archival community thread). — [Apple Community 255114926](https://discussions.apple.com/thread/255114926)
- Atoll creates one tap + aggregate per (bundle id, output device) pair, which makes per-app device routing natural. — [Atoll PR #805](https://github.com/Ebullioscopic/Atoll/pull/805)
- PerAppVolume uses a single aggregate "whose clock is the real output device, with drift compensation enabled", rebuilt with a short fade on output change. — [PerAppVolume](https://github.com/GabrielSabadinn/PerAppVolume)
- per-app-audio: two routes to one device are two aggregates whose outputs Core Audio mixes, so their sum can exceed one route's limiter ceiling. Tap/device rate mismatch is handled by `kAudioSubTapDriftCompensationKey`. — [per-app-audio](https://github.com/mavericksxx/per-app-audio)
- FineTune: "Multi-device output — Route audio to multiple devices simultaneously". It can "Send apps to different outputs or follow system default", and has device priority with auto-fallback and auto-restore. — [FineTune README](https://github.com/ronitsingh10/FineTune)
- SoundSource 6.0 introduced Output Groups to send audio to several devices at once. 6.1.0 removed drift correction for Bluetooth. 6.1.2 re-establishes Output Groups and AirPlay devices after a coreaudiod restart. — [SoundSource release notes](https://rogueamoeba.com/support/releasenotes/?product=SoundSource)
- Including a Bluetooth device in the tap's aggregate is "expected" to increase the tap's latency (Apple engineer). Users saw 300-400 ms. — [Apple Dev Forums 770218](https://developer.apple.com/forums/thread/770218)

### Inferences
- **Recommended topology (inference):** one "device engine" per active physical output, each a private aggregate with that device as main sub-device and clock, holding the taps of the apps routed to it. Each engine is its own IOProc running per-app gain and EQ, then a device EQ, then output. An app sent to two devices gets a tap in each engine, which is acceptable because `mutedWhenTapped` mutes the source once.
- Keeping Bluetooth devices out of shared aggregates, one aggregate per BT device with no drift correction, matches both Apple's comment and Rogue Amoeba's 2026 change.
- Per-device engines also isolate clock domains. Drift correction (resampling) is then only needed where a tap's rate differs from the device's rate, which matters for the bit-perfect goal (section 7).

### Gaps
- No primary measurement of drift-correction quality (SRC artefacts) in Apple's aggregate devices.
- How FineTune implements multi-device output internally (multiple aggregates vs one multi-subdevice aggregate) was not verified from its source.

---

## 6. Open-source reference repos (license, stars, last activity, quality)

### Takeaway
For process taps, the most mature open-source reference by far is **FineTune** (GPL-3.0, ~10.2k stars, per-app volume, multi-device routing, EQ, AutoEQ, 400+ issues). **Atoll** (GPL-3.0, ~5.3k stars) is the precedent for a notch app with tap-based per-app volume. **AudioCap** (BSD-2-Clause) is the canonical minimal sample. For drivers, the references are BackgroundMusic (GPL-2.0), BlackHole (GPL-3.0 plus commercial) and libASPL (MIT). A flood of MIT-licensed tap mixers appeared in Aug-Nov 2026; they are permissive but very young, and many have 0-10 stars.

### Cited Findings (metrics from the GitHub API on 2026-11-21; "pushed" = last push)

**Process-tap based (no driver)**

| Repo | License | Stars | Created → last push | Notes |
|---|---|---|---|---|
| [ronitsingh10/FineTune](https://github.com/ronitsingh10/FineTune) | GPL-3.0 | 10,229 | 2026-01-18 → 2026-07-09 (issues active through v1.9.0) | per-app volume and boost, multi-device output, per-app routing, 10-band EQ, AutoEQ ParametricEQ import, loudness compensation; macOS 15+; Homebrew cask. Most real-world bug data. |
| [Ebullioscopic/Atoll](https://github.com/Ebullioscopic/Atoll) | GPL-3.0 | 5,322 | 2024-11-01 → 2026-11-21 | Notch "Dynamic Island" app; per-app volume merged 2026-09-06 ([PR #805](https://github.com/Ebullioscopic/Atoll/pull/805)); off by default |
| [insidegui/AudioCap](https://github.com/insidegui/AudioCap) | BSD-2-Clause | 513 | → 2025-08-07 | Canonical minimal tap + aggregate recording sample; uses private TCC SPI (optional flag) |
| [lishuangqiang/mixbar](https://github.com/lishuangqiang/mixbar) | MIT | 314 | 2026-11-15 → 2026-11-15 | "Per-app volume mixer… Built on Core Audio Process Tap" |
| [ljmng7/MacMix](https://github.com/ljmng7/MacMix) | GPL-3.0 | 150 | 2026-06-29 → 2026-11-10 | per-app volume, EQ, multi-device output |
| [pantafive/fader](https://github.com/pantafive/fader) | MIT | 91 | → 2026-11-19 | per-app volume, output switching |
| [makeusabrew/audiotee](https://github.com/makeusabrew/audiotee) | none detected | 94 | → 2026-03-31 | CLI system-audio capture via taps |
| [niyamvora/ILoveNotch](https://github.com/niyamvora/ILoveNotch) | MIT | 42 | 2026-09-24 → 2026-11-20 | Notch app incl. per-app volume |
| [lucianodiisouza/voulum](https://github.com/lucianodiisouza/voulum) | MIT | 38 | 2026-07-27 → 2026-11-11 | per-app volume, output routing, EQ, meters |
| [niharnm/Semper](https://github.com/niharnm/Semper) | Apache-2.0 | 7 | 2026-07-31 → 2026-11-05 | per-app mixer, router, EQ |
| [valenxi0/Nano](https://github.com/valenxi0/Nano) | MIT | 7 | 2026-09-09 → 2026-11-16 | Notch app incl. per-app volume |
| [mavericksxx/per-app-audio](https://github.com/mavericksxx/per-app-audio) | MIT | 0 | 2026-08-27 → 2026-09-18 | Excellent README on drift keys, zero-buffer watchdog and limiter design |
| [GabrielSabadinn/PerAppVolume](https://github.com/GabrielSabadinn/PerAppVolume) | PolyForm Noncommercial (not OSI) | 0 | 2026-11-02 | Per-tab via Safari extension + WebSocket; single-aggregate design; macOS 26+ |
| [csutora/knob](https://github.com/csutora/knob) | MIT | 4 | 2026-04-02 → 2026-04-04 | parametric EQ + per-app volume |
| [jkjoplin/AudioRouter](https://github.com/jkjoplin/AudioRouter) | none | 4 | 2026-07-22 → 2026-11-10 | per-app routing to any device |
| [Sakuleta/tapmix](https://github.com/Sakuleta/tapmix), [dracuthang2000/Volume-mixer](https://github.com/dracuthang2000/Volume-mixer), [quentinved/MixBar](https://github.com/quentinved/MixBar), [Artech011/AudioMixer](https://github.com/Artech011/AudioMixer) | MIT | 0-3 | Sep-Nov 2026 | Small MIT tap mixers (AudioMixer adds per-app output and 10-band EQ) |

- A GitHub code search for `AudioHardwareCreateProcessTap` returns ~40 repos, mostly meeting recorders and transcribers. Mixers include SDTong/resound, Horuse/Splitwave and andreypudov/core-eq. — GitHub code search (`gh search code "AudioHardwareCreateProcessTap"`, 2026-11-21)

**Driver / AudioServerPlugIn based**

| Repo | License | Stars | Last push | Notes |
|---|---|---|---|---|
| [kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic) | GPL-2.0 | 19,401 | 2026-06-10 (v0.5.0) | Per-client volume in driver; playthrough; "alpha" |
| [ExistentialAudio/BlackHole](https://github.com/ExistentialAudio/BlackHole) | GPL-3.0 + commercial license for non-GPL use | 20,088 | 2026-11-07 | Loopback driver, up to 768 kHz, 2/16/64 ch |
| [bitgapp/eqMac](https://github.com/bitgapp/eqMac) | Apache-2.0 (repo) | 6,836 | releases to 2026-09-19; no code commits since 2023 | Driver plus (since 1.9.2) per-device choice of tap capture |
| [gavv/libASPL](https://github.com/gavv/libASPL) | MIT | 91 | 2025-08-17 | Best C++ AudioServerPlugIn scaffold |
| [0bmxa/Pancake](https://github.com/0bmxa/Pancake) | Apache-2.0 | 63 | 2019-08-27 | Swift HAL framework, stale |

**Utility**
- [rnine/SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio): MIT, 455 stars, **archived** (last push 2024-02-25). Swift Core Audio device wrapper; no tap support.

### Inferences
- GPL-3.0 references (FineTune, Atoll, MacMix) can be studied freely. Copying their code forces the notch app to be GPL-3.0, which is acceptable for an open-source project and worth deciding early. BSD/MIT/Apache sources (AudioCap, libASPL, per-app-audio, mixbar, voulum) can be reused under any license.
- Most 2026 MIT repos are weeks old, which suggests rapid and likely AI-assisted creation, and have little real-world testing. FineTune's issue tracker is the richest source of field bugs to design against.

### Gaps
- Code quality of the small repos was not audited, beyond reading READMEs and PR descriptions.
- FineTune's `pushed_at` (2026-07-09) conflicts with issue discussions referencing v1.9.0 and later fixes. Release cadence after July 2026 was not verified.

---

## 7. Recommendation-grade facts: future-proofing, distribution, permissions, latency, bit-perfect

### Takeaway
Apple's direction points clearly to **process taps** as the sanctioned interception path:
- Apple engineers point developers to taps for loopback.
- Rogue Amoeba was moved off ACE with Apple's help onto a tap-based ARK.
- macOS 26 extended taps with bundle-ID targeting and process restore.
- eqMac and BackgroundMusic are adding or reacting to tap paths.

A tap-only design needs no driver, can be signed with Developer ID and notarized, and possibly works sandboxed. It costs about one buffer of latency, a system-audio-recording grant with a purple dot, stereo Float mixdown (not bit-perfect), and active bug management on macOS 26/27. A HAL plug-in remains useful only for named virtual devices, multichannel buses or pre-14.2 support, and it rules out the Mac App Store.

### Cited Findings
- Apple engineer (2025): use an AudioServerPlugIn for virtual devices ("AudioDriverKit only supports physical audio devices"), and suggested Core Audio taps for system-audio loopback. — [Apple Dev Forums 775341](https://developer.apple.com/forums/thread/775341)
- Rogue Amoeba's move off ACE was enabled by Apple's macOS 14 changes. They now use "System Audio Access" permission on first launch (capture apps) plus an admin-installed ARK plugin (routing apps). — [Rogue Amoeba blog 2024-12](https://weblog.rogueamoeba.com/2024/12/13/the-developers-who-came-in-from-the-cold/)
- macOS 26 added `CATapDescription.bundleIDs` and `isProcessRestoreEnabled`. — [Apple: bundleIDs](https://developer.apple.com/documentation/coreaudio/catapdescription/bundleids); [Apple: isProcessRestoreEnabled](https://developer.apple.com/documentation/coreaudio/catapdescription/isprocessrestoreenabled)
- eqMac 1.9.2 (Sep 2026) added per-device selection of capture method on macOS 14.2+. — [eqMac releases](https://github.com/bitgapp/eqMac/releases)
- **Distribution:**
  - A tap path "works inside the App Sandbox with com.apple.security.device.audio-input" (macOS 27 report). — [Apple Dev Forums 848578](https://developer.apple.com/forums/thread/848578)
  - DGR Labs: "Hardened Runtime stays on for notarization"; sandbox disabled as "fragile". — [DGR Labs](https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html)
  - HAL plug-ins need an installer that kills coreaudiod. — [Apple Dev Forums 775341](https://developer.apple.com/forums/thread/775341)
- **Permissions UX:** `NSAudioCaptureUsageDescription`; prompt on first start; no public API to check or request — [AudioCap](https://github.com/insidegui/AudioCap). The "System Audio Recording Only" list — [FavTray](https://favtray.com/blog/per-app-volume-mac-without-driver). The purple indicator is non-hideable — [Rogue Amoeba KB](https://rogueamoeba.com/support/knowledgebase/?showArticle=Misc-ARK-Plugin-Audio-Capture-Details&product=SoundSource). Silent denial yields zero buffers — [per-app-audio](https://github.com/mavericksxx/per-app-audio).
- **Latency:** taps add about 10-13 ms (one buffer at 48 kHz/512) — [FineTune #98](https://github.com/ronitsingh10/FineTune/issues/98). BlackHole advertises "zero additional driver latency" for the loopback itself, though a playthrough app still adds its own buffering — [BlackHole](https://github.com/ExistentialAudio/BlackHole).
- **Bit-perfect and exclusive access:**
  - Hog mode "allows a process to prevent other processes on the system from using a given device." — [Apple: toggleHogMode()](https://developer.apple.com/documentation/coreaudio/audiohardwaredevice/togglehogmode())
  - SoundSource 5.8.0 added a "hog" mode warning, meaning hog-mode players conflict with system-wide processing. — [SoundSource release notes](https://rogueamoeba.com/support/releasenotes/?product=SoundSource)
  - The tap stream is a mono or stereo mixdown in the tap's format. — [FavTray](https://favtray.com/blog/per-app-volume-mac-without-driver); [Apple: CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
  - Multichannel devices showed level attenuation through taps. — [Forum 806799](https://developer.apple.com/forums/thread/806799); [FineTune #105](https://github.com/ronitsingh10/FineTune/issues/105)
  - Tap-based mixers deliberately leave apps at 100% untapped to avoid any processing. — [Atoll PR #805](https://github.com/Ebullioscopic/Atoll/pull/805); [FavTray](https://favtray.com/blog/per-app-volume-mac-without-driver)
  - per-app-audio's limiter is "bit-exact and completely inert on anything that does not approach the ceiling". — [per-app-audio](https://github.com/mavericksxx/per-app-audio)
- **Coexistence:** FineTune recommends ignoring Rogue Amoeba apps, DAWs and VoIP apps because of tap conflicts. — [FineTune troubleshooting](https://github.com/ronitsingh10/FineTune/blob/main/guide/troubleshooting.md). Concurrent taps from different processes block `AudioDeviceStart`. — [Forum 848578](https://developer.apple.com/forums/thread/848578)

### Inferences (recommendation-grade, to be validated by prototype)
- **Primary architecture:** process taps (`mutedWhenTapped`, private aggregates clocked by each real device, one IOProc engine per device) for both per-app volume and system EQ. Target macOS 14.4+ (or 15+, as FineTune does). Use macOS 26 `bundleIDs`/`isProcessRestoreEnabled` where available to pre-create taps and avoid the unprocessed-start leak.
- **Distribution:** Developer ID + notarization + Homebrew cask, as FineTune does, is the low-risk route. The Mac App Store might be possible for a tap-only build (sandbox entitlement `com.apple.security.device.audio-input`), but App Review acceptance is unverified. Any HAL plug-in component excludes the App Store.
- **Bit-perfect mode:** "EQ on" and "bit-perfect" are mutually exclusive by definition. A credible audiophile design should:
  - leave apps untapped at unity with EQ bypassed, so audio goes straight to the device at its native rate and format
  - keep the device sample rate following the source, without forced SRC (inference; SoundSource added sample-rate auto-adjust on Tahoe)
  - detect hog-mode players such as Roon, Audirvana or Apple Music lossless exclusive mode and step aside
- **Robustness features to budget for:**
  - zero-buffer watchdog with full rebuild
  - fade-in on tap start
  - multichannel channel-mapping fallback
  - Bluetooth isolation from shared aggregates
  - device-change and sleep/wake rebuild
  - per-app ignore list (DAWs, VoIP, Rogue Amoeba)
  - orphaned-aggregate cleanup at launch (FineTune logs show an `OrphanedTapCleanup` step, [#105](https://github.com/ronitsingh10/FineTune/issues/105))
- **Per-tab:** this always needs browser extensions (section 4), so plan an app ↔ extension IPC from day one.
- **Optional HAL plug-in (phase 2):** only if the product needs a selectable named virtual output (Loopback-style), multichannel virtual buses, or EQ on audio from apps that refuse taps. libASPL (MIT) is the best starting point.

### Gaps
- No Apple statement or App Review precedent found confirming Mac App Store acceptance of a per-app volume app built on taps.
- No measurement found of whether a tap at unity gain with matching sample rate is bit-transparent (e.g. via a null test). This needs an in-house test.
- No public Apple roadmap on deprecating third-party AudioServerPlugIns. The "future-proof" judgement rests on Apple's guidance and on industry migration (Rogue Amoeba, eqMac), not on a published Apple policy.
