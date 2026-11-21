# 03 · Superfícies e anatomia

> Implementação: `NotchOverlay.swift` (notch e pílula), `MenuBarPanel.swift` (barra de menus), `StudioWindow.swift` (Estúdio), `OnboardingWindow.swift` (Introdução). Regras de comportamento em `02-produto/especificacao-funcional.md §3`.

## 1. O notch

### 1.1 O preto (e o limite físico dele)

O preenchimento é `Color(.sRGB, 0, 0, 0, 1)`: zero absoluto, sem contorno, sem sombra, sem blur, sem transparência (lei L1).

**Limite do hardware, dito com honestidade.** O notch físico é um vazio sem pixels. A área que o timbr. desenha ao redor dele são pixels de tela exibindo preto:

| Tela | O preto desenhado parece… | Por quê |
|---|---|---|
| **Liquid Retina (LCD IPS, MacBook Air)** | Levemente acinzentado ao lado do notch físico, em sala escura | O LCD não apaga a luz de fundo; o pixel preto deixa vazar luz (contraste ~1000:1). Nenhum software corrige isso. |
| **Liquid Retina XDR (mini-LED, MacBook Pro)** | Quase indistinguível | Zonas de escurecimento local apagam a luz de fundo, com halo leve perto de áreas claras |
| **OLED (MacBook Pro 2026)** | Idêntico | Pixel preto = pixel apagado |

O que está sob nosso controle, e foi corrigido na v2.0: (1) não existe mais contorno de 11% de branco, que era o que tornava a borda visível em qualquer tela; (2) o topo é reto e encosta na moldura, sem frestas da barra de menus entre a moldura e a forma; (3) os ombros côncavos continuam a curva do hardware; (4) em repouso não desenhamos nada, só o notch físico aparece.

### 1.2 Pescoço e corpo: o notch nunca disputa a barra de menus

A forma tem duas partes (`NotchShape`, animável em 6 medidas):

```
   ombro ╮                    ╭ ombro                ← altura da barra de menus (H)
          │   PESCOÇO = notch  │                        largura ≤ notch físico (+ orelhas medidas)
   ╭──────╯  filete côncavo    ╰──────╮              ← y = H
   │               CORPO                 │            abaixo da barra de menus
   ╰─────────────────────────────────────╯           cantos contínuos
```

- **Pescoço:** na altura da barra de menus, a forma nunca é mais larga que o notch físico. A única exceção são as orelhas do estado compacto, e só onde a barra está **medida como livre**.
- **Corpo:** tudo o que é espiada, expandido ou HUD fica **abaixo** da barra de menus, ligado ao notch por filetes côncavos (14 pt) e cantos superiores convexos (14 pt). Resultado: menus de apps (Chrome, Safari) e ícones de status nunca ficam cobertos.
- **Ombros** côncavos de 9 pt no topo do pescoço continuam a curva do hardware.

### 1.3 Orelhas medidas (divisão de espaço com a barra de menus)

`MenuBarSpace.freeEars` mede o espaço livre de cada lado do notch:
- **Direita:** janelas de ícones de status (`CGWindowList`, camada 25; sem permissão).
- **Esquerda:** menus do app em primeiro plano, via Acessibilidade (só quando já concedida). Sem ela, o lado esquerdo é tratado como ocupado: nunca adivinhamos por cima dos menus de alguém.
- Orelha = espaço livre − 8 pt de respiro, limitada a 44 pt; abaixo de 26 pt, não há orelha.
- Remede ao trocar de app em primeiro plano, ao entrar no compacto e a cada 4 s enquanto compacto.

| Espaço livre | Compacto mostra |
|---|---|
| Dois lados | Ícone do app à esquerda, medidor à direita |
| Só um lado (≥ 40 pt) | Ícone e medidor dividem a orelha disponível |
| Só um lado (26–40 pt) | Só o ícone |
| Nenhum | **Queixo**: o notch cresce 20 pt para baixo, com ícone e medidor dentro, sem tocar a barra |

### 1.4 Estados e medidas

`W` e `H` são a largura e a altura do notch físico.

| Estado | Pescoço | Corpo (largura × profundidade abaixo da barra) | Raio |
|---|---|---|---|
| Repouso | W | — (só o hardware, nada desenhado) | — |
| Compacto | W + orelhas medidas | — (ou queixo W × 20) | 10 / 12 |
| HUD | W | 248 × 34: ícone de volume, barra, valor | 17 |
| Espiada | W | 360 × 66: ícone, nome, volume, fader | 22 |
| Expandido | W | 444 × (cabeçalho 30 + foco 74 + 34 por fonte até 3 + alerta 44 + rodapé 46) | 26 |

A janela tem **tamanho fixo** (cabe o maior estado) e nunca é redimensionada. Só a forma se move. Os cliques atravessam a janela fora da forma (`ignoresMouseEvents` atualizado a cada movimento do ponteiro enquanto aberta).

### 1.5 Interação

- **Abrir:** hover de 70 ms sobre o notch (ou sobre as orelhas) abre a espiada; clique abre o expandido. Detecção por `NSTrackingArea`, sem polling.
- **Fechar acompanhando o ponteiro:** enquanto aberto, a distância do ponteiro até a forma dirige um progresso contínuo de 0 a 1 (espiada: 70 pt; expandido: 110 pt), com curva elástica. A forma encolhe em direção ao estado fechado, o conteúdo desfoca (até 6 pt) e some, e o ícone viaja de volta para a orelha, tudo em tempo real. Se o ponteiro volta, tudo volta. Passando o limite, fecha com a mola `notchClose`, partindo exatamente de onde estava (sem salto).
- **Expandido por clique ou atalho:** só passa a seguir o ponteiro depois que ele entra na forma uma vez; abrir pelo teclado não fecha sozinho.
- **Um único ícone viaja** entre orelha, espiada e expandido; os blocos de conteúdo reservam o espaço dele. Nunca há duas cópias se cruzando.
- Clique fora ou `Esc` fecham. O monitoramento de movimento só existe enquanto aberto (custo zero em repouso).

### 1.6 Personalização permitida

O notch é **sempre preto absoluto**: não há tema de notch claro nem degradê. Personalizações seguras: mostrar ou não a atividade nas orelhas; usar só a barra de menus. Propostas futuras (acento monocromático branco no lugar do violeta) exigem ADR e teste em sala escura.

## 2. Barra de menus

Painel `MenuBarExtra(.window)` de 348 pt, nas cores do Estúdio (claro ou escuro, conforme o sistema): marca, estado do caminho e saída, switch de processamento; até 5 fontes com fader; lista de saídas com taxa e ✓; botões Abrir Estúdio, A/B neutro e Sair. É o fallback universal (Mac sem notch, outro app de notch ativo, usuário de teclado).

## 3. Estúdio

```
┌────────────┬──────────────────────────────────────────────────────┐
│ ● ● ●      │ 01 — MIXER                                           │
│ timbr.     │ Cada fonte no seu volume                [Ação]       │
│            │ Frase-resumo do caminho do sinal                     │
│ ▤ Mixer    │ ┌KPI┐ ┌KPI┐ ┌KPI┐ ┌KPI┐                              │
│ ∿ EQ       │ 01 Fontes de áudio ───────────────────────────────── │
│ ⌁ Observ.  │ ┌ lista em cartão com hairlines ──────────────────┐ │
│ APP        │ └──────────────────────────────────────────────────┘ │
│ ⚙ Ajustes  │ 02 Saídas …                                         │
│ ⓘ Sobre    │ 03 Entrada …                                        │
│ ─────────  │                                                      │
│ ● Caminho  │                                                      │
│ [Desligar] │                                                      │
└────────────┴──────────────────────────────────────────────────────┘
```

- Janela com conteúdo em tamanho total (`fullSizeContentView`), barra de título transparente; a barra lateral passa sob os semáforos. 1180×780 inicial, mínimo 980×640, posição lembrada.
- Barra lateral: marca, navegação (⌘1–5), bloco de estado no rodapé com o botão de desligar o processamento (⌥⌘B).
- Tema: Sistema, Claro ou Escuro (Ajustes). O notch não segue o tema.

| Página | Tarefa principal (acima da dobra) | Secundário (abaixo) |
|---|---|---|
| Mixer | KPIs + volumes por fonte | Saídas (padrão, espelho, atraso, impedância do M4), Entrada (microfone, mudo global, ducking) |
| Equalizador | Curva + métricas + Gosto (4 controles) ou Filtros (tabela Pro-Q) | Correção do fone · Comparar às cegas + treinador · Descreva o som (IA) |
| Observatório | Caminho do sinal com marcas de origem + KPIs medidos | Espectro real · driver do fone · Guardião · linha do tempo |
| Ajustes | Aparência · Notch · Permissões · Navegadores · Dados | — |
| Sobre | Marca, propósito, código-fonte, apoiar | Versão, licença, motor, privacidade |

## 4. Introdução

Janela escura de 720×520 com barra de título transparente, quatro passos com indicador de progresso em cápsulas, sem decoração (os círculos "atmosféricos" da v1 foram removidos por parecerem template). Idioma em `TSegmented`; botões `TButtonStyle`.
