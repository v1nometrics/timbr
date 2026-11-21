# Market, benchmarks, user voice and platform/distribution constraints for an open-source audiophile notch app on macOS (as of 21 Nov 2026)

Method note: the GitHub figures (stars, license SPDX, created and last-push dates, open-issue counts, top issues by reactions) were pulled live from the GitHub REST API on 2026-11-21 through `gh api`. Each one links to its repo. I could not read Reddit, because the JSON and HTML endpoints were blocked for automated clients. Search returned no ASR or Head-Fi threads, so the user voice below comes from GitHub issue trackers, Apple Community, MacRumors and RME forums, and Hacker News (Algolia API). Vendor pages that write about competitors are marked **[vendor-on-competitors]**.

---

## 1. Commercial benchmarks: features, pricing, technology, business model

### Takeaway
SoundSource 6 ($49 one-time, macOS 15–27, v6.2.0 on 11 Nov 2026) is still the best-in-class commercial benchmark for per-app volume, per-app output, per-app and system effects, Headphone EQ and output groups. Its main limits are a 10-band graphic EQ and no parametric editor. The rest of the market splits into two groups. The first is EQ-first utilities: eqMac Pro, Boom 3D, Sound Control, and newer process-tap EQs such as EQBase and Sonance EQ. The second is player-internal DSP: Audirvana, Roon, Fidelia and Colibri, which only processes audio played inside that player. A 2026 wave of driverless "process tap" apps has made per-app volume a commodity feature.

### Cited Findings

**Rogue Amoeba (SoundSource / Audio Hijack / Loopback)**
- SoundSource 6 was announced on 4 Dec 2025 at **$49** for new users and **$25** to upgrade. New features: output groups (audio to several devices at once), built-in AirPlay streaming, an Audio Devices window, Quick Configs and a preferred device order. — [Rogue Amoeba press release](https://www.rogueamoeba.com/company/lists/archives/press/2025-12-soundsource-600.html)
- The current SoundSource feature set, per the product page: per-app volume, louder/softer/mute; per-app output routing; per-app **10-band EQ** and **Audio Unit** hosting; system-wide 10-band EQ plus AUs; built-in effects "Headphone EQ", "Magic Boost" and "Volume Overdrive"; output groups, including synced AirPlay groups; input level; sample-rate adjustment for Output, Input and Sound Effects devices; **"Super Volume Keys"** that make keyboard volume keys work on HDMI/DisplayPort outputs without hardware volume; menu-bar UI; Shortcuts automation. Download is **v6.2.0, released 11 Nov 2026, for macOS 15 through 27**. The trial is the full app with limitations. The page lists no parametric EQ. — [rogueamoeba.com/soundsource](https://rogueamoeba.com/soundsource/)
- Version 6.x point releases: 6.0.3, 6.0.4, 6.0.5, 6.1 ("dozens of refinements"), then 6.1.2 with preliminary macOS 27 beta support. — [TidBITS 6.1 watchlist](https://tidbits.com/watchlist/soundsource-6-1/); [Rogue Amoeba blog](https://weblog.rogueamoeba.com/)
- Rogue Amoeba states that "all of our products support" macOS 27 ("Golden Gate"). Audio Hijack 4.6 (27 Aug 2026) added macOS 27 support and Transcribe updates. — [Rogue Amoeba blog, Audio Hijack 4.6](https://weblog.rogueamoeba.com/2026/08/27/audio-hijack-4-6-is-now-available/)
- Capture technology: the older **ACE** engine needed an Apple allowlist exception from macOS 11 to 14, and on Apple silicon a "20-step" install that included Reduced Security. By the end of 2024 the new backend, **ARK**, "powers all of our audio capture apps on MacOS 14 and higher". Audio Hijack, Airfoil and Piezo need no installer, only the "System Audio Access" permission. **Loopback and SoundSource still install an "ARK plugin" that requires an administrator password.** The post says no extensions, no Security Policy changes and no restarts are needed. — [Rogue Amoeba, "The Developers Who Came In From the Cold" (13 Dec 2024)](https://weblog.rogueamoeba.com/2024/12/13/the-developers-who-came-in-from-the-cold/)
- Licensing model: one single-user license covers all of a user's personally owned Macs. Refunds within 14 days. Trials for everything. Paddle checkout. The store page shows no prices. — [Rogue Amoeba store](https://rogueamoeba.com/store/)
- Rogue Amoeba also licenses its capture technology to other developers, for example "ACE for Audiolens" from iZotope. — [Rogue Amoeba licensing](https://www.rogueamoeba.com/licensing/); [iZotope support](https://support.izotope.com/hc/en-us/articles/7209907906589-Installing-ACE-for-Audiolens-on-macOS)

**eqMac (Bitgapp): freemium EQ with its own driver**
- Free tier: bass/mid/treble, a 10-band EQ, "Headphone Presets" for "4600+ Headphones", Super Presets, volume boost above 100%, every device type (BT, AirPlay 1, USB, HDMI, TB, Aggregate, Multi-Output). Pro: Expert EQ (unlimited parametric bands, Q, filter types, spectrum analyzer), **App Mixer (per-app volume)**, Spatial Audio, separate L/R EQ, AU hosting. Pricing: **Pro $3/month or $30/year; Lifetime $40 (one Mac)**. "Future Pro features might require a partial upgrade." macOS 10.13+. — [eqmac.app](https://eqmac.app)
- Release cadence in 2026: v1.8.13–1.8.15 (Apr 2026; v1.8.15 fixed "AirPods causing eqMac to go into a device swap loop and freezing"); v1.9.0 (11 Sep 2026); **v1.9.1 (13 Sep 2026) "Completely removed Helper which caused issues on macOS 27", experimental AirPlay (macOS 14.2+)**; **v1.9.2 (19 Sep 2026) "Allowing to select which Capture method to use per device (macOS 14.2+ only)"** and "Fixed Volume Mixer not working sometimes". — [GitHub releases, bitgapp/eqMac](https://github.com/bitgapp/eqMac/releases)
- In other words, eqMac now offers a per-device choice of capture method on 14.2+, which suggests a process-tap path next to its original driver. The vendor's EULA and pricing apply to the binaries. — [eqMac v1.9.2 notes](https://github.com/bitgapp/eqMac/releases)

**Boom 3D (Global Delight)**
- Mac App Store listing: "Free · In-App Purchases", macOS 10.14+. — [App Store](https://apps.apple.com/app/apple-store/id1233048948)
- Also sold on Steam ($19.99 list) and through Setapp (from $14.99/month, macOS 11+). — [Steam](https://store.steampowered.com/app/1133640); [Setapp](https://setapp.com/how-to/boost-mac-volume-with-boom-3d)
- About $17 (list $49.99), a 31-band graphic EQ, "5,000+ profiles", no parametric EQ; criticised as "colours the sound rather than correcting it". — [eqbase.app comparison](https://eqbase.app/compare/best-mac-equalizer/) **[vendor-on-competitors]**

**FxSound**
- Open source under **AGPL-3.0** (4,769 stars, pushed 17 Nov 2026). The README says it is "built for Windows PC's". Build instructions are Windows SDK/Visual Studio only, and it uses JUCE under AGPL v3. **No macOS version.** — [GitHub fxsound2/fxsound-app](https://github.com/fxsound2/fxsound-app)

**Sound Control (Static Z), EQBase, Sonance EQ, Pragmatic Audio PEQ (newer EQ-first utilities)**
- Sound Control: **$30 once**, free trial, macOS 14.6+, 10- or 31-band graphic plus Apple's AUNBandEQ, "thousands of AutoEQ profiles", per-app EQ and output routing, AU hosting. Drawback: "on macOS 14, a one-time trip to Recovery mode to allow its system extension". — [eqbase.app comparison](https://eqbase.app/compare/best-mac-equalizer/) **[vendor-on-competitors]**
- EQBase (self-description): free with no time limit; **Pro $4.99/month, $39.99/year, $79.99 once**; macOS 14.4+; **process tap, no driver**; 24-band parametric with 7 filter types, dynamic and linear-phase; headphone correction for "6,033 models (8,666 corrections)"; AU hosting. — [eqbase.app](https://eqbase.app/compare/best-mac-equalizer/) **[vendor self-claims]**
- Sonance EQ: free, **Pro $9.99 once**, macOS 14.4+, process tap; parametric, linear-phase and Mid-Side EQ plus 8,850 headphone profiles in Pro; app volume mixer. — [eqbase.app comparison](https://eqbase.app/compare/best-mac-equalizer/) **[vendor-on-competitors]**
- Pragmatic Audio PEQ: the Mac version installs a virtual output called "Pragmatic EQ" (so it is driver-based) and is in "early release". The iOS version needs iOS 27. — [Pragmatic Audio, Oct 2026](https://www.pragmaticaudio.com/articles/2026/10/pragmatic-audio-peq/)

**Sonarworks SoundID Reference**
- The Speakers & Headphones edition is $249 at Sweetwater and Multichannel is $499. Pluginfox lists Speakers & Headphones from $89 to $249 and the Headphones edition from $39 to $99. Prices vary by retailer and promotion. — [Sweetwater](https://www.sweetwater.com/store/detail/SoundIDRefStu); [Pluginfox](https://pluginfox.com/collections/sonarworks/plugins)

**Player-internal DSP (audiophile players)**
- Audirvana Studio, subscription: **€7.99/month or €79.99/year** from 6 Jan 2026, up from €6.99 and €69.99; USD figures exclude tax. — [Audirvana help center](https://help.audirvana.com/en/support/solutions/articles/202000051017)
- Audirvana Origin, perpetual: **$149.99**, or $119.99 for previous owners and Studio subscribers. Prices did not change in Jan 2026. The DSP "Signal Processing Suite" is a paid option for Origin (bundle 219.99 incl. VAT). Studio includes convolution as standard. — [Audirvana Origin FAQ](https://help.audirvana.com/en/support/solutions/articles/202000051018); [Audirvana price page](https://audirvana.com/price/); [issoh.co.jp review](https://www.issoh.co.jp/md/tech/11566)
- Roon: the lifetime price historically rose from $499 to $699. A third-party tracker (verified 16 Oct 2026, AI-structured) lists **$829.99 lifetime or $12.49/month**, which I could not confirm on roon.app. — [Roon community thread](https://community.roonlabs.com/t/lifetime-price-increase-499-699/84339); [PulseSignal tracker](https://getpulsesignal.com/compare/roon-vs-viki) (unverified aggregator)
- Fidelia (Audiofile Engineering, Mac App Store only): the App Store lists IAP "Full License $99.99" and "Network & Server $49.99". TidBITS (6 Jul 2026) reports a 14-day trial and an introductory **$49.99 rising to $69.99**. **The two sources conflict.** — [App Store](https://apps.apple.com/app/id416135376); [TidBITS](https://tidbits.com/2026/07/06/appbits-fidelia-offers-audiophiles-precise-control-over-music-playback/)
- Colibri: **$19.99** on the Mac App Store (€22.99 in Portugal). — [App Store](https://apps.apple.com/us/app/colibri/id1178295426?ls=1&mt=12)

**Mac App Store per-app volume apps (signals that process taps can ship through MAS)**
- VolumeHub (Mac App Store) offers per-app volume from 0% to 100% using Apple's "Audio Tap API". Other MAS listings include "Volume Mixer" and "FaBar". — [App Store VolumeHub](https://apps.apple.com/us/app/volumehub/id6758415969); [Volume Mixer](https://apps.apple.com/app/id6759479050); [FaBar](https://apps.apple.com/app/fabar/id6789618146)

### Feature / technology matrix (synthesised from the citations above; "?" = not verified)

| App | Model / price (Nov 2026) | Tech approach | Per-app vol | Per-app output | Multi-output | System EQ | Parametric | Headphone/AutoEQ presets | AU hosting | Min macOS |
|---|---|---|---|---|---|---|---|---|---|---|
| SoundSource 6.2 | $49 once ($25 upg) | ARK plugin (admin pw) + capture | Yes | Yes | Yes (groups, AirPlay) | 10-band | No | Headphone EQ (count ?) | Yes | 15 |
| eqMac 1.9.2 | Free / $3 mo / $30 yr / $40 life | Own driver, + per-device capture method on 14.2+ | Pro | No* | Uses OS Multi-Output | 10-band free | Pro (unlimited) | 4,600+ | Pro | 10.13 |
| Boom 3D | IAP / ~$17–50 / Setapp | ? (system enhancer) | ? | ? | ? | 31-band graphic | No | 5,000+ | ? | 10.14/11 |
| Sound Control | $30 once | System extension (Recovery on macOS 14) | Yes | Yes | ? | 10/31-band | AUNBandEQ | AutoEQ | Yes | 14.6 |
| EQBase | Free / $4.99 mo / $39.99 yr / $79.99 | Process tap | ? | Pro routing | ? | Yes | 24-band, dyn, lin-phase | 6,033 models | Yes | 14.4 |
| Sonance EQ | Free / $9.99 | Process tap | Yes | ? | ? | Yes | Pro | 8,850 (Pro) | ? | 14.4 |
| FineTune (OSS) | Free, GPL-3.0 | Process tap | Yes (+4x) | Yes | Yes | 10-band per app | No (imports ParametricEQ.txt) | AutoEQ search | No | 15 |
| Audirvana / Roon / Fidelia / Colibri | Subscription or perpetual | Player-internal | n/a | n/a | n/a | Own playback only | Yes (Audirvana SPS / Roon) | ? | Audirvana: AU/VST | ? |

*eqbase lists "no per-app output routing" for eqMac **[vendor-on-competitors]** — [eqbase.app](https://eqbase.app/compare/best-mac-equalizer/)

### Inferences
- The gap at the top of the market is **parametric/AutoEQ-grade headphone correction combined with per-app volume, per-app routing and multi-output, in one fast surface**. SoundSource has the routing but only a 10-band graphic EQ. eqMac Pro and EQBase have deep EQ but weaker or unclear per-app routing. Audirvana and Roon have the best DSP but only for their own playback.
- Prices cluster around $30–50 one-time (SoundSource, Sound Control, eqMac Lifetime) or $3–5/month (eqMac, EQBase). A free OSS app competes against $0–49.
- Subscription fatigue is visible in Roon and Audirvana pricing changes. Two of the most popular commercial tools (SoundSource, Sound Control) are one-time purchases.

### Gaps
- Audio Hijack and Loopback list prices for Nov 2026 were not shown on the store page. Training-era figures (Audio Hijack ~$64, Loopback ~$109) are **unverified**.
- SoundSource Headphone EQ: preset count and AutoEq provenance, and what Magic Boost does technically, were not on the product page.
- I found no 2026 sources for Sound Siphon (Static Z), Hosting AU (Hosting AU / Hosting Labs) or Equalizer Pro, so their status and pricing are unverified.
- SoundID **Listen** (the consumer product): no pricing or status found.
- "Doppler": no search result matched a Mac audiophile player of that name. It may be the Brushed Type "Doppler" music app, which I did not verify.
- Apple Music's built-in EQ: I found no current source on its band count or scope. From memory, it is a 10-band graphic EQ that applies only inside Music.app; treat that as unverified.
- Roon DSP (PEQ, convolution, headroom, crossfeed) and current official pricing: roon.app/pricing returned no plan details.

---

## 2. Open-source players: status, stars, licenses, technology

### Takeaway
The open-source field changed in 2026. **FineTune** (GPL-3.0, created Jan 2026, about 10.2k stars) is the de-facto free SoundSource alternative: driverless process taps, per-app volume, multi-output, routing, 10-band EQ and AutoEQ. Since mid-2026 dozens of small process-tap mixers and EQs have appeared, most under MIT. eqMac's public source is effectively frozen while its closed binaries keep shipping. BackgroundMusic (driver-based) is legacy. No open-source project combines a parametric/AutoEQ-grade EQ, per-app routing and a notch UI with real traction.

### Cited Findings

**GitHub snapshot (via GitHub API, 2026-11-21)**

| Repo | Stars | License (SPDX) | Created | Last push | Open issues | Notes |
|---|---|---|---|---|---|---|
| [ronitsingh10/FineTune](https://github.com/ronitsingh10/FineTune) | 10,229 | GPL-3.0 | 2026-01-18 | 2026-07-09 (v1.9.0) | 248 | Process tap; macOS 15+ |
| [kyleneideck/BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic) | 19,401 | GPL-2.0 | (2016) | 2026-06-10 | 545 | Virtual driver |
| [ExistentialAudio/BlackHole](https://github.com/ExistentialAudio/BlackHole) | 20,088 | GPL-3.0 (API shows NOASSERTION) + commercial license | (2019) | 2026-11-07 | 7 | Loopback HAL driver |
| [bitgapp/eqMac](https://github.com/bitgapp/eqMac) | 6,836 | Apache-2.0 | (2017) | 2026-09-19 (release) | 88 | Master code commits stop at Feb 2023 |
| [mattingalls/Soundflower](https://github.com/mattingalls/Soundflower) | 9,029 | MIT | — | 2024-12-07 | 7 | Legacy kext-era |
| [vincentneo/LosslessSwitcher](https://github.com/vincentneo/LosslessSwitcher) | 2,029 | GPL-3.0 | — | 2026-06-07 | 73 | Apple Music sample-rate switching |
| [jaakkopasanen/AutoEq](https://github.com/jaakkopasanen/AutoEq) | 16,476 | MIT | — | 2026-11-05 | 244 | Headphone EQ database/tool |
| [HEnquist/camilladsp](https://github.com/HEnquist/camilladsp) | 1,110 | GPL-3.0 | — | 2026-11-12 | 45 | IIR/FIR engine |
| [HEnquist/camillagui-backend](https://github.com/HEnquist/camillagui-backend) / [camillagui](https://github.com/HEnquist/camillagui) | 60 / 17 | GPL-3.0 | — | 2026-11-02 / 10-31 | — | Web GUI (cross-platform) |
| [insidegui/AudioCap](https://github.com/insidegui/AudioCap) | 513 | BSD-2-Clause | — | 2025-08-07 | 1 | Process-tap sample code |
| [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) | 311 | BSD-3-Clause | — | 2026-11-20 | — | Now Playing workaround for 15.4+ |
| [lishuangqiang/mixbar](https://github.com/lishuangqiang/mixbar) | 314 | MIT | 2026-11-15 | 2026-11-15 | — | Process-tap per-app mixer |
| [belugaming/tapline](https://github.com/belugaming/tapline) | 5 | GPL-3.0 | 2026-10-10 | 2026-11-03 | — | System **parametric EQ** + per-app mixer + AutoEQ + squig.link |
| [jatinindia/MacEQ](https://github.com/jatinindia/MacEQ) | 14 | MIT | 2026-07-15 | 2026-11-01 | — | Process-tap system EQ, volume keys keep working |
| [fc79/RoomEQ](https://github.com/fc79/RoomEQ) | 1 | GPL-3.0 | 2026-11-01 | 2026-11-19 | — | REW room EQ, per-app exclusion, "no sample-rate conversion" |
| [pimmesz/Loudini](https://github.com/pimmesz/Loudini) | 3 | MIT | 2026-07-15 | 2026-10-15 | — | Software master volume for DACs/interfaces that ignore volume keys |
| [gokturkgocen/EqLume](https://github.com/gokturkgocen/EqLume) | 5 | NOASSERTION | 2026-07-03 | 2026-09-16 | — | Auto genre-detect EQ presets |
| [CJStanfield/CoreAudioTapKit](https://github.com/CJStanfield/CoreAudioTapKit) | 4 | MIT | 2026-07-02 | 2026-09-07 | — | Tap lifecycle library |
| [burghr/MacMixer](https://github.com/burghr/MacMixer) | 7 | MIT | 2026-06-09 | 2026-11-09 | — | "no driver, no microphone indicator" |
| [PabloJuGo/OpenMixer](https://github.com/PabloJuGo/OpenMixer) | 0 | GPL-3.0 | 2026-10-23 | 2026-10-25 | — | Per-app vol, EQ, AU, routing, meters |
| [Sakuleta/tapmix](https://github.com/Sakuleta/tapmix) | 0 | MIT | 2026-10-27 | 2026-10-28 | — | 0–200%, limiter; per-process so no per-tab |
| [mianjazibali/fader](https://github.com/mianjazibali/fader) | 0 | MIT | 2026-08-21 | 2026-08-29 | — | Synced with volume keys |
| [tgkd/buried-anchor](https://github.com/tgkd/buried-anchor) | 0 | none | 2026-08-13 | 2026-11-08 | — | 0–150% |
| [elad12390/AppVolume](https://github.com/elad12390/AppVolume) | 0 | MIT | 2026-10-08 | 2026-10-08 | — | |
| [troazz/swara](https://github.com/troazz/swara) | 2 | none | 2026-07-08 | 2026-07-15 | — | |
| FineTune forks: [FineTunePro](https://github.com/djbob2000/FineTunePro), [Liquid Glass version](https://github.com/gudelgado1/FineTune-LiquidGlass-Version), [finetune-app-only](https://github.com/westo27/finetune-app-only) | 0–2 | GPL-3.0 | 2026 | 2026 | — | |
| [wait2050/MonoSplit](https://github.com/wait2050/MonoSplit) | 1 | 0BSD | 2026-11-10 | 2026-11-10 | — | Mono crossover + EQ with a FineTune bridge |

- A GitHub search for "process tap" repos created after 1 Jan 2024 returns about 30 macOS audio projects, nearly all created between June and November 2026. They include mixers, EQs, recorders, captioners (daformat/subtitles, spokemark, notchsub) and level meters. — [GitHub search API results (2026-11-21)](https://github.com/search?q=process+tap+macos&type=repositories)

**FineTune details (README)**
- Per-app volume, mute and 2x/3x/4x boost; pinned and ignored apps (ignoring an app "tears down the audio tap"); global per-app volume hotkeys that target "whichever is currently making sound"; **multi-device output**; per-app routing; device priority and auto-restore; **10-band EQ with 20 presets and user presets per app**; **AutoEQ headphone correction** (search profiles or import ParametricEQ.txt); **ISO 226:2023 loudness compensation**; "smart volume backend" (hardware, DDC or software volume per device), with keys that keep working on USB interfaces and HDMI "where macOS's own keys are greyed out"; device inspector with a sample-rate picker and a hog-mode banner; URL schemes; Homebrew cask; Ko-fi tips. Requires macOS 15+ and the "Screen & System Audio Recording" permission. — [FineTune README](https://github.com/ronitsingh10/FineTune)
- Release cadence: v1.5 (8 Apr), v1.6 (23 Apr), v1.7 (14 May), v1.8 (14 Jun), v1.9 (9 Jul 2026). There has been no release in the 4+ months since. — [FineTune releases](https://github.com/ronitsingh10/FineTune/releases)

**eqMac status**
- The last five commits on `master` are "Update issue templates" (2 Nov 2025) and README edits (Feb 2023). Releases v1.8.13 to v1.9.2 (Apr to Sep 2026) were published as binaries. — [eqMac commits](https://github.com/bitgapp/eqMac/commits/master); [eqMac releases](https://github.com/bitgapp/eqMac/releases)
- Third-party listings disagree about activity. Desktop Insights showed v1.8.12 / "last updated October 29, 2025", while Softpedia lists 1.9.1/1.9.2 in Sep 2026. — [Desktop Insights](https://desktopinsights.com/apps/eqmac); [AlternativeTo](https://alternativeto.net/software/eqmac/)
- Other OSS EQs per a vendor comparison: **CoreEQ** (Apache-2.0, process tap, macOS 14.2, 11-band ISO + up to 16 parametric, AutoEq, "not notarized; first appeared July 2026"); **Equaliser** (GPL-3.0, 1–64 bands, Apple silicon + macOS 15 only, not notarized). — [eqbase.app](https://eqbase.app/compare/best-mac-equalizer/) **[vendor-on-competitors]**
- SoundMax is a free OSS 10-band system EQ that **requires BlackHole**, macOS 13+. — [GitHub snap-sites/SoundMax](https://github.com/snap-sites/SoundMax)
- Recent Show HN launches: "eqMini – Open-source macOS equalizer with per-app controls" (15 Oct 2026, 1 point); "HiFidelity – native macOS offline audiophile music player" (20 Dec 2025, 4 points / 7 comments); "I wrote a macOS C++ audio driver to fix HDMI volume controls" (18 Mar 2026, 6 points). — [HN 50111236](https://news.ycombinator.com/item?id=50111236); [HN 46334191](https://news.ycombinator.com/item?id=46334191); [HN 47422178](https://news.ycombinator.com/item?id=47422178)

### Inferences
- **Per-app volume via process taps is now a commodity.** At least 15 OSS implementations appeared in 2026, many MIT-licensed, which gives a permissive code base to learn from or reuse. Differentiation has to come from EQ fidelity, routing robustness (AirPods, Bluetooth, AirPlay, OBS and Discord interplay), the notch UX and audiophile features (bit-perfect awareness, sample-rate handling, DAC volume).
- FineTune is the incumbent to beat in OSS. Reaching 10k stars in under a year shows strong demand, but development has paused since July and 248 issues are open, which leaves an opening. Its GPL-3.0 license constrains reuse (see section 6).
- **Per-tab volume is unsolved.** Process taps work per process, and tapmix says explicitly that browser tabs cannot be controlled separately. Chromium tabs share renderer/audio-service processes, so per-tab control likely needs a browser extension. — [tapmix](https://github.com/Sakuleta/tapmix)
- eqMac's "open source" status is mostly historical: the public code is from 2023 and the shipping product is a closed freemium binary.

### Gaps
- I did not verify a native macOS CamillaDSP GUI. CamillaGUI is a cross-platform web GUI (GPL-3.0), and I found no Mac-native wrapper.
- No "Sleeve-like" OSS now-playing apps were profiled beyond the lyrics apps in section 3 (Sleeve itself is commercial and was not checked).
- Download counts (for example FineTune release downloads) were not pulled.

---

## 3. Notch apps that already touch audio — is anyone doing "audiophile notch"?

### Takeaway
The big notch apps (boring.notch, Atoll, NotchNook, Alcove, MediaMate) only do **now-playing, transport controls, a visualizer and a volume HUD**. None offers system EQ, AutoEQ or per-app routing. The audiophile-adjacent attempts are tiny: Liland (36 stars, no license; HTDemucs stems plus a 5-band EQ, Portuguese UI), R9-EQ (closed source, calls itself a "notch equalizer"), and a few boring.notch forks with per-app volume (ledge, volnotch, NekoNotch, all 1–3 stars). **No one is doing a credible audiophile notch app yet.**

### Cited Findings
- **boring.notch**: 11,421 stars, **GPL-3.0**, pushed 20 Nov 2026. Music control center with a visualizer, calendar, file shelf with AirDrop, "complete MacOS HUD replacement" (volume, brightness, backlight). Uses **MediaRemoteAdapter** to get Now Playing on macOS 15.4+. — [GitHub](https://github.com/TheBoredTeam/boring.notch)
- **Atoll** ("Dynamic Island for macOS"): 5,322 stars, **GPL-3.0**, pushed 21 Nov 2026. Media controls for Apple Music, Spotify and Cider; Live Activities (media, Focus, screen recording, privacy indicators, battery); lock-screen widgets; a live music visualizer adapted from rtaudio. Its core is **derived from boring.notch** ("foundational codebase… Major architectural patterns… adapted"). Permissions: Accessibility, Camera, Calendar, Screen Recording, Music. — [GitHub](https://github.com/Ebullioscopic/Atoll)
- **Liland** (the HTDemucs notch project; repo `sacis/Liland`): 36 stars, **no license file** (default "all rights reserved"), created 5 Oct 2026, pushed 21 Nov 2026, macOS 14+, 20 languages. It reads Spotify and Music through AppleScript. For Deezer, YouTube and browsers it uses a "NowPlayingHelper" that asks the system `perl` to read Now Playing, adapted from mediaremote-adapter (BSD-3). The README warns this breaks if Apple closes the loophole. Its "avançado" mode: isolate **voice, guitar, bass and drums** using **HTDemucs (including htdemucs_6s) converted to Core ML** on Apple silicon, with a heuristic mid/side estimate on Intel; a **5-band EQ (80 Hz–10 kHz, ±12 dB)**; pitch shift of ±6 semitones. In this mode "Liland plays the music, not the app", adding **~0.3 s latency** (1/8 s on Intel) and another ~0.1 s for pitch, so lip-sync drifts in video. The audio-reactive equalizer bars need macOS 14.4 plus the audio permission. It is distributed unsigned, so users must click "Open Anyway". — [GitHub sacis/Liland README](https://github.com/sacis/Liland)
- **R9-EQ**: the repo describes itself as "native macOS system-wide notch equalizer", with "source is private". 10-band EQ plus a parametric PRO mode, and a "Virtual Driver Configuration studio" for designing hybrid IEM driver stacks. Cross-platform (macOS 14.4+, Windows, Linux beta). Requires "System Audio Recording". Installed with `curl | bash`. 0 stars. — [GitHub XPro-Gamer-Rhine/R9-EQ-app](https://github.com/XPro-Gamer-Rhine/R9-EQ-app)
- Notch apps with per-app volume: **ledge** ("notch UI + per-app volume mixer", **GPL-3.0 fork of boring.notch**, 1 star); **volnotch** ("per-app volume mixer in a side notch", MIT, 3 stars); **NekoNotch** (GPL-3.0, per-app audio mixer, 2 stars); **dynamic-island** by QUBITABHAY (MIT, media plus volume mixer). — [ledge](https://github.com/lsuryatej/ledge); [volnotch](https://github.com/simplym7md/volnotch); [NekoNotch](https://github.com/1zumiii/NekoNotch); [dynamic-island](https://github.com/QUBITABHAY/dynamic-island)
- Other music-in-notch projects: NotchIsland ("music with a live equalizer"), MacNotchAudioPlayer (MIT, 10 stars), lyrimuse (GPL-3.0, 447 stars, word-by-word lyrics with Dynamic Island), Lyrics-Plus (MIT, 59 stars), MacIsland (MPL-2.0, 53 stars), Pulse (MIT, a menu-bar Liquid Glass visualizer with a live 6-band display via process tap). — [NotchIsland](https://github.com/theoron-apps/NotchIsland); [MacNotchAudioPlayer](https://github.com/metraakladap/MacNotchAudioPlayer); [lyrimuse](https://github.com/Yudaotor/lyrimuse); [Lyrics-Plus](https://github.com/afeibukaixin/Lyrics-Plus); [MacIsland](https://github.com/BadRat-in/MacIsland); [Pulse](https://github.com/infarmor/Pulse)
- Commercial notch apps (prices conflict across mostly affiliate roundups): **NotchNook** ~$24–30 one-time or ~$3/month, productivity-focused; **Alcove** ~$14 one-time (another source says it costs slightly more than NotchNook), visuals and animation focused; **MediaMate** ~$5–7 one-time, music controls only. — [MacUpdate comparison](https://www.macupdate.com/comparisons/notchnook-vs-alcove-whats-the-best-macbook-notch-app-in-2026); [MacObserver](https://www.macobserver.com/tips/round-ups/notchbook-vs-alcove-what-macbook-notch-app-is-actually-worth-using-in-2026/)
- Notchy ships a pill-style island for any Mac on macOS 13+ and markets it as an alternative to buying the OLED MacBook Pro. — [notchy.dev](https://notchy.dev/macos-dynamic-island/)

### Inferences
- The "audiophile notch" niche is empty in practice. Mainstream notch apps treat audio as now-playing plus a decorative visualizer, and the few with per-app volume are weekend forks. A notch-native app with **per-app volume + multi-output + parametric/AutoEQ + device/sample-rate status** would be first in its category.
- Liland's stem separation is a novelty with a real cost (0.3 s latency, the app replays the audio). It is not a fidelity feature and is not reusable without a license from the author.
- Most notch codebases (boring.notch → Atoll → ledge) are **GPL-3.0**, so forking them for the UI shell imposes GPL.

### Gaps
- I could not locate the LinkedIn post that presented Liland. The repo was identified by name and its HTDemucs feature matches the description.
- I could not confirm official pricing pages for NotchNook, Alcove or MediaMate.

---

## 4. User voice: complaints and wishes in macOS audio

### Takeaway
The recurring pain points are: (1) no native per-app volume or system EQ, with Apple Community pushback; (2) **reliability of the workarounds**: crackling, distortion, a short full-volume blast before the tap engages, AirPods auto-switching broken, double audio in OBS and Discord; (3) **OS updates breaking things**: eqMac on Catalina and macOS 27, boring.notch Now Playing on 15.4; (4) **privacy indicators and permissions**: the orange mic dot with driver-based tools; (5) **Apple Music not switching sample rate** on Mac; (6) DAC/HDMI volume keys greyed out; (7) wanted features: AirPlay, balance, per-device profiles, save/load presets, parametric EQ on any device.

### Cited Findings

**GitHub issue trackers (top issues by reactions; reactions / comments)**
- FineTune: "AirPlay Support?" (15 / 2, open); "**FineTune Prevents AirPods from Automatically Switching to Other Apple Devices**" (9 / 3, open, plus a duplicate with 5 reactions); "FR: add balance option" (7 / 3, open); "Can't apply parametric EQ to 'External Headphones'" (7 / 4); "Ability to Save and Load Custom EQ Presets" (8); "Crashes immediately when a volume key is pressed (v1.8.0)" (5). Most-commented open issues: "**loudness equalization causing glitches**" (28 comments), "Doesn't Open" (15), "**crackling sounds**" (11), "System-wide EQ to have all-in-one solution" (9), "Initial audio playback bypasses EQ/Volume settings for a brief moment (Tap Initialization Delay)" (7), "Echo/Duplicated Audio while recording in OBS" (6), "Double audio when screen sharing on Discord" (6), "**Short blast of full volume before taking effect**" (6), "FaceTime Audio" (8). — [FineTune issues](https://github.com/ronitsingh10/FineTune/issues)
- eqMac (historical, mostly 2017–2022): "**Is this project dead? NO!**" (131 reactions, 2019); "Support for macOS Catalina" (71 / 53); "**Sound is crackling**" (47 / 73); "Add ability to **bypass eqMac for specific devices**" (29); "**Save different profiles per device**, switch when device connects" (25); "Switching between speaker/headphone… not responding" (20 / 34); "Weird pitch sliding" (20); "Periodic crackling" (15). — [eqMac issues](https://github.com/bitgapp/eqMac/issues)
- BackgroundMusic: "thanks for nothing" (31, open); "Big Sur" (25); "Cannot uninstall using brew on macOS 14.4" (24); "**Constant mic usage (orange dot in Monterey)**" (22); "Distorted audio on all output devices" (19); "**Per-application volume control not working for some apps**" (17); "Output sound crack on bluetooth earphone" (15); "Can you get this working without microphone access?" (12). — [BackgroundMusic issues](https://github.com/kyleneideck/BackgroundMusic/issues)
- boring.notch: "**Now Playing no longer working after updating to MacOS 15.4**" (54 reactions / 58 comments); several requests to disable the "jiggly wobbly" animation (26, 21, 21, 16); "Disable Notch UI in Fullscreen and on external displays" (14); "Liquid Glass" (11); "boring.notch AI" (9). — [boring.notch issues](https://github.com/TheBoredTeam/boring.notch/issues)

**Forums**
- Apple Community thread "**Can we have individual volume controls for each app please?**" (multi-page); replies argue per-app volume "is not a feature of macOS" and apps should handle their own volume. — [Apple Discussions 255099590](https://discussions.apple.com/thread/255099590)
- Sample rate: "Music on MacOS does not switch automatically the sample rate of the song that is playing"; Music "uses whatever [rate] the output device happens to be set at" and mismatched tracks are resampled. — [Apple Discussions 253867262](https://discussions.apple.com/thread/253867262); [Apple Discussions 255983083](https://discussions.apple.com/thread/255983083); MacRumors (2021): "the Apple Music app on macOS does not support automatic sample rate switching" the way iOS does — [MacRumors forum](https://forums.macrumors.com/threads/apple-music-app-on-macos-automatic-sample-rate-switching.2311864/); RME forum (2023) users disagree — [RME forum](https://forum.rme-audio.de/viewtopic.php?id=38219)
- LosslessSwitcher is the common fix (Darko.Audio, Apr 2022: "adds bit-perfect Apple Music playback"). Its developer warns of short interruptions while switching, and users report a pause between tracks. Users have asked for bit-depth switching to be optional for people relying on digital volume control. — [Darko.Audio](https://darko.audio/2022/04/losslessswitcher-adds-bit-perfect-apple-music-playback-to-macos/); [LosslessSwitcher](https://github.com/vincentneo/LosslessSwitcher); [discussion #62](https://github.com/vincentneo/LosslessSwitcher/discussions/62)
- DAC/HDMI volume keys: SoundSource sells "Super Volume Keys" for HDMI and DisplayPort outputs without hardware volume. FineTune says keys "keep working on USB interfaces and HDMI outputs where macOS's own keys are greyed out". Loudini exists for "Focusrite Scarlett and other fixed-level interfaces/DACs" that ignore volume keys. A Show HN author wrote a C++ driver "to fix HDMI volume controls". — [SoundSource](https://rogueamoeba.com/soundsource/); [FineTune](https://github.com/ronitsingh10/FineTune); [Loudini](https://github.com/pimmesz/Loudini); [HN 47422178](https://news.ycombinator.com/item?id=47422178)
- eqMac praise themes on Product Hunt (aggregated): preset library, flexible customisation, solid core. — [Product Hunt eqMac reviews](https://www.producthunt.com/products/eqmac-2/reviews)
- Hacker News engagement in this category is low. Mac EQ and mixer Show HNs in 2025–26 got 1–6 points. The 2017 "EqMac2: The Open Source Alternative to Boom 2/3D" got 2 points. — [HN Algolia search](https://hn.algolia.com/?q=macOS%20equalizer)

### Inferences
- **Reliability is the main battleground.** Users forgive missing features but abandon tools that crackle, blast at full volume, break AirPods handoff or double audio in calls and streams. An audiophile app should treat "never glitch, never blast, fail open" as a headline feature (Loudini already markets "fails open").
- **Per-device profiles that switch automatically** (headphone A gets AutoEQ profile A) have been requested since 2020 and remain a differentiator.
- OS-update fragility (Catalina, Big Sur, 14.4, 15.4, macOS 27) is the long-term trust problem. Relying only on public APIs (process taps) rather than drivers, helpers or private MediaRemote is a credible selling point.
- The orange mic indicator and "why does it need microphone access" complaints favour process taps, which use the "System Audio Recording Only" permission and no mic indicator (MacMixer claims "no microphone indicator").

### Gaps
- **Reddit** (r/macapps, r/audiophile, r/headphones, r/macsetups) could not be accessed (blocked for automated clients), so no direct quotes or frequency counts from Reddit.
- **Audio Science Review and Head-Fi**: search returned no relevant 2025–26 threads, so I have no direct quotes.
- Bluetooth codec complaints (AAC only, no LDAC/aptX on Mac) were not sourced in this pass.
- I found no source on complaints about SoundSource's price; its $25 upgrade fee is documented, but sentiment is not.

---

## 5. Platform and distribution constraints; Apple's moves and sherlock risk

### Takeaway
Since macOS 14.2/14.4, **Core Audio process taps** let a user-space app capture and re-render per-process audio with only the **"System Audio Recording Only"** TCC permission and no driver or admin password. Several such apps are already on the Mac App Store. Driver approaches (HAL plug-ins in /Library/Audio/Plug-Ins/HAL) need an admin password and Developer ID distribution. **MediaRemote (system Now Playing) has been closed to third parties since macOS 15.4**, and notch apps rely on fragile workarounds. Apple is shipping a **real Dynamic Island on the new OLED touch MacBook Pro** and **Live Activities in the menu bar in macOS 27.3**, open to third parties. That reduces the "notch" surface on new hardware and adds an official API. I found **no credible rumor** that Apple is building native per-app volume or a system EQ.

### Cited Findings
**Process taps and TCC**
- Process taps arrived in Core Audio in macOS 14.2 (`AudioHardwareTapping.h`, `API_AVAILABLE(macos(14.2))`). Many projects require 14.4+ for the permission flow. — [catap README](https://github.com/sbetko/catap); [AudioCap](https://github.com/insidegui/AudioCap)
- The prompt text comes from `NSAudioCaptureUsageDescription`, which must be added to Info.plist by hand. The grant appears under **Privacy & Security › "System Audio Recording Only"**. — [DGR Labs (Apr 2026)](https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html); [catap](https://github.com/sbetko/catap)
- "Core Audio taps do not add a separate system-audio-capture entitlement" for sandboxed apps (catap). AudioCap's sample still ships `com.apple.security.device.audio-input`. Whether the MAS sandbox needs that entitlement has not been verified. Process taps need a **signed binary**, and unsigned xcodebuild output cannot be tested end to end. — [catap](https://github.com/sbetko/catap); [AudioCap](https://github.com/insidegui/AudioCap); [DGR Labs](https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html)
- The common process-tap mixer design: one tap per app, a private aggregate device, and gain applied in a realtime callback. Tap granularity is per process, so browser tabs cannot be separated. — [tapmix](https://github.com/Sakuleta/tapmix)
- FineTune asks for "Screen & System Audio Recording" on first launch. MacMixer: "no driver, no microphone indicator". MacEQ: "no virtual audio driver, no admin password, volume keys keep working". — [FineTune](https://github.com/ronitsingh10/FineTune); [MacMixer](https://github.com/burghr/MacMixer); [MacEQ](https://github.com/jatinindia/MacEQ)
- Known process-tap failure modes reported by users: a brief bypass at tap initialisation and a "short blast of full volume"; echo/double audio when other capture apps (OBS, Discord screen share) are active; interference with AirPods automatic switching. — [FineTune issues](https://github.com/ronitsingh10/FineTune/issues)

**Drivers, extensions, security policy**
- Rogue Amoeba's history: the ACE capture engine broke in the macOS 11 betas. Apple granted a temporary allowlist through macOS 14, and Apple silicon users had to lower Startup Security (a "20-step" process). After Apple's macOS 14-era changes, the new ARK backend needs "no extensions… no adjustments to… System Security Policy… no restarts". Loopback and SoundSource still install an ARK plug-in with an admin password. — [Rogue Amoeba blog (Dec 2024)](https://weblog.rogueamoeba.com/2024/12/13/the-developers-who-came-in-from-the-cold/)
- Sound Control needs "a one-time trip to Recovery mode to allow its system extension" on macOS 14. — [eqbase.app](https://eqbase.app/compare/best-mac-equalizer/) **[vendor-on-competitors]**
- eqMac v1.9.1 "Completely removed Helper which caused issues on macOS 27". — [eqMac releases](https://github.com/bitgapp/eqMac/releases)
- BlackHole, a HAL loopback driver, is GPL-3.0, and any non-GPL app needs a commercial license from Existential Audio. — [BlackHole README](https://github.com/ExistentialAudio/BlackHole)

**Now Playing / MediaRemote**
- Since macOS 15.4 "only Apple programs can see what is playing on the system". Liland works around this by asking the system `perl` to read it, and says it will stop working if Apple closes the loophole. — [Liland README](https://github.com/sacis/Liland)
- boring.notch's top issue: "Now Playing no longer working after updating to MacOS 15.4" (54 reactions). It is now fixed using mediaremote-adapter (BSD-3, 311 stars, active). — [boring.notch #issue](https://github.com/TheBoredTeam/boring.notch/issues); [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)

**Gatekeeper / notarization in practice**
- Several OSS audio apps ship **un-notarized** (CoreEQ, Equaliser, Liland), which forces users through "Open Anyway". FineTune ships a DMG and a Homebrew cask. — [eqbase.app](https://eqbase.app/compare/best-mac-equalizer/) **[vendor-on-competitors]**; [Liland](https://github.com/sacis/Liland); [FineTune](https://github.com/ronitsingh10/FineTune)

**Apple's moves (macOS 27, hardware)**
- The new **touch-enabled OLED MacBook Pro replaces the notch with a Dynamic Island** that supports Live Activities. Dynamic Island assets were found in macOS 27 code (28 Oct 2026). — [MacRumors 28 Oct 2026](https://www.macrumors.com/2026/10/28/pill-shaped-macos-27-dynamic-island-macbook-pro/); [9to5Mac](https://9to5mac.com/2026/10/28/on-the-day-of-the-touchscreen-mac-launch-dynamic-island-elements-found-in-macos-27/)
- **macOS 27.3 (first developer beta in early Nov 2026, release expected December)** brings **Live Activities to the menu bar** on Apple silicon Macs without the Dynamic Island, covering Apple Music, Clock, Voice Memos and others. Per MacRumors, "third-party Mac apps can also implement Live Activities support now". macOS 26+ already mirrored iPhone Live Activities. — [MacRumors 4 Nov 2026](https://www.macrumors.com/2026/11/04/macos-27-3-live-activities-in-menu-bar/)
- Notchy cites the OLED MacBook Pro at "from $2,899". One guide says it shipped on 6 Nov 2026; that comes from a single secondary source. — [notchy.dev](https://notchy.dev/macos-dynamic-island/); [FavTray](https://favtray.com/blog/how-to-get-dynamic-island-on-mac)
- **Sherlock risk for per-app volume / EQ**: searches found no credible rumor of native per-app volume or a system EQ in Control Center. Only user requests and third-party apps came up. — [Apple Discussions 255099590](https://discussions.apple.com/thread/255099590); [dev.to explainer](https://dev.to/appish/why-mac-has-no-volume-mixer-and-how-to-get-per-app-audio-control-52e0)

### Inferences
- **Distribution recommendation implied by the evidence:** a **process-tap-only architecture**, with no HAL driver, can ship as Developer ID + notarized DMG/Homebrew from day one and could also target the Mac App Store, since VolumeHub is already there with the Audio Tap API. A HAL plug-in (for a virtual device, AU hosting on all output, or system-wide bit-perfect paths) pushes the app outside MAS and adds an admin-password install. That is the trade-off Rogue Amoeba accepted for SoundSource and Loopback.
- The notch is a shrinking surface on Apple's newest hardware. A "notch app" should also be a menu-bar app with a **Live Activity** presence (macOS 27.3), and have a floating-pill fallback for OLED Dynamic Island Macs, external displays and non-notch Macs. Apple's own Live Activities will cover basic now-playing, so **commodity now-playing in the notch is the most sherlockable part**. Per-app routing, EQ and AutoEQ is the least.
- Now-playing metadata from arbitrary apps is legally and technically fragile after 15.4 (private framework plus a perl workaround). Relying on it for core features is a risk. AppleScript and the Spotify/Music scripting bridges (Automation TCC) are stable but limited.
- The TCC surface for the planned app: System Audio Recording Only (taps), Automation (Music/Spotify scripting), possibly Accessibility (media key interception, HUD replacement), and Bluetooth (device control). Each extra prompt adds onboarding friction.

### Gaps
- No Apple primary documentation was fetched. Whether the MAS sandbox accepts taps without the `audio-input` entitlement, and whether the "System Audio Recording Only" permission re-prompts periodically the way ScreenCaptureKit did in macOS 15, remain unverified.
- I found no source on whether App Review accepts HAL plug-in installers. The inference is that it does not, because sandboxed apps cannot write to /Library/Audio/Plug-Ins/HAL; this is not sourced.
- Kernel-extension deprecation timeline: I did not fetch Apple's own statement. Rogue Amoeba's account covers its practical effect.
- I could not determine whether the Live Activities API on macOS is ActivityKit and what UI constraints it imposes.

---

## 6. Open-source licensing implications for reuse (with a possible future paid tier)

### Takeaway
The most useful audio codebases are **copyleft**: FineTune, boring.notch, Atoll, LosslessSwitcher, CamillaDSP and BlackHole are GPL-3.0; BackgroundMusic is GPL-2.0; FxSound is AGPL-3.0. Reusing any of them makes the whole app GPL. That still allows a paid binary, but anyone can fork it, and it conflicts with Mac App Store terms. A permissive core can be built from **MIT/BSD/Apache sources**: AudioCap (BSD-2), mediaremote-adapter (BSD-3), AutoEq (MIT), tapmix, fader, MacMixer, mixbar, MacEQ and CoreAudioTapKit (MIT), CoreEQ and eqMac's older public code (Apache-2.0), and HTDemucs (MIT).

### Cited Findings
- License inventory (GitHub API 2026-11-21 and READMEs): FineTune GPL-3.0; boring.notch GPL-3.0; Atoll GPL-3.0 (derived from boring.notch); ledge GPL-3.0 (boring.notch fork); LosslessSwitcher GPL-3.0; CamillaDSP and CamillaGUI GPL-3.0; BackgroundMusic **GPL-2.0**; FxSound **AGPL-3.0** (JUCE under AGPL); BlackHole GPL-3.0 with paid commercial license ("You can use BlackHole as long as your app is also licensed as GPL-3.0. For all other applications please contact Existential Audio"); eqMac **Apache-2.0** (public code ≤2023); AutoEq **MIT**; AudioCap **BSD-2-Clause**; mediaremote-adapter **BSD-3-Clause**; Soundflower MIT; tapmix, fader, MacMixer, mixbar, MacEQ, CoreAudioTapKit, Loudini, volnotch: **MIT**; MonoSplit 0BSD; MacIsland MPL-2.0; Liland **no license** (all rights reserved); buried-anchor, swara, R9-EQ: no license or private. — repos linked in sections 2–3; [BlackHole README](https://github.com/ExistentialAudio/BlackHole); [FxSound README](https://github.com/fxsound2/fxsound-app)
- CoreEQ Apache-2.0; Equaliser GPL-3.0. — [eqbase.app](https://eqbase.app/compare/best-mac-equalizer/) **[vendor-on-competitors]**
- HTDemucs (Meta) is **MIT**, and Liland converted the models to Core ML. — [Liland README](https://github.com/sacis/Liland); [facebookresearch/demucs](https://github.com/facebookresearch/demucs)
- GPL and App Store: in 2010–11 the FSF argued that App Store terms impose "further restrictions" that GPLv2 disallows. VLC for iOS was pulled on 8 Jan 2011 after a GPL contributor complained, and GNU Go had been pulled earlier. Commentators called the two "incompatible until proven otherwise". *(Historical, 2010–2011; App Store terms have changed since, and the conflict has never been tested in court.)* — [Computerworld](https://www.computerworld.com/article/1347653/gplv2-blocks-vlc-from-apple-s-app-store.html); [Engadget 2011](https://www.engadget.com/2011-01-09-the-gpl-the-app-store-and-you.html); [michelf.ca](https://michelf.ca/blog/2011/gpl-ios-app-store)

### Inferences
- **To keep a paid tier or a future MAS listing open**: (a) keep your own code under a permissive license, or dual-license it with a CLA that lets you relicense contributions; (b) learn from GPL projects (FineTune, boring.notch) but do not copy their code; (c) take process-tap plumbing from BSD/MIT sources (AudioCap, tapmix, MacMixer, CoreAudioTapKit); (d) take headphone data from AutoEq (MIT), checking the measurement sources' terms separately; (e) avoid BlackHole unless you pay or go GPL.
- Apache-2.0 code (old eqMac, CoreEQ) is compatible with GPLv3 but **not GPLv2**, which matters only when mixing with BackgroundMusic.
- A GPL-3.0 app can still be sold (Developer ID, Gumroad/Paddle) and accept donations, as FineTune does with Ko-fi. The business risk is that free forks can strip the paid parts, which FineTune forks like "FineTunePro" already do in spirit.
- An "open-core" model similar to eqMac (open engine, closed Pro binaries) works with permissive licenses. eqMac shows the reputational cost: the public repo has been stale since 2023.

### Gaps
- I did not verify the license terms on AutoEq's underlying measurement data (oratory1990, crinacle and others), as distinct from the MIT code.
- No current (2024–26) Apple or FSF statement on GPL and Mac App Store compatibility was found. The evidence is historical.
- I did not check whether FineTune requires a CLA, or whether its author would consider relicensing.
