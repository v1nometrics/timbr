# Bíblia do design system · timbr.

> **Status:** v2.3 · 2026-11-22 · **Lei, não sugestão.** Substitui a v1, que descrevia uma tipografia (Geist) que nunca chegou a renderizar no app nativo e permitia controles padrão do macOS nas superfícies do produto.
> **Direção de arte:** `apple-design` (fluidez, molas, materiais, tipografia de sistema) + `emil-design-eng` (detalhes invisíveis, curvas fortes, nada de animação em ação de teclado) sobre o DNA do **Órbita / ronda diária** (acromático, editorial, eyebrows em mono, números grandes; **sem cor de marca**, ADR-0016).
> **Fonte executável:** `design-system/tokens/*.tokens.json` → `design-system/generated/TimbreTokens.swift` e `tokens.css` (ADR-0012). Componentes: `Sources/TimbreApp/DSComponents.swift`.

## 1. O que o timbr. tem que parecer

**Um instrumento de precisão que a Apple poderia ter feito.** Silencioso em repouso, exato quando usado, honesto sobre o que mede. Nunca um painel de desenvolvedor, nunca um template.

Três frases-teste. Se uma tela falha em uma delas, ela está errada:
1. *"Parece parte do Mac."* Tipografia de sistema, materiais e molas do macOS, preto do hardware no notch.
2. *"Dá para ler o estado em um segundo."* Uma frase de resumo, um número grande, o resto em camadas.
3. *"Nada aqui está mentindo."* Todo número tem origem (medido, reportado, inferido); sem sinal, mostra "—".

## 2. As dez leis

| # | Lei | Como verificar |
|---|---|---|
| L1 | **O notch é preto absoluto.** `sRGB 0,0,0`, sem contorno, sem blur, sem alpha. Topo reto, colado na moldura; ombros côncavos como o hardware. Única sombra permitida: preta e suave, só enquanto aberto (profundidade, como nos apps de referência). | CI reprova `stroke`/`strokeBorder` em `NotchOverlay.swift`. Foto em sala escura. |
| L2 | **Nenhum controle padrão nas superfícies do produto.** Sem `Slider`, `Toggle`, `Picker`, `.bordered`, `Divider` do sistema. Use `TFader`, `TSwitch`, `TSegmented`, `TButtonStyle`, `Hairline`. | CI (etapa 3b) reprova. |
| L3 | **Sem matiz de marca: ênfase por tinta, peso e espessura.** O sistema é só preto, branco e cinzas quentes (ADR-0016). O sinal processado se distingue por linha sólida de 2 pt em tinta primária, contra tracejado e linhas finas. A cor aparece só com significado semântico (verde nativo, âmbar aviso, vermelho destrutivo, azul info), nunca em repouso nem como marca. | Revisão: nenhuma matiz fora de `semantic.*`; `grep` sem valores violeta nos tokens. |
| L4 | **Tipografia de sistema com tracking por tamanho.** SF Pro (texto e números), SF Mono (eyebrows, valores técnicos), New York (letras de música). Tracking negativo no grande, positivo no eyebrow. Sempre via `.type(token)`. | Nenhum `.font(.system(...))` solto fora de ícones e da marca. |
| L5 | **Números tabulares e unidades separadas.** O número em `mediumValue`/`notchValue`, a unidade em mono menor e esmaecida (`72` `%`, `−4.5` `dB`). Sinal de menos tipográfico (`−`). | `Fmt.db`, `Fmt.signed`, `Fmt.percent`. |
| L6 | **Honestidade visual (P4).** `OriginMark` em todo valor do Observatório; sem sinal na cadeia, métricas medidas mostram "—" e o espectro mostra o estado vazio. Nunca visualizador aleatório. | `hasLiveSignal`. |
| L7 | **Movimento com propósito.** Molas para o que o usuário toca; `notchOpen` com bounce 0,2 porque imita a Dynamic Island (mesma faixa do DynamicNotchKit e do boring.notch); fechar sem bounce e mais rápido. Ação por teclado nunca anima. | Tabela em `02-motion-e-fisica.md`. |
| L8 | **Densidade editorial.** Página = eyebrow numerado + título + frase-resumo + KPIs + seções numeradas (`01`, `02`…). Listas em cartão com hairlines, não cartões empilhados. | Estrutura das páginas do Estúdio. |
| L9 | **Divulgação progressiva.** Notch: estado e ação direta. Estúdio: configuração. Termos técnicos (tap, HAL, IPC) só no Observatório e na documentação. | Revisão de texto (`07` abaixo). |
| L11 | **O estado persistente nunca cobre a barra de menus; o aberto abre como Dynamic Island.** O compacto (que fica na tela enquanto toca) usa só o espaço da barra medido como livre, ou um queixo. Espiada, expandido e HUD são transitórios e abertos por intenção: crescem para os lados e para baixo a partir do notch, como em todos os apps de referência, e soltam a barra assim que o ponteiro vai para ela. | Captura com um app de muitos menus em primeiro plano; vídeo `--demo`. |
| L10 | **Calma.** Em repouso o notch é invisível e não consome CPU (hover por `NSTrackingArea`, sem polling). Um alerta por vez. | Instruments em repouso. |

## 3. Mapa do sistema

| Documento | Conteúdo |
|---|---|
| [01 · Fundações e tokens](01-fundacoes-tokens.md) | Cor (claro, escuro, notch), tipografia, espaço, raios, linhas |
| [02 · Motion e física](02-motion-e-fisica.md) | Molas, curvas, durações por interação, movimento reduzido |
| [03 · Superfícies e anatomia](03-superficies-e-anatomia.md) | Notch (geometria exata, estados, preto), pílula, barra de menus, Estúdio, Introdução |
| [04 · Componentes e visualização de áudio](04-componentes-e-visualizacao-audio.md) | Catálogo de componentes e regras de gráficos (curva de EQ, espectro, medidores, origem) |
| [05 · Assets, iconografia e referências](05-assets-iconografia-e-referencias.md) | SF Symbols, ícones de app, marca, referências mestras e como usar shadcn/Bencho/Spell/libraries.dev |

## 4. Voz e texto

- **Frases curtas, caixa de frase**, sem ponto de exclamação. "Cada fonte no seu volume", não "Gerencie Seus Volumes!".
- **Específico vence genérico.** "Voltar tudo a 100%", não "Resetar". "Desligar processamento", não "Bypass".
- **Explique a consequência.** "Este dispositivo não tem volume próprio; o timbr. controla em software e o caminho deixa de ser bit-perfect."
- **Vocabulário controlado** do [glossário](../01-visao/glossario-tecnico.md): nunca "Hi-Fi", "lossless" ou "bit-perfect" fora das condições definidas.
- **Três idiomas com paridade** (PT, ES, EN): o teste do CI falha se faltar uma tradução. Todo texto novo entra em `LocalizationUI.swift`.

## 5. Checklist de revisão (obrigatório antes de merge de UI)

| Item | Pergunta |
|---|---|
| Superfície | Está usando `.surface(...)` e lendo cores do `@Environment(\.palette)`? |
| Controles | Algum controle do sistema escapou (L2)? |
| Tipografia | Todo texto usa `.type(...)`? Números tabulares? Unidade separada? |
| Cor | Alguma matiz aparece sem significado semântico (L3)? A ênfase está em tinta, peso e espessura? |
| Honestidade | Algum número aparece sem origem ou sem sinal real (L6)? |
| Motion | A animação tem propósito? Abre com mola, fecha mais rápido? Teclado sem animação? |
| Estados | Vazio, carregando, erro, desabilitado, foco, hover e pressionado desenhados? |
| Acessibilidade | Rótulo e valor de acessibilidade em faders/switches? Contraste ≥ 4,5:1 no texto? Movimento reduzido respeitado? |
| Idiomas | Chaves em PT/ES/EN? Texto cabe em espanhol (o mais longo)? |
| Foto | Captura real anexada ao PR (claro, escuro e notch, quando aplicável)? |

## 6. Como verificar visualmente (sem depender de alguém clicando)

O app aceita flags de revisão que abrem cada superfície direto no estado desejado:

```bash
./dist/Timbr.app/Contents/MacOS/Timbr --studio mixer|equalizer|observatory|settings|support
./dist/Timbr.app/Contents/MacOS/Timbr --notch compact|peek|expanded|hud
./dist/Timbr.app/Contents/MacOS/Timbr --panel-preview      # painel da barra de menus numa janela
./dist/Timbr.app/Contents/MacOS/Timbr --onboarding
```

Fotografe com `screencapture -x` e revise com o checklist acima. As capturas da revisão de 2026-11-21 estão descritas em `docs/08-registro/auditoria-e2e-2026-11-21.md`.

## 7. Governança e histórico

- Mudança de token = PR que altera o JSON, regenera Swift/CSS e atualiza esta pasta no mesmo commit.
- Exceções à lei exigem ADR.

| Versão | Data | Mudança |
|---|---|---|
| v2.3 | 2026-11-22 | Identidade acromática (ADR-0016): o violeta saiu dos tokens, do ícone e da marca; `accent.*` passa a ser tinta; ênfase por peso e espessura; cor só semântica. |
| v2.2 | 2026-11-22 | Modelo dos apps de referência (DynamicNotchKit, NotchDrop, boring.notch): forma única que abre para os lados e para baixo, conteúdo nas "asas" ao lado da câmera, ícone viajando só na horizontal, pop imediato no hover + abertura após 150 ms, mola de abrir com bounce 0,2, revelação com blur/escala a partir do topo, sombra preta só aberto, liberação rápida da barra. O pescoço da v2.1 foi abandonado. |
| v2.1 | 2026-11-21 | Notch em pescoço + corpo (nunca cobre menus), orelhas medidas na barra (CGWindowList + Acessibilidade) com queixo quando não há espaço, canvas fixo, ícone único viajante, fechamento contínuo seguindo o ponteiro, molas mais rápidas (0,38/0,30 s), flag `--demo` para inspeção quadro a quadro. |
| v2.0 | 2026-11-21 | Reescrita completa: notch com forma de hardware e preto sem contorno; tipografia SF (ADR-0015) com tracking efetivamente aplicado; paleta acromática quente (ronda/Órbita) com acento único de sinal; biblioteca de componentes própria; trava de CI contra controles padrão; honestidade de métricas sem sinal. |
| v1.0 | 2026-11-21 | Primeira versão (Geist, controles do sistema, notch com contorno). Substituída. |
