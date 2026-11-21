# Auditoria E2E · 2026-11-21 (rodada de UI/UX e cumprimento do plano)

> Pedido do dono: revisar de ponta a ponta o plano, o que foi implementado e o que foi executado; a estética estava "muito feia e desfuncional, parecendo template de IA"; o notch não era preto absoluto. Este registro separa o que foi **verificado nesta rodada** do que continua **em aberto**, com as classes de evidência do `AGENTS.md`.

## 1. Diagnóstico (o que estava errado, com causa no código)

| # | Problema | Causa encontrada | Evidência |
|---|---|---|---|
| D1 | Notch "não preto", borda visível | Todas as formas eram `RoundedRectangle` com os 4 cantos arredondados **mais um contorno branco a 11%** (`.stroke(line_default)`); o topo arredondado deixava frestas da barra de menus | Código auditado (`NotchOverlay.swift` v1) |
| D2 | Preto acinzentado em sala escura | Além de D1, a tela do MacBook Air é LCD IPS: pixel preto deixa vazar luz de fundo. Limite físico, documentado em `05-design-system/03 §1.1` | Comprovado (hardware: "Built-in Liquid Retina Display", 2560×1664) |
| D3 | Animação travando | O painel mudava de tamanho de forma brusca (`setFrame` sem animação) enquanto o conteúdo animava dentro | Código auditado |
| D4 | CPU em repouso | Timer de 50 ms checando o mouse o tempo todo, violando P9 | Código auditado |
| D5 | "Cara de template" | `Slider`, `Toggle`, `Picker`, `.bordered`, `.borderedProminent`, `Divider` e `NavigationSplitView` padrão em todas as telas; cartões empilhados com título pesado; tudo visível ao mesmo tempo | Código auditado |
| D6 | Tipografia nunca aplicada | Geist referenciada mas não empacotada; tracking e caixa dos tokens ignorados | Código auditado (ADR-0015) |
| D7 | Textos fixos em inglês e jargão | Mais de 30 rótulos fixos ("Save Preset", "Sample X", "Listen A", "Browser Extension IPC & Diagnostics", "Localhost 127.0.0.1:48192"…) | Código auditado |
| D8 | Métricas desonestas | KPIs mostravam "0.0 dBTP", "0 µs" e o espectro desenhava uma linha em −96 dB **sem sinal na cadeia**; Bluetooth sempre "concedido" (valor fixo `true`) | Captura de tela + código |
| D9 | Barra de menus | `NSMenu` padrão com strings em inglês misturadas | Código auditado |

## 2. O que foi feito e verificado nesta rodada

| Item | Status | Como foi verificado |
|---|---|---|
| Notch reescrito: forma de hardware (topo reto, ombros côncavos 9 pt, cantos inferiores contínuos), preto `sRGB 0,0,0` sem contorno, sombra ou alpha | **Comprovado** | Capturas dos estados compacto, espiada, expandido (com e sem fonte) em 2026-11-21; trava de CI contra `stroke` no notch |
| Morph sem tranco (painel cresce na hora, encolhe após a mola; forma animável) | **Provável** | Inspeção visual em uso; sem gravação em câmera lenta |
| Hover por `NSTrackingArea` (zero polling) | **Comprovado** (código) | Timer removido; consumo em repouso **não medido** com Instruments |
| Biblioteca própria de componentes (TFader com taper de console, TSwitch, TSegmented, TButtonStyle, ScrubValue, MenuChip, KPITile, OriginMark, AppIcon…) | **Comprovado** | Compila; CI 3b reprova controles padrão |
| Estúdio reescrito (barra lateral própria, páginas editoriais numeradas, KPIs, listas com hairlines, tabela de filtros estilo Pro-Q, curva de EQ nova, caminho do sinal com marcas de origem, espectro real, Ajustes no padrão do macOS) | **Comprovado** | Capturas das 5 páginas no tema escuro e de Mixer/EQ no claro |
| Painel da barra de menus desenhado | **Comprovado** | Captura via `--panel-preview` |
| Introdução sem decoração e com componentes próprios | **Comprovado** | Captura |
| Tipografia SF com tracking/caixa aplicados (ADR-0015) | **Comprovado** | Gerador + capturas |
| Paleta nova (papel quente/grafite/preto) com acento único de sinal | **Comprovado** | Tokens JSON + capturas |
| ~170 textos novos em PT/ES/EN, sem inglês fixo nas telas | **Comprovado** | Teste de paridade: 308 chaves |
| Honestidade: "—" sem sinal; espectro vazio; status real do Bluetooth | **Comprovado** | Capturas + código |
| Preset por dispositivo aplicado ao trocar de saída (RF-0404/RF-0607) | **Provável** | Compila e está ligado à troca de saída; **não testado com dois dispositivos reais** |
| Flags de revisão visual (`--studio`, `--notch`, `--panel-preview`, `--onboarding`) | **Comprovado** | Usadas para todas as capturas |
| CI completo | **Comprovado** | `./scripts/ci_check.sh` → ALL CI CHECKS PASSED (DSP com sanitizers, núcleo, motor, 20× `kill -9` sem vazamento) |
| Bíblia do design system v2.0 (6 documentos) | **Comprovado** | `docs/05-design-system/` |

## 3. Lacunas em aberto (o que o plano pede e o código ainda não faz)

Classificadas pela prioridade do PRD. Nada aqui foi maquiado na interface: nenhuma dessas funções aparece como se existisse.

| Prioridade | Requisito | Situação no código | O que falta |
|---|---|---|---|
| **P0** | RF-0201 Rotear cada app para uma saída diferente | **Não implementado.** Existe espelhamento global de saídas, mas `targetDestinationUIDs` não é usado pelo motor | Motor: um aggregate por destino com os taps das fontes roteadas (ADR-0004); UI: seletor de saída por linha no Mixer |
| **P0** | RF-1404 Atualizações automáticas (Sparkle 2) | **Não implementado** | Integrar Sparkle (o build atual não usa SwiftPM por limitação do ambiente), feed assinado EdDSA |
| **P0** | RF-0205 Política quando a saída some | **Não verificado** | Teste de bancada com fone desconectando |
| **P0** | Notarização / Developer ID | Script pronto (`build_dmg.sh`), **sem conta** | Conta Apple Developer |
| P1 | RF-1001/1002 Cenas e regras | Só o modelo (`AudioScene`); ducking em chamada funciona | Persistência, editor no Estúdio, gatilhos |
| P1 | RF-1101/1102 Now playing e metadados | **Não implementado** | Integrar `mediaremote-adapter` (BSD-3) + AppleScript Music/Spotify |
| P1 | RF-0703 Medidores LUFS S, picos por fonte | Parcial (LUFS M e true peak globais) | Medidores por fonte |
| P2 | RF-1105/1106 Letras e reconhecimento | **Não implementado** | LRCLIB; ShazamKit alimentado pelo tap |
| Hardware | E-08 (HFP), E-09 (Momentum 4 em bancada), E-10 (coexistência), E-11 (dogfood) | Código de leitura existe; **sem execução física registrada** | Sessão de bancada com o Momentum 4 e os AirPods do dono |
| UI | MacBook Pro OLED com Dynamic Island nativa | **Desconhecido** | Teste em hardware |
| UI | Consumo em repouso da casca do notch | **Não medido** | Instruments + `powermetrics` (E-12) |

## 4. Próximos passos recomendados

1. **Roteamento por app (RF-0201)**: é o maior buraco funcional do mixer e uma das duas prioridades do dono.
2. **Sessão de bancada** com o Momentum 4 e os AirPods: E-08, E-09 e o teste de preset por dispositivo.
3. **Now playing** no notch, com o adaptador BSD-3.
4. **Sparkle + notarização**, quando houver conta de desenvolvedor.
