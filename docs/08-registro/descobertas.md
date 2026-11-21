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
