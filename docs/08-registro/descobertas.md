# Registro de Descobertas

> Fatos relevantes descobertos durante pesquisa e execução, com data, fonte e impacto no plano.

## 2026-11-21 · Pesquisa Inicial e Design System

1. **Process taps com `.mutedWhenTapped` não exigem driver nem root (Comprovado — Doc Apple).**
   - `AudioHardwareCreateProcessTap` (macOS 14.2+) silencia a saída original do processo enquanto o tap está sendo lido; se o mixer travar, o som volta ao app ([Apple Docs](https://developer.apple.com/documentation/coreaudio/catapmutebehavior)).
   - *Impacto:* fundamenta P2 (fail-safe) e [ADR-0004](../07-decisoes/ADR-0004-captura-por-process-taps.md).

2. **Leva de bugs nos taps do macOS 26/27 (Provável — Apple Developer Forums + OSS).**
   - Buffers `0.0f` após minutos (FB / thread 825780); bloqueio mútuo de `AudioDeviceStart` entre apps diferentes (thread 848578); atenuação de `−12,04 dB` em interfaces multicanal de 8 saídas (thread 806799); estouro inicial de 200–500 ms (FineTune #170/#268).
   - *Impacto:* E-02, E-03 e E-10 são bloqueadores obrigatórios antes do MVP.

3. **Abas de navegador compartilham um único processo de áudio (Comprovado — Chromium/WebKit).**
   - Chromium usa um Audio Service único; Safari usa `com.apple.WebKit.GPU`. Logo, taps não enxergam abas individuais.
   - *Impacto:* controle por aba exige extensão de navegador (E-05); nunca prometer como função nativa de tap.

4. **Dynamic Island no MacBook Pro OLED e Live Activities no macOS 27.3 (Relato de terceiros — MacRumors, out–nov/2026).**
   - O novo MacBook Pro OLED substitui o recorte estático por uma Dynamic Island; o macOS 27.3 leva Live Activities de terceiros à barra de menus.
   - *Impacto:* [ADR-0013](../07-decisoes/ADR-0013-superficies.md) evita aprisionar o produto no formato do notch físico.

5. **Visualizador do `boring.notch` é aleatório (Comprovado — Código auditado).**
   - `MusicVisualizer.swift` usa `CGFloat.random(in: 0.35 ... 1.0)`.
   - *Impacto:* reforça P4 (verdade no sinal): no Timbre, se um visualizador está ligado, ele vem de FFT/nível real do tap; caso contrário, não finge medir áudio.

6. **CamillaDSP v5 adota licença dupla GPL-3.0 ou MPL-2.0 (Comprovado — README v5.0.0-beta.2).**
   - Abre caminho para um núcleo DSP de 64 bits de referência mundial dentro de um produto sob licença permissiva/MPL-2.0 ([ADR-0001](../07-decisoes/ADR-0001-licenca.md), [ADR-0003](../07-decisoes/ADR-0003-nucleo-dsp.md)).

7. **Mistura de cores em OKLCH puxa para o rosa em produção (Comprovado — Código Órbita `badge.module.css:7`).**
   - Toda tintura programática deve rodar em **OKLab**, não em OKLCH nem RGB linear direto.
   - *Impacto:* regra documentada em [01 · Fundações e Tokens](../05-design-system/01-fundacoes-tokens.md).

8. **Dados do `master` do `AutoEq` estão sem atualização desde julho de 2025 (Comprovado — GitHub commits).**
   - Além disso, medições individuais (ex.: oratory1990) têm propriedade de terceiros e novos bancos pagos (GraphWorks, out/2026) restringem exportação.
   - *Impacto:* baixar índice em runtime com cache + crédito explícito, nunca empacotar banco fechado sem licença.

9. **Spotify Web API restringiu Development Mode em fev/2026 (Comprovado — Spotify Developer Blog).**
   - Exige conta Premium e limita Client ID a 5 usuários.
   - *Impacto:* controle do Spotify no desktop deve depender de AppleScript/`mediaremote-adapter`, não de OAuth Web API.

10. **Núcleo permissivo completo validado na auditoria de 62 repositórios (Comprovado — Auditoria Fase 2, nota 11).**
    - `Sakuleta/tapmix` (MIT, `TapPlan`, triple-buffer atômico, `LookaheadLimiter`) + `CJStanfield/CoreAudioTapKit` (MIT, 1 aggregate + 1 `IOProc` single-clock) + `CAAudioHardware` / `swift-core-audio` (MIT) + `CamillaDSP` v4/v5 (`MPL-2.0` via licença dupla) + `ebur128` (MIT) + `DynamicNotchKit` (MIT) formam um stack integralmente compatível com MPL-2.0, sem copiar uma linha de código GPL.

11. **Armadilhas de licenciamento em repositórios de áudio macOS (Comprovado — Auditoria Fase 2, nota 11a/11b/11c).**
    - `GabrielSabadinn/PerAppVolume` adota **PolyForm Noncommercial 1.0.0** (não-OSI); `makeusabrew/audiotee`, `sacis/Liland`, `ungive/media-control` e `james34602/JamesDSPManager` **não têm arquivo `LICENSE`** (`NONE` = todos os direitos reservados); `bitgapp/eqMac` open source (Apache-2.0) não contém Process Taps (ficaram no fork Pro fechado).

12. **Issues críticas recém-catalogadas para o macOS 26/27 (Comprovado — Issues GitHub, nota 11).**
    - `LosslessSwitcher#231`: leitura de logs do CoreMedia dispara troca de sample rate no meio da música por pre-buffering da próxima faixa.
    - `Torteous44/radioform#84`: interpolação linear de drift causou *treble roll-off* durante ~55 s após início da reprodução.
    - `FineTune#493/#483/#477`: `MediaRemoteUIService` vaza como app fantasma no macOS 27; chamadas VoIP (WeChat/Google Meet) sofrem esmagamento de ganho ou distorção cumulativa se entrarem em process tap.
    - `sdroege/ebur128#69`: modo True Peak 4× padrão subestima picos próximos de 20 kHz em até ~1,8 dB (exige verificação com oversampling maior em E-06).
    - `Yudaotor/lyrimuse`: `KeyboardShortcuts` 2.2+/3.0+ usa macros `@Entry` que quebram `swift build` headless sem Xcode completo.

13. **Protocolo GAIA v3 do Sennheiser Momentum 4 mapeado e com lista negra crítica de segurança (Comprovado — Nota 07 / `omarchy-momentum4`, `sennheiser-control`, `android-momentum-4-widget`).**
    - RFCOMM UUID `A2129FF3-081B-4C45-8AFE-469D9C4842EC` sem auth; firmware `>= 3.18.0` muda comando `0x1002` de EQ Gen1 para EQ Gen2; **`AudioMode = 1` é obrigatório para EQ interno surtir efeito**, enquanto `0x0800`/`0x089A` reportam codec/taxa diretamente do fone.
    - **Comando letal `0x0607` derruba o fone da barra BT exigindo power-cycle**; `0x1405/1406` apaga pareamento; `0x02xx` é DFU/OTA. Todos bloqueados por denylist no driver.
    - Gist `dvf` (`defaults write bluetoothaudiod`) está obsoleto no macOS Sonoma+; Momentum 4 USB-C opera em UAC 1.0 (16-bit/48 kHz) e 3.5 mm muda impedância de `470 Ω` (ligado/DSP) para `60 Ω` (passivo/sem DSP), exigindo perfis AutoEq separados.

14. **AirPods Pro AACP (L2CAP `0x1001`) bloqueado em user-space no macOS (Comprovado — Nota 07 / `LibrePods`, `BeatsBar`).**
    - `bluetoothd` reserva o canal de controle dos AirPods; apps Developer ID não conseguem alternar ANC/Transparency via L2CAP no macOS. O valor entregue para AirPods Pro é HAL + proteção anti-HFP ("Output Only") + AutoEq + pesquisa read-only de beacons BLE Continuity (`0x004C`).

15. **Diretriz visual `timbr.` × `v1torres.dev` consolidada (Comprovado — `v1dev app/frontend/DESIGN_SYSTEM.md` + captura `timbr.`).**
    - `timbr.` herda o DNA minimalista, lowercase com pontuação (`.` vs `›v1_`), superfícies neutras puras e tipografia Geist do `v1torres.dev`, mantendo raios concêntricos do notch e cor funcional apenas para telemetria/segurança sonora (ADR-0014).

16. **Validação empírica da Fase 0 no host local (`E-06`, `E-07`, `E-12`, `E-01` — Comprovado em 2026-11-21).**
    - **E-06 (`Float64` + Vicanek):** em `MacBook Air arm64, macOS 26.6`, o Null Test neutro atingiu `0.000e+00` (`-240 dBFS`); pico `12 kHz +6dB Q=1.8 @ 48 kHz` teve erro máximo `0.3019 dB` (Vicanek) vs `1.6869 dB` (RBJ); filtro `20 Hz Q=4.0 +8dB @ 192 kHz` obteve THD+N **`-43.86 dB` em Float32 vs `-149.23 dB` em Float64** (+105 dB comprovando `H-06`); CPU `28.90 µs/bloco (0.27%)` em 10 bandas @ 48 kHz.
    - **E-07 (HAL local):** `BuiltInSpeakerDevice` (`MacBook Air Speakers`) expõe `hwVolumeOutputMainSettable=true` (elem 0) e `hwVolumeOutputCh1Settable=false` (elem 1), latência `60+48` frames; Momentum 4 e AirPods Pro constam pareados porém desconectados no host durante a execução automatizada.
    - **E-12 (Geometria do notch):** `Built-in Retina Display` (`1470x956`, scale `2`) apresentou `safeAreaTopInset = 32 pt`, `auxiliaryTopLeftArea w=646`, `auxiliaryTopRightArea x=825 w=645` -> **`computedNotchWidthPt = 179 pt`**.
    - **E-01 (Process Tap smoke):** `AudioHardwareCreateProcessTap` com `CATapDescription.bundleIDs` e `isProcessRestoreEnabled` retornou `status: 0, tapID: 124`, e `AudioHardwareDestroyProcessTap` retornou `status: 0`.

17. **Toolchain CLT `swift-package` vs `swiftc` direto no macOS 26.6 e achados de `CLEAN_SWEEP` (Comprovado).**
    - Sem `/Applications/Xcode.app`, `/Library/Developer/CommandLineTools/usr/bin/swift-package` aborta com `dyld: Symbol not found: _$s19BuildServerProtocol...`. Invocar `clang++` + `swiftc -sdk .../MacOSX26.sdk -swift-version 6 -wmo` resolve 100% do build e execução de testes.
    - Apple Clang 21 do CLT não distribui runtime de `-fsanitize=realtime`; testes C++ executaram com `-fsanitize=address,undefined`, que inclusive detectou UB real ao passar `UInt32.max` como enum `timbre_eq_layer_t` (corrigido adicionando `TIMBRE_LAYER_ALL = 255` em [`timbre_dsp.h`](../../Sources/CTimbreDSP/include/timbre_dsp.h)).
    - Durante `CLEAN_SWEEP`, a verificação do thread RT removeu captura `[weak self]` e chamada `Date()` do bloco `AudioDeviceCreateIOProcIDWithBlock` (movendo `zero_buffer_streak` para contador atômico lock-free em `CTimbreDSP`), corrigiu o alinhamento logarítmico das 128 bandas FFT no `EQCurveCanvas` e sincronizou o formato `pairKey` de silenciamento do Guardião (`rule|bundle|device`).

18. **Auditoria complementar de concorrentes & reaproveitamento MIT direto (`Notchy`, `R9-EQ`, `OmniMac`, `ILoveNotch`, `m4-companion`, `AudioRouter` — Comprovado em 2026-11-21).**
    - **Panorama competitivo atualizado:** `Notchy` (comercial `$24,99`) cobre 78 utilidades no notch incluindo mixer até 150%, EQ de 3 bandas, FFT via Process Tap e API `127.0.0.1:9999`, mas sem PEQ `Float64`, AutoEq, `dBTP`/`BS.1770`, Guardião `G-01..G-07` ou Momentum 4 GAIA v3; `XPro-Gamer-Rhine/R9-EQ-app` distribui binário fechado (`license: null`, só `docs/` no GitHub); `BySergiMM/OmniMac` (MIT) usa `Float32` RBJ Cookbook 10 bandas; `niyamvora/ILoveNotch` (MIT) é notch generalista SwiftUI.
    - **Descoberta crítica de protocolo no Momentum 4 (`Zhengyang-Liu/m4-companion`, MIT):** o framing SPP real sobre RFCOMM usa cabeçalho de 4 bytes `[0xFF, 0x03, lenHi, lenLo]` seguido de `[vendorID(2B)=0x0495, commandID(2B), payload]`, e os getters verificados são `0x0603` (bateria), `0x0804` (`SoundMode`), `0x1000`/`0x1002` (config/bandas EQ), `0x1009` (`BassBoost`), `0x1a05`/`0x1805`/`0x1a03` (ANC/transparência) e `0x0406` (modo compatibilidade BT). Implementado em [`Momentum4Driver.swift`](../../Sources/TimbreEngine/Momentum4Driver.swift) com `GaiaSPPDeframer`, leitor RFCOMM estritamente *read-only* e manutenção integral da denylist (`0x0607`/`0x0040`/`0x1405`/`0x02xx`).
    - **Higiene de Process Tap pós-crash (`AbhisekGanguly/AudioRouter`, MIT):** adicionado `OrphanedTapCleanup` em [`ProcessTapEngine.swift`](../../Sources/TimbreEngine/ProcessTapEngine.swift) para destruir aggregates `dev.v1torres.timbr.agg.*` órfãos antes de criar novos taps, evitando que apps fiquem silenciosamente mudos após `SIGKILL`. Atribuições MIT formalizadas em [`NOTICE`](../../NOTICE).


15. **Linha Apple Continuity no `timbr.` (Comprovado em parser / Provável em hardware — 2026-11-21).**
    - Implementado `ContinuityProximityParser` + `ContinuityBLEScanner` (manufacturer `0x004C`, type `0x07`) com classificação AirPods/Pro/Max/Beats e telemetria L/R/Case sem AACP.
    - UI do Observatório nunca inventa ANC/Transparency (P11); aviso de Spatial Audio em A2DP.
    - Validação com case aberto e E-08 HFP permanecem como bancada física.

19. **`CATapDescription.isExclusive` inverte o tap (Comprovado, 2026-11-22).** `stereoMixdownOfProcesses:` nasce com `isExclusive = false` e `stereoGlobalTapButExcludeProcesses:` com `true`. Forçar `true` depois transforma "só estes processos" em "todos menos estes". Era a causa de "o volume por app não funciona". Medido com `--selftest-audio`.

20. **Um segundo tap no mesmo processo para de receber áudio (Comprovado, 2026-11-22).** Com o timbr. já capturando um processo com `.mutedWhenTapped`, um tap de medição sobre o mesmo processo lia silêncio. O autoteste mede a fonte antes de o motor assumir o processo.

21. **O HAL não notifica `IsRunningOutput` para processos novos (Comprovado, macOS 26, 2026-11-22).** Para um processo que acabou de aparecer, só `kAudioProcessPropertyIsRunning` dispara. O `AudioProcessMonitor` ouve os dois e relê a saída 60 ms depois; senão, sons curtos (um alerta de 0,3 s) se perdiam.

22. **Atribuir áudio pelo texto do bundle ID erra (Comprovado, 2026-11-22).** `com.apple.WebKit.GPU` serve Safari, Raycast, Mail e qualquer app com WKWebView, e era rotulado "Safari". `responsibility_get_pid_responsible_for_pid` (libSystem, sem header público, buscado em runtime) devolve o app responsável. Apps accessory (barra de menus) precisam contar como donos.

23. **Daemons do macOS tocam áudio sem app (Comprovado, 2026-11-22).** São eles `systemsoundserverd` (alertas; bundle reportado sem domínio reverso), `PowerChime`, `NotificationCenter`, `corespeechd`, `assistantd`, `avconferenced`, `callservicesd`, `universalaccessd` e `heard`. Viraram o catálogo `SystemAudioClient`.

24. **Apps de ditado mantêm a saída "ligada" em silêncio (Comprovado, 2026-11-22).** O superwhisper fica com `IsRunningOutput = 1` por minutos sem emitir som. O Core Audio não dá o nível por processo; medi-lo exigiria um tap, que piora o item 25.

25. **Qualquer tap faz o processo "usar entrada" (Comprovado, 2026-11-22).** O processo que lê um tap fica com `IsRunningInput = 1` (o microfone segue com `DeviceIsRunningSomewhere = 0`), e o macOS mostra o ponto roxo. O superwhisper interpreta isso, com um navegador aberto, como reunião ("Meeting detected"). Reproduzido duas vezes, também com política de ativação `.regular`.

26. **TCC prende a Acessibilidade ao `cdhash` em builds ad-hoc (Comprovado, 2026-11-22).** A entrada no `TCC.db` tinha `csreq = cdhash H"31c867…"` de um build antigo. Com o build novo, `AXIsProcessTrusted()` passava a falso sem aviso e o macOS voltava ao HUD de volume próprio. Solução: identidade de assinatura local estável (`setup_dev_signing.sh`).

27. **`MenuBarExtra(isInserted:)` controlado pelo estado do app entra em laço (Comprovado, SwiftUI no macOS 26, 2026-11-23).** O `sample` do processo mostrou `AppDelegate.scenesDidChange → makeMainMenu` sem parar (100 % de CPU, o app não fechava, o CI travou). Uma cena `Settings` permanente não resolveu. Trocado por `NSStatusItem` + `NSPopover`.

28. **O macOS guarda a visibilidade de itens da barra de menus por `autosaveName` (Comprovado, 2026-11-23).** `NSStatusItem VisibleCC Item-0 = 0` herdado do item antigo fazia o novo nascer invisível (`isVisible = false`, frame fora da tela). Agora o item tem `autosaveName` próprio e visibilidade explícita.

29. **Swift 6.1 (Xcode 16.4) é mais rígido que o 6.3 com isolamento em SwiftUI (Comprovado, 2026-11-22).** Closures de `Canvas` são `nonisolated` no 6.1, e propriedades estáticas de uma `View` são inferidas como `@MainActor`. O CI do GitHub ficou vermelho do redesign de 21/11 até 22/11 com o build local verde. A matemática do eixo do EQ foi para um `enum` fora da `View`.

30. **Vídeo mudo no player do navegador não gera áudio para o macOS (Comprovado, 2026-11-23).** Com o YouTube em `muted: true`, nenhum processo do Chrome tinha saída ativa. Não aparece como fonte, e está correto.
