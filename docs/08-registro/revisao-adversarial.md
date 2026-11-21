# Revisão Adversarial Obrigatória (5 Personas) & Reformulação do Plano

> **Diretriz:** Protocolo da Seção 16 — antes de iniciar código de produto ou encerrar o planejamento definitivo, o plano inteiro foi submetido a crítica adversarial severa sob cinco perspectivas especializadas independentes. Toda crítica procedente gerou **reformulação explícita** nos documentos afetados.

---

## 1. Síntese das Críticas por Persona

### Persona 1 · Engenheiro Sênior de Áudio / Core Audio
1. **Complexidade prematura do helper XPC (`ADR-0006`) no MVP:** Separar motor e UI em processos distintos exige anel PCM cross-process (`IOSurface` / Mach shared memory + Mach semaphores com herança RT) além de lidar com duas identidades TCC diferentes. Se forçado antes do Gate G2, atrasa em semanas a estabilidade de `E-01..E-03`.
2. **Armadilha em chamadas VoIP (`Zoom`, `Meet`, `Teams`, `WeChat`) dentro de Process Taps:** Confirmado em issues reais do `FineTune#477/#493` (Nota 11): capturar saída de apps VoIP com AEC/AGC próprio gera esmagamento de ganho ou microfonia/eco se roteado junto a música ou multissaída. O plano mencionava uma lista de ignore genérica no `E-10`, mas não tornava a **exclusão segura padrão de apps VoIP/DAW** um requisito explícito de produto.
3. **Desalinhamento de toolchain local (`Xcode` vs `CommandLineTools`):** Na máquina local observou-se CommandLineTools Swift 6.3.3 com SDK esperando Swift 6.4, e pacotes como `KeyboardShortcuts` 2.2+/3.0+ falham em `swift build` sem Xcode completo. Falta verificação de ambiente pré-Fase 0.

### Persona 2 · Especialista em DSP (`Float64`, Limiter & Acústica)
1. **Subestimação do True Peak `4×` perto de 20 kHz (`sdroege/ebur128#69`):** A própria auditoria do projeto mostrou que o modo padrão 4× de ITU-R BS.1770 pode subestimar picos inter-amostra em altas frequências em até **`~1,8 dB`**. Mesmo assim, o plano propunha teto de limiter em `-0,1 / -0,2 dBTP` e margem padrão de apenas `0,2 dB` no preamp — arriscado especialmente antes de encoders Bluetooth AAC-LC!
2. **Preamp por magnitude somada ignora transientes de fase:** Calcular `max_f |H_total(f)|` em módulo não impede overshoot temporal em ondas retangulares ou transientes curtos quando filtros IIR fase-mínima rotacionam fase na mesma região. Falta margem empírica de fase ou validação no domínio do tempo ao compilar o preset.
3. **Transição silenciosa Ativo ↔ Passivo no Momentum 4 via cabo 3,5 mm:** O jack P2 do Mac é puramente analógico; ele não informa se o Momentum 4 está ligado (`470 Ω`, DSP ativo) ou se acabou a bateria (`60 Ω`, passivo). Confiar só em troca automática via `DeviceUID` falharia no cabo P2.

### Persona 3 · Audiófilo Exigente
1. **A/B cego invalidado por diferença de latência entre Bypass (sem tap) e Processado (com tap):** Se o modo neutro destrói o tap (`0 ms`) e o modo equalizado mantém o tap (`2,67 ms` ou `+FIR`), o clique ou salto de atraso entrega imediatamente qual é A e qual é B no teste cego!
2. **Fadiga de alertas ("Guardião barulhento"):** Usuários avançados que escolhem deliberadamente 48 kHz ou EQ próprio no fone não podem ser interrompidos repetidamente por alertas do Guardião.
3. **Tradução forçada de jargões técnicos em `PT` e `ES`:** Traduzir *Headroom*, *True Peak*, *Bypass* ou *Crossfeed* para neologismos artificiais prejudica a clareza técnica de audiófilos bilíngues/trilíngues.

### Persona 4 · Mantenedor Open Source
1. **Toolchain tri-linguagem (Swift + C++ + Rust `camilladsp`) no MVP espanta contribuidores:** Exigir Cargo/Rust + C ABI + Swift + C++ desde a Fase 1 aumenta drasticamente o atrito de build, CI e revisão. Se **C++20 + `Accelerate/vDSP` (`Float64`)** passar nos mesmos golden tests (`< -140 dBFS`, `THD+N < -130 dB`, RTSan 0 violações) em `E-06`, manter Rust fora do MVP e reservar `camilladsp` para convolução avançada pós-MVP torna o repositório muito mais contribuível.
2. **Dependência do script `/usr/bin/perl` no `mediaremote-adapter`:** Precisa estar isolada em pacote adaptador substituível para não quebrar o build central quando a Apple alterar o runtime.

### Persona 5 · Product Designer Sênior
1. **Colisão de largura no Notch de MacBooks de 13"/14" com Menu Bar cheia:** Em telas 14" (com muitos ícones na direita), um estado *Compacto* que ultrapasse `~40–44 pt` por orelha conflita com ícones de menu do macOS. Falta orçamento numérico rígido por largura de tela.
2. **Expansão de texto em `ES` e `PT` (25–35% mais longo que `EN`) nos chips do Notch:** Rótulos como *"Noise Cancelling"* viram *"Cancelación de ruido"* ou *"Cancelamento de ruído"*, quebrando chips compactos da Espiada/Pílula se não houver variantes curtas obrigatórias em `.xcstrings`.
3. **Uso indevido da wordmark `timbr.` em ícones pequenos (`.icns`):** A wordmark completa `timbr.` (6 caracteres) fica ilegível em `16×16` / `32×32` na menu bar e Dock; o ícone de app deve usar o glifo geométrico derivado (`curva paramétrica + ponto .`) enquanto a wordmark vive em superfícies ≥ 80 px.

---

## 2. Decisões e Reformulações Aplicadas ao Plano

| # | Crítica Recebida | Veredito | Ação Aplicada nos Documentos |
|---|---|---|---|
| **C-01** | Helper XPC no MVP dobra risco RT/TCC | **Aceita** | `roadmap-e-backlog.md` e `ADR-0006`: MVP (Fase 1) roda **in-process com módulo `Engine` desacoplado + watchdog**, mantendo `E-16` como experimento que promove XPC no Beta/1.0 se a UX/TCC compensar. |
| **C-02** | Apps VoIP/DAW sofrem ganho/eco em Process Taps | **Aceita** | `PRD.md` (`EP-01`) e `roteamento-e-abas.md`: **lista de exclusão segura ativa por padrão** para apps VoIP (`Zoom`, `Teams`, `Meet`, `FaceTime`, `Discord` voz) e DAWs exclusivos, com opt-in consciente. |
| **C-03** | True Peak `4×` subestima `~1,8 dB` perto de 20 kHz + fase IIR | **Aceita** | `motor-dsp-e-precisao.md` e `requisitos-nao-funcionais.md`: teto do limiter BT AAC ajustado para **`-1,0 dBTP`** (`-1,5 dB` de margem extra recomendável no preamp BT), adição de margem de fase (`+0,5 dB`) sobre `H_total(f)` e atualização da nota sobre **Vicanek (2024) *Matched Two-Pole Digital Shelving Filters***. |
| **C-04** | A/B cego inválido se Bypass destruir tap (`0 ms` vs `2,67+ ms`) | **Aceita** | `motor-dsp-e-precisao.md` e `PRD.md`: dentro do **modo A/B cego**, A e B compartilham **tap ativo e mesma latência compensada** com crossfade de `20 ms`; fora do A/B, o **Bypass diário** continua destruindo o tap para transparência bit-exact. |
| **C-05** | Cabo 3,5 mm do M4 não sinaliza se fone está ligado (`470 Ω`) ou desligado (`60 Ω`) | **Aceita** | `momentum4-laboratorio.md` e `PRD.md`: adicionado **seletor rápido de 1 clique (`Ativo 470 Ω` / `Passivo 60 Ω`)** no card do dispositivo quando conectado por saída analógica P2. |
| **C-06** | Toolchain Swift + C++ + Rust no MVP afasta contribuidores | **Aceita** | `roadmap-e-backlog.md` e `ADR-0003`: **viés explícito em E-06 para C++20 + `vDSP` (`Float64`) no MVP** se atingir as metas metrológicas (RTSan `0`, `< -140 dBFS`, `THD+N < -130 dB`); `CamillaDSP` v5 fica reservado para convolução/extras pós-MVP se reduzir complexidade sem perda. |
| **C-07** | Guardião intrusivo para usuários experientes | **Aceita** | `PRD.md` (`EP-07`): adicionado **silenciamento por par `(app, dispositivo)`** e **"Modo Estúdio Silencioso"** (registra na timeline sem popup no notch). |
| **C-08** | Colisão no Notch 14" + truncamento `PT/ES/EN` + `.icns` com texto | **Aceita** | `03-superficies-e-anatomia.md`, `00-biblia-do-design-system.md` e `05-assets...md`: teto estrito de **`≤ 40 pt` por orelha** no Compacto, **variantes curtas obrigatórias** no `.xcstrings`, regra editorial de **jargões técnicos preservados (`dBTP`, `Headroom`, `Bypass`, `Crossfeed`)** e separação estrita entre **wordmark `timbr.`** e **glifo `.icns` (`curva + .`)**. |
