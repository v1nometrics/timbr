# Matriz de viabilidade técnica

> Status: v1.0 · 2026-11-21 · Fonte primária: `docs/00-pesquisa/` (notas 01–11 e relatório da fase 1). Classes de evidência conforme `AGENTS.md`.
>
> **Como ler.** "Veredito" diz o que a plataforma permite. "Evidência" diz o quanto sabemos. "Prova pública" mostra quem já demonstrou, e em que grau: **demo** (protótipo/projeto pequeno), **funcional** (projeto usado, com bugs abertos) ou **produção** (produto comercial ou projeto maduro). Uma demo não prova que dá para fazer com confiabilidade de produção. A coluna "Experimento" aponta para a prova que nós mesmos vamos fazer (`06-plano/plano-de-experimentos.md`).

Legenda de veredito: ✅ Possível · 🟡 Parcial (com restrições relevantes) · ❌ Inviável · ❔ Desconhecido

## A. Captura, volume e roteamento

| Funcionalidade | Veredito | API | Permissões / requisitos | macOS mín. | Dispositivos | Compromissos | Prova pública (grau) | Evidência | Exp. |
|---|---|---|---|---|---|---|---|---|---|
| Volume e mute por app (processo) | ✅ | Pública: `AudioHardwareCreateProcessTap` + `CATapDescription` (`.mutedWhenTapped`) + aggregate privado + IOProc | "System Audio Recording Only" (TCC); `NSAudioCaptureUsageDescription`; app assinado com identidade estável | 14.2 (14.4 recomendado); 26 para `bundleIDs` e `isProcessRestoreEnabled` | Qualquer saída; Bluetooth com ressalvas | +~10–13 ms por app; mixdown estéreo Float32; ponto roxo permanente; bugs do 26/27 (buffers zerados, estouro inicial de 200–500 ms, −12 dB em interfaces multicanal, taps que se bloqueiam) | SoundSource 6 (produção, ARK), FineTune (funcional), Atoll (funcional), AudioCap (demo) | Provável | E-01, E-02, E-03 |
| Volume por **processo auxiliar** (renderers do Chrome, WebKit, helpers do Slack) | 🟡 | Pública: lista de processos de áudio + mapeamento para o app "responsável" | Idem | 14.2 | — | Mapeamento helper→app é heurístico; BackgroundMusic precisou de correções por navegador | PerAppVolume, BackgroundMusic 0.5 (funcional) | Provável | E-02 |
| Volume por **janela** | ❌ (genérico) | Áudio no macOS é por processo, não por janela | — | — | — | Só seria possível se o app usasse um processo por janela; não há como generalizar | Nenhuma | Provável | — |
| Volume por **aba** de navegador | 🟡 | Extensões: Safari Web Extension (interceptar `element.volume`); Chromium MV3 `chrome.tabCapture` + offscreen document; Firefox native messaging | Instalar extensão por navegador; `tabCapture` exige gesto do usuário a cada captura | 14.2 (extensão Safari do PerAppVolume exige 26) | — | Interceptar `element.volume` só **atenua** (≤100%) e não alcança Web Audio; `tabCapture` só no Chromium; abas não aparecem para o SO | PerAppVolume (funcional, licença não-OSI), Earmix (produção, comercial) | Provável (atenuação) / Hipótese (boost, EQ, rota) | E-05 |
| Rotear uma **aba** para outra saída | ❔ | Hipótese: `setSinkId` no offscreen document do Chromium | Idem | — | — | Sem precedente | Nenhuma | Desconhecido | E-05 |
| Rotear app A → fone, app B → caixas | ✅ | Pública: um aggregate por dispositivo físico, cada um com os taps dos apps roteados | Idem | 14.2 | Qualquer | Bluetooth deve ficar em aggregate próprio | FineTune, SoundSource 6 (produção) | Provável | E-04 |
| Mesma fonte em várias saídas | ✅ | Pública: um tap da mesma fonte em cada motor | Idem | 14.2 | Qualquer | Desalinhamento de latência entre BT (~150–300 ms) e com fio; drift | SoundSource Output Groups (produção), FineTune (funcional) | Provável | E-04 |
| Alinhar latência entre saídas (compensação) | 🟡 | Atrasar as saídas rápidas para alinhar à mais lenta | — | — | — | Latência de BT reportada pelo HAL nem sempre é real; exige medição ou ajuste manual | Nenhuma conhecida | Hipótese | E-04 |
| Mixar vários apps numa saída | ✅ | Soma dentro do aggregate/IOProc | — | 14.2 | — | Soma pode exceder 0 dBFS → limiter de saída | Todos os mixers | Comprovado (doc) | E-01 |
| Grupos de apps e políticas de prioridade | ✅ | Software nosso sobre o mixer | — | — | — | Nenhum técnico | — | Provável | — |
| Ducking (baixar música quando uma chamada fala) | ✅ (provável) | Detectar atividade da fonte "gatilho" por `kAudioProcessPropertyIsRunningOutput` ou por medidor do tap; aplicar ganho rampado nas fontes "alvo" | Idem | 14.2 | — | Apps de chamada não toleram tap (eco); a detecção deve ser **sem tap** no app de chamada | Nenhuma conhecida em app de taps | Hipótese | E-04 |
| Sidechain por nível (compressão disparada por outra fonte) | 🟡 | Requer tapear a fonte gatilho | Idem | 14.2 | — | Mesma restrição de apps de chamada; latência de um buffer | Nenhuma | Hipótese | backlog |
| Medidores de pico por app | ✅ | Tap **sem mute** (cópia) só para medir, ou medir dentro do tap do mixer | Idem | 14.2 | — | Tap só para medir também acende o ponto roxo | AudioCap (demo) | Provável | E-02 |
| Recuperar ao desconectar/trocar dispositivo, sleep/wake, reinício do `coreaudiod` | ✅ (engenharia) | Listeners de propriedades do HAL; `kAudioHardwarePropertyServiceRestarted`; reconstrução completa de taps e aggregates | — | 14.2 | — | Restart do `coreaudiod` apaga todos os listeners; IDs de dispositivo mudam (usar UID) | SoundSource (produção), per-app-audio watchdog (demo) | Provável | E-03, E-07 |
| Perfis automáticos (reunião, jogo, música, chamada) | ✅ | Regras sobre apps ativos, dispositivo conectado, horário, Focus | Automation opcional | 14.2 | — | Nenhum técnico relevante | SoundSource (parcial), eqMac (pedido) | Provável | backlog |

## B. DSP e fidelidade

| Funcionalidade | Veredito | Mecanismo | Compromissos | Prova pública | Evidência | Exp. |
|---|---|---|---|---|---|---|
| EQ paramétrico de sistema, 64 bits | ✅ | Nosso DSP dentro do IOProc (biquads DF2T em double, coeficientes double, `vDSP_biquadD`/`vDSP_biquadm` ou núcleo C++/Rust) | Não é bit-perfect enquanto ativo; latência de um buffer do tap | eqMac, SoundSource (produção, mas EQ menos rigoroso); CamillaDSP (produção, fora do contexto de taps) | Provável | E-06 |
| Filtros casados / sobreamostragem anti-cramping | ✅ | Vicanek/Orfanidis (peaking, LP/HP/BP); oversampling 2× para shelves | CPU; shelves sem fórmula casada | LSP (produção), FabFilter (produção) | Comprovado (literatura) | E-06 |
| FIR / convolução (fase linear, IR de correção) | ✅ | Convolução particionada | Latência (70–116 ms para fase linear típica); CPU; IR precisa casar a taxa | CamillaDSP, EqualizerAPO (produção) | Provável | backlog |
| Correção de fone por AutoEq | ✅ | Dados do AutoEq (MIT no código) buscados em runtime; otimização PEQ local contra alvo escolhido | Licença das **medições** de terceiros incerta; dados do master parados desde jul/2025 | FineTune (funcional), SoundSource (produção, curva gráfica) | Provável | E-06 |
| Bit-perfect com EQ ativo | ❌ | Por definição | — | — | Comprovado | — |
| Caminho intocado quando nada é processado | ✅ | Não criar tap quando o app está em volume 1.0 sem EQ (Atoll faz isso) | Ligar/desligar o tap gera transição; precisa de rampa | Atoll PR #805 (funcional) | Provável | E-01 |
| Tap com ganho unitário é bit-transparente | ❔ | Null test contra saída direta | Se não for, o "A/B neutro" precisa destruir o tap | Ninguém mediu | Desconhecido | E-01 |
| Troca automática de taxa do dispositivo para a da fonte | 🟡 | `kAudioDevicePropertyNominalSampleRate` é público; **descobrir** a taxa da fonte é o problema: logs do Music (admin, sem sandbox), metadados por player | Troca durante a música causa clique; nem todo player informa | LosslessSwitcher (funcional, GPL) | Provável | backlog |
| Limiter true-peak de saída | ✅ | Lookahead + sobreamostragem 4× para detecção | Latência de lookahead (~1–5 ms) | CamillaDSP v5 (sem oversampling documentado) | Provável | E-06 |
| Hospedar Audio Units de terceiros no sistema | ✅ | AUv3 fora do processo (padrão) | Latência variável por plug-in; estabilidade de terceiros | SoundSource, Hosting AU (produção) | Provável | backlog |
| Crossfeed, loudness, dither | ✅ | bs2b (MIT), shelves estilo RME/CamillaDSP, TPDF/noise shaping | Baixo | CamillaDSP, EasyEffects (produção) | Comprovado | backlog |
| Evitar EQ duplicado (firmware do fone + app) | 🟡 | Depende de o driver do fabricante ler o EQ interno | Só para fones com protocolo conhecido | Ver `momentum4-laboratorio.md` | Hipótese | E-09 |

## C. Dispositivos

| Funcionalidade | Veredito | API | Permissões | Compromissos | Prova | Evidência | Exp. |
|---|---|---|---|---|---|---|---|
| Dispositivo padrão de entrada/saída/alertas | ✅ | HAL `AudioObject*` | Nenhuma | — | SwitchAudioSource, SoundSource | Comprovado (SDK) | — |
| Volume, mute, por canal, dB | ✅ (se o driver expõe) | HAL | Nenhuma | Cada driver decide o que é gravável → sondar `IsPropertySettable` em runtime | spfk-audio-hardware | Comprovado (SDK) | E-07 |
| Taxa de amostragem, formato físico (bit depth), fonte de dados, clock | ✅ (se o driver expõe) | HAL | Nenhuma | Mudança pode ser revertida pelo sistema | LosslessSwitcher | Comprovado (SDK) | E-07 |
| Volume em software para DAC sem volume de hardware | ✅ | Nosso pipeline (tap global) ou proxy HAL | System Audio Recording | Perde bit-perfect; precisa sinalizar | SoundSource "Force software volume", Proxy Audio Device | Provável | E-07 |
| Teclas de volume/mídia controlando o Timbre + HUD próprio no notch | ✅ | `CGEventTap` ativo | Acessibilidade | Inviabiliza Mac App Store; HUD nativo instável no Tahoe | boring.notch, MonitorControl (funcional) | Provável | backlog |
| Teclas de brilho com HUD próprio no notch | ✅ | `CGEventTap` + `DisplayServices` (privado, em runtime) com IOKit de reserva | Acessibilidade | API privada pode mudar; tecla volta ao macOS se o brilho não puder ser lido | timbr. (Comprovado em MacBook Air, 2026-11-22) | Comprovado | — |
| Uso do microfone por app (quem está ouvindo) | ✅ | `kAudioProcessPropertyIsRunningInput` | Nenhuma | Versão mínima não confirmada (14?) | — | Provável | E-07 |
| Modo do microfone (Isolamento de Voz) | 🟡 | Leitura possível; mudança só abrindo o seletor do sistema | — | — | — | Provável | — |
| Codec Bluetooth em uso (AAC/SBC) | ❔ | Sem API pública; `system_profiler`/logs a verificar | — | Pode exigir parsing frágil | — | Desconhecido | E-08 |
| Detectar queda para HFP (mono, banda estreita) | ✅ (provável) | Mudança de formato/taxa do dispositivo BT; surgimento do stream de entrada | Nenhuma | — | — | Hipótese | E-08 |
| Evitar HFP (manter A2DP) quando um app abre o mic | 🟡 | Definir a entrada padrão como mic interno; avisar quando um app escolhe o mic do fone explicitamente | Nenhuma | Apps que forçam o mic do fone ainda derrubam para HFP | SoundSource "Output Only" Bluetooth (produção) | Provável | E-08 |
| Bateria de fones | 🟡 | Chaves não documentadas do sistema; ou protocolo do fabricante | — | Privado, frágil | AirBattery (AGPL) | Provável | E-09 |
| Modos de escuta dos AirPods (ANC/transparência) | ❌ público / 🟡 privado | Sem API pública | — | APIs privadas quebram a cada versão; NoiseBuddy quebrado | LibrePods (só Linux/Android) | Provável | — |
| Controle do Sennheiser Momentum 4 | ver `momentum4-laboratorio.md` | — | — | — | — | — | E-09 |

## D. Mídia, letras, reconhecimento

| Funcionalidade | Veredito | Mecanismo | Compromissos | Prova | Evidência |
|---|---|---|---|---|---|
| Now playing da sessão eleita | 🟡 | `ungive/mediaremote-adapter` (BSD-3) rodando via `/usr/bin/perl` | Contorno de API privada; pode fechar em qualquer versão | boring.notch, Atoll (produção comunitária) | Provável |
| Ler várias sessões ao mesmo tempo | 🟡 | `get --bundle-id` (PR #42, nov/2026) por polling | Só testado no 27 / Apple Silicon | — | Provável |
| Controlar sessão não eleita | ❌ (genérico) / ✅ por player | AppleScript para Music e Spotify; HTTP para alguns | Exige Automation por app | boring.notch | Provável |
| Metadados audiófilos da fonte (codec, taxa, bits) | 🟡 | Music.app `sample rate`/`bit rate`; MusicKit `audioVariants`; TIDAL `mediaTags`; logs do Music | Spotify e MediaRemote não expõem formato | LosslessSwitcher | Provável |
| Visualizador real (espectro, VU) | ✅ | Tap sem mute + FFT `vDSP` + Metal | Precisa da permissão de captura; custo de energia | — | Provável |
| Letras sincronizadas | ✅ | LRCLIB (sem chave; limite por IP; User-Agent obrigatório) | Direito autoral do texto não licenciado pela LRCLIB | Lyric Fever, LyricsX | Provável |
| Reconhecimento de música (som do sistema) | ✅ | `SHSession.matchStreamingBuffer` alimentado pelo tap | Serviço ShazamKit precisa estar habilitado no App ID; sem preço/limites publicados | — | Provável |
| Reconhecimento pelo microfone | ✅ | `SHManagedSession` | Permissão de microfone | — | Comprovado (doc) |
| Live Activities no Mac | ❔ | ActivityKit no macOS 27.3 | Sem documentação de desenvolvedor encontrada | — | Desconhecido |

## E. Interface (notch)

| Funcionalidade | Veredito | Mecanismo | Compromissos | Prova | Evidência |
|---|---|---|---|---|---|
| Overlay no notch | ✅ | `NSPanel` sem borda, não ativante, nível acima da barra, `.canJoinAllSpaces`/`.fullScreenAuxiliary` | Geometria do notch varia por modelo (bug do MacBook Air M5 no boring.notch) | boring.notch, NotchDrop, DynamicNotchKit | Provável |
| Macs sem notch e monitores externos | ✅ | Pílula flutuante | — | DynamicNotchKit | Provável |
| MacBook Pro OLED com Dynamic Island nativa | ❔ | Coexistência de overlay de terceiros desconhecida | Pode exigir outra superfície (Live Activity, barra de menus) | — | Desconhecido |
| Sobre apps em tela cheia | ✅ | `.fullScreenAuxiliary` | — | Todos | Provável |

## F. Inteligência

| Funcionalidade | Veredito | Mecanismo | Compromissos | Prova | Evidência |
|---|---|---|---|---|---|
| Texto → delta de EQ, on-device | ✅ (provável) | Foundation Models (macOS 26, ~3B, saída estruturada, 4.096 tokens) ou Ollama/LM Studio; chave própria opcional | Nenhuma validação com audiófilos em teste cego | LLM2Fx (Sony), estudo B&O 2026 (pesquisa) | Provável |
| Aprender preferência por A/B | ✅ (provável) | Otimização bayesiana com GP de preferência em 2–4 dimensões (graves, agudos, presença) | Ruído de julgamento; precisa de 10–20 comparações | Widex (produção em aparelhos auditivos), BoTorch `PairwiseGP` | Provável |
| EQ por gênero musical | 🟡 | Possível tecnicamente | **Evidência científica fraca** de que a preferência muda por gênero | — | Provável (de que vale pouco) |
| Teste auditivo em fone arbitrário | 🟡 | Tons + limiares relativos | Erros > 8–14 dB sem calibração; não é diagnóstico | Apple (só AirPods, validação FDA) | Comprovado (literatura) |

## G. Distribuição

| Caminho | Veredito | Motivo |
|---|---|---|
| Developer ID + notarização + Sparkle + Homebrew | ✅ | Padrão do FineTune e dos utilitários de áudio sérios |
| Mac App Store com o produto completo | ❌ (provável) | Acessibilidade para teclas de mídia, helper `/usr/bin/perl`, Automation, possível plug-in HAL |
| Mac App Store com versão "lite" (só taps + EQ) | ❔ | VolumeHub está na loja com taps; não há precedente de EQ de sistema aprovado |
