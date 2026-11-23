# PRD · `timbr.`

> Status: v1.0 · 2026-11-21 · Dono: Vinicius. Documento vivo: toda mudança de escopo atualiza este arquivo e o `progresso.md`.
> Leitura prévia: `01-visao/visao-e-principios.md`, `03-viabilidade/matriz-de-viabilidade.md`.

## 1. Resumo

O Timbre transforma o notch do MacBook na central de controle de áudio do Mac: volume, mute, rota e EQ **por fonte** (app e, via extensão, aba), **várias saídas** ao mesmo tempo, **EQ paramétrico de 64 bits** com correção de fone e camada de gosto, **controle total de dispositivos**, um **Observatório** que explica o caminho do sinal e um **Guardião** que avisa quando algo degrada o som. A IA ajuda a configurar, nunca processa áudio.

## 2. Objetivos

| # | Objetivo | Medida |
|---|---|---|
| O1 | Ser o melhor mixer por app do Mac em confiabilidade | Zero glitch em soak de 24 h (RNF-REL-01); taxa de crash-free ≥ meta do RNF |
| O2 | Ser o EQ de sistema mais fiel e verificável do Mac | Golden tests dentro da tolerância; null test publicado; A/B cego nivelado disponível em todo lugar |
| O3 | Explicar o som | 100% dos números da UI com selo de origem (medido, reportado, inferido) |
| O4 | Ser calmo | CPU/energia em repouso dentro do RNF; notch invisível em repouso |
| O5 | Funcionar com qualquer dispositivo e brilhar com alguns | Matriz de capacidades sondada; driver do Momentum 4 no beta |

## 3. Não objetivos (desta versão do plano)

Separação de stems; player de música próprio; efeitos "3D/realce" por padrão; suporte a Windows/Linux; room correction com microfone de medição (fica no horizonte futuro); Mac App Store para o produto completo.

## 4. Personas e trabalhos a fazer

| Persona | Trabalho principal | Momento crítico |
|---|---|---|
| **Ana, audiófila de fone** (o dono) | "Quero que o meu Momentum 4 soe como eu gosto, igual em qualquer app, e saber que nada está estragando o sinal" | Conectar o fone → o perfil certo entra sozinho; um app abre o mic → é avisada antes do som piorar |
| **Bruno, controlador do som** | "Reunião no fone, música baixinha nas caixas, notificações mudas" | Entrar numa call → a música abaixa sozinha e volta depois |
| **Carla, criadora** | "Quero ver níveis reais, rotear e não ter surpresas" | Gravar sem áudio duplicado, com medidores confiáveis |

## 5. Fases

| Fase | Nome | Conteúdo | Saída |
|---|---|---|---|
| F0 | Fundação | Repositório, licença, CI, tokens, docs, ferramentas de medição | Repositório pronto para experimentos |
| F1 | Provas de risco | Experimentos E-01 a E-12, E-16 | **Gate G1**: ADRs aceitos |
| F2 | MVP (alpha privado) | P0: mixer, multissaída, EQ + Correção + Gosto, presets, dispositivos essenciais, notch essencial, Observatório mínimo, permissões transparentes | **Gate G2**: dono usa 14 dias sem desligar |
| F3 | Beta público | P1: Guardião completo, cenas e ducking, Momentum 4, abas (se E-05 passar), now playing, texto→EQ, A/B treinador, Estúdio completo | **Gate G3**: 50 testadores, critérios de qualidade |
| F4 | 1.0 estável | P2: aprendizado de preferência, letras, reconhecimento, crossfeed/loudness, AU, CLI/Atalhos, Live Activity | Release estável |
| F5 | Horizonte | P3: convolução/room correction, plug-ins da comunidade, MIDI, outros fabricantes, versão lite na loja | Roadmap contínuo |

Prioridades: **P0** = MVP · **P1** = Beta · **P2** = 1.0 · **P3** = Horizonte.

## 6. Requisitos funcionais

Coluna "Viab." referencia a seção da matriz de viabilidade. Critérios de aceitação detalhados dos P0 e P1 estão em `06-plano/criterios-de-aceitacao.md`.

### EP-01 · Mixer de fontes
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0101 | Listar fontes de áudio ativas (apps que tocam ou tocaram recentemente) com ícone e nome, agrupando processos auxiliares no app responsável | P0 | A |
| RF-0102 | Volume por fonte de 0 a 100% (e boost até +12 dB com aviso de clipping) com rampa sem clique | P0 | A |
| RF-0103 | Mute por fonte | P0 | A |
| RF-0104 | Nenhum processamento (nenhum tap) para fonte em 100%, sem EQ e na saída padrão | P0 | A, B |
| RF-0105 | Lembrar volume/mute/rota por app entre execuções | P0 | A |
| RF-0106 | Lista de "nunca tocar" (apps de chamada, DAWs, Rogue Amoeba) com padrão sensato e editável | P0 | A |
| RF-0107 | Medidor de pico por fonte (opcional, desligado por padrão para economizar energia) | P1 | A |
| RF-0108 | Grupos de fontes (ex.: "Navegadores", "Comunicação") com controle conjunto | P2 | A |
| RF-0109 | Solo de fonte (silencia todas as outras temporariamente) | P1 | A |

### EP-02 · Destinos e multissaída
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0201 | Rotear cada fonte para qualquer saída física | P0 | A |
| RF-0202 | Enviar uma fonte para várias saídas ao mesmo tempo | P1 | A |
| RF-0203 | Volume de saída (destino) independente do volume das fontes | P0 | A, C |
| RF-0204 | Compensação de atraso manual por saída para alinhar Bluetooth e com fio | P2 | A |
| RF-0205 | Quando uma saída some, as fontes roteadas a ela seguem a política escolhida (voltar à padrão / pausar / mutar) | P0 | A |
| RF-0206 | Prioridade de saídas: "use o fone se conectado, senão as caixas" | P1 | A, C |

### EP-03 · Motor de EQ
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0301 | EQ paramétrico por destino com até 20 filtros: peaking, low/high shelf (Q ou slope), low/high pass (Butterworth/Linkwitz-Riley, ordens 1–8), notch, band pass, all-pass | P0 | B |
| RF-0302 | Processamento e coeficientes em 64 bits | P0 | B |
| RF-0303 | Método de desenho selecionável: RBJ, casado (padrão), sobreamostrado 2× | P1 | B |
| RF-0304 | Preamp automático pela resposta somada + margem; modo manual com aviso | P0 | B |
| RF-0305 | Limiter true-peak de proteção no fim da cadeia, com indicador quando atua | P0 | B |
| RF-0306 | Curva de resposta **digital real** (não o protótipo analógico) com grade log 20 Hz–20 kHz | P0 | B |
| RF-0307 | Bypass verdadeiro (remove o processamento) e A/B neutro rotulados distintamente | P0 | B |
| RF-0308 | A/B com volume nivelado (loudness-matched) e modo cego | P0 | B |
| RF-0309 | EQ por fonte (app), além do EQ por destino | P1 | B |
| RF-0310 | Troca de parâmetros sem zipper noise (interpolação de coeficientes) | P0 | B |
| RF-0311 | Fase linear/FIR opcional com latência exibida | P3 | B |
| RF-0312 | Níveis de controle do EQ de gosto: 4, 5 ou 10 bandas fixas (só o ganho) e PEQ livre, com ganhos próprios por nível, nomes em português com o termo audiófilo entre parênteses e **Resetar filtros** com desfazer ([ADR-0019](../07-decisoes/ADR-0019-equalizador-de-4-5-10-bandas-e-peq-livre.md)) | P1 | B |

### EP-04 · Correção de fone
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0401 | Buscar o modelo do fone no índice do AutoEq (em runtime, com cache e crédito da fonte) | P0 | B |
| RF-0402 | Escolher alvo (Harman OE/IE, diffuse field, alvos alternativos) e fonte de medição, mostrando equipamento de medição | P1 | B |
| RF-0403 | Otimizar PEQ localmente contra o alvo escolhido | P1 | B |
| RF-0404 | Vincular Correção ao dispositivo detectado (UID) e aplicar automaticamente ao conectar | P0 | B, C |
| RF-0405 | Importar medição própria (REW, CSV de FR) para gerar Correção | P2 | B |

### EP-05 · Presets
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0501 | Formato nativo `timbre.preset/v1` (ADR-0009) | P0 | B |
| RF-0502 | Importar/exportar EqualizerAPO ParametricEQ | P0 | B |
| RF-0503 | Importar AutoEq GraphicEQ, CamillaDSP YAML | P1 | B |
| RF-0504 | Versionamento automático de presets com histórico, diff legível e reverter | P1 | B |
| RF-0505 | Compartilhar preset por arquivo e por link de texto (sem servidor) | P2 | — |

### EP-06 · Dispositivos
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0601 | Trocar saída e entrada padrão pelo notch | P0 | C |
| RF-0602 | Volume e mute de dispositivo, inclusive mute global de microfone | P0 | C |
| RF-0603 | Taxa de amostragem e formato do dispositivo (quando gravável) | P0 | C |
| RF-0604 | Sonda de capacidades: só mostrar controles suportados | P0 | C |
| RF-0605 | Volume em software para dispositivos sem volume de hardware (DAC, HDMI), com aviso de perda de bit-perfect | P1 | C |
| RF-0606 | Teclas de volume/mute (e de brilho da tela embutida) controlam o destino atual, com HUD no notch | P1 | C |
| RF-0607 | Perfis por dispositivo (UID): volume inicial, EQ, rotas | P0 | C |
| RF-0608 | Mostrar quais apps usam o microfone agora | P1 | C |
| RF-0609 | Troca automática da taxa do dispositivo para a da fonte (quando a taxa da fonte for conhecida) | P2 | B |
| RF-0610 | Balanço L/R por destino | P1 | B |

### EP-07 · Observatório e Guardião
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0701 | Diagrama do caminho do sinal por destino: fontes → estágios → dispositivo → transporte (USB/BT/HDMI/interno) → fone | P0 | A–D |
| RF-0702 | Cada valor com selo de origem: **medido**, **reportado pelo sistema**, **inferido** | P0 | — |
| RF-0703 | Medidores de saída: pico de amostra, true peak, RMS, LUFS M/S | P1 | B |
| RF-0704 | Contador de clipping e de atuação do limiter | P0 | B |
| RF-0705 | Guardião: alertas para queda HFP, reamostragem, clipping recorrente, EQ duplicado (firmware + app), volume em software num caminho que poderia ser bit-perfect, dispositivo trocado inesperadamente | P1 | C |
| RF-0706 | Linha do tempo de eventos (trocas de dispositivo, formato, rotas) exportável. **Implementado:** histórico completo paginado, busca por trecho, filtro por categoria, exportação CSV/JSON ([ADR-0018](../07-decisoes/ADR-0018-linha-do-tempo-busca-e-exportacao.md)) | P1 | — |
| RF-0707 | Estimativa de exposição sonora (dB SPL **estimado**) com dados de sensibilidade do fone e aviso de limites WHO/ITU H.870 | P2 | C |
| RF-0709 | Tempo de escuta com fone e com volume alto (regra prática 60/60), aviso no Observatório e no notch, **sem decibéis e sem tap** ([ADR-0023](../07-decisoes/ADR-0023-tempo-de-escuta-e-volume-alto.md)); o RF-0707 (dB estimado) segue à parte | P1 | C |
| RF-0708 | Selo "bit-perfect" só quando as condições do glossário forem satisfeitas | P1 | B |

### EP-08 · Bluetooth e drivers de fabricante
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0801 | Detectar queda para HFP e explicar | P1 | C |
| RF-0802 | Política anti-HFP: manter entrada padrão no mic interno quando a saída é um fone BT | P1 | C |
| RF-0803 | Driver Momentum 4: leitura de bateria, ANC, transparência, EQ interno, firmware | P1 | ver laboratório |
| RF-0804 | Driver Momentum 4: escrita segura (ANC/transparência, EQ interno neutro) | P2 | ver laboratório |
| RF-0805 | Sincronizar EQ interno do fone com o do Timbre (oferecer zerar o interno) | P2 | ver laboratório |
| RF-0806 | Bateria de fones Bluetooth genéricos (quando exposta) | P2 | C |
| RF-0807 | SDK de drivers documentado para outros fabricantes | P3 | — |
| RF-0808 | Driver linha Apple (AirPods / Pro / Max / Beats): HAL + Continuity BLE L/R/Case + AutoEq; **sem** AACP (ANC/Transparency ficam no macOS) | P1 | ver airpods-laboratorio |
| RF-0809 | Observatório: card Apple com SF Symbol, selos REPORTADO/INFERIDO, aviso Spatial Audio e copy AACP fechado (P11) | P1 | G |

### EP-09 · Abas de navegador
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-0901 | Extensões Safari e Chromium mostram abas com áudio no notch | P1 (se E-05) | A |
| RF-0902 | Volume (atenuação) e mute por aba | P1 (se E-05) | A |
| RF-0903 | Boost/EQ por aba (Chromium) | P2 (se E-05) | A |
| RF-0904 | Rota por aba para outra saída | P3 (se E-05) | A |
| RF-0905 | Firefox | P3 | A |

### EP-10 · Cenas e automações
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-1001 | Cenas: salvar e aplicar o estado completo (volumes, rotas, EQs) | P1 | A |
| RF-1002 | Regras: quando app X toca / dispositivo Y conecta / Focus Z ativa → aplicar cena | P1 | A |
| RF-1003 | Ducking: abaixar fontes-alvo quando a fonte-gatilho emite som, com rampa e tempo de retorno | P1 | A |
| RF-1004 | Ações para Atalhos (App Intents), esquema de URL e CLI | P2 | — |
| RF-1005 | Controle por MIDI (faders físicos) | P3 | — |

### EP-11 · Mídia
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-1101 | Now playing com capa, título, artista, progresso e controles | P1 | D |
| RF-1102 | Metadados de formato da fonte quando disponíveis (codec, taxa, bits) com origem | P1 | D |
| RF-1103 | Várias sessões simultâneas (leitura) | P2 | D |
| RF-1104 | Visualizador real (espectro/VU) a partir do áudio, nunca falso | P2 | D |
| RF-1105 | Letras sincronizadas (LRCLIB) | P2 | D |
| RF-1106 | Reconhecer música do sistema ou do microfone (ShazamKit), com histórico local | P2 | D |
| RF-1107 | Scrobbling opcional (ListenBrainz) | P3 | D |

### EP-12 · Inteligência
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-1201 | Questionário inicial (fones, uso, sensibilidade a agudos/graves, idade opcional) que define priors do Gosto | P1 | F |
| RF-1202 | Texto → delta de EQ (ADR-0008) com justificativa, variantes e A/B | P1 | F |
| RF-1203 | Treinador A/B cego com volume nivelado | P1 | B |
| RF-1204 | Aprendizado de preferência por otimização bayesiana em 2–4 dimensões, por fone e por tipo de conteúdo | P2 | F |
| RF-1205 | Recomendações com justificativa e nível de confiança | P2 | F |
| RF-1206 | Perfil auditivo **relativo** (não diagnóstico) usado como limite do Gosto | P3 | F |

### EP-13 · Notch e superfícies
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-1301 | Estados do notch: repouso, compacto, espiada (hover), expandido; HUD transitório | P0 | E |
| RF-1302 | Pílula para Macs sem notch e monitores externos | P0 | E |
| RF-1303 | Item na barra de menus com o mesmo conteúdo do notch expandido, visível quando o notch não é a entrada (sem notch, notch desligado, modo só barra de menus) ou por opção | P0 | E |
| RF-1304 | Estúdio (janela) | P0 (mínimo) / P1 (completo) | E |
| RF-1305 | Operação completa por teclado e VoiceOver | P0 | E |
| RF-1306 | Live Activity (macOS 27.3+) | P2 | D |
| RF-1308 | O notch recolhe sem esperar o macOS: debounce curto, vigia leve e silêncio medido quando há tap; chave opcional "Perceber pausas na hora" ([ADR-0021](../07-decisoes/ADR-0021-notch-percebe-a-pausa-sem-esperar-o-macos.md)); sons curtos do sistema não acordam o notch ([ADR-0020](../07-decisoes/ADR-0020-sons-do-sistema-nao-acordam-o-notch.md)) | P1 | E |
| RF-1307 | Aparência do notch personalizável (preto contínuo, preto com fio editorial ou modo silencioso na pílula/menu) dentro do design system | P1 | E |

### EP-14 · Plataforma e confiança
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-1401 | Onboarding que pede cada permissão no momento de uso, explicando para quê | P0 | G |
| RF-1402 | Painel "Permissões e privacidade" mostrando o que está concedido e o que cada uma habilita | P0 | G |
| RF-1403 | Sair e desinstalar restauram o sistema (snapshot) e não deixam processos/dispositivos | P0 | A |
| RF-1404 | Atualizações via Sparkle com notas de versão | P0 | G |
| RF-1405 | Trilíngue nativo desde a v1: **Português (`pt-BR`), Espanhol (`es`) e Inglês (`en`)** via `.xcstrings` (variantes curtas para notch + preservação de termos universais `dBTP`/`Headroom`/`Bypass`) | P0 | A |
| RF-1406 | Exportar/importar toda a configuração | P1 | — |
| RF-1408 | Feedback por e-mail, local e visível: o app só abre o e-mail da pessoa com a mensagem pronta e mostra o que acompanha ([ADR-0024](../07-decisoes/ADR-0024-feedback-por-email-local.md)) | P1 | G |
| RF-1409 | Mudo à prova de falha: app silenciado continua mudo se o timbr. morrer ([ADR-0017](../07-decisoes/ADR-0017-mudo-a-prova-de-falha.md)) | P0 | A |
| RF-1407 | Relatório de diagnóstico para bugs, revisável antes de enviar, sem áudio | P1 | — |

### EP-15 · Extensibilidade e extras audiófilos
| ID | Requisito | Prior. | Viab. |
|---|---|---|---|
| RF-1501 | Crossfeed (bs2b, presets Meier/Chu Moy) | P2 | B |
| RF-1502 | Loudness compensation dependente do volume | P2 | B |
| RF-1503 | Hospedar Audio Units por destino | P2 | B |
| RF-1504 | Convolução com IR do usuário | P3 | B |
| RF-1505 | Exportar medições e configurações para REW/CamillaDSP | P3 | B |
| RF-1506 | API de plug-ins da comunidade (efeitos e drivers) | P3 | — |

## 7. Requisitos não funcionais & Fronteira Local vs. Rede

Ver [requisitos-nao-funcionais.md](../04-engenharia/requisitos-nao-funcionais.md) (inclui matriz explícita do que é **100% local/offline** vs. **opt-in de rede**).

### Posicionamento Competitivo
Ver [mercado-e-diferenciacao.md](mercado-e-diferenciacao.md).

## 8. Dependências externas e riscos

Ver `08-registro/riscos-e-mitigacoes.md`. Os maiores: bugs de taps no 26/27; fechamento do contorno do MediaRemote; licença dos dados de medição; Dynamic Island nativa; protocolo do Momentum 4 no macOS.
