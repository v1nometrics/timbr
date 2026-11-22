# Mercado, Concorrência e Diferenciação (Inclui Ideias Fora da Caixa)

> **Base empírica:** [Relatório Fase 1](../00-pesquisa/relatorio-fase-1-notch-audiofilo.md), [Nota 06](../00-pesquisa/notas-fase-1/06_mercado_benchmarks_restricoes.md) e [Nota 11](../00-pesquisa/notas-fase-2/11_auditoria_repositorios_oss.md).

---

## 1. Mapa Competitivo Detalhado (Onde Todos Sangram Hoje)

| Concorrente | Categoria / Modelo | Pontos Fortes Reais | Falhas Reais Comprovadas (Voz do Usuário & Arquitetura) | Como o `timbr.` Vence com Rigor |
|---|---|---|---|---|
| **SoundSource** (Rogue Amoeba) | Pago (~US$ 45) · Fechado | Referência de estabilidade em Process Taps (v6.2+), suporte amplo a AU, política "Output Only" anti-HFP, EQ sólido. | Interface utilitária tradicional (menu bar), sem camada inteligente/AutoEq nativa no fluxo principal, sem telemetria de cadeia/transparência honesta, sem drivers Bluetooth (Momentum 4), sem abas individuais de browser, código fechado. | Paridade de confiabilidade HAL + **Notch Editorial vivo**, **Observatório + Guardião**, **AutoEq integrado**, **Correção × Gosto** e **driver Momentum 4**, em **open source MPL-2.0**. |
| **FineTune** | OSS (`GPL-3.0`) · Gratuito | Pioneiro em Process Taps gratuitos, leve, simples por app. | Issues recorrentes de *loudness glitches*, *crackling*, **estouro de volume nos primeiros ms** ao abrir stream, falhas com AirPods e áudio duplicado em OBS/Discord; sem Observatório, sem notch, sem DSP Float64 avançado; `GPL-3.0`. | Nasce exatamente dos aprendizados de **E-02** (sem estouro inicial) e **E-01/E-03** (watchdog + null test), adiciona DSP `Float64` + True-Peak limiter + Guardião HFP + Notch. |
| **eqMac** | Freemium (`GPL-3.0` core) | Popularidade alta, UI visual para EQ gráfico/paramétrico, integração AutoEq. | Driver virtual legado causa *crackling*, pedidos abertos há anos por bypass por dispositivo e troca automática confiável; fonte aberta não usa Process Taps modernos como base unificada. | Process Taps sem driver virtual de kernel (`0` kexts/AudioServerPlugIn obrigatório), perfis automáticos por `DeviceUID + modo`, `Float64` com matched biquads. |
| **Loopback / Audio Hijack** | Pago (US$ 99 / US$ 77) | Roteamento de estúdio extremamente poderoso entre apps e canais virtuais. | Complexidade excessiva para escuta diária; UI de patchbay pesado; não vive no notch nem oferece AutoEq/preferência auditiva. | Roteamento essencial (multissaída + alinhamento ms + cenas) acessível em 2 cliques no notch, mantendo foco em escuta audiófila. |
| **BackgroundMusic** | OSS (`GPL-2.0`) | Famoso histórico de volume por app gratuito no macOS. | Arquitetura antiga baseada em driver virtual + **bug crônico do ponto laranja de microfone ativo** no macOS moderno; manutenção lenta. | Zero ponto laranja (Process Taps `NSAudioCaptureUsageDescription` em modo *System Audio Recording Only*, nunca captura de mic contínua). |
| **boring.notch / Alcove / DynamicLake / Atoll** | Apps de Notch (OSS `GPL-3.0` ou Pagos) | Popularizaram o uso do notch do MacBook para Now Playing, HUD e utilidades rápidas. | Foco estético/superficial em capa de álbum e widgets genéricos; **nenhum** controla áudio por app/aba, **nenhum** tem EQ audiófilo nem proteção anti-HFP; `boring.notch` sofreu quebra grave do Now Playing no macOS 15.4. | O notch deixa de ser brinquedo de capa de disco para virar **instrumento de precisão acústica** com divulgação progressiva (0 caos no Repouso). |
| **LosslessSwitcher** | OSS (`GPL-3.0`) | Troca automática de sample rate do DAC conforme a faixa no Apple Music. | Foco único estreito; sem mixer, sem EQ, sem proteção multi-app; dependente de heurísticas de log/AppleScript. | Integra lógica de taxa honesta dentro do **Observatório + Guardião G-02**, indicando quando o modo exclusivo Bit-Perfect está preservado vs quando o mixer está ativo. |
| **FabFilter Pro-Q 4** | Plugin DAW (~US$ 179) | Padrão-ouro mundial em UX de EQ (`±3/6/12/30 dB`, Spectrum Grab, Piano Display, curva por banda + somada). | É apenas um plugin AU/VST dentro de DAWs; não controla o sistema operacional nem dispositivos/apps do Mac. | Traz a **ergonomia visual e precisão matemática de nível Pro-Q** para dentro do **Estúdio do macOS**, de forma calma e legível. |
| **Notchy** (`notchy.dev`) | Comercial (US$ 24,99 · Fechado) | 78 utilidades no notch (Face Unlock, AI Usage, Terminal, Shelf), mixer por app (até 150%), EQ de 3 bandas, AirPods battery, FFT via Process Tap, pílula em telas externas e API local `127.0.0.1:9999`. | Produto generalista (*Swiss Army knife*): apenas EQ gráfico simples de **3 bandas** (sem PEQ `Float64`, sem AutoEq, sem Vicanek/dBTP/BS.1770), sem Guardião `G-01..G-07`, sem driver Momentum 4 GAIA v3, sem abas de browser isoladas e código fechado. | Foco 100% acústico sem bloat de produtividade: **DSP `Float64` + Vicanek + `dBTP`/`BS.1770`**, **Correção × Gosto + `PairwiseGP`**, **Guardião HFP/Duplo-EQ**, **GAIA v3 Momentum 4** e código **MPL-2.0** auditável. |
| **R9-EQ** (`XPro-Gamer-Rhine/R9-EQ-app`) | Binário fechado (`license: null`) | EQ visual no notch + modos Liquid Glass/Frosted, curvas por app e suporte VDC. | Repositório público contém apenas `docs/` e scripts de instalação sem código-fonte nem arquivo `LICENSE` (`NONE`); zero auditoria possível de latência, DSP ou segurança. | Transparência total em **MPL-2.0**, núcleo DSP C++20 verificável com sanitizers/Null Test, Guardião e metrologia aberta. |
| **OmniMac** (`BySergiMM/OmniMac`) | OSS (`MIT`) | App nativo multi-utilitário no notch com mixer por app, `Equalizer.swift` 10 bandas, `Limiter`, bateria BT e `NotchGeometry`. | EQ gráfico fixo de 10 bandas (`Float32` RBJ Biquad Cookbook, sem PEQ livre, sem shelving Vicanek, sem `dBTP`, sem AutoEq e sem Guardião de sinal). | Mantém a precisão **`Float64` + Vicanek + True-Peak Lookahead + BS.1770 + AutoEq + Correção × Gosto + Guardião**, mantendo código 100% compatível (`MIT`/`MPL-2.0`). |
| **ILoveNotch** (`niyamvora/ILoveNotch`) | OSS (`MIT`) | Notch multi-tool limpo em SwiftUI com espectro e controles básicos por app/mídia. | Foco generalista (calendário, clipboard, mirror) com áudio básico; sem PEQ paramétrico, sem metrologia e sem driver de fones. | Especialização audiófila profunda + P4 ("verdade no sinal") + ecossistema Momentum 4 / abas de browser. |
| **Tapline** (`belugaming/tapline`) | OSS (`GPL-3.0`) | Process Taps no macOS com EQ por app, `LinearPhaseEQ`, `RoomAdvisor` e fix para HFP `< 40 kHz` (PR #33). | Sem notch, `GPL-3.0` (incompatível com projetos MPL-2.0/híbridos), sem driver Momentum 4 nem `PairwiseGP`. | Mesma proteção Nyquist HFP implementada em `CTimbreDSP` (`Float64` C++20), somada a Notch Editorial, Guardião e licença **MPL-2.0**. |
| **AudioRouter** (`AbhisekGanguly/AudioRouter`) | OSS (`MIT`) | Roteamento per-app via Process Taps + extensão Chrome Tabs e **`OrphanedTapCleanup`** para evitar apps presos em mudo após crash. | Sem EQ, sem notch, sem metrologia DSP nem proteção HFP/driver BT. | **Padrão `OrphanedTapCleanup` adaptado (MIT, em `NOTICE`)** dentro de `ProcessTapEngine`, somado a todo o pipeline DSP `Float64`, Guardião e Notch do `timbr.`. |
| **M4 Companion** (`Zhengyang-Liu/m4-companion`) | OSS (`MIT`) | Cliente Swift nativo exemplar para Sennheiser Momentum 4 via `IOBluetooth` RFCOMM GAIA v3 (bateria, SoundMode, ANC, EQ 5 bandas, multiponto). | Focado apenas em utilitário menu bar do Momentum 4; sem Process Tap, sem EQ do sistema, sem AutoEq e sem proteção `G-04` integrada ao DSP do Mac. | **Framing `GaiaSPP` (`0xFF 0x03`) + opcodes read-only adaptados (MIT, em `NOTICE`)** em `Momentum4Driver`, alimentando diretamente o Guardião `G-04` (Duplo EQ). |
| **LibrePods / AirBattery / apple-ble / mubar** | GPL-3 / AGPL-3 / MIT / MIT | Estado da arte AACP (Linux) e Continuity BLE no macOS. | AACP bloqueado no macOS user-space; AirBattery AGPL. | **HAL + Continuity parser próprio (MPL-2.0)** + AutoEq; zero GPL/AGPL; UI honesta AACP fechado (Nota 12). |

---

## 2. Proposta de Valor Única (Sweet Spot do `timbr.`)

O **`timbr.`** ocupa um espaço hoje **vazio** no macOS: a interseção entre:
1. **Confiabilidade de engenharia de áudio real-time** (nível SoundSource / CamillaDSP, com testes metrológicos públicos e fail-safe em `< 1s`);
2. **Controle hardware-aware profundo** (Momentum 4 via GAIA v3 + linha Apple via HAL/Continuity + proteção anti-HFP para qualquer fone BT);
3. **Arquitetura de EQ em duas camadas (Correção × Gosto) + Observatório + Guardião** — elimina erro de iniciante e dá controle cirúrgico ao audiófilo;
4. **Notch Editorial silencioso e elegante** (baseado no Design System `timbr.`, sem ruído visual);
5. **100% local-first, open source MPL-2.0 e trilíngue (`PT`, `ES`, `EN`) desde a v1.**

### Veredito Honesto sobre Ineditismo vs. Mercado

O **`timbr.`** **não é inédito nas peças isoladas** — e reconhecer isso torna o produto melhor:
- Já existem apps de notch com áudio básico e mixer (**Notchy**, **OmniMac**, **ILoveNotch**, **R9-EQ**);
- Já existem apps de Process Tap + EQ/roteamento (**SoundSource**, **FineTune**, **Tapline**, **AudioRouter**);
- Já existe cliente nativo macOS para Momentum 4 via GAIA v3 (**M4 Companion**).

**Onde o `timbr.` continua genuinamente único hoje no macOS** é na **convergência integrada** dessas frentes com rigor metrológico:
1. **Motor DSP `Float64` verificável (Null Test, Vicanek Nyquist-matched, True-Peak `dBTP` lookahead, `ITU-R BS.1770`)** exposto no **Notch + Estúdio** — nenhum app de notch existente (nem `Notchy` com 3 bandas nem `OmniMac` com `Float32` RBJ) entrega esse nível de engenharia;
2. **Separação Correção Física (AutoEq/APO) × Gosto Pessoal + `PairwiseGP` A/B cego nivelado por LUFS**;
3. **Guardião Proativo (`G-01..G-07`) conectado à telemetria real de hardware** (detectando HFP, resampling oculto, clipping inter-amostra e **Duplo EQ no Momentum 4 via GAIA v3 read-only**);
4. **Arquitetura aberta `MPL-2.0` limpa** que reutiliza mecanismos `MIT` validados (`OrphanedTapCleanup`, `GaiaSPPDeframer`) com atribuição em [`NOTICE`](../../NOTICE), sem herança viral `GPL-3.0`.


---

## 3. Ideias Criativas & "Fora da Caixa" Avaliadas com Rigor

Durante a pesquisa, surgiram ideias diferenciadas para audiófilos. Cada uma foi triada pelo filtro de **viabilidade técnica + alinhamento ao P8 (MVP enxuto primeiro)**:

| Ideia Audiófila Fora da Caixa | Valor Real para o Audiófilo | Risco / Custo | Decisão no Planejamento |
|---|---|---|---|
| **1. Separação "Correção Física" × "Gosto Pessoal" + 4 Controles Macro** | Resolve a confusão de misturar AutoEq do fone com ajuste de humor/gravação, mantendo 3 curvas visíveis no gráfico. | Baixo (aritmética de biquads somados em `Float64`). | **Entra na Fase 2 (`B-203` / ADR-0010)** — núcleo diferenciador do Estúdio. |
| **2. Treinador Bayesiano de Gosto (`PairwiseGP` + EUBO 2–4D)** | Em 6–10 comparações A/B cegas niveladas por LUFS, descobre a assinatura ideal daquela pessoa sem exigir conhecimento de Hz/Q. | Médio (exige nivelamento LUFS exato `≤ 0,1 dB`). | **Entra na Fase 3 (`B-302`)** após gate E-14. |
| **3. Guardião Proativo (G-01..G-07) + Selo `BIT-PERFECT` Honesto** | Evita que o usuário passe horas ouvindo em HFP 16 kHz, resampling oculto, clipping inter-amostra ou **duplo EQ** (Momentum 4 + Mac). | Baixo/Médio (leitura HAL + GAIA + BS.1770). | **G-01 + selo honesto no MVP (`B-107/B-108`)**; Guardião completo na **Fase 2 (`B-205`)**. |
| **4. Modo "Escuta Noturna / Baixo Volume" (Equal-Loudness ISO 226 / Estilo RME ADI-2)** | Compensa perda fisiológica de graves e agudos quando o usuário ouve em volume baixo à noite, sem comprimir dinâmica. | Médio (depende de curva de calibração/ganho de referência). | **Entra na Fase 3 (`B-304` / RF-1502)** como módulo opt-in. |
| **5. Simulação Binaural / Crossfeed Natural (`bs2b`) para Gravações Ping-Pong (Jazz 60s / Rock Clássico)** | Elimina fadiga auditiva de separação L/R extrema em fones fechados como o Momentum 4. | Baixo (algoritmo `bs2b` clássico leve e determinístico). | **Entra na Fase 3 (`B-304` / RF-1501)** como toggle no Estúdio. |
| **6. "Snapshots A/B de Mesa & Cenas por Cabo/Ambiente" (USB-C vs BT vs 3.5mm Passivo)** | Troca automaticamente o perfil AutoEq do Momentum 4 quando você pluga o P2 com ele desligado (60 Ω) vs USB-C vs Bluetooth. | Baixo (`DeviceUID` + perfil distinto). | **Entra na Fase 2 (`B-206` + `momentum4-laboratorio.md`)**. |
| **7. Exportador de "Dossiê do Sistema de Áudio" & Bridge REW/CamillaDSP** | Permite exportar preset/medição direta para REW ou CamillaDSP Linux/Raspberry Pi streamer (ex.: mesa de som ou DAC de sala). | Baixo (parsers bidirecionais YAML/txt). | **Entra no MVP (`B-105` APO) e Pós-1.0 (`RF-1505` CamillaDSP export)**. |
| **8. Reconhecimento ShazamKit + Letras Editoriais em New York no Notch** | Identifica vinil/stream sem metadata e exibe letras com respiro tipográfico apenas quando solicitado (modo *Espiada/Expandido*). | Baixo/Médio (opt-in, rede só sob demanda). | **Fase 2 (`B-207` letras)** e **Fase 3 (`B-305` ShazamKit)**. |
| **9. Perfil Auditivo Relativo (Calibração Biológica 1 kHz sem Alegação Médica)** | Evita que o EQ aplique ganho inútil ou perigoso em banda onde o usuário tem queda auditiva ou assimetria L/R. | Alto risco regulatório se parecer audiograma médico. | **Pós-1.0 estritamente rotulado como relativo (`B-306`)**, nunca médico. |
| **10. "Audio Time Machine" (Buffer de gravação contínua de 30s)** | Ideia descartada como padrão: exigiria manter captura/RAM constante e viola o princípio **P7 ("zero áudio em disco/memória desnecessária")**. | Privacidade e RAM negativos. | **Rejeitado** (substituído por reconhecimento pontual ShazamKit de hash espectral sem salvar áudio). |
