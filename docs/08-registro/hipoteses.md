# Registro de Hipóteses e Dúvidas

> **Regra ([AGENTS.md](../../AGENTS.md)):** toda afirmação técnica ainda não verificada diretamente ou sem documentação oficial explícita mora aqui até ser promovida a **Comprovado** (com data, método e commit) ou **Descartado**.

| ID | Hipótese / Dúvida | Classe atual | O que decide | Experimento | Critério de promoção |
|---|---|---|---|---|---|
| **H-01** | Process tap com ganho `1.0` e taxa casada é bit-transparente | Desconhecido | Se "A/B neutro" pode manter o tap ativo ou precisa desmontá-lo | E-01 | Null test < limiar definido em `06-plano/estrategia-de-testes.md` |
| **H-02** | `bundleIDs` + `isProcessRestoreEnabled` (macOS 26+) eliminam o estouro inicial de 200–500 ms sem EQ | Hipótese | Topologia de criação dos taps e piso de UX do mixer | E-02 | 0 ms de estouro detectável em 20 inícios de Music/Safari/Chrome |
| **H-03** | Watchdog com backoff de 30 s recupera buffers zerados (`0.0f`) no macOS 26/27 sem intervenção | Provável | Confiabilidade de 24 h em produção | E-03 | Zero silêncio > 2 s sem recuperação num soak de 24 h |
| **H-04** | Topologia "1 aggregate privado por saída física" sustenta fio + BT simultâneos sem drift audível | Hipótese | Arquitetura do roteamento multissaída | E-04 | 1 h contínua sem xrun; alinhamento manual estável |
| **H-05** | `chrome.tabCapture` + `OffscreenCanvas`/`AudioContext` + `setSinkId` permite rotear uma aba para outra saída | Desconhecido | Se controle por aba entrega apenas volume/EQ ou também roteamento por destino | E-05 | Spike funcional em Chrome/Arc/Brave + análise de latência |
| **H-06** | `vDSP_biquad` em Float32 introduz ruído mensurável em shelves graves (20 Hz, Q alto) a 192 kHz vs `Float64` | Provável | Escolha definitiva do núcleo DSP (ADR-0003) | E-06 | Comparação medida THD+N / ruído vs referência analítica |
| **H-07** | O crate `camilladsp` v5 (MPL-2.0) compila e é linkável em biblioteca macOS via FFI C ABI | Desconhecido | Viabilidade de reuso do CamillaDSP sem GPL (ADR-0001/0003) | E-06 | Build de teste linkado ao Swift passando golden tests |
| **H-08** | Queda BT A2DP → HFP é detectável em runtime pelo surgimento do stream de entrada / mudança de taxa no HAL | Hipótese | Confiabilidade do Guardião Bluetooth (G-01) | E-08 | Zero falso negativo em 20 eventos com Zoom/Meet/FaceTime |
| **H-09** | Codec BT efetivamente negociado pode ser lido de `system_profiler` ou `log stream` no macOS 26+ | Desconhecido | Se o Observatório exibe o codec como `REPORTADO` ou omite | E-08 | Verificação empírica em macOS 26+ com AAC/SBC/aptX |
| **H-10** | IOBluetooth RFCOMM no macOS alcança o canal de controle GAIA do Sennheiser Momentum 4 enquanto A2DP toca | Hipótese | Existência do driver do Momentum 4 (ADR-0011) | E-09 | Leitura segura de bateria, ANC e EQ sem travar A2DP |
| **H-11** | Taps de apps distintos (SoundSource, OBS, Loopback) bloqueiam `AudioDeviceStart` no macOS 26/27 | Provável | Política de coexistência e lista de "ignorar" | E-10 | Matriz real executada app × cenário |
| **H-12** | Tokens adaptados para a superfície `Notch #000000` (`#7A7A7A` muted, alfas brancos) mantêm contraste e calma em LCD mini-LED e OLED | Hipótese | Finalização da Bíblia do Design System | E-12 | Teste visual e leitura em hardware real |
| **H-13** | Apple Foundation Models on-device (~3B, 4096 tokens) gera deltas de EQ úteis e aceitos em ≥ 95% pelo esquema | Hipótese | Runtime padrão da camada de IA (ADR-0008) | E-13 | Benchmark com 60 prompts PT/ES/EN + avaliação cega |
| **H-14** | `PairwiseGP` + EUBO em 2–4 dimensões converge em ≤ 20 comparações A/B e se mantém após 7 dias | Provável | Viabilidade do aprendizado contínuo de gosto | E-14 | Piloto teste-reteste com diferença menor que limiar perceptual |
| **H-15** | `mediaremote-adapter` via `/usr/bin/perl` permanece funcional no macOS 26.x/27.x para múltiplas sessões | Provável | Confiabilidade do Now Playing | E-15 | Suite de testes com Music, Spotify, Safari, Chrome, TIDAL |
| **H-16** | Motor de áudio em processo auxiliar (XPC/LoginItem) isola crashes de UI e mantém TCC limpa | Hipótese | Separação de processo UI × Motor (ADR-0006) | E-16 | Protótipo comparando in-process vs helper com `kill -9` na UI |
| **H-17** | App Review aceita EQ de sistema baseado em taps num build sandbox "lite" | Desconhecido | Existência futura de distribuição via Mac App Store | E-17 | Submissão experimental mínima pós-MVP |
