# Roadmap por Fases e Backlog Estruturado

> **Regra de ouro (P5 + P8):** nenhuma feature das Fases 2+ entra antes da aprovação nos Gates anteriores. O **MVP** só é considerado pronto quando o Mixer por Fonte + EQ HiFi rodarem por 14 dias reais sem desligamento.

---

## Visão Geral das Fases e Gates

```
[Fase 0: Laboratório & Provas] ──(Gate G0/G1)──▶ [Fase 1: MVP — O Essencial Impecável]
         (E-01 a E-12)                                   (Mixer + EQ + Dispositivos + Notch)
                                                                 │
                                                           (Gate G2: 14 dias dogfood)
                                                                 ▼
[Fase 3: 1.0 — Inteligência & Ecossistema] ◀──(Gate G3)── [Fase 2: Beta Público — Expansão]
  (LLM deltas, A/B Bayesiano, Live Activity, Site)          (Abas, Multissaída, M4, Observatório+)
```

---

## Fase 0 · Laboratório de Viabilidade (Semanas 1–6)

**Objetivo:** eliminar todos os "desconhecidos" críticos antes de escrever o app definitivo.
**Entregáveis:** executáveis/scripts descartáveis em `experiments/E-XX-*` e `RESULTADO.md` por experimento.

| Lote | Experimentos | Critério de Gate (G1) |
|---|---|---|
| **Lote A · Audio Core** | E-01 (null test / failsafe), E-06 (C++20 `vDSP` Float64 vs CamillaDSP v5 / matched), E-07 (sonda HAL) | Null test documentado; núcleo DSP decidido (ADR-0003 — preferência por C++20/`vDSP` no MVP se atingir RNFs, reduzindo toolchain para contribuidores); matriz real de dispositivos |
| **Lote B · Confiabilidade & Mixer** | E-02 (estouro inicial 500 ms), E-03 (watchdog 24h), E-04 (multissaída + ducking), E-10 (coexistência), E-16 (processo helper) | 24h soak sem áudio morto/órfãos; topologia de taps definida; ADR-0005 e ADR-0006 aceitos |
| **Lote C · Diferenciação & UI** | E-05 (abas Safari/Chrome), E-08 (guardião HFP + codec), E-09 (Momentum 4 RFCOMM), E-12 (notch LCD/OLED + tokens) | Veredito real para abas e M4; tokens de notch validados em hardware |

---

## Fase 1 · MVP ("Duas Coisas Excelentes", P8)

**Público:** uso diário do autor + contribuidores iniciais.
**Condição de saída (Gate G2):** 14 dias seguidos usando o Timbre como único mixer e EQ sem precisar matá-lo.

| ID | Épico | Item de Backlog | Prioridade | Critério de Aceite |
|---|---|---|---|---|
| **B-101** | EP-14 | Motor de áudio (módulo `Engine` isolado in-process no MVP ou helper XPC se E-16 provar necessidade imediata) + snapshot/restore e fail-safe (`kill -9` ≤ 1 s) | P0 | Teste automatizado + soak 24h |
| **B-102** | EP-01 | Mixer por app ativo (volume com rampa 10 ms, mute, ganho `>100%` com alerta) | P0 | Sem cliques ao arrastar; lista agrupando helpers |
| **B-103** | EP-03 | Motor EQ `Float64` (mín. 10–20 bandas PEQ, filtros casados/RBJ, preamp por resposta somada + margem) | P0 | Golden tests dentro da tolerância NFR |
| **B-104** | EP-03 | Limiter true-peak de proteção com indicador visível + bypass verdadeiro + A/B nivelado | P0 | Zero amostra `> 0 dBTP` na saída com limiter ativo |
| **B-105** | EP-04/05 | Import/export EqualizerAPO ParametricEQ + integração sob demanda com índice AutoEq (crédito + cache) | P0 | Round-trip de presets sem perda de intenção |
| **B-106** | EP-06 | Sonda HAL + seleção de entradas/saídas + volume/mute HW ou SW sinalizado + tecla de mídia (`CGEventTap`) | P0 | Nenhuma UI exibe controle não gravável |
| **B-107** | EP-07 | Observatório v1: cadeia de estágios com selos `MEDIDO` / `REPORTADO` / `INFERIDO` e selo `BIT-PERFECT` honesto | P0 | `BIT-PERFECT` só acende sem taps ativos |
| **B-108** | EP-08 | Guardião Bluetooth G-01 (política "Output Only" anti-HFP + aviso de chamada) | P0 | Zero falso negativo nos testes E-08 |
| **B-109** | EP-13 | Notch (5 estados) + Pílula (monitor externo) + MenuBarExtra + Estúdio v1 (`TimbreTokens`) | P0 | 100% no checklist do Design System (§5) |
| **B-110** | EP-14 | Pipeline de assinatura Developer ID, notarização e cask Homebrew inicial | P1 | Instalação limpa sem aviso de Gatekeeper |

---

## Fase 2 · Beta Público (Expansão Controlada)

**Condição de saída (Gate G3):** 50 testadores externos; zero corrupção de áudio não reproduzível; crash-free dentro da meta NFR.

| ID | Épico | Item de Backlog | Dependência | Notas |
|---|---|---|---|---|
| **B-201** | EP-02 | Roteamento multissaída simultânea por app + alinhamento de atraso em ms | E-04 | Aggregates isolados (BT sem drift correction) |
| **B-202** | EP-09 | Extensões de navegador (Safari Web Extension + Chrome/Arc/Brave MV3) com volume por aba | E-05 | Boost/EQ/setSinkId entram se E-05 comprovar viabilidade |
| **B-203** | EP-03 | Separação explícita das camadas **Correção** × **Gosto** (4 controles simples + PEQ avançado) | ADR-0010 | UI sempre mostra as 3 curvas |
| **B-204** | EP-08 | Driver Sennheiser Momentum 4 v1 (read-first: bateria, ANC/Transparency, EQ interno + alerta G-04; escrita reversível de ANC se E-09 aprovar) | E-09 | Isolado do motor de áudio (ADR-0006/0011) |
| **B-204b** | EP-08 | Driver linha Apple (AirPods/Pro/Max/Beats): HAL + Continuity BLE flip-aware + matriz de capacidades + AutoEq 4/Pro/Max + UI Observatório/Mixer/Notch (sem AACP) | E-08 | [`airpods-laboratorio.md`](../03-viabilidade/airpods-laboratorio.md) — UI compartilhada feita; live Continuity pendente |
| **B-205** | EP-07 | Guardião completo (G-02 reamostragem, G-03 clipping, G-04 EQ duplicado, G-06 troca de device, G-07 conflito de tap) + medidores EBU R128/PPM | B-107 | Linha do tempo exportável em relatório de diagnóstico |
| **B-206** | EP-10 | Cenas e automações por contexto (device conectado, app de reunião aberto, USB vs BT) + ducking | B-201 | Transições com rampa suave |
| **B-207** | EP-11 | Now Playing multi-sessão (`mediaremote-adapter` + AppleScript/HTTP fallback) + espectro FFT ao vivo + letras LRCLIB (`Geist Serif`) | E-15 | Espectro só com permissão e opt-in |
| **B-208** | EP-14 | Sparkle 2 (canais stable/beta) + ferramenta de diagnóstico/export de logs sem dados sensíveis | B-110 | — |

---

## Fase 3 · Versão 1.0 e Pós-1.0

**Condição de saída:** áudio neutro preferido ou indistinguível do SoundSource/FineTune em teste cego; documentação pública e site no ar.

| ID | Épico | Item de Backlog | Dependência | Notas |
|---|---|---|---|---|
| **B-301** | EP-12 | Assistente IA de EQ (delta tipado via Foundation Models / Ollama / chave própria) + A/B nivelado + desfazer 1 toque | E-13, ADR-0008 | Limites duros no DSP |
| **B-302** | EP-12 | Questionário inicial (prior) + Treinador de preferência A/B bayesiano (`PairwiseGP` + EUBO em 2–4 dims) | E-14 | Histórico versionado de evolução do gosto |
| **B-303** | EP-13 | Live Activity macOS 27.3+ / compatibilidade nativa MacBook Pro OLED Dynamic Island | E-12 | Coexistência automática |
| **B-304** | EP-15 | Extras audiófilos selecionados: Crossfeed (`bs2b`), Convolução FIR / Room Correction (CamillaDSP / vDSP), Loudness adaptativo (estilo RME) | E-06 | Cada módulo opt-in com custo de latência visível |
| **B-305** | EP-11 | Reconhecimento ShazamKit (áudio do sistema via tap + microfone) + histórico local / ListenBrainz | B-101 | Sem envio automático |
| **B-306** | EP-15 | Perfil auditivo relativo (assimetria L/R e teto de segurança, sem alegação médica) + suporte MIDI/StreamDeck | — | Pós-1.0 se necessário |
| **B-307** | Web | Site, documentação interativa e Playground Design System (`shadcn` + `Bencho` + `Spell` + `DSSSP` usando `tokens.css`) | ADR-0012 | Paridade visual 1:1 |
