# Análise de Riscos e Mitigações

> Classificação de impacto: **Crítico** (quebra áudio ou inviabiliza produto), **Alto** (degrada fidelidade ou UX central), **Médio** (limita recurso secundário).

## 1. Riscos de Plataforma e Core Audio

| ID | Risco | Prob. | Impacto | Mitigação planejada | Experimento / ADR |
|---|---|---|---|---|---|
| **R-01** | Bugs de process tap no macOS 26/27 (buffers `0.0f`, travamento de `AudioDeviceStart` entre taps) | Alta | Crítico | Watchdog de silêncio com backoff (máx. 1 rebuild / 30 s); matriz de coexistência com lista de "ignore" padrão; failsafe via `mutedWhenTapped` | E-03, E-10, ADR-0004 |
| **R-02** | Estouro de 200–500 ms sem EQ no início da reprodução | Alta | Alto | Testar captura precoce (gain 1.0) vs `bundleIDs` + `isProcessRestoreEnabled` vs tap global de sistema | E-02 |
| **R-03** | Atenuação de `−12,04 dB` em interfaces multicanal de 8+ saídas | Média | Alto | Sonda de layout de canais no HAL + mapeamento explícito/fallback estéreo validado em RME/MOTU/Focusrite | E-01, E-07 |
| **R-04** | Degradação ou bloqueio de overlay no notch pela Dynamic Island do MacBook Pro OLED | Alta | Alto | Arquitetura multi-superfície (Notch + Pílula + MenuBar + Estúdio + Live Activity macOS 27.3+) | E-12, ADR-0013 |
| **R-05** | Fechamento da brecha `/usr/bin/perl` do `mediaremote-adapter` em update do macOS | Média | Médio | Comando `test` em runtime; fallback imediato para AppleScript (Music/Spotify) e HTTP (Pear Desktop) | E-15 |
| **R-06** | Falha na recuperação após `sleep/wake` ou `kAudioHardwarePropertyServiceRestarted` | Alta | Crítico | Listener explícito de `ServiceRestarted`, reconstrução limpa de listeners/aggregates, snapshot de sistema restaurado na saída | E-03, P3 |

## 2. Riscos de Qualidade Sonora e DSP

| ID | Risco | Prob. | Impacto | Mitigação planejada | Experimento / ADR |
|---|---|---|---|---|---|
| **R-07** | Clipping por headroom insuficiente ou inter-sample peaks (`+5 dBTP+`) | Alta | Crítico | Preamp calculado pelo **máximo da resposta somada** (Correção + Gosto + margem) + limiter true-peak com lookahead e indicador visível | E-06, ADR-0010 |
| **R-08** | Ruído/erro numérico em biquads `Float32` em graves extremos | Média | Alto | Processamento e coeficientes sempre em `Float64` (`vDSP_biquadD` / C++ / CamillaDSP v5) | E-06, ADR-0003 |
| **R-09** | Cramping de filtros RBJ acima de 10 kHz a 44,1/48 kHz | Alta | Médio | Modo de filtro casado (Vicanek/Orfanidis) ou sobreamostragem 2×; plotar sempre a resposta digital real | E-06 |
| **R-10** | Dupla equalização silenciosa (EQ no firmware do fone + EQ no Timbre) | Alta | Alto | Regra G-04 do Guardião (via driver read-first) + alerta claro e ação para zerar o EQ interno | E-09, ADR-0011 |
| **R-11** | Queda silenciosa do Bluetooth de A2DP para HFP/SCO durante reuniões | Alta | Alto | Política "Output Only" (entrada padrão = mic interno) + alerta G-01 ao detectar stream de entrada BT | E-08 |

## 3. Riscos de Produto, UX e Escopo

| ID | Risco | Prob. | Impacto | Mitigação planejada |
|---|---|---|---|---|
| **R-12** | **Scope creep antes de dominar os 2 pilares:** tentar lançar abas, AI, Shazam, letras e driver M4 tudo no MVP | Alta | Crítico | Regra P8 + Gates estritos: MVP só fecha após 14 dias de uso diário perfeito do **Mixer por fonte + EQ** |
| **R-13** | Notch sobrecarregado roubando foco ou atrapalhando menus do macOS | Média | Alto | `NSPanel` não-ativante, histerese de hover, pass-through fora da forma, zero configuração dentro do notch (ADR-0013) |
| **R-14** | Controle por aba frustrar usuário por exigir extensão e gesto manual (MV3 `tabCapture`) | Alta | Médio | Deixar claro o que é limitação do navegador vs OS; entregar atenuação simples primeiro e tratar boost/roteamento por aba como spike (E-05) |

## 4. Riscos Jurídicos, Licenciamento e Segurança

| ID | Risco | Prob. | Impacto | Mitigação planejada |
|---|---|---|---|---|
| **R-15** | Contaminação de licença por cópia acidental de código GPL/AGPL (FineTune, boring.notch, Atoll, BlackHole) | Média | Crítico | Proibição explícita no `AGENTS.md`: GPL/AGPL só para estudo; decisão prévia de ADR-0001 antes do 1º commit de código |
| **R-16** | Reclamação de direitos autorais sobre medições de fone (oratory1990) ou letras (LRCLIB / endpoints privados) | Média | Alto | Baixar índice AutoEq em runtime com cache + crédito; nunca redistribuir letras nem empacotar endpoints privados sem opt-in explícito |
| **R-17** | Risco de escrita destrutiva em dispositivos Bluetooth (brick/despareamento) | Baixa | Crítico | Read-first; lista negra explícita em ADR-0011 (sem DFU, factory reset ou pairing) |
| **R-18** | Rejeição na Mac App Store por `CGEventTap`, Perl helper ou Automation | Certa (full) | Médio | Distribuição oficial via Developer ID + Notarização + Sparkle 2 + Homebrew (ADR-0007); versão "lite" avaliada apenas em E-17 |
