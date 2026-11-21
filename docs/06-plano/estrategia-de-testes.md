# Estratégia de Testes e Verificação Metrológica

> **Base técnica:** [Nota 10 · Engenharia de Áudio, Qualidade e Testes](../00-pesquisa/notas-fase-2/10_engenharia_de_audio_qualidade_e_testes.md) · **Princípios:** P2 (*Fidelidade antes de tudo*), P3 (*Nunca deixar rastro*), P5 (*Viabilidade antes da complexidade*).

---

## 1. Pirâmide de Testes do `timbr.`

```
                 /\
                /  \   [5. Escuta Cega ABX + Dogfood 14 dias]  (Humano, nivelado ±0,1 LU)
               /----\
              /      \  [4. Bancada Hardware + Instruments + Soak 24h] (Mac real + M4 + BlackHole)
             /--------\
            /          \ [3. Integração HAL Mock + Parsers Fuzz + UI Snapshot PT/ES/EN]
           /------------\
          /              \ [2. Metrologia DSP Offline: Null, FFT, ESS/THD+N, BS.1770, EBU R128]
         /----------------\
        /   1. Unit + RTSan \ (-fsanitize=realtime: 0 allocs / 0 locks no caminho RT)
```

---

## 2. Suítes Automatizadas no CI (Sem Necessidade de Hardware de Áudio)

Mais de 85% das regressões de qualidade sonora e segurança RT podem ser detectadas antes de qualquer teste em fone físico através de processamento **offline determinístico de buffers** na suíte do motor DSP:

1. **RealtimeSanitizer (RTSan Gate):**
   - Toda função executada na callback de áudio é marcada com `[[clang::nonblocking]]` (C++) ou encapsulada em harness C/C++ compilado com `-fsanitize=realtime`.
   - O CI **falha imediatamente** se qualquer PR introduzir alocação (`malloc`/`new`), lock (`mutex`), syscall, log ou chamada Swift/ObjC dinâmica no caminho RT.
2. **Null Test Automatizado (Bit-Exact & Residual):**
   - Entradas sintéticas (`Float32` e `Float64`, `44.1 / 48 / 96 / 192 kHz`): seno `997 Hz`, ruído rosa, sweep e pulso unitário.
   - Cenário 1 (Bypass verdadeiro): saída `===` entrada (diferença exata `0.0`).
   - Cenário 2 (Tap em ganho `1.0`, EQ flat): diferença máxima `≤ −140 dBFS`.
3. **Golden Curve & Magnitude Match (`≤ ±0,05 dB`):**
   - Injetar impulso unitário (`Dirac`) por 65.536 amostras; calcular FFT; comparar módulo e fase contra função de transferência analítica contínua (`20 Hz–20 kHz`) para filtros *Matched* (Vicanek), *Orfanidis* e *RBJ*, incluindo bandas extremas (`20 Hz` a `192 kHz` e `16 kHz` a `44,1 kHz`).
4. **Farina ESS & THD+N (`AES17`):**
   - Rodar *Exponential Sine Sweep* (`20 Hz–20 kHz`) + tom `1 kHz @ −1 dBFS` através de 10 bandas PEQ ativas + preamp + limiter em modo inativo (`−2 dBTP`).
   - Deconvolver resposta ao impulso + separar harmônicos H2..H5 e aplicar filtro `AES17 20 kHz`: exigir `THD+N < −130 dB` no domínio `Float64` e ausência de aliases.
5. **True-Peak (`ITU-R BS.1770-5 Annex 2`) & EBU R128 (`Tech 3341`):**
   - Rodar vetores oficiais de conformidade EBU Tech 3341 (`M`, `S`, `I`, `dBTP` `4×` oversampling) exigindo erro `≤ ±0,1 LU` e `≤ ±0,1 dBTP`.
   - Injetar faixa sintética com inter-sample peaks `+4,5 dBTP` + EQ `+6 dB`: verificar que pós-limiter **100% das amostras ficam `≤ 0,0 dBTP`**.
6. **Fuzzing e Validação de Parsers & Protocolo GAIA:**
   - Fuzzing contínuo (libFuzzer / Swift property tests) nos parsers de **EqualizerAPO `.txt`**, **CamillaDSP `.yaml`**, **AutoEq JSON**, **WAV IR** e **frames binários GAIA v3** (com os vetores de `protocol-vectors.json` e verificação garantida da denylist `0x0607`, `0x0040`, `0x1405`, `0x02xx`).
7. **UI, Acessibilidade e Localização (`PT`, `ES`, `EN`):**
   - Verificação automática de 100% das chaves no `.xcstrings` sem strings órfãs ou faltantes em `pt-BR`, `es` e `en`.
   - Snapshot tests em SwiftUI cobrindo modo Claro, Escuro e Notch `#000000`, verificação de contraste (`≥ 4.5:1`), truncamento de texto em `ES`/`PT` (idiomas ~20% mais longos que `EN`) e presença de labels VoiceOver em controles sobre `Canvas`.

---

## 3. Testes em Bancada Real (MacBook com Notch + Hardware)

1. **Loopback Digital com BlackHole (E-01, E-02, E-04, E-06):** captura digital direta da saída roteada pelo `timbr.` para medir latência por correlação cruzada, descontinuidades no início de stream (primeiros `500 ms` — estouro E-02) e estabilidade de clock em multissaída.
2. **Instruments *Audio System Trace* & `powermetrics` (E-03, E-10):** gravação de 1h sob estresse verificando `0 overloads`, `engine jitter` dentro da margem do buffer, CPU `< 1,5%` e RAM estável.
3. **Teste de Falha e Restauração (`kill -9`):** script que dispara `kill -9` no processo do motor/app durante música tocando e mede tempo de recuperação de áudio (`≤ 1,0 s`) e integridade do snapshot do sistema ao reiniciar.
4. **24h Soak Test Automatizado:** alternância cíclica de apps (Safari, Music, Spotify, Zoom), troca de dispositivos (Interno ↔ Momentum 4 BT ↔ USB-C ↔ AirPods Pro), sleep/wake do MacBook e `killall coreaudiod` simulado.
5. **Bancada Bluetooth / Guardião (E-08, E-09):** abertura simultânea de chamadas (Meet/Zoom/Discord) com Momentum 4 e AirPods Pro para garantir `0` falsos negativos na proteção anti-HFP; sonda read-first e validação segura de RFCOMM GAIA v3 no M4.

---

## 4. Validação Perceptual: Escuta Cega ABX (`ITU-R BS.1116` / `MUSHRA`)

Para comprovar o objetivo de 1.0 (*"neutro indistinguível e equalizado preferido ou igual aos líderes"*):
- **Regra absoluta de nivelamento:** medir `Integrated LUFS` (ou `Short-term` do trecho em loop) de A e B via `libebur128` e igualar ganho com precisão **`≤ ±0,1 dB`** antes de qualquer julgamento humano (neutralizando o viés de "mais alto = melhor").
- **Estatística:** teste ABX com **20 tentativas** (mínimo matemático para `p < 0,05` unilateral é `5/5`, mas `20` tentativas dá poder estatístico real exigindo **`≥ 15/20` acertos**, `p = 0,0207`).
  - *Comparação Neutro vs. Original:* esperamos resultado próximo ao acaso (`8–12/20`), provando transparência auditiva.
  - *Comparação `timbr.` vs. SoundSource/FineTune com mesma curva:* audição cega para detectar diferenças de ringing, fase ou clipper.
