# 03 · Superfícies, Geometria e Anatomia Espacial

> **Base normativa:** [ADR-0013 · Superfícies](../07-decisoes/ADR-0013-superficies.md), [Especificação Funcional §3](../02-produto/especificacao-funcional.md#3-notch-estados-e-transições), Apple HIG (Menu Bar, Popovers, Live Activities) e [nota 08 §5](../00-pesquisa/notas-fase-2/08_referencias_ui_componentes.md#5-linguagem-de-design-apple-macos-26-tahoe--macos-27-golden-gate-nov2026).

---

## 1. Princípio de Arquitetura Espacial: "Notch é Estado, Estúdio é Profundidade"

O Timbre existe em **seis superfícies complementares** para nunca sobrecarregar o notch e para garantir funcionamento idêntico em Macs com notch LCD, MacBook Pro OLED com Dynamic Island, Macs desktop sem notch e monitores externos.

| Superfície | Papel | Densidade | Fundo | Regra de corte |
|---|---|---|---|---|
| **1. Notch** | Estado imediato, controle do foco, HUD, espiada | Mínima | `#000000` absoluto | Nunca configuração; máx. 2 níveis |
| **2. Pílula Flutuante** | Equivalente ao notch em telas sem recorte físico | Mínima | `#000000` absoluto + borda `line.default` | Mesmo conteúdo do notch; posicionável |
| **3. MenuBarExtra** | Fallback universal e acesso por teclado | Média | Material nativo macOS (menu) | Sempre disponível, mesmo com notch desligado |
| **4. Estúdio** | Edição de EQ, Correção/Gosto, Cenas, Drivers, Preferências | Alta | `light` (`#FAFAFA`) / `dark` (`#141414`) | Layout 7/5; janela padrão macOS |
| **5. Observatório** | Caminho do sinal ponta a ponta, medidores, linha do tempo | Alta | `light` / `dark` (aba do Estúdio ou janela destacável) | Selos `MEDIDO` / `REPORTADO` / `INFERIDO` |
| **6. Live Activity** | Presença nativa na Dynamic Island OLED e menu bar (macOS 27.3+) | Mínima | `#000000` opaco (norma HIG) | Compact/Minimal (≤ 28 pt) + Expanded |

---

## 2. Anatomia do Notch (5 Estados + Regras de Hardware)

### 2.1 Detecção geométrica e janelas AppKit (`NSPanel`)

- **Geometria real:** calculada por `NSScreen.safeAreaInsets.top`, `auxiliaryTopLeftArea` e `auxiliaryTopRightArea`. A largura física do notch é `screen.frame.width - left.width - right.width`; a altura é `safeAreaInsets.top` (`~32–38 pt` conforme modelo Air/Pro e escala).
- **Janela não-ativante:** subclasse de `NSPanel` com `.nonactivatingPanel`, `level = .mainMenu + 3` (ou `.statusBar`), `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]`.
- **Foco:** o painel **nunca** vira `keyWindow` em `Repouso`, `Compacto`, `HUD` ou `Espiada`. Só aceita teclado no estado `Expandido` quando o usuário clica num campo ou abre via atalho (`⌥⌘V`).
- **Pass-through de cliques:** a janela é ligeiramente maior que o desenho visível para abrigar a área de histerese do hover; cliques fora da forma preta atravessam para a barra de menus nativa (ou ativam `ignoresMouseEvents` dinamicamente conforme posição do cursor).

- **Orçamento horizontal no estado `Compacto` (MacBooks 13"/14"):** extensão lateral estritamente limitada a **`≤ 40 pt` por lado** além das orelhas físicas do notch (máx. 2 sinais visuais: mini-capa/indicador de atividade + métrica única ou ícone de estado). Em menu bars densas, recuar automaticamente para `Repouso` antes de colidir com ícones do sistema.
- **Localização compacta (`PT / ES / EN`):** strings no Notch/Pílula usam chaves curtas dedicadas no `.xcstrings` para evitar truncamento em espanhol e português.

### 2.2 Máquina de estados do Notch

```
  [Repouso] ──(áudio ativo + pref)──▶ [Compacto]
      ▲                                   │
      │ (3s inativo)                      │ (hover 120ms)
      └─────────── [HUD] ◀──(tecla/alerta)┘
                     │                    ▼
                     │              [Espiada] ──(hover sai 300ms)──▶ [Compacto/Repouso]
                     │                    │
                     └──(clique / ⌥⌘V)────▼
                                     [Expandido] ──(clique fora / Esc / ⌥⌘V)──▶ [Compacto/Repouso]
```

| Estado | Dimensão indicativa `[Proposta]` | Conteúdo permitido (teto rígido) |
|---|---|---|
| **Repouso** | Exatamente o recorte do hardware (`0 px` extras) | Nada. O notch é invisível. |
| **Compacto** | `+28–44 pt` em cada asa lateral (altura = `safeAreaInsets.top`) | **Asa esquerda:** mini-capa (`18×18 pt`, `radius 4 pt`) ou ícone do app em foco + micro espectro opcional (`3–4` barras). **Asa direita:** destino curto ou selo de estado (`EQ`, ponto de alerta único). |
| **HUD** | Largura do notch + `60–80 pt` por asa (ou barra abaixo `+36 pt` de altura) | **Só o evento:** ícone do destino + nome curto em `type.eyebrow` + barra horizontal fina (`4–6 pt` cápsula) + valor em `type.mediumValue` com `.numericText()`. Some em `1,2 s`. |
| **Espiada** | `~360 × 96 pt` (desce suavemente abaixo do recorte) | **Uma linha principal:** fonte em foco (capa/ícone + faixa + artista em 1 linha) + slider de volume direto + chip de destino + botão de bypass rápido. Máximo 3 controles interativos. |
| **Expandido** | `~440–520 pt` largura × altura dinâmica (`≤ 380 pt`) | **3 zonas separadas por `0.5 pt line.subtle`:** (1) Cabeçalho: destino ativo, botão `Estúdio`, status `BIT-PERFECT` / `EQ ATIVO`; (2) **Mixer**: até 5 fontes ativas (ícone, nome, slider 1:1, mute, chip de destino); (3) **Faixa + Letra / Ação:** transport compacto ou 2 linhas de letra `Geist Serif` + eventual **1 alerta** do Guardião. |

### 2.3 Regras anti-poluição no Notch

1. **Zero caixas dentro do notch.** Nada de `RoundedRectangle` com fundo cinza envolvendo cada app do mixer. Cada linha do mixer é texto + slider diretamente sobre `#000000`, separada por `0.5 pt` de `white @ 7%`.
2. **Sem configurações no notch.** Editar bandas Q/Hz, importar AutoEq, treinar preferências ou configurar drivers **nunca** acontece no notch — um botão `Estúdio ↗` abre a janela completa.
3. **Personalização de estética do notch (pedido explícito do usuário):** oferecer nas Preferências do Estúdio um seletor de modo do notch com 3 presets fiéis à gramática do projeto:
   - **Preto Contínuo (Padrão):** `#000000` puro, bordas inferiores suaves `continuous`, zero borda externa.
   - **Preto com Fio Editorial:** `#000000` com filete inferior `0.5 pt` em `white @ 11%` (ou gradiente sutil de `1 px` para separar de wallpapers muito escuros).
   - **Silencioso (Somente Menu Bar / Pílula):** desativa o overlay do recorte e mantém todas as funções rápidas no menu e pílula sob demanda.
4. **Conflito no MacBook Pro OLED (Dynamic Island):** quando `safeAreaInsets.top` indicar ausência de recorte estático ou presença de Dynamic Island nativa / outro app de notch no topo central, o Timbre não compete pelo espaço: muda automaticamente o modo primário para **Live Activity + Pílula/MenuBar**, avisando de forma calma.

---

## 3. Anatomia do Estúdio e Observatório (Janela Padrão macOS)

### 3.1 Estrutura geral (`~1040 × 700 pt` mínima)

- **Navegação lateral estreita (`200–220 pt`):** `Mixer & Saídas` · `Equalizador` · `Correção & Gosto` · `Dispositivos` · `Observatório` · `Inteligência & A/B` · `Preferências`. Item ativo com `accent.subtle` + texto `accent.strong` (`[Órbita]`).
- **Grid de conteúdo 7/5 (`gap: 20 pt`, padding `24 pt`):**
  - **Tela Equalizador:** `7/12` = Gráfico PEQ interativo (curvas `Correção`, `Gosto`, `Resultado` + espectro pós-EQ atrás + faixa de headroom/preamp no rodapé); `5/12` = controles simples (`Graves`, `Calor`, `Presença`, `Ar`) no topo + tabela numérica de bandas embaixo (alternável).
  - **Tela Correção & Gosto:** `7/12` = Resposta do fone vs. alvo Harman/5128; `5/12` = Seletor de medição AutoEq (fonte, equipamento, crédito) + controles de gosto + botão `A/B Cego`.
  - **Tela Dispositivos:** `7/12` = Lista de saídas/entradas com capacidades sondadas pelo HAL (taxa nominal, formato físico, clock, volume HW/SW); `5/12` = Painel do driver ativo (ex.: Momentum 4: bateria, ANC, Transparency, Sidetone, EQ interno + aviso de conflito G-04).
  - **Tela Observatório:** Bloco superior `12/12` = Diagrama horizontal do caminho do sinal (`Fonte → Mixer → Correção → Gosto → Preamp/Limiter → Saída → Fone`), cada nó clicável mostrando latência e selo `MEDIDO` / `REPORTADO` / `INFERIDO`; abaixo em `7/5` = Medidores calibrados (Peak / dBTP / EBU R128) à esquerda e Linha do tempo de eventos do Guardião à direita.

---

## 4. Live Activity (macOS 27.3+ e MacBook Pro OLED)

Seguindo rigorosamente a HIG (`Live Activities`, acesso 2026-11-21):
- **Fundo obrigatório:** `#000000` opaco para encaixar na Dynamic Island sem borda visível.
- **Minimal / Compact Trailing:** caber dentro de um círculo de `28 pt` de diâmetro — mostra apenas ícone do destino ou mini-anel de nível em `accent.base` (`#A78BFF`).
- **Compact Leading:** mini-capa (`20×20 pt`) ou ícone do app de áudio em foco.
- **Expanded:** nome do app + volume em `type.mediumValue` + estado do EQ (`+3,2 dB · Harman` ou `BIT-PERFECT`) + botão de bypass e de abrir Estúdio.
