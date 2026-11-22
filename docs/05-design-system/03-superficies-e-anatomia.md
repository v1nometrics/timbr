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

### 1.2 Forma única que abre para os lados e para baixo

Estudamos o código dos apps de notch abertos mais usados: DynamicNotchKit (base de vários apps), boring.notch e NotchDrop. Todos usam o mesmo modelo, e é o que faz a forma ler como o notch crescendo:

```
 ╮ombro                                              ombro╭     ← borda da tela (y = 0)
 │  [ícone] Nome do app   ▓▓▓ câmera ▓▓▓   100 %  [mudo]  │     ← asas, na altura da barra de menus (H)
 │  ─────────────────────●──────────────                  │     ← corpo
 ╰────────────────────────────────────────────────────────╯     ← cantos contínuos
```

- **Uma forma só**, colada na borda da tela. Ela cresce para os lados e para baixo a partir do notch físico, nos dois eixos ao mesmo tempo.
- **Asas:** na altura da barra de menus, à esquerda e à direita da câmera, fica o conteúdo mais importante: quem toca (ícone e nome) e quanto (volume) ou para onde (saída). Abaixo fica o controle. É o mesmo arranjo do boring.notch aberto e das atividades compactas do DynamicNotchKit.
- **Ombros** côncavos no topo continuam a curva do hardware: 7 pt fechado, 14 pt aberto (os apps de referência usam 6 → 15/19 pt).
- **Sombra preta suave só enquanto aberto** (raio 14, y 6, 50%). Ela dá a profundidade de "ilha" sobre conteúdo claro; sobre conteúdo escuro some.

**Por que abandonamos o "pescoço" da v2.1.** Na v2.1 os estados abertos desciam só para baixo, sem tocar a barra. O dono do produto testou e achou estranho: parecia um cartão pendurado, não o notch crescendo. Nenhum app de referência faz isso. O que resolve a disputa com os menus é separar os estados persistentes dos transitórios (§1.3 e §1.5), não deformar a abertura.

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

| Estado | Largura | Altura total | Raio de baixo / ombro | Conteúdo |
|---|---|---|---|---|
| Repouso | W | H | 10 / 7 | nada desenhado (só o hardware); no hover aparece +5 pt de cada lado e +3 pt para baixo |
| Compacto | W + orelhas medidas | H (ou H + 20 de queixo) | 10 / 7 | ícone e medidor nas orelhas livres |
| HUD | W + 2 × 58 | H + 18 | 14 / 11 | asas: ícone e valor; queixo: barra de nível |
| Espiada | W + 2 × 128 | H + 44 | 20 / 14 | asas: ícone, nome, volume, mudo; abaixo: fader |
| Expandido | máx(W + 2 × 140, 464) | H + 8 + foco 66 + 34 por fonte (até 3) + alerta 44 + rodapé 46 | 24 / 14 | asas: app e saída; abaixo: volume, fader, outras fontes, rodapé |

A janela tem **tamanho fixo** (cabe o maior estado) e nunca é redimensionada. Só a forma se move. Os cliques atravessam a janela fora da forma (`ignoresMouseEvents` atualizado a cada movimento do ponteiro enquanto aberta).

### 1.5 Interação

- **Abrir:** o hover sobre o notch (ou sobre as orelhas) faz o pop na hora. Se o ponteiro fica 150 ms, abre a espiada, com um toque háptico leve. Passar rápido pela barra não abre nada. Clique abre o expandido. Detecção por `NSTrackingArea`, sem polling.
- **Clicar:** como tocar na Dynamic Island.
  - Na espiada, clicar em qualquer lugar fora de um controle a transforma no expandido, com a mesma mola e o ícone viajando.
  - No expandido, clicar no nome de um app (na asa ou numa linha de fonte) traz esse app para a frente, ou o abre se ele foi fechado, e o notch se recolhe. Um realce suave no hover indica que o nome é clicável.
  - Clicar no notch fechado abre direto o expandido.
  - O painel aceita o primeiro clique: não é preciso "focar" antes.
- **Fechar acompanhando o ponteiro:** enquanto aberto, a distância do ponteiro até a forma dirige um progresso contínuo de 0 a 1 (espiada: 64 pt; expandido: 104 pt; **30 pt quando o ponteiro está na faixa da barra de menus**, para que ir até um menu coberto o libere quase na hora), com curva elástica. A forma encolhe em direção ao estado fechado, o conteúdo desfoca (até 6 pt) e some, e o ícone viaja de volta para a orelha, tudo em tempo real. Se o ponteiro volta, tudo volta. Passando o limite, fecha com a mola `notchClose`, partindo exatamente de onde estava (sem salto).
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
