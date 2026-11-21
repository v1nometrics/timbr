# ADR-0002 · App nativo; stack web fora do app

- **Status:** Aceito · 2026-11-21

## Contexto

O dono quer usar fortemente bibliotecas web gratuitas (shadcn/ui e seus gráficos, spell.sh, bencho.dev, libraries.dev/waves) e uma estética derivada do Órbita e da ronda diária, que são web. O produto, porém, é um app de sistema: overlay no notch acima da barra de menus, motor de áudio em tempo real, eventos de teclado globais, Bluetooth, Core Audio.

## Decisão

1. **O app é 100% nativo: Swift 6, SwiftUI para a interface, AppKit onde o SwiftUI não alcança** (`NSPanel` do notch, `CGEventTap`, janelas, menus). Visualizações em tempo real (medidores, espectro, curva de EQ animada) usam `Canvas`/`TimelineView` ou Metal; Swift Charts só para gráficos não tempo-real no Estúdio e no Observatório.
2. **A stack web (React, Tailwind, shadcn/ui, Motion) é usada em três lugares, todos fora do app:** o site de documentação, o playground vivo do design system (`design-system/playground`), e a landing page.
3. **As bibliotecas web são referência visual e de comportamento para o design system nativo.** Cada componente nativo cita o componente web que o inspirou e documenta o que foi adaptado.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Painel do Estúdio em `WKWebView` com React/shadcn | Dois sistemas de design para manter; peso de memória (~um processo WebContent); acessibilidade e foco de teclado inferiores; risco de "cara de site" num app que precisa parecer do sistema. Fica registrada como opção de recuo apenas para o playground interno. |
| Electron/Tauri | Inviável para overlay acima da barra de menus com a qualidade e o custo de energia exigidos; motor de áudio continuaria nativo. |
| Flutter/Compose Multiplatform | Mesmos problemas de integração com AppKit e de "sentir-se Mac". |

## Consequências

- O design system mantém **uma fonte única de tokens** (ADR-0012) que gera Swift e CSS, para que docs, playground e app falem a mesma língua visual.
- Gráficos do shadcn (Recharts) e componentes animados das outras bibliotecas viram especificação: geometria, espaçamento, interação e motion são portados para SwiftUI.
