# Registro de Progresso

> **Regra ([AGENTS.md](../../AGENTS.md)):** este arquivo registra o estado real do projeto, o que já foi pesquisado, formalizado e auditado, e qual é o próximo passo exato. Nunca marcar como implementado o que está apenas planejado.

---

## Estado Atual

- **Atualizado em:** 2026-11-23. **Fase:** MVP (Fase 1) em uso diário pelo autor; Gate G2 (14 dias como único mixer e EQ) ainda não contado. Todo o trabalho está no `main` (PR #1 mesclado em 2026-11-22, commit `5c33e74`).
- **Funciona e foi verificado:**
  - volume e mudo por app (autoteste E2E com ganho exato);
  - fontes simultâneas com atribuição correta e serviços do macOS nomeados;
  - EQ `Float64` com limiter true-peak;
  - notch nos cinco estados, com volume geral, menu de contexto e teclas de volume e brilho;
  - Estúdio; ícone de barra de menus condicional; identidade acromática.
  
  Estado por item em [roadmap · Situação](../06-plano/roadmap-e-backlog.md).
- **CI:** `./scripts/ci_check.sh` verde localmente (Swift 6.3) e no GitHub (`macos-15`, Swift 6.1). E2E de áudio: `./scripts/selftest_audio.sh`.
- **Desenvolvimento:** builds locais assinados com identidade estável (`./scripts/setup_dev_signing.sh`), para a permissão de Acessibilidade sobreviver aos builds.
- **Pendências honestas:**
  - RF-0201 (rotear app para outra saída), a maior lacuna do mixer;
  - Sparkle e notarização, que exigem conta Apple Developer;
  - now playing, letras, reconhecimento e cenas;
  - bancada E-08/E-09/E-10 com Momentum 4 e AirPods;
  - consumo em repouso e latência por tap (não medidos);
  - MacBook Pro OLED com Dynamic Island (desconhecido);
  - helper XPC (E-16).
- **Próximo passo sugerido:** RF-0201, depois a sessão de bancada com os fones.

---

## Histórico Consolidado

### 2026-11-23 · Verificação no hardware: volume 0 sem vazamento

- **Relato:** com o notch e o menu do Mac mostrando volume 0, ainda dava para ouvir a música baixinho.
- **Causa (Comprovado):** nos alto-falantes internos, `scalar = 0` equivale a −63,5 dB, não a silêncio, e o macOS não liga o mudo sozinho nesse ponto.
- **Correção:** PRs #7 e #9, mesclados por outra sessão. O app liga o mudo antes de zerar o volume, se corrige sozinho quando encontra "0 % sem mudo" e zera o ganho digital dos taps.
- **Verificado nesta sessão:**
  - Estado forçado `scalar 0 / mute 0`: sem o timbr., fica assim; com o timbr., vira `mute 1` imediatamente.
  - CI local verde e CI do GitHub verde no `main` (`13911bf`).
  - Volume do dono restaurado a 53 % após o teste.

### 2026-11-23 · Dois ou mais apps tocando: compacto e espiada no notch

- **Dúvida de produto:** quando dois apps (ex.: Spotify + Google Chrome) tocam ao mesmo tempo, qual logo aparece no compacto em cima do notch e o que a espiada (hover sem clique) deve priorizar — um dos apps ou o volume geral?
- **Decisão e implementação (`NotchPeekTarget`, `compactPair`, `NotchOverlay`):**
  - **Compacto (topo):** com 2+ apps tocando, mostra **os dois logos** juntos com recorte preto de 1,5 pt para leitura limpa (app mais recente à frente, segundo atrás/ao lado) em todos os arranjos medidos da barra de menus (queixo, duas orelhas, só esquerda e só direita ≥ 26 pt).
  - **Espiada (hover sem clique):**
    - `0` apps tocando → **Saída / Geral** (mesmo se houver apps pausados recentes).
    - `1` app tocando → **esse app** diretamente nas asas + fader (ou saída se VoIP protegido).
    - `2+` apps tocando → **Geral (master)** no topo com nome do dispositivo, fader de hardware e mudo, seguido de hairline e de **todos os apps tocando** (até 4) em igualdade logo abaixo — sem escolher arbitrariamente um "vencedor" no hover.
  - **Revisão visual:** flag `--review-multi` adicionada ao app para inspecionar `compact`, `peek` e `expanded` com 2 fontes simultâneas sem mexer nos taps reais.
- **Verificado:** testes unitários em `TimbreCoreTests`, `./scripts/ci_check.sh`, capturas reais da build `--notch compact|peek|expanded --review-multi` e CI Swift 6.1 no PR.

### 2026-11-23 · Revisão E2E da documentação

- **Pedido:** garantir que todas as docs estejam atualizadas de ponta a ponta e o GitHub em dia.
- **Feito:**
  - **Raiz:** README (estado atual com evidências, estrutura de código, Swift 6.1 × 6.3, flags e scripts), CONTRIBUTING (preparação da máquina, fluxo de branch e PR, autoteste) e AGENTS/CLAUDE (regra de GPL e seção de verificação).
  - **Produto:** especificação funcional (§3 do notch reescrita com o comportamento real; fontes, permissões e atalhos) e PRD (RF-0606, RF-1303).
  - **ADRs:** 0004 (lições: `isExclusive`, topologia real, `IsRunningInput`), 0007 (assinatura local), 0013 (barra de menus condicional), 0014 (fonte substituída pela 0015).
  - **Engenharia:** arquitetura, roteamento, motor DSP, observatório, segurança, RNF e IA ganharam a seção "Estado implementado", separando o que existe do alvo.
  - **Plano:** situação item a item no roadmap; "o que roda hoje" nos testes; nota nos critérios.
  - **Registros:** hipóteses H-18…H-20, descobertas 19…30, riscos R-19…R-22, nota de atualização na auditoria de 21/11.
  - **Design system:** painel da barra de menus em `NSStatusItem`, componentes novos do notch, ponto da marca em tinta, flags `--demo` e `--review-empty`.
  - **Open source e mercado:** fontes do sistema no app, Geist só na web.
  - **Viabilidade:** linha das teclas de brilho.
- **Verificado:** todos os links relativos das docs resolvem (script de checagem); CI.
- **Notas de pesquisa (`00-pesquisa/`):** mantidas como registro histórico; as decisões posteriores estão nos ADRs.

### 2026-11-23 · Volume geral (master) no notch

- **Relato:** não faz sentido controlar o volume de cada app sem controlar o geral. Com a saída muda, mexer no notch não mudava nada, e o notch não trazia o som de volta.
- **Feito:**
  - `activeOutputMuted` publicado e atualizado por refresh, teclas de mídia e ações.
  - Faixa "Geral" no expandido (fader do hardware e mudo).
  - Mudo também no controle de saída dos estados vazios.
  - Na espiada, "Saída sem som" ou "Saída em 0%" com "Ativar som": tira o mudo e, se estiver em 0%, leva a 25%.
  - Reativação automática do master ao aumentar o volume de um app, tirar um app do mudo ou subir o fader geral.
- **Verificado:** saída mutada com `osascript`, capturas da espiada (aviso e botão) e do expandido (faixa Geral mutada); CI.

### 2026-11-23 · Ícone da barra de menus só quando necessário

- **Pedido:** não faz sentido ter o timbr. na barra de menus se ele já está no notch.
- **Feito:**
  - O ícone fica oculto por padrão enquanto o notch é a entrada. Ele aparece sozinho sem tela com notch, com o notch desligado ou no modo "só barra de menus". Há a opção "Ícone na barra de menus" em Ajustes.
  - Clique direito no notch (fechado ou aberto): Abrir Estúdio, Ajustes…, Mostrar ícone na barra de menus, Sair do timbr.
  - Reabrir o app (Finder, Spotlight, Dock) abre o Estúdio. ⌘, abre os Ajustes do Estúdio.
- **Defeitos encontrados e corrigidos no caminho (Comprovado):**
  - `MenuBarExtra(isInserted:)` controlado pelo estado do app deixava o SwiftUI reconstruindo o menu principal em laço: 100% de CPU, e o app de teste nunca fechava (o CI travou). Trocado por `NSStatusItem` + `NSPopover` no AppKit (`MenuBarIconController`).
  - O macOS tinha guardado `NSStatusItem VisibleCC Item-0 = 0` para o item antigo, e o novo nascia invisível. Agora o item tem `autosaveName` próprio e visibilidade explícita.
- **Verificado:**
  - `--smoke-check` fecha em 2 s.
  - Com a opção ligada, o item nasce visível ao lado do notch (x = 855).
  - Desligada, não há item.
  - CI passando.

### 2026-11-22 · Compatibilidade: superwhisper e Chrome

- Detalhes e evidências em [compatibilidade-apps-2026-11-22.md](compatibilidade-apps-2026-11-22.md).
- **Feito:**
  - `SilentOutputApps`: superwhisper e outros apps de ditado não contam mais como "tocando".
  - O tap global só existe com áudio ativo (10 s de folga), o que reduz o "Meeting detected" falso do superwhisper e o ponto roxo em repouso.
- **Medido:**
  - Taps ⇒ `IsRunningInput = 1` no processo do timbr., sem usar o microfone. O superwhisper vê isso como reunião sempre que há um navegador aberto; reproduzido duas vezes.
  - Chrome + Spotify simultâneos aparecem corretamente na espiada.

### 2026-11-22 · Teclas de volume e brilho no notch

- **Relato:** o controle de volume e brilho não funcionava mais no notch; aparecia a animação padrão do Mac.
- **Causa (Comprovado):** a permissão de Acessibilidade no TCC estava presa ao `cdhash` do build de 21/11 (`31c867…`). Cada build ad-hoc tem outro `cdhash` (o atual era `28d541…`). `AXIsProcessTrusted()` passou a devolver falso, o interceptador de teclas nunca ligava, e nada avisava.
- **Brilho:** nunca tinha sido implementado; o interceptador só tratava volume.
- **Feito:**
  - `scripts/setup_dev_signing.sh` cria a identidade "timbr Local Signing" num keychain próprio, com senha aleatória fora do repositório. O `build_app.sh` assina com ela, e o requisito designado passa a ser `identifier "com.timbr.app" and certificate leaf = H"e426…"`, estável entre builds.
  - Brilho da tela embutida via DisplayServices, com IOKit de reserva. Se não der para ler o brilho, a tecla continua com o macOS.
  - HUD do notch com ícone de sol; ⌥⇧ dá um quarto de passo; o key-up também é consumido.
  - O interceptador liga sozinho quando a permissão é concedida com o app aberto. Se a permissão sumir, o app registra o evento e pede de novo.
- **Verificado:** requisito estável conferido com `codesign -d -r-`; leitura e escrita de brilho testadas (0,5625 → 0,5625); evento "permission no longer applies" registrado e prompt exibido; CI passando.
- **Pendente do dono:** reativar o timbr. em Ajustes › Privacidade e Segurança › Acessibilidade, uma vez. A permissão antiga foi removida com `tccutil reset`.

### 2026-11-22 · Fontes do macOS com nome e ícone

- **Relato:** apareceu "systemsoundser…" com a letra "S" como ícone.
- **Causa:** processos do macOS sem app (alertas, chime do carregador, Siri, chamadas, leitura em voz alta) caíam no último recurso da atribuição: o nome do executável.
- **Feito:**
  - Catálogo `SystemAudioClient` (TimbreCore) com seis grupos: Sons do sistema, Siri e Ditado, Chamadas (protegidas como VoIP), Leitura em voz alta, Visualização Rápida e Outros sons do macOS. Cada grupo tem nome em PT/ES/EN e o ícone de um app real (Ajustes, Siri, FaceTime…).
  - Clicar num desses grupos abre o painel de Ajustes correspondente.
  - O monitor passou a ouvir também `IsRunning`. Medido no macOS 26: para um processo novo, o HAL notifica `IsRunning`, mas não `IsRunningOutput`. Ele também registra o início de cada saída, para sons curtos (um alerta de 0,3 s) não se perderem entre varreduras.
  - No Mixer, "Em pausa" deu lugar a "Tocou há N minutos" para fontes que não estão tocando agora.
- **Verificado:**
  - Alerta real via `AudioServicesPlayAlertSound` aparece como "Sons do sistema" com o ícone de Ajustes.
  - Atribuição testada: Chrome → Google Chrome, Spotify, Superwhisper, `systemsoundserverd` → Sons do sistema.
  - Testes do catálogo no CI.

### 2026-11-22 · Espiada sem nada tocando e asa da saída

- **Relato:** a espiada vazia mostrava "Nenhuma…" cortado e uma dica sem utilidade. O botão com o nome do alto-falante ficava debaixo do notch.
- **Feito:**
  - Com nada tocando, a espiada vira a saída: ícone e "Saída" nas asas, o volume do hardware à direita, e abaixo o nome completo e o fader. O fader não abre o HUD por cima.
  - O expandido mostra só o ícone do dispositivo na asa direita (o nome vira dica e rótulo de acessibilidade). A legenda passou a "Tocando em <dispositivo>", e o estado vazio ganhou o fader da saída.
  - Regra das asas documentada.
  - Flag de revisão `--review-empty`.
  - `activeOutputVolume` publicado, atualizado por refresh, teclas de mídia e fader.
- **Verificado:** capturas da espiada vazia, do expandido vazio e do expandido com Spotify; CI.

### 2026-11-22 · Revisão E2E do caminho de áudio (volume por app)

- **Relato:** a regulagem não funcionava direito, acima de 100% nada mudava, e a saída criada pelo app tinha bug.
- **Causa raiz (Comprovado):** `isExclusive = true` forçado em todo tap transformava o tap por app em "todos os outros apps". Reproduzido e medido; detalhes em [teste-e2e-volume-por-app-2026-11-22.md](teste-e2e-volume-por-app-2026-11-22.md).
- **Feito:**
  - Flag corrigida.
  - Agregados próprios fora da lista de dispositivos.
  - Buffer triplo wait-free de parâmetros, com publicação só quando a EQ muda.
  - Callback de áudio que respeita o layout dos canais.
  - Falhas registradas no Observatório.
  - `updateDSP` só no slot global; espelho exclui apps no mudo.
  - Estado "No limite" no Mixer.
  - Autoteste `--selftest-audio` e `scripts/selftest_audio.sh`.
- **Verificado:** autoteste 6/6 no app instalado (−6,02 / −12,04 / +6,02 / +3,52 dB exatos, mudo em silêncio, limitador em −0,30 dBFS). Teste de corrida do DSP no CI; CI inteiro passando.

### 2026-11-22 · Identidade acromática (ADR-0016)

- **Pedido do dono:** tirar a obrigação com o roxo; o Órbita continua como referência, sem o violeta dele.
- **Feito:**
  - Os tokens `accent.*` (claro, escuro, notch) passaram a apontar para a tinta da superfície, e a primitiva `brandViolet` foi removida.
  - O ponto do ícone do app ficou branco.
  - A curva de resultado do EQ passou a 2 pt para manter a hierarquia sem cor.
  - O botão `.accent` usa `ink.inverse`, para não ficar branco sobre branco no escuro.
  - Bíblia v2.3 (L3 e checklist), docs 01, 03, 04 e 05 reescritos.
  - A ADR-0016 substitui a linha de cor da ADR-0014.
  - O CI ganhou uma trava: nenhuma matiz fora de `semantic.*` nos tokens e nenhuma cor nomeada no app.
- **Verificado:**
  - Capturas do Mixer, do Equalizador, do painel da barra de menus e do ícone, todos acromáticos.
  - A trava do CI foi testada com tokens violeta e reprovou como esperado.
  - CI inteiro passando.

### 2026-11-22 · Clique no notch

- **Relato:** clicar no notch não fazia nada. A espiada abria no hover e o clique caía numa área sem ação.
- **Feito:**
  - Na espiada, clicar fora dos controles abre o expandido.
  - No expandido, clicar no nome do app (na asa ou nas linhas de fonte) traz o app para a frente, ou o abre se ele foi fechado, e recolhe o notch.
  - Os nomes clicáveis ganham um realce no hover.
  - O painel passou a aceitar o primeiro clique.
  - Textos novos em PT, ES e EN.
- **Verificado:** build e CI. **Não verificado:** o clique real com a mão, porque o app estava em uso e não movi o mouse.

### 2026-11-22 · Detecção de fontes simultâneas

- **Relato:** com dois apps tocando, o notch mostrava só um.
- **Causas encontradas:**
  1. O estado "tocando" de uma fonte era somado ao da varredura anterior e nunca voltava a falso.
  2. A atribuição adivinhava pelo texto do bundle ID: o áudio WebKit do Raycast aparecia como "Safari", e helpers de outros apps não eram reconhecidos.
  3. A espiada e o compacto mostravam só o app em foco.
  4. A lista só atualizava a cada 2 s.
  5. Com dois apps tocando, a ordem podia trocar a cada varredura.
- **Feito:**
  - `AudioProcessAttribution` resolve o dono do processo nesta ordem: processo responsável, depois o pacote `.app` do executável, depois a cadeia de pais, e por fim o ID reportado. Apps de barra de menus contam como donos.
  - O estado "tocando" é recalculado do zero em toda varredura.
  - `AudioProcessMonitor` ouve as mudanças da lista de processos e de `IsRunningOutput`, com coalescência de 120 ms; o timer de 2 s ficou só como reserva.
  - `playingSince` mais `displayOrder` dão uma ordem estável: o app que começou a tocar por último lidera.
  - Na espiada, cada app que está tocando tem o próprio fader. No compacto, o ícone do segundo app aparece atrás do primeiro.
- **Verificado (Comprovado):**
  - Dois tons simultâneos (QuickTime e `afplay`) aparecem na espiada e no expandido, cada um com fader.
  - Atribuição testada: Raycast → Raycast, Safari → Safari, QuickTime → QuickTime, `afplay` → app responsável pelo terminal.
  - Teste de ordem no CI; CI inteiro passando.
- **Limite conhecido:** o Chrome toca todas as abas e PWAs por um único processo de áudio. Separar por aba depende da extensão (porta IPC 48192).

### 2026-11-22 · Notch v2.2 — modelo dos apps de referência (abre para os lados e para baixo)

- **Pesquisa:** leitura do código-fonte de DynamicNotchKit (MIT), NotchDrop (MIT), boring.notch e Atoll (GPL, só parâmetros, nenhum código copiado). Os três têm o mesmo modelo:
  - a forma é colada na borda e cresce em largura e altura a partir do notch;
  - os ombros côncavos vão de 6 a 15–19 pt;
  - a mola de abrir tem bounce entre 0,2 e 0,3, e a de fechar é suave;
  - o conteúdo entra com blur, escala ancorada no topo e opacidade;
  - há um "pop" ou estado de hover antes de abrir, e a sombra preta aparece só aberto.
- **Feito:**
  - Espiada, expandido e HUD voltaram a abrir para os lados e para baixo, com o conteúdo nas asas ao lado da câmera. O pescoço da v2.1 foi removido.
  - O ícone do app viaja só na horizontal, da orelha para a asa.
  - O hover faz o pop na hora e abre após 150 ms de permanência, com toque háptico.
  - Na faixa da barra de menus, o fechamento por ponteiro solta a barra em 30 pt.
  - O compacto continua usando só o espaço medido como livre.
  - Tokens: `notchOpen` 0,42 s/0,2, `notchClose` 0,34 s, `notchPop` novo, ombros 7/14 pt, raio do expandido 24 pt.
- **Verificado (Comprovado):**
  - Capturas de espiada, expandido e compacto sobre o Safari.
  - Vídeo `--demo` inspecionado quadro a quadro: pop, abertura, fechamento seguindo o ponteiro, expansão, fechamento e HUD.
  - CI inteiro passando.
- **Não verificado:** uso real com a mão (o `--demo` simula o ponteiro), em especial a sensação dos 150 ms de permanência e do háptico.

### 2026-11-21 · Notch v2.1 — fluidez, espaço da barra de menus e fechamento que segue o ponteiro

1. **Causas:** ícone duplicado (cópias por estado cruzando opacidade), atraso de 60 ms na entrada do conteúdo, redimensionamento da janela, notch alargando na altura da barra de menus, fechamento só após 300 ms parado.
2. **Forma pescoço + corpo** (`NotchShape` com 6 medidas animáveis): na altura da barra, nunca mais larga que o notch (+ orelhas medidas); espiada, expandido e HUD descem abaixo da barra.
3. **Orelhas medidas** (`MenuBarSpace`: CGWindowList para status items, Acessibilidade para menus do app) e queixo quando não há espaço.
4. **Ícone único viajante**, canvas fixo, molas 0,38/0,30 s, hover 70 ms.
5. **Fechamento contínuo** guiado pela distância do ponteiro, reversível, com commit sem salto.
6. **Verificação:** capturas com Finder e Chrome em primeiro plano; vídeo `--demo` inspecionado quadro a quadro (abrir, fechar seguindo o ponteiro, expandir). CI verde.

### 2026-11-21 · UI/UX v2.0 — redesign completo, notch preto de hardware e auditoria E2E

1. **Diagnóstico com causa no código** (notch com contorno 11% e topo arredondado, controles padrão do macOS, Geist nunca empacotada, métricas sem sinal mostrando zero, polling de 50 ms): ver [auditoria-e2e-2026-11-21.md](auditoria-e2e-2026-11-21.md).
2. **Notch reescrito** (`NotchOverlay.swift`): `NotchShape` com topo reto e ombros côncavos, preto `sRGB 0,0,0` sem contorno/sombra, morph em canvas estável, hover por `NSTrackingArea`, compacto/HUD/espiada/expandido redesenhados.
3. **Componentes próprios** (`DSComponents.swift`) e **Estúdio** reescrito (`StudioWindow.swift`, `EQCurveCanvas.swift`), **barra de menus** desenhada (`MenuBarPanel.swift`), Introdução limpa.
4. **Tokens v2** (paleta acromática quente + acento único de sinal; SF Pro/Mono/New York com tracking aplicado — ADR-0015).
5. **~170 textos novos** PT/ES/EN (`LocalizationUI.swift`), paridade 308 chaves.
6. **Preset por dispositivo** aplicado ao trocar de saída (RF-0404/0607).
7. **CI:** nova etapa 3b reprova controles padrão e contorno no notch. `./scripts/ci_check.sh` → **ALL PASSED**.
8. **Bíblia do design system v2.0** reescrita (`docs/05-design-system/`).
9. **Em aberto (sem maquiagem):** roteamento por app (P0), Sparkle (P0), now playing, cenas, bancada física M4/AirPods.

### 2026-11-21 · Encerramento da Fase 0 de Planejamento, Pesquisa & Auditoria E2E (`timbr.`)

1. **Pesquisa Técnica & Benchmarking (Fase 1 e Fase 2):**
   - SDK macOS 15–27, Audio Process Taps, Core Audio HAL, DSP `Float64`, dispositivos de entrada/saída, Now Playing/MediaRemote, personalização/IA e panorama competitivo (`docs/00-pesquisa/relatorio-fase-1-notch-audiofilo.md` e `notas-fase-1/01..06`).
   - Protocolo Sennheiser Momentum 4 (GAIA v3 RFCOMM, UUID `A2129FF3-081B-4C45-8AFE-469D9C4842EC`, gate de firmware `3.18.0`, `AudioMode=1`, USB-C UAC 1.0, 3,5 mm `470 Ω`/`60 Ω`, denylist de segurança `0x0607`/`0x0040`/`0x1405`/`0x02xx`, obsolescência de `bluetoothaudiod` do gist `dvf` no Sonoma+ e travamento L2CAP `0x1001` dos AirPods Pro) em [`07_momentum4_protocolo_e_ecossistema.md`](../00-pesquisa/notas-fase-2/07_momentum4_protocolo_e_ecossistema.md).
   - Engenharia de áudio em tempo real, Audio Workgroups, Clang RTSan, filtros Vicanek 2016/2024, dBTP (`ITU-R BS.1770-5` / Lund `0 dBFS+`), `libebur128`, `WHO-ITU H.870`, SRC, TPDF, Null Test, Farina ESS (`AES17`) e validação ABX em [`10_engenharia_de_audio_qualidade_e_testes.md`](../00-pesquisa/notas-fase-2/10_engenharia_de_audio_qualidade_e_testes.md).
   - Auditoria de código-fonte de **62+ repositórios OSS** (captura/HAL, DSP/presets, UI/notch/mídia e ecossistema Momentum 4), com inventário BOM de licenças e bloqueio estrito de contaminação GPL em [`11_auditoria_repositorios_oss.md`](../00-pesquisa/notas-fase-2/11_auditoria_repositorios_oss.md) e [`inventario-e-classificacao.md`](../09-open-source/inventario-e-classificacao.md). Diretórios temporários de clone (`oss-audit-tmp/`, `m4-audit-tmp/`) removidos após auditoria.

2. **Produto, Mercado, Viabilidade & Arquitetura E2E:**
   - Visão, 12 princípios testáveis (`P1`–`P12`) e glossário controlado (`docs/01-visao/`).
   - PRD (`EP-01`–`EP-15`), especificação funcional e matriz competitiva + ideias fora da caixa avaliadas (`docs/02-produto/PRD.md`, `especificacao-funcional.md`, [`mercado-e-diferenciacao.md`](../02-produto/mercado-e-diferenciacao.md)).
   - Matriz de viabilidade, matriz de dispositivos e laboratório seguro do Momentum 4 + AirPods Pro (`docs/03-viabilidade/matriz-de-viabilidade.md`, `matriz-de-dispositivos.md`, [`momentum4-laboratorio.md`](../03-viabilidade/momentum4-laboratorio.md)).
   - Arquitetura completa (`docs/04-engenharia/`): processos, motor DSP `Float64`, roteamento/abas, Observatório & Guardião, inteligência/personalização (`PairwiseGP`), segurança/privacidade/distribuição e **Requisitos Não Funcionais + Matriz 100% Local vs Rede/Nuvem** ([`requisitos-nao-funcionais.md`](../04-engenharia/requisitos-nao-funcionais.md)).

3. **Design System & Identidade Oficial (`timbr.`):**
   - Bíblia do Design System completa (`docs/05-design-system/00..05`), tokens fonte única (`design-system/tokens/*.tokens.json`) e gerador `generate_tokens.py` validado.
   - **[ADR-0014](../07-decisoes/ADR-0014-nome-identidade-e-i18n.md) (Aceito):** definição do nome oficial **`timbr.`** (*Sound, precisely yours.* / *Som, precisamente seu.* / *Sonido, precisamente tuyo.*), alinhamento filosófico/tipográfico avaliado contra **`v1torres.dev`** (`v1dev app`), glifo geométrico `.icns` (`curva + .`) e suporte **trilíngue obrigatório (`PT / ES / EN`)** via `Localizable.xcstrings` desde a v1.

4. **Plano de Experimentos, Testes & Revisão Adversarial Obrigatória:**
   - Plano de 17 experimentos (`E-01`–`E-17`), roadmap em 4 fases com gates (`G0`–`G3`), pirâmide de testes metrológicos (`estrategia-de-testes.md`) e critérios de aceitação (`criterios-de-aceitacao.md`).
   - **[Revisão Adversarial](revisao-adversarial.md):** crítica de 5 especialistas independentes resultando em **8 reformulações aplicadas (`C-01`–`C-08`)** diretamente nos documentos normativos (in-process `Engine` no MVP, preferência C++20/`vDSP`, exclusão VoIP/DAW segura por padrão, teto BT AAC `-1,0 dBTP`, A/B cego com latência equalizada, toggle manual `470 Ω / 60 Ω` no M4 P2, Modo Estúdio Silencioso e orçamento `≤ 40 pt` no notch 14" + variantes curtas `PT/ES/EN`).

---

## Próximo Passo Imediato (fora de CI headless)

1. Instalar localmente com `./scripts/install_local.sh --reset-onboarding` e percorrer o onboarding (RF-1401) + conceder TCC na hora do uso.
2. Conectar Momentum 4 + AirPods Pro e fechar **E-08 / E-09 / E-10** (HFP, GAIA RFCOMM live, coexistência de taps).
3. Iniciar dogfood diário de 14 dias (**Gate G2**).
4. Com certificado Developer ID: `DEVELOPER_ID=… NOTARY_PROFILE=… ./scripts/build_dmg.sh` → publicar release + atualizar `sha256` do cask Homebrew; depois Sparkle 2 (**B-208** / Gate G3).

---

### 2026-11-21 · Fase 2 — Implementação E2E, `CLEAN_SWEEP` e Verificação Automatizada (`vinicius/e2e-implementation`)

1. **Governança Open Source & Portfolio (`ADR-0001` Aceito):**
   - Adicionados [`LICENSE`](../../LICENSE) (**MPL-2.0**) e [`CONTRIBUTING.md`](../../CONTRIBUTING.md) (DCO + isolamento GPL/AGPL); [`ADR-0001`](../07-decisoes/ADR-0001-licenca.md) e [`README.md`](../07-decisoes/README.md) promovidos para **Aceito**.
2. **Experimentos de Fase 0 executados no hardware local:**
   - `E-06`, `E-07`, `E-12` e `E-01` executados com binários reais compilados e resultados documentados em `experiments/*/RESULTADO.md`; `H-06` e `ADR-0003` promovidos para **Comprovado / Aceito**.
3. **Implementação completa dos 4 módulos + extensões + playground + bundle `.app`:**
   - `CTimbreDSP` (C++20 + `Accelerate/vDSP` Float64 RT-safe), `TimbreDesignSystem` (tokens gerados fonte única + playground HTML/CSS/JS), `TimbreCore` (Swift 6: modelos, EqualizerAPO, i18n `PT/ES/EN`, Guardião `G-01`–`G-07`, SQLite, AutoEq, IA com bounds, `PairwiseGP`, IPC loopback Bearer+Origin, diagnósticos sanitizados), `TimbreEngine` (HAL + snapshot P3, Process Tap P1, GAIA v3 read-only + denylist, AirPods HAL, detector de notch concorrente, `MediaKeyTap`), `TimbreApp` (`timbr.` SwiftUI+AppKit com 5 estados de notch + Pílula, MenuBarExtra, Estúdio completo + aba Apoiar/Doações, atalhos globais `⌥⌘V/B/A/O/M/,`) e extensões MV3 (`chrome-mv3` / `safari-web-ext`).
4. **Testes & `CLEAN_SWEEP`:**
   - `./scripts/ci_check.sh` passou integralmente após os ajustes finais da auditoria: geração de tokens, validação JSON das extensões, guarda zero-GPL, build `dist/Timbr.app` assinado ad-hoc (`codesign --verify`), `CTimbreDSPTests` sob ASan+UBSan, `TimbreCoreTests`, `TimbreEngineTests` e `--smoke-check` no binário `Timbr.app`.
5. **Auditoria Competitiva Ampliada & Upgrades MIT (`Notchy`, `OmniMac`, `ILoveNotch`, `R9-EQ`, `m4-companion`, `AudioRouter`):**
   - Incorporados [`NOTICE`](../../NOTICE), [`OrphanedTapCleanup`](../../Sources/TimbreEngine/ProcessTapEngine.swift) (MIT `AudioRouter`) e framing/codecs GAIA v3 SPP `[0xFF, 0x03]` + cliente RFCOMM *read-only* em [`Momentum4Driver.swift`](../../Sources/TimbreEngine/Momentum4Driver.swift) (MIT `m4-companion`), mantendo a denylist de segurança bloqueada e alimentando o Guardião `G-04` (Duplo EQ).
   - Novos testes unitários de `GaiaSPPDeframer`, decodificadores Momentum 4, `G-04` e `OrphanedTapCleanup` validados em `./scripts/ci_check.sh`, além de atualização completa da matriz de mercado e inventário OSS (`docs/02-produto/mercado-e-diferenciacao.md`, `11_auditoria_repositorios_oss.md`, `inventario-e-classificacao.md`).
   - **Pendências honestas de hardware/ambiente:** testes físicos com Momentum 4 / AirPods Pro conectados (E-08/E-09/E-10 completos), TCC interativo de janela em uso contínuo e dogfood de 14 dias / 50 testadores (Gates G2/G3) permanecem abertos fora deste ambiente headless.

### 2026-11-21 · Sweetspot headless — multi-tap, P3 crash recovery, fail-safe, packaging

1. **Motor & roteamento:**
   - `ProcessTapEngine.reconcileMultiTap` com `kAudioHardwarePropertyTranslatePIDToProcessObject`, slots multi-tap, `MirrorOutputTarget` (atraso 0–250 ms) e invariante P1 (`0` taps ativos com bypass/desligado).
   - DSP C++: linha de atraso RT pré-alocada (`delay_ms`) para alinhamento multi-saída.
   - `HALManager`: snapshot persistido + `recoverLeftoverSnapshotIfPresent()` pós-crash; watchdog de devices/default output.
   - App: auto-duck em chamada VoIP, espelho multi-saída no Estúdio, IPC/extensões MV3 com volume por aba.
2. **CI & higiene P3:**
   - `scripts/verify_failsafe.sh` — 20× `SIGKILL` sem aggregates `dev.v1torres.timbr.agg.*` vazados e default output idêntico.
   - `ci_check.sh` — RTSan opcional (Homebrew LLVM) + fail-safe como etapa 9.
   - `build_dmg.sh` — assinatura Developer ID + `notarytool`/`stapler` quando `DEVELOPER_ID`/`NOTARY_PROFILE` estão definidos.
   - `Packaging/Homebrew/timbr.rb` (B-110 scaffold).
3. **Verificação local (2026-11-21):** `./scripts/ci_check.sh` **ALL PASSED**; `hdiutil verify dist/Timbr.dmg` **VALID**; SHA-256 `83f4b4e1749f82704a80a85c871e9b9d86031a5945cd3f9956693e9a614e47fd`.
4. **O que o plano total ainda exige (não esquecido, só impossível headless):** hardware M4/AirPods (E-08/09/10), TCC real, G2 dogfood, G3 beta+notarização, Sparkle 2 (B-208). A parte pesada de engenharia/código/CI deste ambiente está fechada.

### 2026-11-21 · First-run onboarding (RF-1401) + install local

1. **Onboarding em 4 passos** (`OnboardingWindow`): marca → promessa de privacidade/P3 → permissões explicadas *antes* de abrir Ajustes (nada auto-prompt) → pronto com atalhos e CTA Estúdio / barra de menus.
2. **Persistência:** `onboardingCompleted` no SQLite; idioma inicial via locale do sistema; `--smoke-check` pula a intro; Ajustes → “Repetir introdução”.
3. **`scripts/install_local.sh`:** instala em `/Applications`, limpa quarentena Gatekeeper e opcionalmente reseta onboarding para ensaio de 1ª abertura.
4. **CI:** `./scripts/ci_check.sh` verde (114 chaves PT/ES/EN).


### 2026-11-21 · Linha Apple (AirPods → Max) — paridade documental com Momentum 4

1. **Código:** [`AirPodsFamilyDriver.swift`](../../Sources/TimbreEngine/AirPodsFamilyDriver.swift) — classificador família, parser Continuity flip-aware (in-ear/lid), matriz `AppleModelCapabilityProfile`, scan CoreBluetooth passivo, telemetria HAL honesta (sem ANC inventado).
2. **UI:** [`AppleAccessoryViews.swift`](../../Sources/TimbreApp/AppleAccessoryViews.swift) — card Observatório + strip Mixer + Notch (compact glyph / expanded strip); AACP fechado; chips systemManaged.
3. **AutoEq starter:** AirPods 4 + 4 ANC (Rtings 5128), Pro 1/2, AirPods 3, Max; Pro 3 aguarda índice público.
4. **Docs:** [`airpods-laboratorio.md`](../03-viabilidade/airpods-laboratorio.md), Nota [`12_airpods_linha_apple.md`](../00-pesquisa/notas-fase-2/12_airpods_linha_apple.md), ADR-0011, matriz, PRD RF-0808/0809, NOTICE §3.
5. **Testes:** Pro 2 / AirPods 4 / 4 ANC / Pro 3 + flip + capabilities no `TimbreEngineTests`.
6. **Ainda físico:** Continuity live com case aberto + E-08 HFP com AirPods conectados.

### 2026-11-21 · CLEAN_SWEEP pré-merge (correções adversarial)

1. **GAIA:** denylist completa Nota 07 (`0x0605–0x06FF`, `0x1403/05/06`, DFU) + allowlist read-only no `Gaia3Packet.encode`.
2. **IA:** `adjust_band`/`setTilt` contam no cap de 3 bandas; teto absoluto de taste = ±6 dB.
3. **Continuity:** sem fallback cross-family; scan duty-cycled; start só com saída Apple; Mixer strip só no destino ativo.
4. **AutoEq:** match específico AirPods 4/Pro/Max; allowlist de `relativePath`; aviso Spatial no painel.
5. **IPC:** clamp BOPLA de volume/título; CI `permissions: contents: read`; rollback de taps `mutedWhenTapped` em falha parcial (mirrors best-effort).
7. **Passe D:** `requestScanBurst` rearmável; match Continuity same-family por tokens HAL; writes GAIA `0x1001`/`0x1003`/… na denylist; docs duty-cycle alinhadas.

### 2026-11-23 · Marca harmônica sutil no notch e ocultação em tela cheia

1. **Marca `timbr.` no Compacto (`TimbreHarmonicMath` + `MiniMeter`):** substitui as 3 barras genéricas pela silhueta simétrica de 5 barras do ícone do app (`Timbr.icns`), com respiração harmônica contida (~2,6 s, 12 Hz, variação ≤ 1,1 pt, opacidade 0,70–0,86) para indicar atividade sem distrair em vídeos janelados; respeita `Reduzir movimento` e pausa em repouso/tela cheia.
2. **Ocultação em tela cheia (`FullscreenEvaluator` + `FullscreenProbe`):** detecta vídeo/app em tela cheia na tela do notch (YouTube HTML5 em Chrome/Safari, Spaces nativos, Split View e `AXFullScreen` sem falso positivo em janela maximizada ou monitor externo), suprime o indicador compacto e o sensor de hover imediatamente (preservando o botão `×` de saída e zero distração) e mantém HUD de teclas e `⌥⌘V` funcionais. Preferência **Ocultar em tela cheia** ligada por padrão em Ajustes → Notch (PT-BR/ES/EN).
3. **Proteção de menus à direita + fallback seguro no queixo (`MenuBarSpaceEvaluator`):** `MenuBarSpace.freeEars` agora mede itens de menu do app em primeiro plano que transbordam à direita do notch (ex.: `Janela`/`Ajuda` no Chrome) além dos status items e dos menus à esquerda, e `shouldUseChin` move automaticamente o modo Compacto com 2+ apps para o queixo quando não há espaço limpo nas duas orelhas (evitando sobreposição com menus e corte na borda física do notch).
4. **Consistência bilateral no Compacto:** o app em reprodução fica **sempre à esquerda** e a marca 5-bar **sempre à direita**; quando apenas um dos lados tem espaço (ex.: menus largos à esquerda ou status items até o notch à direita), o Compacto desce direto para o queixo em vez de jogar o ícone para a orelha direita, e a sonda lê `CGWindowListCopyWindowInfo([.optionAll])` em `layer == 25` para detectar ícones da Central de Controle/terceiros no macOS 26.
5. **Mute real de hardware em 0% e liderança neutra no Expandido (`OutputVolumeBehavior` + `NotchExpandedTarget`):**
   - **Zero-bleed em `0%`:** o CoreAudio dos alto-falantes do MacBook deixa `-63,5 dB` residuais quando `kAudioDevicePropertyVolumeScalar = 0.0` e `kAudioDevicePropertyMute == 0`. O novo `OutputVolumeBehavior` espelha o comportamento nativo do macOS: qualquer escrita `< 0,5%` (que exibe `0`) ou tecla de diminuir volume até `0%` engata o mute de hardware (`kAudioDevicePropertyMute = 1`), e desmutar a partir de `0%` no botão da UI restaura para `25%` antes de abrir o mute (sem jamais passar por `(0.0, mute: 0)`). Refletido também no slider de saídas do Estúdio (`OutputRow`).
   - **Espiada e Expandido unificados:** ambos os estados seguem a mesma regra de cardinalidade (`0 / 1 / 2+` apps tocando). Com `2+` apps tocando ao mesmo tempo (ex.: Spotify + Chrome) ou só apps pausados, o **Geral** neutro assume o destaque no topo do Expandido e todos os apps aparecem em igualdade nas linhas abaixo, com recolhimento suave do ícone viajante.

### 2026-11-23 · Refinamento de Audio UI e Metrologia com `audiocn/ui` (MIT)

1. **Auditoria de licença e conformidade (`NOTICE` + `11_auditoria_repositorios_oss.md`):** verificada a licença **MIT** de `github.com/audiocn/ui` (`audiocn.dev`), compatível com MPL-2.0 e zero-GPL, mantendo 100% a identidade acromática do **ADR-0016**.
2. **Núcleo matemático de UI de áudio (`Sources/TimbreCore/AudioUIMath.swift`):**
   - `AudioDecibelMath` & `AudioMeterZone`: conversão ganho ↔ dB, normalização com *audio taper* (`expoente 1,65`) para faders e medidores, e classificação em zonas (`safe`, `warning` ≥ `-6 dB`, `clip` ≥ `-1 dB`).
   - `AudioMeterBallistics`: balística determinística com ataque rápido, queda contínua, retenção de pico (*peak hold* de `1,2 s`) e *latch* de clip por borda de subida com contador de eventos e reset explícito (`resetClip()`).
   - `LCDSegmentLayout`: quantização de bloco inteiro (32 segmentos — nenhum bloco LCD acende parcialmente) e cálculo do índice de *peak hold*.
   - `KnobArcGeometry`: varredura de 270° (`-135°…+135°`), origem bipolar em 12h (`0 dB`) e iluminação seletiva de ticks periféricos.
   - Cobertura completa de testes unitários em `Tests/TimbreCoreTests/main.swift`.
3. **Primitivas SwiftUI (`Sources/TimbreApp/DSComponents.swift`) e integração nas superfícies:**
   - `TKnob`, `TChannelButton` (`M`/`S`/`BYP`), `TClipIndicator`, `TdBReadout`, `TdBScale`, `TLevelMeter`, `TLCDDisplay`, `TLCDMeterRow` e `TFader` aprimorado (`liveMeterNorm`, `scaleMarks`).
   - **Estúdio — Mixer:** faixas de fontes, abas e saídas com medidor ao vivo translúcido dentro do `TFader`, marcas de escala e botão de console `M` (`TChannelButton`).
   - **Estúdio — Equalizador:** barra de metrologia com `TLevelMeter` (True Peak + LUFS Momentary + Peak Hold) e `TClipIndicator` clicável; cartões `Seu gosto` com dials rotativos bipolares `TKnob` em par com `TFader` bipolar (`-6…+6 dB`).
   - **Estúdio — Observatório:** monitor `TLCDDisplay` (`TRUE PEAK & LUFS RECORDER MONITOR`) com par estéreo `L`/`R` de 32 segmentos (`TLCDMeterRow`), `TdBScale` e `TClipIndicator`, além de `SpectrumView` com eixo dB, grade de frequência e envelope tracejado de Peak Hold. Corrigida também a inicialização atômica de `metric_tp_l`/`metric_tp_r` em `timbre_dsp.cpp` para `-120.0 dBTP` em repouso.
   - **MenuBarPanel & Playground Web:** `MenuBarPanel` (estilo *Quick Audio Popover*) com `MiniMeter` no cabeçalho, `TFader` com `scaleMarks` e `TChannelButton` (`M`); `design-system/playground/` atualizado para demonstrar `LCD Display + Stereo LCD Meter`, `Bipolar Rotary Knobs`, `Channel Strip` e `Clip Latch` em paleta acromática ADR-0016.

### 2026-11-23 · Continuidade entre Áreas de Trabalho (Spaces / swipe 3 dedos) e Tela Cheia inteligente

1. **Espaço de overlay persistente (`NotchSpaceOverlay` em `NotchOverlay.swift`):** carrega dinamicamente `SkyLight.framework` (`SLSSpaceCreate` / `SLSSpaceSetAbsoluteLevel(..., 1)` / `SLSShowSpaces` / `SLSSpaceAddWindowsAndRemoveFromSpaces`) com fallback automático para AppKit público. Retira `panel` (`level = mainMenu + 3 = 27`) e `sensor` (`level = mainMenu + 4 = 28`) dos Spaces gerenciados para que o gesto horizontal de 3 dedos, Mission Control e novos Spaces nunca escondam ou arrastem o notch; reanexa automaticamente após qualquer `orderOut`/`orderFrontRegardless`.
2. **Política de ativação do app (`TimbrApp.swift`):** `AppDelegate` agora implementa `NSWindowDelegate` (`windowWillClose`) para restaurar `NSApp.setActivationPolicy(.accessory)` assim que Estúdio e Onboarding forem fechados, evitando que o app fique preso em `.regular` após a primeira abertura.
3. **Ocultação em tela cheia inteligente (`FullscreenEvaluator` + `FullscreenProbe` + `LocalizationUI.swift`):** diferencia trabalho/navegação em Space nativo abaixo da moldura física (Chrome/Safari `Cmd+Ctrl+F`, Cursor, Split View — mantêm o notch ativo na faixa preta) de vídeo HTML5 em tela cheia (Chrome sem toolbar, Safari `WKFullScreenWindow` ou Safari com áudio ativo), players dedicados (`QuickTime`, `IINA`, `VLC`, `TV`, `Keynote`, etc.) e tela cheia sem borda/top-edge (`minY <= 2`).
