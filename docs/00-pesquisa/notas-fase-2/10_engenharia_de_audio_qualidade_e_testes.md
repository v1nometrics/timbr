# Nota 10 · Engenharia de Áudio, Precisão DSP, Segurança Auditiva e Estratégia de Testes

> **Status:** Auditoria técnica concluída em 2026-11-21 · **Fontes primárias consultadas:** Ross Bencina (*Real-time Audio Programming 101*), Timur Doumler (CppCon Real-Time Audio), Apple Developer Docs (*Audio Workgroups*, *Instruments Audio System Trace*, `kAudioDevicePropertyIOCycleUsage`), Martin Vicanek (*Matched Second Order Digital Filters* 2016/2024), S. J. Orfanidis (JAES 1997), Cytomic/Andy Simper (TPT SVF), William Gardner (JAES 1995 NUPOLS), Wannamaker/Lipshitz/Vanderkooy (IEEE 2000 Nonsubtractive Dither), ITU-R BS.1770-4/5 & EBU R128 (`libebur128`), Nielsen & Lund (AES 2000/2003 Inter-Sample Peaks), Angelo Farina (AES 2000 ESS), WHO-ITU H.870 (2022), ITU-R BS.1116 / BS.1534 (MUSHRA) e InfiniteWave.

---

## 1. Disciplina de Tempo Real (Real-Time Audio Thread Safety)

Em áudio digital no Core Audio, cada ciclo de I/O (`IOProc`) possui um orçamento estrito: para `48 kHz` com buffer de `128 frames`, o deadline absoluto é **`2,67 ms`** (`512 frames` = `10,67 ms`). **Time waits for nothing (Bencina, 2011; Doumler, 2015–2024):** se a thread de render atrasar 1 microssegundo além do deadline, ocorre um *buffer underrun* (`xrun`) — estalo ou silêncio audível.

### Regras Invioláveis da Thread de Áudio (`AudioRenderThread`)
1. **Zero alocação/desalocação de memória:** nunca chamar `malloc`, `free`, `new`, `swift_allocObject`, nem manipular arrays/strings Swift dinâmicos dentro do `IOProc`. Toda memória de ring buffers, coeficientes, scratch buffers e linha de delay é **pré-alocada fora da thread RT** antes de registrar o `IOProc`.
2. **Zero locks e inversão de prioridade:** nunca usar `pthread_mutex`, `NSLock`, `os_unfair_lock`, `DispatchQueue.sync` ou `actor` Swift dentro do callback RT. Comunicação Controle → Áudio e Áudio → UI ocorre exclusivamente via:
   - **Ring buffer SPSC lock-free** (para fluxo de PCM entre tap e dispositivo de saída e para snapshots de telemetria/FFT rumo à UI);
   - **Atomic pointer / double-buffer swap** com epoch ou wait-free FIFO para atualização de parâmetros/coeficientes de EQ (usando `std::atomic` em C++/Rust ou atomics C11).
3. **Zero Objective-C / Swift runtime / ARC no caminho quente:** `objc_msgSend`, retain/release de ARC (`Swift.swift_retain`/`release`), `NSLog`, `os_log` formatado, I/O de disco ou rede são **banidos** da callback RT. **Consequência arquitetural:** o callback RT e o grafo DSP vivem em **C++20 / Rust puro (ou C estrito sem ARC)**, enquanto Swift 6 gerencia controle (`actor`), HAL não-RT e UI.
4. **Agendamento Real-Time e Audio Workgroups (Apple):**
   - Threads auxiliares paralelas de DSP (se usadas para multissaída/convolução) devem ingressar no `os_workgroup_t` do dispositivo via `kAudioDevicePropertyIOThreadOSWorkgroup` (**Apple Audio Workgroups**), além de usar Mach `THREAD_TIME_CONSTRAINT_POLICY` (`thread_policy_set`) quando aplicável, garantindo que o scheduler do macOS conheça o orçamento conjunto e evite throttling em núcleos de eficiência.
5. **Verificação automática com Clang RealtimeSanitizer (RTSan):**
   - Compilar a suíte de testes do núcleo DSP em C++/Rust com `-fsanitize=realtime` (Clang 20+, atributo `[[clang::nonblocking]]` na função de processamento por bloco) para falhar o build no CI caso qualquer dependência ou refatoração introduza alocação, syscall ou lock acidental no caminho RT!

---

## 2. Precisão Matemática do Motor DSP (`Float64`)

### 2.1 Por que `Float64` (Double Precision) como padrão interno
- Biquads IIR em *Direct Form I* (DF1) sofrem de erro de quantização e ruído numérico em frequências graves quando operam em `Float32` (ex.: corte em 20–40 Hz a 96/192 kHz, onde os polos ficam a < 0,002 radianos do círculo unitário, exigindo alta mantissa para coeficientes e acumuladores).
- Operar o grafo interno em **64 bits ponto flutuante (`Float64`)** mantém ruído de quantização e acumulação abaixo de **`−300 dBFS`** mesmo com 20 bandas em cascata a 192 kHz (**Comprovado** em teoria de filtros IIR e adotado por CamillaDSP, FabFilter Pro-Q e DAWs de masterização), antes de converter para `Float32` (Core Audio padrão) ou inteiro de saída no último estágio.

### 2.2 Topologia de Filtros: Bilinear Clássica vs. Orfanidis vs. Vicanek vs. TPT SVF
| Topologia | Problema resolvido | Trade-off | Decisão para o `timbr` |
|---|---|---|---|
| **Audio EQ Cookbook (RBJ Bilinear)** | Simples e clássico | Sofre **cramping** (compressão de largura) perto de Nyquist em `44.1 / 48 kHz` para picos acima de `~8–10 kHz`. | Bom para compatibilidade exata com EqualizerAPO quando usuário pedir *"modo legado RBJ"* (verificado em E-06). |
| **Orfanidis (1997, JAES)** | Prescreve ganho exato em Nyquist no pico paramétrico | Resolve cramping para peaking EQ sem oversampling. | Referência analítica; porém não cobre shelves casados tão uniformemente quanto Vicanek. |
| **Vicanek (2016/2024, *Matched 2nd-Order / Shelving*)** | Fórmulas fechadas de biquad cujo ganho em magnitude casa a resposta analógica contínua até Nyquist em `44.1/48 kHz` | Custo de cálculo apenas na geração de coeficientes (fora da thread RT!); execução RT continua sendo **um biquad DF1 padrão** (ultrarrápido com `vDSP_biquadD` ou SIMD NEON!). | **Candidato nº 1 para modo "Matched / Alta Precisão"** (validar em E-06). |
| **Cytomic TPT SVF (`SvfLinearTrapOptimised2`)** | Preserva estabilidade e ausência de estalos durante **varredura rápida de frequência/Q em tempo real** (modulação contínua) | Custo levemente maior por amostra que DF1 estático, mas zero zipper/instabilidade ao arrastar alça no gráfico. | Excelente para interpolação de alça durante arraste ao vivo (ou interpolação suave de ganho/coeficientes entre blocos). |

- **Suavização de parâmetros (De-zippering):** Mudanças de volume, balanço ou ganho de banda nunca aplicam salto instantâneo. Usar **rampa exponencial/linear por amostra de 5–20 ms** (ex.: 10 ms padrão para faders de mixer; ~20 ms para bypass/A-B) para eliminar cliques em descontinuidades de derivada.

### 2.3 Convolução FIR (Fase Mínima vs. Fase Linear) & Latência
- **Fase Mínima (IIR/PEQ padrão ou IR mínimo):** latência zero extra (`0` amostras de atraso de grupo adicional), **zero pré-ringing** (pré-eco antes de transientes secos de bateria/percussão). Ideal para 95% da escuta diária, jogos e vídeo.
- **Fase Linear via Convolução Particionada Não-Uniforme (Gardner, 1995 — NUPOLS):** evita distorção de fase em cortes cirúrgicos extremos, mas introduz **latência algorítmica inevitável** (metade do comprimento da IR) e **pré-ringing audível** quando há ganhos ou cortes muito estreitos (`Q` alto) em graves. **Regra de produto:** modo padrão = **IIR Fase Mínima (baixa latência)**; Convolução FIR / Fase Linear (via CamillaDSP ou FFT particionada em vDSP) = **modo avançado opt-in** com exibição explícita da latência adicional em `ms` no Observatório.

---

## 3. Inter-Sample Peaks (`dBTP`), Limiter, SRC e Dither

### 3.1 O Fenômeno `0 dBFS+` (Nielsen & Lund, AES 2000/2003)
- Mesmo quando nenhuma amostra PCM excede `0,0 dBFS`, o filtro de reconstrução DAC (e o upsampling/AAC encoder Bluetooth!) gera **picos inter-amostra (*inter-sample peaks*)** que em gravações comerciais modernas altamente limitadas ultrapassam **`+3 dBTP`**, chegando frequentemente a **`+5,8 dB`** em casos extremos (**Comprovado**, Lund/TC Electronic AES 23rd Conf. Table 4).
- **Por que isso quebra a fidelidade no macOS:** ao aplicar +3 dB em um slider de EQ (ou enviar sinal a 0 dBFS para o encoder AAC Bluetooth ou DAC com pouca folga no estágio analógico), sem headroom prévio o sinal ceifa com distorção intermodular severa.
- **Arquitetura obrigatória de headroom no `timbr`:**
  1. **Preamp automático conservador:** calcular o pico máximo positivo da resposta composta somada (`max_f H_total(f)`) + **margem de segurança configurável (padrão `-1,0 dB` ou `-1,5 dBTP` para Bluetooth)**, garantindo que ganho positivo do EQ nunca empurre o teto para `> 0 dBTP`.
  2. **Medidor True Peak real (`ITU-R BS.1770-4 / BS.1770-5 Annex 2`):** filtro polifásico com **oversampling 4×** (48 fases / 12 taps por fase a 48 kHz = 192 kHz efetivo) antes de detectar o módulo máximo — exibindo valor exato em **`dBTP`** com retenção de pico e flag de overload.
  3. **Limiter de proteção True-Peak (Safety Limiter):** estágio final com look-ahead mínimo (ou modo *soft-clip transparente* opcional vs *brickwall TP*) que **só atua se `> −0,2 dBTP`** (ou limiar configurado) para evitar estouros sem colorir sinais normais; **acende indicador visível no Observatório sempre que entrar em redução de ganho (> 0,0 dB GR)** para nunca mascarar clipping silenciosamente.

### 3.2 Sample Rate Conversion (SRC) e Dither
- **Regra nº 1 (Anti-SRC):** Sempre que possível, evitar reamostragem casando a taxa do dispositivo HAL com o fluxo (ou alertando via **Guardião G-02**).
- **Quando SRC for inevitável (ex.: Multissaída ou Aggregate com relógios assíncronos):**
  - Benchmark **InfiniteWave** (`-180 dB` de piso): `libsoxr` (VHQ), `r8brain-free-src` e Apple `CoreAudio` (`kAudioConverterSampleRateConverterComplexity_Mastering` + `kAudioConverterQuality_Max`) são auditivamente transparentes, com stopband abaixo de `-120` a `-150 dB`. `rubato` (Rust, sinc polifásico / FFT) é nativo para integração com CamillaDSP v5 (MPL-2.0) e evita copyleft GPL do `libsoxr` (LGPL-2.1+) caso linkado estaticamente, embora **CoreAudio AudioConverter** (nativo macOS) ou **rubato** (MIT) cubram ambos os casos com licença limpa.
- **Dither (`Wannamaker, Lipshitz & Vanderkooy, 2000`):**
  - Quando reduzir de `Float64` interno para inteiro **16-bit** (ex.: **Momentum 4 via USB-C UAC 1.0 = 16-bit/48 kHz!**) ou saída **24-bit** sem flutuação nativa, aplicar **TPDF Dither** (Triangular Probability Density Function, amplitude 2 LSB pico-a-pico) — opcionalmente com *noise shaping* psicacústico leve — **desacopla a distorção harmônica de quantização**, convertendo-a em piso de ruído branco benigno e estável. Em saída `Float32` nativa do Core Audio, **não aplicar dither** (mantém transparência bit-exact em ganho unitário).

---

## 4. Loudness (`EBU R128`) e Dosimetria Auditiva (`WHO-ITU H.870`)

1. **Medição de Loudness (`ITU-R BS.1770-4/5` & `EBU Tech 3341 / R128`):**
   - Filtro **K-weighting** (high-shelf `+4 dB` em ~1.5 kHz + high-pass 2ª ordem ~38 Hz) → média quadrática por canal ponderada:
     - **Momentary (`M`):** janela deslizante de **`0,4 s`**
     - **Short-term (`S`):** janela deslizante de **`3,0 s`**
     - **Integrated (`I`):** acumulado com **duplo gate** (`-70 LUFS` absoluto e `-10 LU` relativo à média preliminar)
   - Implementação MIT de referência: **`libebur128`** (C, MIT) ou port puro `ebur128` (Rust/Swift validado contra vetores oficiais EBU Tech 3341).
   - **Uso prático essencial no `timbr`:** **Nivelamento automático de A/B (`Δ ≤ 0,1 dB`)**! Sem compensação de loudness entre curva A e curva B, o ouvido humano quase sempre prefere o sinal mais alto por apenas `0,5 dB` (**Comprovado**, literatura de testes cegos).
2. **Proteção Auditiva (`WHO-ITU H.870`, 2022):**
   - Teto semanal de referência: **`80 dBA` por `40 horas/semana`** (taxa de troca de `3 dB`: `83 dBA` = 20 h, `86 dBA` = 10 h, `92 dBA` = 2,5 h, `100 dBA` = 24 min).
   - **Regra de honestidade metrológica (P6):** Em fones Bluetooth via USB/A2DP arbitrários no macOS, o sistema **não conhece com precisão científica a curva de sensibilidade (`dB SPL / mW`), a impedância real e o ganho analógico pós-DAC** (diferente da Apple com AirPods Pro + iOS/FDA DEN230081). Portanto, o monitor de exposição do `timbr` opera em **dois modos claramente rotulados**:
     - **`ESTIMADO (dBFS + Sensibilidade do Modelo)`** quando houver dado de sensibilidade/impedância do fone;
     - **`EXPOSIÇÃO RELATIVA (dBFS · LUFS)`** quando não houver calibração — nunca exibindo um número falso de "dB SPL exato" sem calibração física.

---

## 5. Estratégia Completa de Testes Metrológicos e Verificação

| Camada | Método / Padrão | O que mede | Critério de Aprovação (Gate) |
|---|---|---|---|
| **1. Null Test (Bypass & Ganho Unitário)** | Injetar arquivo de teste (`96 kHz / 24-bit` + sweep + ruído rosa + silêncio) em modo *Bypass* e em *All-Neutral*; inverter fase da saída e somar (`diff = out - in`). | Qualquer alteração indevida de fase, ganho, dither espúrio ou deslocamento de amostra. | **Bit-exact (`−∞ dBFS` / resíduo `0`)** em caminho neutro sem taps; resíduo `≤ −140 dBFS` quando atravessando pipeline `Float64 -> Float32` em ganho unitário. |
| **2. Verificação de Curva & Erro de Magnitude** | Impulso unitário (`Dirac`) → FFT longa (`65536` pts) comparada à resposta analítica contínua (`|H(jω)|`) de 20 Hz a 20 kHz. | Precisão de coeficientes Matched/Orfanidis/RBJ, comportamento perto de Nyquist (`44.1 / 48 / 96 kHz`), soma composta de 20 bandas. | Erro `≤ ±0,05 dB` vs resposta teórica da topologia selecionada de `20 Hz` a `20 kHz` (Golden Vectors no CI). |
| **3. ESS (Farina, AES 2000) & THD+N (`AES17`)** | *Exponential Sine Sweep* (`20 Hz–20 kHz`) + tom puro `1 kHz` a `-1 dBFS` analisado com filtro passa-baixa `AES17 20 kHz` (`< -60 dB` em `24–200 kHz`). | Separação simultânea de resposta ao impulso linear + harmônicos H2..H5 + piso de ruído (`SINAD` / `THD+N`). | THD+N adicionado pelo motor DSP em `Float64` **`< −130 dB`** (abaixo do limite de 24-bit); zero aliasing ou produtos espúrios de modulação ao variar parâmetros. |
| **4. True-Peak & Limiter Stress** | Injetar faixa sintética com picos inter-amostra conhecidos (`+4,5 dBTP` via `0 dBFS` square-like / `fs/4` phase-shifted tones) + ganho EQ `+6 dB`. | Eficácia do preamp automático e do limiter `4× oversampled BS.1770`. | Saída pós-limiter **`≤ 0,0 dBTP`** em 100% das amostras sob `4×` oversampling; recuperação limpa sem *pumping* perceptível. |
| **5. Real-Time Safety (RTSan + Instruments)** | Build de testes unitários com **`-fsanitize=realtime` (RTSan)** + profiling de sessão real no Xcode **Instruments (*Audio System Trace* + *Time Profiler*)**. | Alocações, mutexes, chamadas ObjC, `page faults`, `engine jitter`, *overloads* e `clock discontinuity`. | **0 violações RTSan** no grafo RT; **0 overloads** sob carga de 8 apps simultâneos + 10 bandas PEQ + FFT ativo em buffer de `128 frames`. |
| **6. EBU R128 Conformance** | Vetores oficiais de teste do **EBU Tech 3341** (tons contínuos, janelas de gate, true-peak 4×). | Acurácia de Momentary, Short-term, Integrated e dBTP. | Desvio `≤ ±0,1 LU` e `≤ ±0,1 dBTP` em todos os vetores EBU. |
| **7. Teste de Longa Duração (Soak 24h) & Fail-Safe** | Loop contínuo de 24h alternando apps, trocando sample rates, conectando/desconectando BT/USB e disparando `kill -9` aleatórios no processo/motor. | Vazamento de memória (`RSS` / `vmmap`), vazamento de file descriptors / AudioObjectIDs órfãos, restauração de som. | Zero crescimento monotônico de memória após estabilização; restauração do áudio do sistema em **`≤ 1,0 s`** após `kill -9`; zero tap/aggregate órfão. |
| **8. Escuta Cega ABX (`ITU-R BS.1116` / `MUSHRA`)** | Comparação às cegas nivelada por LUFS (`Δ ≤ 0,1 dB`) contra SoundSource / FineTune / referência sem EQ com 20 tentativas por par. | Transparência subjetiva e ausência de artefatos de fase/zipper/limiter. | Mínimo estatístico binomial unilateral `p < 0,05`: **≥ 15/20** acertos para declarar diferença audível (ou equivalência se indistinguível: `8–12/20` sem preferência estatística). |

---

## 6. Síntese para o Plano (`estrategia-de-testes.md` e `requisitos-nao-funcionais.md`)

1. **Núcleo RT em C++20 ou Rust com RTSan obrigatório no CI** — garante por compilação que Swift ARC/ObjC nunca entrem no callback de áudio.
2. **Golden Test Suite sem hardware** — 90% da qualidade DSP (null test, curva FFT, THD+N sintético, EBU R128, BS.1770 dBTP, parser fuzzing) roda 100% offline em qualquer runner macOS de GitHub Actions via render offline de buffers, deixando para o Mac físico apenas os testes de HAL/taps/Instruments/Bluetooth.
3. **Respeito rigoroso aos limites de medição:** nenhuma tela exibirá "dB SPL calibrado" ou "codec aptX confirmado" sem sensor/API comprovada.
