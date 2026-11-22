# Motor DSP e Precisão Audiófila

> **ADRs vinculados:** [ADR-0003](../07-decisoes/ADR-0003-nucleo-dsp.md), [ADR-0009](../07-decisoes/ADR-0009-formato-de-presets.md), [ADR-0010](../07-decisoes/ADR-0010-correcao-e-gosto.md).
> **Princípios vinculados:** **P1 (Fidelidade)**, **P4 (Verdade no sinal)**, **P6 (IA propõe, DSP decide)**.
> **Nota de evidência:** a escolha final entre núcleo C++20/Accelerate próprio vs. crate `camilladsp` v5 (MPL-2.0) depende do experimento **E-06** e dos critérios da nota técnica `10_engenharia_de_audio_qualidade_e_testes.md`.

---

## 0. Estado implementado (2026-11-23)

- **Núcleo:** `Sources/CTimbreDSP/src/timbre_dsp.cpp` (C++20, `Float64` interno, vDSP para FFT). Biquads Vicanek/RBJ, preamp automático pela resposta somada (+0,5 dB de margem de fase), limiter true-peak (detector 4× Catmull-Rom, lookahead de 1,5 ms, release de 80 ms, teto padrão −0,3 dBTP), LUFS momentâneo BS.1770, FFT a ~60 Hz, crossfeed estilo bs2b, linha de atraso de até 250 ms e dither TPDF opcional. Classe: **Comprovado** (testes C++ com ASan/UBSan no CI).
- **Parâmetros:** buffer triplo wait-free. O escritor (thread de controle, serializado por mutex que o áudio nunca toca) publica config + bandas num slot livre (`timbre_dsp_update`); o áudio troca de slot no início de cada bloco. Um escritor publicando sem parar nunca sobrescreve o slot em uso: há um teste de corrida no CI. Swift só publica quando a assinatura da EQ muda. Ganho e A/B são atômicos com de-zipper de 10 ms e 20 ms.
- **Render (`TapRenderer`):** sem alocação, lock ou ARC. Lê o tap no fim da lista de entradas (depois das entradas do subdispositivo), em estéreo intercalado ou em dois buffers mono. Escreve L/R nos canais 0/1 de saídas multicanal, em saídas planares ou como mix mono, e zera todo o resto.
- **Medido no app instalado (2026-11-22):** ganho por app exato em ±0,01 dB; limiter segura −0,30 dBFS de pico com +6 dB sobre um tom de −1 dBFS. Ver [teste E2E](../08-registro/teste-e2e-volume-por-app-2026-11-22.md).
- **Ainda não feito:** RTSan no CI (hoje ASan/UBSan), null test bit-exact com tap real (H-01), golden tests contra vetores EBU Tech 3341.

---

## 1. Arquitetura do Pipeline de Processamento (Por Destino)

Todo fluxo de áudio que entra no motor (após decisão de ativação por **P1** e **E-02**) percorre os estágios abaixo em **ponto flutuante de 64 bits (`Float64` / `double`)**:

```
Tap Core Audio (Float32)
   │
   ▼  [Conversão exata Float32 → Float64]
   ├─▶ Estágio 1: Ganho por fonte + Mute (rampa S-curve/linear ≥ 10 ms, zero-crossing/suave)
   ├─▶ Estágio 2: Soma do Mixer + Balanço L/R + Atraso de alinhamento (multissaída)
   ├─▶ Estágio 3: Preamp automático (calculado sobre a resposta somada Correção + Gosto)
   ├─▶ Estágio 4: Camada Correção (biquads Float64 IIR ou FIR opcional)
   ├─▶ Estágio 5: Camada Gosto (biquads Float64 IIR independentes; nunca misturadas no storage)
   ├─▶ Estágio 6: Módulos opt-in (Crossfeed bs2b / Loudness adaptativo / Convolução IR)
   ├─▶ Estágio 7: Proteção True-Peak (Limiter lookahead 4× oversampled, teto configurável -0.1 / 0.0 dBTP)
   ├─▶ Estágio 8: Medição Lock-Free (Pico, True Peak, RMS, LUFS M/S, Clip counter, FFT se ligado)
   └─▶ Estágio 9: Dither TPDF (somente se saída física/integer exigir; padrão Core Audio = Float32)
   │
   ▼  [Conversão Float64 → Float32]
Saída Core Audio HAL
```

### 1.1 Fronteira C ABI (`timbre_dsp.h`) e Regra Real-Time
- **Proibições absolutas na thread `AudioDeviceIOProc`:** `malloc`/`free`, locks (`pthread_mutex`, `os_unfair_lock`, `DispatchSemaphore`), Objective-C messaging (`objc_msgSend`), Swift ARC / alocação de existentials, syscalls de disco/rede/log (`os_log`, `print`).
- **Atualização de parâmetros sem estalos (zipper-free):** o cálculo de coeficientes (`Float64`) ocorre na thread de controle não-RT. Os novos coeficientes ou ganhos são publicados por fila SPSC lock-free ou troca de ponteiro atômico com interpolação por bloco/amostra (`vDSP_biquadm_SetTargetsDoubleD` ou interpolação de estado/coeficientes em ≥ 10 ms).
- **Verificação estática e dinâmica:** validação obrigatória com **Clang Realtime Sanitizer (RTSan)** no CI para builds C/C++ (e verificação `no_alloc` se Rust).

---

## 2. Precisão Numérica e Topologia de Filtros

| Decisão | Especificação | Justificativa / Evidência |
|---|---|---|
| **Precisão interna** | `Float64` (coeficientes **e** acumuladores/estados de atraso) | **Provável / Padrão de referência:** CamillaDSP e Roon usam 64 bits. FineTune usa `vDSP_biquad` (`Float32`), que acumula erro de quantização em filtros high-Q de baixa frequência (ex.: `20 Hz, Q=5, fs=192 kHz`). E-06 quantificará o ganho exato de ruído. |
| **Forma do biquad** | **Direct Form II Transposed (DF2T)** padrão; avaliação de **Direct Form I (DF1)** ou coeficientes interpolados para modulação em tempo real | DF2T possui excelente comportamento numérico em `Float64` (adotado pelo CamillaDSP v5 em `DiffEq`); DF1 evita transientes se polos moverem rapidamente sem crossfade. |
| **Resposta em agudos (anti-cramping)** | Modo padrão mínimo: RBJ Bilinear + exibição da resposta **digital real** na UI; Modo Alta Precisão: filtros **casados analógicos (Vicanek / Orfanidis)** para `Peaking` e **sobreamostragem 2× linear-phase / IIR mínima** quando houver shelves altos (`> 8 kHz`) em `44.1/48 kHz` | **Comprovado (literatura + nota 02):** transformada bilinear comprime a largura/ganho acima de ~10 kHz a 44,1/48 kHz. Vicanek publicou em 2024 (*Matched Two-Pole Digital Shelving Filters*) extensões para shelving que resolvem cramping junto com os filtros de pico (2016); E-06 validará Vicanek 2016/2024 vs Orfanidis vs `2× oversampling` em golden tests. |
| **Fase padrão** | **IIR Fase Mínima** (latência `0 ms`, zero *pre-ringing*) | Essencial para uso sistêmico (vídeo, chamadas, jogos e feedback instantâneo de controles). Convolução FIR de fase linear ou mista é **opt-in explícita** com latência exibida no Observatório. |
| **Bandas** | Mínimo 10–20 bandas no MVP, arquitetura para **N bandas arbitrárias** (`PK`, `LS`, `HS`, `LP`, `HP`, `BP`, `Notch`, `AllPass`, `Tilt`) | Supera o teto de 10 bandas gráficas do SoundSource e iguala flexibilidade de EQ paramétrico de estúdio (FabFilter Pro-Q 4 / CamillaDSP `NPointPeq`). |

---

## 3. Gerenciamento de Headroom, Preamp e Limiter True-Peak

1. **Preamp pela resposta somada (nunca apenas pela maior banda):**
   - Bandas adjacentes de `Correção` e `Gosto` somam-se em fase/magnitude.
   - O cálculo de preamp percorre a grade logarítmica de resposta em frequência combinada `H_total(f) = H_correcao(f) · H_gosto(f)` (ex.: 512–1024 pontos de `10 Hz` a `fs/2`) e encontra `G_max_dB = max(20·log10(|H_total(f)|))`.
   - `Preamp_auto = -max(0, G_max_dB + margem_fase + margem_seguranca)` (padrão `margem_fase = 0,5 dB` para rotação de fase em transientes de filtros fase-mínima + `margem_seguranca = 0,5 dB` em cabo ou **`1,5 dB` automático para destinos Bluetooth AAC** dado o erro de até `~1,8 dB` observado em detecção `4×` perto de 20 kHz — `ebur128#69`).
2. **A/B Nivelado em Loudness e Latência Alinhada (EP-03 / EP-12):**
   - Ao comparar Preset A vs. Neutro (ou A vs. B), o motor compensa o ganho integrado percebido (`K-weighting` / EBU R128 dentro de `±0,1 dB`) **e mantém ambos os ramos no mesmo tap com latência alinhada e crossfade de `20 ms`** (nunca destruindo o tap durante um teste cego, para que diferença de delay/buffer não revele A vs. B). O Bypass fora do A/B continua desmontando os taps.
3. **Limiter True-Peak Lookahead (Rede de Segurança):**
   - **Detecção 4× oversampled** (ITU-R BS.1770-4) para capturar *inter-sample peaks* (`+0.1` a `+5.88 dBTP` observados na literatura — Archimago 2025).
   - **Comportamento:** transparente (ganho `1,0`, zero saturação harmônica) enquanto o sinal estiver abaixo do teto (`-0,2 dBTP` em DAC/cabo ou **`-1,0 dBTP` padrão em Bluetooth AAC** para folga contra overshoot pós-encoding e subestimação `4×` perto de Nyquist).
   - **Sinalização honesta:** sempre que reduzir ganho (`GR > 0 dB`), acende o indicador no Estúdio e incrementa contador no Observatório (regra **G-03**).
4. **Bypass Verdadeiro (P1):**
   - Alternar Bypass (`⌥⌘B`) executa crossfade de `10 ms` até o estado neutro e, quando todas as fontes estão em `1,0`, solicita ao Tap Manager o teardown completo dos process taps (se **E-02** confirmar arranque sem estouro).

---

## 4. Formatos, Otimização Local e Extras Audiófilos

- **Formato canônico:** `timbre.preset/v1` (JSON separado em objetos `correction` e `taste`, conforme ADR-0009 e ADR-0010).
- **Intercâmbio:** parser e exportador lossless para **EqualizerAPO ParametricEQ** (`Preamp`, `PK`/`PEQ`, `LS`/`LSC`, `HS`/`HSC`, `LP`, `HP`, `NO`, `AP`), importação de `GraphicEQ` 127 pontos e exportação de pipelines **CamillaDSP YAML**.
- **Otimizador local (Pós-MVP / Fase 2–3):** ajuste de curva alvo (`Harman OE 2018`, `Harman IE 2019`, `B&K 5128 DF`, curvas futuras com validação pública) a partir de CSV de medição ou índice AutoEq, gerando até N biquads otimizados fora da thread RT.
- **Módulos opt-in (Fase 3 / B-304):**
  - **Crossfeed `bs2b`:** presets `Default` (`700 Hz / 4.5 dB`), `Chu Moy` (`700 Hz / 6 dB`), `Jan Meier` (`650 Hz / 9.5 dB`), licença MIT/BSD compatível.
  - **Convolução FIR (IR):** FFT particionada de baixa latência (se CamillaDSP v5 ou Accelerate `vDSP_FFT`), com exibição obrigatória da latência total em `ms` no Observatório.
  - **Loudness Adaptativo (estilo RME ADI-2):** compensação dinâmica por curvas ISO 226:2023 dependente da atenuação de volume aplicada no destino.
- **Dither (Estágio 9):** Core Audio recebe `Float32` por padrão (`kAudioFormatFlagIsFloat`), delegando quantização final do DAC ao HAL; dither TPDF / High-pass noise shaping (CamillaDSP) fica reservado a fluxos explícitos de saída inteira de 16 bits ou modo exclusivo/bit-exact futuro.
