# Critérios de Aceitação por Fase e por Épico

> **Regra:** um item só é considerado aceito quando passa em critérios funcionais **e** não funcionais mensuráveis, com evidência registrada em `docs/08-registro/progresso.md` ou `RESULTADO.md` de experimento.

---

## 1. Critérios de Passagem entre Fases (Gates)

### Gate G0/G1 · Saída da Fase 0 (Laboratório → MVP)
1. Todos os experimentos obrigatórios (`E-01` a `E-12`, `E-16`) têm `RESULTADO.md` com dados reais, logs e decisão explícita (`Passou`, `Passou com ressalva`, `Falhou`).
2. `ADR-0001` (Licença), `ADR-0003` (Núcleo DSP), `ADR-0005` (Piso macOS) e `ADR-0006` (Processo do motor) promovidos de **Proposto** para **Aceito**.
3. Matriz real de dispositivos (`matriz-de-dispositivos.md`) preenchida pela sonda `E-07` em todos os hardwares de teste do dono (alto-falante interno, Momentum 4, AirPods Pro, DAC USB se disponível).
4. Zero código GPL/AGPL copiado na árvore do projeto.

### Gate G2 · Saída da Fase 1 (MVP → Beta Público)
1. **Dogfood real de 14 dias consecutivos:** o dono usa o Timbre diariamente como único mixer e EQ sem precisar executar `kill` ou desativá-lo por falha de áudio.
2. **Fail-safe validado:** em 20 testes seguidos de `kill -9` no processo de áudio durante reprodução, o som retorna aos apps originais em `≤ 1 s`, sem pico acima do nível pré-falha.
3. **Null test e transparência (P1):** com tudo em neutro, `0` taps criados; com tap em `1.0` e EQ flat, diferença digital documentada conforme `estrategia-de-testes.md`.
4. **Higiene de saída (P3):** após sair e após rodar rotina de desinstalação, `DeviceUID` padrão, volumes HW e lista de `AggregateDevice` públicos são 100% idênticos ao snapshot pré-arranque.
5. **Localização completa v1 (`PT`, `ES`, `EN`):** `100%` das strings do app em `.xcstrings` traduzidas nos três idiomas sem chaves faltantes e sem truncamento no notch.
6. **100% de aderência ao checklist do Design System** (`docs/05-design-system/00-biblia-do-design-system.md`).

### Gate G3 · Saída da Fase 2 (Beta Público → 1.0)
1. Mínimo de **50 testadores externos** em combinações distintas de macOS (15 / 26 / 27), chips Apple Silicon e hardware de áudio (BT, USB DAC, HDMI, interno).
2. **Zero relato** de corrupção de áudio ou queda de som não reproduzível e sem mitigação documentada.
3. Taxa de sessões sem crash (`crash-free`) `≥ 99,5%` no motor de áudio e `≥ 99,0%` na UI durante janela mínima de 14 dias.
4. Assinatura Developer ID + notarização + atualização Sparkle 2 verificadas em máquina limpa (sem Xcode instalado).

---

## 2. Critérios de Aceitação por Épico (Épicos Críticos)

| Épico | Critério objetivo de aceite |
|---|---|
| **EP-01 Mixer por app** | Ajuste de volume de `0%` a `100%` (e boost explícito) sem cliques audíveis (rampa linear/S-curve ≥ 10 ms); agrupamento correto de processos auxiliares (`WebKit.GPU`, helpers); zero vazamento ao alternar mute. |
| **EP-02 Multissaída** | Reprodução simultânea em 2 saídas (ex.: DAC USB + alto-falante, ou BT + alto-falante) sem drift correction habilitado em Bluetooth; slider de alinhamento em `ms` altera o atraso mensurável por impulso. |
| **EP-03 Motor EQ & Proteção** | Processamento `Float64`; erro de resposta em magnitude dentro da tolerância do `estrategia-de-testes.md` até 20 kHz; preamp recalculado automaticamente pela soma `Correção + Gosto`; com limiter ativo e entrada sintética `+6 dBFS`, zero amostra `> 0 dBTP` na saída; bypass verdadeiro remove o processamento sem estalo. |
| **EP-04 / EP-05 Presets & AutoEq** | Round-trip de EqualizerAPO ParametricEQ preserva tipo de filtro, frequência, Q e ganho com precisão `≤ 0,01`; AutoEq baixado sob demanda exibe crédito completo (autor + equipamento de medição) e respeita cache offline. |
| **EP-06 Dispositivos** | Nenhum controle não gravável (`IsPropertySettable == false`) aparece habilitado na UI; teclas de mídia controlam o destino ativo apenas com Acessibilidade concedida; troca de saída ocorre sem congelar o notch. |
| **EP-07 Observatório & Guardião** | Todo número exibe selo `MEDIDO`, `REPORTADO` ou `INFERIDO`; selo `BIT-PERFECT` nunca acende com tap ou volume SW ativo; G-01 dispara em `100%` dos eventos de queda A2DP→HFP em `E-08`. |
| **EP-08 Bluetooth & Momentum 4** | Sem envio de comandos de escrita fora de `E-09` aprovado; leitura exibe valores reais com timestamp ou `Indisponível`; falha do driver nunca trava ou atrasa o callback RT de áudio. |
| **EP-09 Abas de navegador** | Apenas abas com áudio ativo listadas; atenuação/mute respondem em `< 150 ms`; se extensão não instalada, UI explica claramente a limitação do macOS sem fingir suporte nativo. |
| **EP-12 Inteligência** | 100% dos deltas gerados por LLM passam por validador tipado (faixa de frequência, Q, ganho por banda e delta global); desfazer em 1 clique restaura estado exato; A/B cego equaliza loudness antes de comparar. |
| **EP-13 Notch & Superfícies** | Hover com histerese evita abertura acidental; pass-through fora da forma; `⌥⌘V` abre/fecha com `0 ms` de transição; zero botão de configuração dentro do notch; Pílula e MenuBar funcionam sem notch físico. |
| **EP-14 Segurança & Privacidade** | Nenhuma permissão pedida no primeiro start sem ação contextual; zero chamada de rede externa em operação normal offline; relatório de diagnóstico revisável antes de salvar e sem buffers de áudio. |

---

## 3. Estado Real de Evidência em `2026-11-21`

- **Verificado localmente via [`scripts/ci_check.sh`](../../scripts/ci_check.sh):**
  - `E-06` (DSP Float64 + Vicanek + Null Test + Limiter `-0.3`/`-1.0 dBTP` + BS.1770 LUFS + Crossfeed + 24-bit TPDF + A/B igual-latência) sob ASan+UBSan;
  - `E-07` (sonda HAL local), `E-12` (geometria de notch `179 pt`), `E-01` (criação/destruição de Process Tap);
  - `TimbreCoreTests` (EqualizerAPO round-trip/cap, IPC Bearer+Origin 401/403/200, bounds IA, `PairwiseGP`, 73 chaves `PT/ES/EN`, regras `G-01`–`G-07` + Silent Studio, SQLite, AutoEq offline, diagnósticos sem buffers);
  - `TimbreEngineTests` (GAIA v3 + denylist `0x0607`/`0x02xx` + FW `3.18.0`, HAL snapshot/restore, P1 `0 taps` em bypass/neutro) e `--smoke-check` em `dist/Timbr.app`.
- **Pendente de ambiente físico / interação humana (não simulável em CI headless):**
  - Conexão física de Sennheiser Momentum 4 e AirPods Pro (`E-08`, `E-09`, `E-10`, `E-11`);
  - Grants interativos de TCC (Audio Capture, Accessibility) na UI em uso real com `kill -9` (20×), dogfood de 14 dias (`Gate G2`) e beta com ≥ 50 testadores + notarização Developer ID (`Gate G3`);
  - Verificação Clang RTSan (`-fsanitize=realtime`, ausente no Apple Clang 21 CLT).
