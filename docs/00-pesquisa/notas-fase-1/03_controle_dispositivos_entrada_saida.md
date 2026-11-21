# Device-level audio I/O control on macOS (Core Audio HAL + ecosystem), as of Nov 2026 (macOS 26 Tahoe / macOS 27)

Research date: 2026-11-21. Method: web sources + direct inspection of Apple's SDK headers on this machine (`/Library/Developer/CommandLineTools/SDKs/MacOSX27.0.sdk` and `MacOSX26.sdk`, host running macOS 26.6 build 25G72) + GitHub API metadata (stars / license / last push read 2026-11-21). Where a fact comes from a header, the citation links to Apple's public doc page for that symbol and says "(verified in MacOSX27.0.sdk header)". Out of scope (covered by other researchers): per-app interception/routing, process taps, EQ DSP.

## 1. Core Audio HAL: what device-level properties exist, which are writable, and how settability varies by transport

### Takeaway
Everything the brief lists (default input/output/system-output device, volume scalar/dB per element, mute, nominal sample rate, physical format = bit depth, data source, clock source, hog mode, latency/safety offset, transport type, device-list/default-device notifications) is public AudioObject API and still present unchanged in the macOS 27 SDK. The only selector added between the macOS 26 and 27 SDKs is `kAudioDevicePropertySuggestedReferenceDevice` (echo-cancellation reference for voice detection). Whether a property can be *written* depends on the driver, so the app has to ask `AudioObjectIsPropertySettable` for each device at runtime. A fixed table by transport type would be wrong.

### Cited Findings
- **System object (`kAudioObjectSystemObject`) selectors** in macOS 27 SDK `AudioHardware.h`: `kAudioHardwarePropertyDevices`, `kAudioHardwarePropertyDefaultInputDevice`, `kAudioHardwarePropertyDefaultOutputDevice`, `kAudioHardwarePropertyDefaultSystemOutputDevice` (alerts/sound effects), `kAudioHardwarePropertyTranslateUIDToDevice`, `kAudioHardwarePropertyMixStereoToMono`, `kAudioHardwarePropertyHogModeIsAllowed`, `kAudioHardwarePropertyServiceRestarted`, `kAudioHardwarePropertyProcessInputMute`, `kAudioHardwarePropertyProcessIsAudible`, `kAudioHardwarePropertyProcessObjectList`, `kAudioHardwarePropertyTapList`, and others (verified in MacOSX27.0.sdk header) — [Apple: kAudioHardwarePropertyDefaultOutputDevice](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertydefaultoutputdevice)
- **Device (AudioHardwareBase.h) selectors**: `DeviceUID`, `ModelUID`, `TransportType`, `RelatedDevices`, `ClockDomain`, `DeviceIsAlive`, `DeviceIsRunning`, `DeviceCanBeDefaultDevice`, `DeviceCanBeDefaultSystemDevice`, `Latency`, `Streams`, `SafetyOffset`, `NominalSampleRate`, `AvailableNominalSampleRates`, `Icon`, `IsHidden`, `PreferredChannelsForStereo`, `PreferredChannelLayout` (verified in MacOSX27.0.sdk header) — [Apple: kAudioDevicePropertyNominalSampleRate](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertynominalsamplerate)
- **Device (AudioHardware.h) selectors**: `DeviceHasChanged`, `DeviceIsRunningSomewhere`, `IOStoppedAbnormally`, `HogMode` ('oink'), `BufferFrameSize`/`BufferFrameSizeRange`, `StreamConfiguration`, `ActualSampleRate`, `ClockDevice`, `ProcessMute` ('appm'), `VoiceActivityDetectionEnable` ('vAd+'), `VoiceActivityDetectionState` ('vAdS'), plus new-in-27 `kAudioDevicePropertySuggestedReferenceDevice API_AVAILABLE(macos(27.0)) = 'eord'` (verified in MacOSX27.0.sdk header; a diff against MacOSX26.sdk shows this is the **only** new `kAudio*Property*` selector in CoreAudio headers) — [Apple: Core Audio](https://developer.apple.com/documentation/coreaudio)
- **Control-backed device selectors** (element- and scope-addressed): `JackIsConnected`, `VolumeScalar`, `VolumeDecibels`, `VolumeRangeDecibels`, `VolumeScalarToDecibels`/`DecibelsToScalar`, `StereoPan`, `Mute`, `Solo`, `PhantomPower`, `PhaseInvert`, `ClipLight`, `DataSource`/`DataSources`/`DataSourceNameForIDCFString`/`DataSourceKindForID`, `ClockSource`/`ClockSources`/`ClockSourceNameForIDCFString`, `PlayThru*`, `ChannelNominalLineLevel*`, `HighPassFilterSetting*`, `SubVolume*`, `SubMute` (verified in MacOSX27.0.sdk header) — [Apple: kAudioDevicePropertyVolumeScalar](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertyvolumescalar)
- **Stream selectors (bit depth lives here)**: `kAudioStreamPropertyVirtualFormat`, `AvailableVirtualFormats`, `PhysicalFormat`, `AvailablePhysicalFormats`, `TerminalType`, `Latency`, `IsActive`, `Direction`, `StartingChannel` (verified in MacOSX27.0.sdk header) — [Apple: kAudioStreamPropertyPhysicalFormat](https://developer.apple.com/documentation/coreaudio/kaudiostreampropertyphysicalformat)
- **Virtual main volume / balance** are not HAL selectors. They come from AudioToolbox `AudioHardwareService.h`: `kAudioHardwareServiceDeviceProperty_VirtualMainVolume = 'vmvc'` and `_VirtualMainBalance = 'vmbc'`. The old `...VirtualMasterVolume` names are deprecated aliases. The `AudioHardwareService*` wrapper functions are marked `API_DEPRECATED("no longer supported", macos(10.5, 10.11))`, so the selectors are used through `AudioObjectGetPropertyData`/`SetPropertyData` (verified in MacOSX27.0.sdk header) — [Apple: kAudioHardwareServiceDeviceProperty_VirtualMainVolume](https://developer.apple.com/documentation/audiotoolbox/kaudiohardwareservicedeviceproperty_virtualmainvolume)
- **Device IDs vs UIDs**: "An AudioDevice's UID is persistent across boots", but it is "a black box… not suitable for passing between CPUs or for identifying similar models". AudioObjectIDs are run-time handles (verified in MacOSX27.0.sdk header) — [Apple: kAudioDevicePropertyDeviceUID](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertydeviceuid)
- **Hog mode semantics**: value is the owning `pid_t` or -1. Setting it *toggles* ownership for the calling process (the passed value is ignored). "If the AudioDevice is in a non-mixable mode, the HAL will automatically take hog mode on behalf of the first process to start an IOProc." (verified in MacOSX27.0.sdk header) — [Apple: kAudioDevicePropertyHogMode](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertyhogmode)
- **Service restart**: `kAudioHardwarePropertyServiceRestarted` exists "so that clients can be informed when the service has been reset… any state the client has, such as cached data or added listeners, must be re-established by the client." (verified in MacOSX27.0.sdk header) — [Apple: kAudioHardwarePropertyServiceRestarted](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertyservicerestarted)
- **Process mute** (`kAudioDevicePropertyProcessMute`): "the current process's audio will be zeroed out by the system… does not apply to aggregate devices, just real, physical devices." It affects only the calling process, not the device (verified in MacOSX27.0.sdk header) — [Apple: kAudioDevicePropertyProcessMute](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertyprocessmute)
- **Real-world evidence that main-element volume is often missing**: boring.notch's `VolumeManager.swift` reads `kAudioHardwarePropertyDefaultOutputDevice`, then probes `VolumeScalar` on elements `[kAudioObjectPropertyElementMain, 1, 2, 3, 4]` before giving up. When there is no device it falls back to a software-only mute flag — [boring.notch VolumeManager.swift](https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/VolumeManager.swift)
- **Benchmark (SoundSource)** exposes per-device volume, mute, balance, sample rate, "Source" (data source), a Max Volume cap, and "global locks" that stop other apps from changing Volume, Balance, Sample Rate, Source and Mute (outputs) or Volume, Sample Rate, Source and Mute (inputs). The manual does not mention bit depth/format — [SoundSource manual](https://rogueamoeba.com/support/manuals/soundsource/?print=true)
- **Bit-depth switching in practice**: LosslessSwitcher switches sample rate to match Apple Music and supports bit-depth switching, but says "enabling it will reduce detection accuracy, hence, it is not recommended" — [LosslessSwitcher README](https://github.com/vincentneo/LosslessSwitcher)
- **Format persistence**: users report that "24 and 32 bit audio selected in Audio MIDI Setup are not retained after OS reboot" — [Apple Community thread](https://discussions-jp-prz.apple.com/thread/254979603)

### Inferences
- A notch app should treat each device as a capability bag. On attach, enumerate controls (`kAudioObjectPropertyControlList` / owned objects) and call `AudioObjectHasProperty` + `AudioObjectIsPropertySettable` per selector, scope and element. Volume should be tried in this order: main element, then `VirtualMainVolume` (which spans channels), then per-channel elements (the same order boring.notch uses).
- Typical behaviour by transport (inferred from the sources above and general HAL behaviour, **not verified per device**; confirm by runtime probing):
  - **Built-in**: hardware volume and mute; input gain; sample rate usually fixed or limited.
  - **USB DACs**: sample rate and physical format usually settable; hardware volume only if the DAC exposes a USB Audio Class feature-unit volume.
  - **HDMI/DisplayPort**: often no volume. eqMac advertising "HDMI Volume Support" implies this.
  - **Bluetooth**: volume yes; sample rate and format effectively fixed by the codec.
  - **AirPlay**: volume yes; formats fixed.
  - **Aggregate**: no process mute (per the header).
- `DeviceUID` should be the key for per-device presets. `AudioObjectID` must never be persisted.
- Because SoundSource exposes "locks", the HAL has no lock of its own: a lock is a listener that writes the value back. A notch app can do the same, but it will fight other apps that do it too.

### Gaps
- I did not find an authoritative Apple table of which controls each built-in/Bluetooth/AirPlay driver exposes. Runtime probing on real hardware is required.
- `AudioHardwareBase.h`/`AudioHardware.h` per-symbol macOS availability for the process-object API (`kAudioHardwarePropertyProcessObjectList`, `kAudioProcessPropertyIsRunningInput`) was not extracted. It is widely described as macOS 14+, but that is not verified here.
- Apple's per-symbol documentation URLs are cited by convention. The authoritative text quoted above was read from the local SDK headers.

## 2. USB DACs without hardware volume: why the volume keys grey out, and how apps provide software volume (with quality implications)

### Takeaway
macOS greys out volume (slider and keys) when the output device publishes no volume control (for USB, no UAC feature-unit volume). The OS will not put a software gain stage in front of it on its own. Third parties fix this by putting audio they control in the path: a virtual HAL device that forwards to the DAC (Proxy Audio Device, eqMac's driver, Background Music) or SoundSource's ARK driver with "Force software volume control". Software volume is applied in Core Audio's 32-bit float domain and breaks bit-perfect output. For audiophiles the cleanest choice is hardware/DAC volume when it exists, with software volume as a labelled fallback.

### Cited Findings
- On the Apple coreaudio-api list, a reply says that if a USB Audio device does not have volume, volume will not be enabled; this depends on the descriptors the device presents (2012; full page returned HTTP 502 on fetch, content from search snippet) — [coreaudio-api 2012/Feb msg00114](https://lists.apple.com/archives/coreaudio-api/2012/Feb/msg00114.html); thread replies [msg00013](https://lists.apple.com/archives/coreaudio-api/2012/Mar/msg00013.html)
- Users of external speakers and DACs report the greyed-out volume control and use third-party tools such as Proxy Audio Device Settings to "control the external audio interface with media keys (or sliders in MacOS UI)" — [Apple Community 255028132](https://discussions.apple.com/thread/255028132); [MacRumors thread](https://forums.macrumors.com/threads/controlling-system-volume-when-connected-to-a-dac.2037325)
- **Proxy Audio Device** is "A HAL virtual audio driver for macOS that sends all output to another audio device. Its main purpose is to make it possible to use macOS's system volume controls… volume keyboard keys… external audio" devices. It is installed to `/Library/Audio/Plug-Ins/HAL`, and its Settings app picks the target device and buffer size. Available via `brew install --cask proxy-audio-device`. License Unlicense, 1,116★, last push 2026-10-18 — [briankendall/proxy-audio-device](https://github.com/briankendall/proxy-audio-device)
- **SoundSource**: "Super Volume Keys" make the volume keys adjust the System Output "even if the device does not natively offer software-based volume controls" (needs Accessibility). The device's Advanced tab offers "Force software volume control". Magic Boost works on the system output. It requires the ARK (Audio Routing Kit) install with an admin password — [SoundSource manual](https://rogueamoeba.com/support/manuals/soundsource/?print=true)
- **eqMac** lists "`Free` HDMI Volume Support" and "`Free` Volume Balance support for all devices (including HDMI)". Its driver is a passthrough device "based on Apple's Null Audio Server Driver Plug-in". Apache-2.0, 6,836★, last push 2026-09-19 — [bitgapp/eqMac](https://github.com/bitgapp/eqMac)
- **Background Music** (per-app volume, can boost apps): its README warns "Setting an application's volume above 50% can cause clipping". The installer "restarts the system audio process (coreaudiod)". GPL-2.0, 19,401★, last push 2026-06-10 — [kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic)
- **Quality**:
  - Sources agree that software volume or resampling breaks bit-perfect output, and that 32-bit float output can be bit-perfect only when no software volume or SRC is in the chain.
  - One article says 32-bit float carries only 25-bit integer precision, while newer ESS-based DACs run their own volume at 32-bit+ integer precision.
  - Dithered bit-depth reduction plus volume is a feature of the BitPerfect player.
  - These are enthusiast/vendor sources, not measurements.
  - Sources: [Tonal: Secrets of Audiophile Playback on macOS](https://medium.com/tonal-app/secrets-of-audiophile-playback-on-macos-8f940e8f4625); [Positive Feedback: bpplay part 3](https://positive-feedback.com/reviews/music-reviews/bpplay-bit-perfect-playback-software-solution-part3/); [BitPerfect (App Store)](https://apps.apple.com/gb/app/bitperfect/id455545700?mt=12)
- Some DACs (e.g. iFi Zen Sig V2, Modius E per a user) disable keyboard volume control when active. The common advice is OS volume at 100% with level set on the DAC — [Head-Fi thread](https://www.head-fi.org/threads/dac-for-macos-that-allows-keyboard-volume-control.975870)

### Inferences
- The HAL alone cannot give software volume to a volume-less DAC. The app must own a point in the signal path: a virtual device / HAL plug-in, or a process-tap pipeline (the other researcher's scope). A notch app that only does device control can at best detect "no volume control" (no settable `VolumeScalar` or `VirtualMainVolume`) and fall back to a companion driver such as Proxy Audio Device, or to its own DSP path.
- Gain applied in float32 before the device's integer conversion adds a quantisation step at low levels. Good practice is to show a "bit-perfect: off" badge in the notch when software volume is active, and to offer a "100% / DAC controls volume" mode.

### Gaps
- No neutral measurement study of macOS software volume (float gain, then DAC integer conversion, with or without dither) was found.
- Whether macOS 26/27 changed volume-less USB DAC behaviour: no evidence of change was found.

## 3. Bluetooth specifics: codec visibility, AirPods modes, battery

### Takeaway
Codec, AirPods listening mode, spatial audio and head tracking are not exposed by any public macOS API. In practice macOS uses AAC or SBC; aptX is unreliable or absent on Apple Silicon, and Apple never had LDAC. The Option-click codec readout was removed after Catalina; Bluetooth Explorer's Audio Graph is the remaining manual method. Battery levels can be read through IOKit/IOBluetooth private keys or `system_profiler`. Listening-mode control needs either private frameworks (NoiseBuddy, now broken) or a reimplementation of Apple's proprietary AirPods protocol (LibrePods does this on Linux/Android).

### Cited Findings
- **Codec**:
  - Option-click on the Bluetooth menu showed the active codec up to Catalina; that "is not working anymore in Big Sur". The workaround is Bluetooth Explorer's Audio Graph.
  - The forcing knobs are Bluetooth Explorer → Tools → Audio Options ("Force use of aptX", "Enable AAC").
  - Users on Sonoma/Sequoia report these no longer take effect ("macOS Sequoia forces SBC for Bluetooth audio, AAC does not work").
  - Sources: [Apple Community 252294092](https://discussions.apple.com/thread/252294092); [MacRumors how-to](https://www.macrumors.com/how-to/enable-aptx-aac-bluetooth-audio-codecs-macos); [Apple Community 256151211](https://discussions.apple.com/thread/256151211)
- **aptX on Apple Silicon**: an M2 MacBook Air owner enabled both AAC and aptX keys and still saw SBC; another M2 user stayed on AAC. Older guides say macOS "officially supports aptX", while newer coverage says Apple devices support SBC and AAC only (conflicting sources, no Apple statement) — [Apple Community 255528714](https://discussions.apple.com/thread/255528714); [Apple Community 255808520](https://discussions.apple.com/thread/255808520); [9to5Mac aptX guide (2018)](https://9to5mac.com/guides/aptx); [Digital Trends](https://www.digitaltrends.com/home-theater/what-are-bluetooth-codecs/)
- **AirPods listening mode**: a 2026 Apple Developer Forums post reports finding "no documented public API that allows a third-party macOS app to directly set AirPods listening modes" after reviewing the SDK headers; it is unanswered. Apple's own path is the AirPods menu-bar icon or System Settings — [Apple Developer Forums 827650](https://developer.apple.com/forums/thread/827650); [Apple Support: switch listening modes](https://support.apple.com/guide/airpods/dev9812f5cc3/)
- **NoiseBuddy** (Guilherme Rambo; menu bar / Touch Bar toggle for AirPods Pro listening mode) says: "This project doesn't work in recent versions of macOS. Similar functionality is available as part of AirBuddy" (AirBuddy is commercial). BSD-2-Clause, 731★, last push 2024-05-28 — [insidegui/NoiseBuddy](https://github.com/insidegui/NoiseBuddy)
- **LibrePods** "implements the proprietary protocol used to exchange data between AirPods and Apple devices, enabling features like changing noise control modes", ear detection and battery. Head-tracked spatial audio is marked "❓". The targets are Linux/Android, not macOS. GPL-3.0, 30,904★, last push 2026-11-09 — [librepods-org/librepods](https://github.com/librepods-org/librepods)
- **Battery**: AirBattery reads Bluetooth battery from `system_profiler SPBluetoothDataType -json`, from IORegistry properties `BatteryPercent`/`BatteryStatusFlags`, and via KVC on `IOBluetoothDevice.pairedDevices()` with private keys such as `batteryPercentSingle` (with `batteryPercentLeft/Right/Case` commented out). It also parses BLE advertisements and needs Bluetooth permission. AGPL-3.0, 2,999★, last push 2025-11-02 — [AirBattery MagicBattery.swift](https://github.com/lihaoyun6/AirBattery/blob/main/AirBattery/BatteryInfo/MagicBattery.swift); [AirBattery README](https://github.com/lihaoyun6/AirBattery)
- **SoundSource** needs Bluetooth permission "to show Bluetooth devices, maintain connections, and display battery status". For devices with both input and output it offers a per-device **Mode: "Output Only"**, which "can improve audio quality" because the headset mic is not used (avoids the hands-free profile) — [SoundSource manual](https://rogueamoeba.com/support/manuals/soundsource/?print=true)
- **SoundAnchor** (commercial, App Store, bundle `me.kopiro.soundanchor`, by Flavio De Stefano; macOS 12+) exists to stop AirPods from making their low-quality mic the default input. No public repo was found — [Softpedia](https://mac.softpedia.com/get/Audio/SoundAnchor.shtml); [Product Hunt](https://www.producthunt.com/products/soundanchor-for-macos/makers). A different MIT project named SoundAnchor (xincheng1237, 1★, pushed 2026-10-24) is "a zero-polling macOS menu bar utility that keeps Bluetooth headset audio in high quality" — [xincheng1237/SoundAnchor](https://github.com/xincheng1237/SoundAnchor)

### Inferences
- The most valuable *public-API* Bluetooth feature for audiophiles is guarding against the hands-free profile. When a BT headset connects and steals default input, reset default input to the built-in mic. This keeps the headset on A2DP/AAC. It is the SoundAnchor and SoundSource "Output Only" pattern, built from `kAudioHardwarePropertyDefaultInputDevice` plus a device-list listener.
- Codec display and listening-mode switching would need private API or a native port of the LibrePods protocol (L2CAP to AirPods). Expect breakage with each macOS release (see NoiseBuddy) and treat this as an optional, flagged feature. Private APIs also rule out the Mac App Store.

### Gaps
- No source confirms the private framework or selectors that macOS 26/27 Control Center uses for listening mode or spatial audio.
- No public API was found for reading the active Bluetooth codec on macOS 26/27. Whether Bluetooth Explorer (Additional Tools for Xcode) still shows it on Tahoe was not verified.
- The macOS 27 SDK contains `AudioToolbox/AUHeadTrackingBinauralRenderer.h` (seen in a header listing). It appears to be a renderer AU, not a system toggle; its contents and availability were not read.

## 4. Microphone / input: gain, mute, mic-in-use detection, Voice Isolation / mic modes

### Takeaway
Input gain and device mute go through the same HAL volume and mute selectors on input scope, subject to settability. The system mic mode (Standard / Wide Spectrum / Voice Isolation) can be **read** (`AVCaptureDevice.preferredMicrophoneMode` and `activeMicrophoneMode`) but **not set** by apps. An app can only open the system picker (`showSystemUserInterface(.microphoneModes)`). Per-process mic use can be observed through HAL process objects (`kAudioProcessPropertyIsRunningInput`). Any input metering from the notch will light the orange mic-in-use indicator.

### Cited Findings
- `AVCaptureMicrophoneMode` = Standard (0), WideSpectrum (1), VoiceIsolation (2). `+preferredMicrophoneMode` is `readonly`: "the microphone mode selected by the user in Control Center", KVO-observable. `+activeMicrophoneMode` is readonly and "may differ… if the application's active audio route does not support the preferred microphone mode". `AVCaptureSystemUserInterfaceMicrophoneModes = 2` is used with `+showSystemUserInterface:`. All macOS 12.0+ (verified in MacOSX27.0.sdk `AVCaptureDevice.h`) — [Apple: preferredMicrophoneMode](https://developer.apple.com/documentation/avfoundation/avcapturedevice/preferredmicrophonemode)
- `AVAudioApplication` (macOS 14.0+): `-setInputMuted:error:`, `inputMuted`, `AVAudioApplicationInputMuteStateChangeNotification`. The macOS-only `-setInputMuteStateChangeHandler:` lets the system or hardware mute gesture call into the app. This is app-scoped input mute (verified in MacOSX27.0.sdk `AVAudioApplication.h`) — [Apple: AVAudioApplication](https://developer.apple.com/documentation/avfaudio/avaudioapplication)
- HAL: `kAudioHardwarePropertyProcessInputMute` ("all data coming into the process for all devices will be silent"). `kAudioDevicePropertyVoiceActivityDetectionEnable/State` gives voice-activity detection with echo cancellation, which "works when a process mute is used, but not with hardware mute". New in macOS 27: `kAudioDevicePropertySuggestedReferenceDevice` (output device UID used as the echo-cancellation reference; defaults to the system default output) (verified in MacOSX27.0.sdk header) — [Apple: kAudioDevicePropertyVoiceActivityDetectionEnable](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertyvoiceactivitydetectionenable)
- Per-process I/O state: `kAudioHardwarePropertyProcessObjectList` ('prs#'), `kAudioHardwarePropertyTranslatePIDToProcessObject`, `kAudioProcessPropertyIsRunningInput` ('piri') / `IsRunningOutput` ('piro') (verified in MacOSX27.0.sdk header) — [Apple: kAudioProcessPropertyIsRunningInput](https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunninginput)
- SoundSource input metering modes are Passive (default), Active and Disabled, and "any metering causes the macOS mic-in-use indicator to appear". SoundSource offers per-device input volume and mute, plus input volume via global shortcuts. Its manual does not describe "gain" separately — [SoundSource manual](https://rogueamoeba.com/support/manuals/soundsource/?print=true)
- SwitchAudioSource can mute inputs: `SwitchAudioSource -m toggle -t input` ("useful on a hotkey, e.g. to mute your Teams or Zoom input") — [switchaudio-osx README](https://github.com/deweller/switchaudio-osx)

### Inferences
- "Mic mute" in the notch should be **device mute** (`kAudioDevicePropertyMute`, input scope, if settable). The fallback is input volume set to 0 (remember and restore the previous value). `kAudioHardwarePropertyProcessInputMute` and `AVAudioApplication` mute only affect the calling app, so they are useless for a global mute.
- A "who's using the mic" list can be built by listening on `kAudioHardwarePropertyProcessObjectList`, filtering `IsRunningInput == 1`, and mapping PID to app with `NSRunningApplication`. No metering is needed, so the orange dot is not triggered by our app. That claim is inferred: process-object reads don't open input.
- The Voice Isolation picker can only be opened (`showSystemUserInterface`), not changed. This is a firm platform limit for public API.

### Gaps
- No source confirmed whether reading `kAudioProcessPropertyIsRunningInput` for other processes needs any TCC permission on macOS 26/27.
- Whether macOS 26/27 Control Center mic modes apply to third-party USB mics: not researched.

## 5. Swift libraries and wrappers (license, maintenance)

### Takeaway
SimplyCoreAudio, the de-facto Swift HAL wrapper, is archived (last release 4.1.1, June 2023). The maintained successors as of Nov 2026 are:
- **spfk-audio-hardware** (Ryan Francesconi, MIT, derived from SimplyCoreAudio, actor-based with async reads and writes, Sendable devices), the closest match to a modern Swift-concurrency wrapper.
- **CAAudioHardware** (Stephen Booth, MIT, active).
- **orchetect/swift-core-audio** (MIT, early 0.2.x).

AudioKit is not a device-control library: on macOS it only binds `AVAudioEngine` to a device. A thin in-house wrapper over `AudioObject*` is also a realistic option.

### Cited Findings
| Library | License | ★ (2026-11-21) | Last push | Notes |
|---|---|---|---|---|
| [rnine/SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio) | MIT | 455 | 2024-02-25, **archived** | Latest release 4.1.1 (Jun 2023) per [Swift Package Registry](https://swiftpackageregistry.com/rnine/SimplyCoreAudio); spfk says it was archived Mar 2025 |
| [ryanfrancesconi/spfk-audio-hardware](https://github.com/ryanfrancesconi/spfk-audio-hardware) | MIT | 9 | 2026-11-19 | "Devices are `Sendable` and the manager is an actor, with `async` reads and writes"; "Notifications are posted on the main actor"; "Derived from SimplyCoreAudio by Ruben Nine" |
| [sbooth/CAAudioHardware](https://github.com/sbooth/CAAudioHardware) | MIT | 23 | 2026-11-19 | "The Core Audio HAL made Swift-friendly"; docs on [Swift Package Index](https://swiftpackageindex.com/sbooth/CAAudioHardware) |
| [sbooth/CoreAudioExtensions](https://github.com/sbooth/CoreAudioExtensions) | MIT | 2 | 2026-06-22 | Swift extensions for Core Audio types |
| [sbooth/SFBAudioEngine](https://github.com/sbooth/SFBAudioEngine) | MIT | 718 | 2026-11-20 | Playback/decoding engine (FLAC, DSD, etc.), not a device-control library |
| [orchetect/swift-core-audio](https://github.com/orchetect/swift-core-audio) | MIT | 4 | 2026-11-06 | "Core Audio wrapper for macOS 10.15+", Swift value types, v0.2.3 |
| [ExistentialAudio/SwiftCoreAudio](https://github.com/ExistentialAudio/SwiftCoreAudio) | none declared | 9 | 2023-11, **archived** | Avoid (no license) |
| [carescribe/SimplyCoreAudio](https://github.com/carescribe/SimplyCoreAudio) | MIT | 0 | 2021-08 | Fork for CLI use cases; stale |
| [karaggeorge/macos-audio-devices](https://github.com/karaggeorge/macos-audio-devices) | MIT | 175 | 2023-01 | Node/Swift CLI to get/set devices; stale |
| [AudioKit/AudioKit](https://github.com/AudioKit/AudioKit) | MIT | 11,507 | 2026-07-26 | On macOS, `AVAudioEngine+Devices.swift` sets and gets the engine device via `kAudioOutputUnitProperty_CurrentDevice` (`#if os(macOS)`) — [source](https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/Internals/Hardware/AVAudioEngine+Devices.swift) |

- The SPFK page states SimplyCoreAudio was "Open-sourced in March 2014 and archived in March 2025. Ryan Francesconi was a contributor and continued its development (as this package)" (stated on a mirror page; GitHub confirms `archived: true`) — [spfk-audio-hardware](https://github.com/ryanfrancesconi/spfk-audio-hardware)

### Inferences
- Recommended stack: **spfk-audio-hardware** or **CAAudioHardware** as a base, both MIT and compatible with any OSS license. Either way, wrap them behind our own `@Observable` device model. The HAL surface is small enough to vendor and own, especially to handle `kAudioHardwarePropertyServiceRestarted` re-registration and the new macOS 27 selector.
- CoreAudioKit is UI for AU views and the Bluetooth/network MIDI panels, not a device-settings API. AVAudioEngine on macOS has no `AVAudioSession`, follows the default device unless rebound through the output unit's `CurrentDevice`, and gives no access to device volume, sample rate or format. It is the wrong layer for "total control". (Partly inferred; the AudioKit source confirms the `CurrentDevice` binding.)

### Gaps
- No feature/API comparison of spfk vs CAAudioHardware (property coverage, listener API, Swift 6 strict-concurrency status) was done beyond the READMEs.
- CoreAudioKit's current macOS 27 surface was not inspected.

## 6. Open-source apps to study (license, stars, activity)

### Takeaway
No open-source app matches SoundSource's device panel. The useful references are:
- **SwitchAudioSource** (CLI device and mute switching)
- **LosslessSwitcher** (automatic sample rate and bit depth)
- **Proxy Audio Device**, **eqMac** and **Background Music** (software volume through virtual devices)
- **MonitorControl** and **boring.notch** (volume keys, OSD and notch HUD)
- **AirBattery** and **LibrePods** (Bluetooth and AirPods)

"AudioSwitcher", "Sound Control" and "SoundAnchor" (the well-known one) are **not** open source.

### Cited Findings
| Project | What to study | License | ★ | Last push | Source |
|---|---|---|---|---|---|
| deweller/switchaudio-osx (SwitchAudioSource) | `-t input/output/system`, `-s name / -i id / -u uid`, `-m mute/unmute/toggle`, `-n` cycle, `-f cli/human/json`, `-a`, `-c` | NOASSERTION (custom; check LICENSE) | 1,460 | 2024-07-07 | [repo](https://github.com/deweller/switchaudio-osx) |
| vincentneo/LosslessSwitcher | Sets device sample rate (optionally bit depth) from Apple Music; v1 worked to 15.3.1; v2 for 15.4+ "must be an **admin**"; reads Apple Music logs; tested on 26.0–26.3 with Dragonfly, FiiO K11/K17, iBasso DC Elite | GPL-3.0 | 2,029 | 2026-06-07 | [repo](https://github.com/vincentneo/LosslessSwitcher) |
| briankendall/proxy-audio-device | HAL proxy driver giving system volume to volume-less devices | Unlicense | 1,116 | 2026-10-18 | [repo](https://github.com/briankendall/proxy-audio-device) |
| bitgapp/eqMac | HDMI volume, balance, booster via driver based on Null Audio Server | Apache-2.0 | 6,836 | 2026-09-19 | [repo](https://github.com/bitgapp/eqMac) |
| kyleneideck/BackgroundMusic | Virtual device; coreaudiod restart on install; recovery instructions | GPL-2.0 | 19,401 | 2026-06-10 | [repo](https://github.com/kyleneideck/BackgroundMusic) |
| MonitorControl/MonitorControl | Media/brightness key capture, native OSD, Accessibility onboarding | MIT | 34,783 | 2026-10-14 | [repo](https://github.com/MonitorControl/MonitorControl) |
| TheBoredTeam/boring.notch | Notch "System HUD replacements (volume, brightness, backlight)"; `MediaKeyInterceptor.swift`, `VolumeManager.swift`; macOS 15.6+ | GPL-3.0 | 11,421 | 2026-11-20 | [repo](https://github.com/TheBoredTeam/boring.notch) |
| Lakr233/NotchDrop | Notch UI shell | MIT | 2,130 | 2026-05-18 | [repo](https://github.com/Lakr233/NotchDrop) |
| mrkai77/DynamicNotchKit | Notch presentation library | MIT | 486 | 2026-04-24 | [repo](https://github.com/mrkai77/DynamicNotchKit) |
| lihaoyun6/AirBattery | BT/AirPods battery (IORegistry + IOBluetooth KVC + BLE), AppleScript `.sdef` | AGPL-3.0 | 2,999 | 2025-11-02 | [repo](https://github.com/lihaoyun6/AirBattery) |
| librepods-org/librepods | AirPods proprietary protocol (ANC modes, ear detection, battery) on Linux/Android | GPL-3.0 | 30,904 | 2026-11-09 | [repo](https://github.com/librepods-org/librepods) |
| insidegui/NoiseBuddy | AirPods listening-mode toggle (broken on recent macOS) | BSD-2-Clause | 731 | 2024-05-28 | [repo](https://github.com/insidegui/NoiseBuddy) |
| MonitorControl/MediaKeyTap | Swift media-key tap (fork) | MIT | 42 | 2021-05-15 | [repo](https://github.com/MonitorControl/MediaKeyTap) |
| nhurden/MediaKeyTap | Original MediaKeyTap | MIT | 74 | 2024-01, **archived** | [repo](https://github.com/nhurden/MediaKeyTap) |
| sindresorhus/KeyboardShortcuts | User-customisable global hotkeys | MIT | 2,745 | 2026-09-11 | [repo](https://github.com/sindresorhus/KeyboardShortcuts) |
| ExistentialAudio/BlackHole | Loopback driver (routing; reference only) | NOASSERTION (GPL-3.0 + commercial per project) | 20,088 | 2026-11-07 | [repo](https://github.com/ExistentialAudio/BlackHole) |

- "Sound Control" (and Sound Siphon) are commercial StaticZ products, listed as alternatives in the Background Music README — [BackgroundMusic README](https://github.com/kyleneideck/BackgroundMusic)
- The best-known SoundAnchor is closed source (see Section 3) — [Softpedia](https://mac.softpedia.com/get/Audio/SoundAnchor.shtml)

### Inferences
- License hygiene for an OSS notch app:
  - MIT, Apache-2.0, BSD and Unlicense code (SwitchAudioSource pending its license check, MonitorControl, MediaKeyTap, Proxy Audio Device, eqMac, NotchDrop, DynamicNotchKit, spfk, CAAudioHardware) can be reused under most licenses.
  - GPL-2.0/3.0 code (boring.notch, LosslessSwitcher, Background Music, LibrePods) can only be copied if our app is GPL-compatible.
  - AGPL code (AirBattery) is study-only unless we go AGPL.
- SwitchAudioSource's feature set is a good minimum spec for the notch device menu: type filter, UID addressing, mute toggle, cycle, JSON.

### Gaps
- No open-source repos named "AudioSwitcher" or "Sound Control" for macOS were found. GitHub search API calls returned empty, so a few smaller projects may have been missed.
- The exact SwitchAudioSource license text (GitHub reports NOASSERTION) was not read.

## 7. Intercepting volume and media keys, permissions, and drawing our own OSD in the notch

### Takeaway
Use a `CGEventTap` at `.cghidEventTap` for `NSSystemDefined` events (type 14, subtype 8 = `NX_SUBTYPE_AUX_CONTROL_BUTTONS`) and decode `data1 >> 16` into `NX_KEYTYPE_*`. Return `nil` to **consume** the key, which suppresses the system OSD and lets us draw our own notch HUD. Consuming requires an active (`.defaultTap`) tap, which needs **Accessibility** permission; listen-only taps fall under Input Monitoring (`CGRequestListenEventAccess`). boring.notch and SoundSource both use this pattern. On Tahoe, piggy-backing on the native OSD is unreliable.

### Cited Findings
- Key codes in IOKit `ev_keymap.h`: `NX_KEYTYPE_SOUND_UP 0`, `NX_KEYTYPE_SOUND_DOWN 1`, `NX_KEYTYPE_MUTE 7`, `NX_KEYTYPE_PLAY 16`, `NEXT 17`, `PREVIOUS 18`, `FAST 19`, `REWIND 20` (verified in MacOSX27.0.sdk header) — [Apple: IOKit HID system](https://developer.apple.com/documentation/iokit)
- CoreGraphics: `CGPreflightListenEventAccess`, `CGRequestListenEventAccess`, `CGPreflightPostEventAccess` (macOS 10.15+); `kCGEventTapOptionDefault = 0` vs `kCGEventTapOptionListenOnly = 1` (verified in MacOSX27.0.sdk `CGEvent.h`/`CGEventTypes.h`) — [Apple: CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- boring.notch `MediaKeyInterceptor.swift` (a working notch implementation as of Nov 2026):
  - `CGEventType(rawValue: 14)` with `CGEvent.tapCreate(tap: .cghidEventTap, options: .defaultTap, …)`.
  - Checks `nsEvent.type == .systemDefined` and `subtype.rawValue == 8`, then `keyCode = (data1 & 0xFFFF0000) >> 16`.
  - Returns `nil` to swallow the event.
  - Default step is 1/16; Option+Shift gives quarter steps.
  - The Option modifier triggers a configurable action.
  - Accessibility authorization is checked through an XPC helper.
  - [MediaKeyInterceptor.swift](https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/observers/MediaKeyInterceptor.swift)
- MonitorControl requires adding the app to Accessibility "only if you wish to use the native Apple keyboard brightness and media keys". It "Shows native OSD", but "current versions have limited native macOS OSD support on macOS Tahoe – although the Control Center brightness or volume OSD appears, the OSD percentage value will not show or update" — [MonitorControl README](https://github.com/MonitorControl/MonitorControl)
- SoundSource Super Volume Keys require Accessibility access — [SoundSource manual](https://rogueamoeba.com/support/manuals/soundsource/?print=true)
- Customisable non-media hotkeys: sindresorhus/KeyboardShortcuts (MIT, 2,745★, active 2026-09) — [repo](https://github.com/sindresorhus/KeyboardShortcuts)

### Inferences
- Notch flow:
  1. The tap receives SOUND_UP, SOUND_DOWN or MUTE.
  2. Decide the target device (the default output, or a "controlled device" override such as a DAC behind a proxy).
  3. Write hardware volume if settable; otherwise write `VirtualMainVolume`; otherwise use the software-volume path.
  4. Return `nil`. The system HUD never appears.
  5. Animate the notch HUD with dB as well as % (`VolumeScalarToDecibels`).
  - Pass events through unchanged when our app is disabled or the device is "system-controlled".
- Re-enable the tap when `kCGEventTapDisabledByTimeout` or `ByUserInput` arrives (standard CGEventTap hygiene; not sourced here). Keep the callback non-blocking and do HAL writes off the tap thread.
- An Accessibility-dependent active event tap rules out the Mac App Store sandbox in practice. MonitorControl, boring.notch and SoundSource all ship outside the store.

### Gaps
- The exact way the Tahoe volume HUD is drawn (private `OSDUIHelper` vs Control Center) and whether it can be suppressed without consuming the key were not verified.
- Behaviour on non-Apple keyboards that send HID consumer-page volume usages, and on Touch Bar Macs, was not researched.

## 8. Automation hooks: per-device presets, Shortcuts/App Intents, AppleScript, CLI

### Takeaway
Per-device presets come down to "listen for device-list and default-device changes, match `DeviceUID`, apply the saved settings". SoundSource offers Preferred Device Order, Quick Configs, per-device locks and Shortcuts actions; that is the parity target. The public surfaces we can expose are App Intents (Shortcuts and Spotlight), an AppleScript `.sdef`, and a CLI in the SwitchAudioSource style.

### Cited Findings
- **SoundSource automation**:
  - Shortcuts actions: Get Device List, Get Device, Set Device Volume, Set Device Mute, Set Device Sample Rate, Set Source Device, Set Group Device Volume.
  - "Quick Configs" save system device selections and volume levels.
  - "Preferred Device Order" sets default input, output and sound-effects devices at launch.
  - Hidden devices are kept from becoming default.
  - Per-device keyboard shortcuts: Set as System Output/Input, Toggle Mute, Volume Up/Down.
  - The manual does not mention AppleScript or automatic per-device rules.
  - Source: [SoundSource manual](https://rogueamoeba.com/support/manuals/soundsource/?print=true)
- **SwitchAudioSource CLI**: `-t type`, `-s name | -i id | -u uid` ("by uid or a substring of the uid"), `-m mute|unmute|toggle`, `-n` (cycle), `-f cli|human|json` — [switchaudio-osx README](https://github.com/deweller/switchaudio-osx)
- AirBattery ships `AirBattery/Supports/Scriptable.sdef` (AppleScript dictionary) — [AirBattery repo tree](https://github.com/lihaoyun6/AirBattery)
- `DeviceUID` is persistent across boots, which makes it the right preset key (verified in MacOSX27.0.sdk header) — [Apple: kAudioDevicePropertyDeviceUID](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertydeviceuid)
- App Intents is Apple's framework for exposing app actions to Shortcuts, Siri and Spotlight — [Apple: App Intents](https://developer.apple.com/documentation/appintents)

### Inferences
- The preset engine:
  - Triggers: `kAudioHardwarePropertyDevices`, `DefaultOutputDevice`, `DefaultInputDevice` and `kAudioHardwarePropertyServiceRestarted`.
  - On connect: match UID, then apply volume, sample rate, physical format, data source, the "make default" rule, the "don't let this BT headset be default input" rule, and the EQ preset ID (handed to the other subsystem).
  - Debounce. Bluetooth devices appear, disappear and re-enumerate during connection; that is a common observation, not sourced here.
- Expose App Intents mirroring SoundSource's set (set default device, volume, mute, sample rate, apply preset), plus a tiny CLI for power users.

### Gaps
- Whether macOS 26/27 Shortcuts has a built-in "set sound output device" action for Macs was not verified.

## 9. Pitfalls reported in the wild (coreaudiod, IDs, aggregates, sample-rate resets, OS updates)

### Takeaway
The main risks:
- macOS releases regularly break audio. Tahoe 26.0 had capture and sample-rate bugs fixed in 26.1. macOS 27.0.1–27.2 broke multi-output devices that span display audio.
- High-rate switching on Tahoe still fails for some DACs.
- `coreaudiod` restarts invalidate listeners.
- Object IDs aren't stable.
- Aggregates are excluded from some properties.
- Private-API features (NoiseBuddy, LosslessSwitcher's log reading, the native OSD) break on OS updates.

### Cited Findings
- **Rogue Amoeba (Nov 4, 2025)**: two critical 26.0 bugs, now "resolved with the recent release of MacOS 26.1". They were (a) FaceTime and Phone capture failures and (b) "audio captures failing when secondary output devices had a different sample rate" than the default output. Other fixes: Safari clicks at 44.1 kHz, the low-sample-rate capture regression from late Sequoia, and MOTU/Apogee stream-group issues. Recommendation: "upgrading your Mac to Tahoe (26.1 or higher)" — [Rogue Amoeba blog, Nov 2025](https://weblog.rogueamoeba.com/2025/11/)
- **macOS 27 regression** (thread created Sept 2026):
  - A Multi-Output Device spanning two display-audio endpoints (HDMI+DP, DP+DP, or HDMI+USB-C) fails with error 1937010544 = `'stop'` (`kAudioHardwareNotRunningError`), logging "could not establish a timeline after waiting 10000000 microseconds".
  - Reported on 27.0.1 and 27.2; worked on 26. Filed as FB25041393; no Apple reply.
  - Workarounds: one display only, pairing with built-in or USB output, toggling the sample rate, 16-bit/48 kHz.
  - Restarting coreaudiod or rebooting does not help.
  - Source: [Apple Developer Forums 845929](https://developer.apple.com/forums/thread/845929)
- **Roon**: "Failed to Initialize when Switching Sample Rates on MacOS Tahoe [Ticket in]". Playback fails when switching between 44.1, 96 and 192 kHz on 26.1; a fix was mentioned in a changelog, but 192 kHz switching still failed for some users — [Roon Community](https://community.roonlabs.com/t/failed-to-initialize-when-switching-sample-rates-on-macos-tahoe-ticket-in/306818?page=9)
- **Tahoe glitches, distortion and crackling**: users report progressive distortion with app and system sample-rate mismatches. Restarting coreaudiod or changing the format in Audio MIDI Setup helps only briefly — [Apple Community 256140785](https://discussions.apple.com/thread/256140785); [Apple Community 256306733](https://discussions.apple.com/thread/256306733)
- A USB audio device showed 0 Hz in Audio MIDI Setup on macOS 26 betas — [Apple Developer Forums 794599](https://developer.apple.com/forums/thread/794599)
- "macOS 26.0 Tahoe + Xcode 26.0.1 Simulator causes system-wide audio distortion" (thread title) — [Apple Developer Forums 802289](https://developer.apple.com/forums/thread/802289)
- Format not retained after reboot (24/32-bit set in Audio MIDI Setup) — [Apple Community 254979603](https://discussions-jp-prz.apple.com/thread/254979603)
- **coreaudiod restarts** require clients to re-establish cached state and listeners (`kAudioHardwarePropertyServiceRestarted`). Background Music's installer restarts coreaudiod, and its README tells users to switch output in System Settings if it crashes — [Apple: kAudioHardwarePropertyServiceRestarted](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertyservicerestarted); [BackgroundMusic README](https://github.com/kyleneideck/BackgroundMusic)
- **Aggregates**: `kAudioDevicePropertyProcessMute` "does not apply to aggregate devices" (verified in MacOSX27.0.sdk header) — [Apple: kAudioDevicePropertyProcessMute](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertyprocessmute)
- **OS-update breakage of non-public mechanisms**:
  - LosslessSwitcher v1 stopped working after 15.3.1; v2 requires admin for log access.
  - MonitorControl's native-OSD value display is broken on Tahoe.
  - NoiseBuddy is broken on recent macOS.
  - boring.notch needed MediaRemoteAdapter for Now Playing on macOS 15.4+.
  - Sources: [LosslessSwitcher](https://github.com/vincentneo/LosslessSwitcher); [MonitorControl](https://github.com/MonitorControl/MonitorControl); [NoiseBuddy](https://github.com/insidegui/NoiseBuddy); [boring.notch](https://github.com/TheBoredTeam/boring.notch)
- **Sample-rate switch interruptions**: "There may be short interruptions to your audio playback" during switches, and frequent querying "may accelerate battery usage" on MacBooks — [LosslessSwitcher README](https://github.com/vincentneo/LosslessSwitcher)
- **Bluetooth codec knobs** silently stopped working on Sonoma/Sequoia (see Section 3) — [Apple Community 256151211](https://discussions.apple.com/thread/256151211)

### Inferences
- Design rules:
  1. Key everything by UID and re-resolve IDs on every device-list change.
  2. Treat `ServiceRestarted` as a full re-init.
  3. Verify after every write: read back `NominalSampleRate` and `PhysicalFormat`, because writes can be accepted and then reverted or fail asynchronously. Surface failures in the notch.
  4. Debounce sample-rate switching and avoid switching mid-track.
  5. Exclude aggregate and multi-output devices from features that rely on process mute, and warn about the macOS 27 display multi-output bug.
  6. Isolate every private-API feature (codec readout, AirPods modes, native OSD) behind a feature flag with OS-version gating.
- Tahoe 26.1+ is the realistic minimum OS. Rogue Amoeba's guidance and boring.notch's macOS 15.6+ floor both point that way.

### Gaps
- No Apple release notes for 26.x/27.x audio fixes were located; evidence is vendor and community reports.
- I found no source quantifying how often `coreaudiod` crashes on Tahoe or macOS 27, only anecdotal restart advice.
- Whether macOS 27 fixed the Roon/Tahoe 192 kHz switching failure is unknown.
