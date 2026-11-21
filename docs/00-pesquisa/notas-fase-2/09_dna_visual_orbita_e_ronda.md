# DNA visual da Órbita (SIP) e da "Ronda diária": tokens, regras e tradução para o Timbre em SwiftUI

Nota de pesquisa da fase 2, escrita em 21/11/2026. As duas fontes foram só lidas; nada foi alterado nelas. Os valores de CSS estão copiados literalmente. As referências seguem o formato `arquivo:linha`.

---

## 0. Fontes, siglas e qual direção está no ar

### 0.1 Siglas usadas nesta nota

| Sigla | Caminho real |
|---|---|
| `MON/` | `/Users/viniciustorres/Documents/SIP/migration-2026-11-17/calendar-invitee-worktree/apps/monitoring/` (branch `codex/workspace-migration-calendar`, HEAD `807699ad6`) |
| `DIG` | `MON/src/service/digital/digital.module.css` (2.156 linhas) |
| `SCR` | `MON/src/service/screen.module.css` (casca da Presidência) |
| `FND` | `MON/src/components/arc/foundation-css.ts`. É uma única string JS na linha 1. As linhas citadas como `FND:n` são da cópia decodificada (`JSON.parse` da string), na mesma ordem do arquivo |
| `MOT` | `MON/src/components/arc/lib/motion-tokens.ts` |
| `RONDA` | `/Users/viniciustorres/.t3/userdata/attachments/b1a86daa-…-html.html` (378.540 bytes; 322 linhas. As linhas 1–3 são as três fontes em base64 e o CSS vai da linha 5 à 264) |

### 0.2 Qual direção é a do link `#/orbita/presidencia/digital`

O endereço publicado **não usa nenhuma das rodadas `round1`–`round8`** nem a direção "Lavanda/Noite" do laboratório. Ele roda o módulo `src/service/`, escrito em React com CSS Modules, sobre a fundação da biblioteca **Arc** com acento **violeta**.

- **A rota existe só neste worktree de migração.** O README dele diz: "`#/orbita/presidencia/digital` | Leitura demonstrativa de audiência, sentimento, publicações, temas, imprensa e concorrentes" (`MON/README.md`, tabela "Experiências disponíveis"). Os checkouts `app-tereza-visual` (branch `feat/diagnostico-tereza-sem-marca`, 09/11) e `app-tereza-public` (`feat/diagnostico-tereza-publico`, 09/11) **não têm `src/service/`**. Neles, a direção mais recente é a Rodada 08 (`docs/round8-study.md`), que nunca foi publicada.
- **O módulo carrega a fundação e fixa o acento violeta.** `MON/src/service/mount.tsx:11-16` injeta `foundationCss` e executa `document.documentElement.dataset.accent = "violet"`.
- **O bundle publicado é o mesmo código.** O `https://orbita.santanainteligencia.com.br/` responde com uma casca SPA (`main.css` de 1,13 MB e `main.js` de 1,40 MB). O `main.js` contém `dataset.accent="violet"`. O `main.css` contém o CSS Module do Digital com o sufixo `_j-Ipsw`. **O conjunto de classes publicado é idêntico ao de `DIG`**: `comm` deu zero diferenças. As regras minificadas batem com o local; por exemplo, `heroTitle_j-Ipsw{…font-size:clamp(2.4rem,4.3vw,3.6rem);font-weight:500;line-height:1.01}`.
- **A página autenticada não foi vista.** A rota exige o magic link da SIP para um e-mail cadastrado em `allowed_users` (README). Por isso a análise se apoia no código e no CSS publicado, não numa captura de tela.
- **O tema escuro existe, mas não é usado.** A fundação define `:root[data-theme="dark"]` (`FND:93-139`), porém nada em `src/service` ativa esse atributo: a busca por `data-theme`, `dataset.theme` e `prefers-color-scheme` não encontrou nada. **O produto publicado é só claro.**

**A Ronda diária descende diretamente do Dash Diário da Órbita.** Ela reusa os mesmos nomes de classe (`hero`, `profileCard`, `metrics`, `metricTop`, `cardIndex`, `cardFoot`, `donutCenter`…) e as mesmas declarações. A linha 25 do hero, por exemplo, repete a de `DIG:20-31`. Sobre essa base ela aplica três diferenças decisivas:

1. **O fundo da página fica levemente cinza.** A Ronda usa `--background:oklch(98.4% 0 0)` (RONDA:7), enquanto o Arc usa `--background: var(--neutral-0)`, branco puro (FND:15). Com isso, os cards brancos se destacam do fundo off-white.
2. **O corpo de texto é Inter.** A Ronda declara `--font-body:"Inter",sans-serif` (RONDA:14) e carrega `Inter:wght@400;500;600` do Google Fonts (RONDA:1). Títulos e números continuam em `"Geist"`. No app publicado, a casca sobrescreve as duas variáveis para `"Geist Sans"` (SCR:3-4).
3. **Uma "passada editorial" remove ornamentos** (RONDA:211): `/* ——— editorial pass: no tinted boxes, no side stripes, no chips ——— */`. É a camada que torna a Ronda "extremamente limpa" (detalhes em §6).

**A direção de laboratório não foi publicada.** As rodadas e a "Lavanda/Noite" (`MON/src/design/tokens.css`, `src/platform/styles.css`, `src/brand/brand.css`) aparecem aqui só para contraste. Exemplos: `:root{ color:#282c27; background:#f4f2ed; --ease: cubic-bezier(0.2, 0.7, 0.2, 1) }` (`tokens.css:22-30`); `.ob-app{ --ob-ink:#30233b; --ob-muted:#6f5e7c; --ob-line:#e3d8ea; --ob-accent:#6d468f; --ob-night:#221c2c; background:#f7f4fa }` (`platform/styles.css:2-11`). A fundação tipográfica é a mesma (Geist Sans, Mono e Serif, `tokens.css:1-28`), mas a paleta é quente e lavanda, não neutra.

Os estudos em `docs/studies/orbita/` e `experiments/orbita-fase0/` tratam do motor de inteligência (manchetes, associação, ciclo) e **não têm conteúdo visual**. Foram descartados.

---

## 1. Tipografia

### 1.1 Famílias

| Papel | Órbita publicada | Ronda | Onde |
|---|---|---|---|
| Interface e corpo | `"Geist Sans", sans-serif` | `"Inter",sans-serif` (com `letter-spacing:-.01em` global) | SCR:3-4; RONDA:14, RONDA:18 |
| Display (títulos e números grandes) | `--font-display: "Geist Sans", sans-serif` | `--font-display:"Geist",sans-serif` | SCR:3; RONDA:14 |
| Rótulos, eyebrows e metadados | `var(--mono, "Geist Mono", monospace)` | `--mono:"Geist Mono",monospace` | DIG:71; RONDA:14 |
| Voz humana (citações) | `var(--serif, Georgia, serif)` → `"Geist Serif"` | `--serif:"Geist Serif",Georgia,serif` | DIG:1169; RONDA:14, RONDA:224 |
| Arquivos | `Geist-Variable.woff2` (100–900), `GeistMono-Variable.woff2` (100–900), `GeistSerif-Regular.woff2` (400) | Os mesmos, embutidos em base64 com `font-display:block` | `MON/src/design/tokens.css:1-21`; RONDA:1-3 |

A licença é a SIL OFL (`MON/src/design/fonts/geist-OFL.txt`). O Geist pode ser embarcado no app.

A divisão de papéis é rígida. **O Sans traz o conteúdo. O Mono em caixa alta só rotula, nunca fala. O Serif aparece só quando quem fala é uma pessoa**, em `.quote p` (DIG:1166-1173) e `.q blockquote` (RONDA:224).

### 1.2 Pesos

- **Só dois pesos existem, 400 e 500.** `b,strong{font-weight:500}` (RONDA:21). Todos os títulos e números de display usam `font-weight: 500`: `.heroTitle` em DIG:84, `.cardTitle` em DIG:419, `.donutCenter strong` em DIG:596.
- **O 600 aparece só em caminhos de exceção.** São eles `.metricValueEmpty` (DIG:1885, o "—" de valor ausente), `.printAudienceTitle` (DIG:1915) e a carga do Inter 600 na Ronda, que nenhuma regra visível usa.
- **Não há bold de verdade.** A hierarquia vem de tamanho, tracking e cor, nunca de peso.

### 1.3 Escala de tamanhos (valores reais)

A fundação declara a escala em `FND:79-81`:
`--text-xs: .75rem; --text-sm: .875rem; --text-base: 1rem; --text-lg: 1.125rem; --text-xl: 1.375rem; --text-2xl: 1.75rem; --text-3xl: 2.25rem; --text-4xl: 3.25rem; --text-5xl: 4.5rem;`

Na prática, os dois produtos usam uma escala bem mais fina nos tamanhos pequenos:

| px | Uso | Fonte |
|---|---|---|
| 9 | Rótulos do sparkline (horas) | `.sparkLbl{…font-size:9px}` RONDA:176 |
| 9.5 | Cabeçalhos de tabela e `dt` | `.netHead`, `.shift th`, `.kv dt`, `.profileFacts dt`, `.cmpHead` (`font-size:9.5px`) RONDA:89, 154, 171, 50, 187 |
| 10 | Índice de card, kicker, percentuais, ranks | `.cardIndex{font-size:10px}` DIG:410; `.themePercent` DIG:958; `.rank` RONDA:123 |
| 10.5 | Pílulas numéricas, `small` de tabela | `.pill…{font-size:10.5px}` RONDA:217; `.shift td.lbl small` RONDA:158 |
| 11 | Eyebrow, rótulo de KPI, rodapé de card, legendas | `.eyebrow{font-size:11px}` DIG:72; `.metricTop` DIG:328; `.cardFoot` DIG:449 |
| 11.5 / 12 | Tabela de mar aberto; tópicos | `.ext{font-size:11.5px}` RONDA:178; `.pressTopic{font-size:12px}` DIG:1104 |
| 12 (`--text-xs`) | Subtítulo de card, notas, nome de tema | `.cardSub` DIG:428; `.metricNote` DIG:357 |
| 12.5 / 13 / 13.5 | Texto de insight, callout editorial, facts | `.insight p{font-size:12.5px}` RONDA:214; `.profileFacts dd{font-size:13px}` RONDA:51; `.callout{…font-size:13.5px}` RONDA:212 |
| 14 (`--text-sm`) | Nome de rede, título de post, valores de linha | `.networkName strong` DIG:499; `.networkValue` DIG:533 |
| 14.5 | Prosa longa | `.prose{font-size:14.5px;line-height:1.62}` RONDA:195 |
| 16 (`--text-base`) | Valor do post, citação serif no app | `.postValue` DIG:764; `.quote p` DIG:1170 |
| 17 | Citação serif na Ronda | `.q blockquote{font-size:17px}` RONDA:224 |
| 17.9 (1.12rem) | Título de card na Ronda | `.cardTitle{font-size:1.12rem}` RONDA:70 |
| `clamp(1.02rem, 1.15vw, 1.16rem)` | Título de card no app | DIG:418 |
| 21.6 (1.35rem) | Número de KV (imprensa) | `.kv dd{font-size:1.35rem}` RONDA:172 |
| 22 (`--text-xl`) | Nome do perfil | `.profileName` DIG:168 |
| 27.2 (1.7rem) | Centro do donut | `.donutCenter strong{font-size:1.7rem}` RONDA:105; app `clamp(1.45rem, 2.2vw, 1.7rem)` DIG:595 |
| 39.2 (2.45rem) | Número de KPI | `.metricValue{font-size:2.45rem}` RONDA:59; app `clamp(1.9rem, 2.9vw, 2.55rem)` DIG:350; diário `clamp(1.65rem, 2.5vw, 2.15rem)` DIG:2112 |
| 46.4 (2.9rem) | Manchete do hero na Ronda | `.heroTitle{font-size:2.9rem}` RONDA:249, que sobrescreve `3.25rem` de RONDA:30 |
| `clamp(2.4rem, 4.3vw, 3.6rem)` | Manchete do hero no app | DIG:83 |

O salto é grande. **Entre 14 e 39 px quase não há texto**: só títulos de card (~18 px), o centro do donut (~27 px) e o nome do perfil (22 px). A página vive em dois registros, micro (9–14 px) e display (39–58 px).

### 1.4 Letter-spacing por tamanho

O tracking cai conforme o tamanho cresce. No mono em caixa alta ele é sempre positivo.

| Faixa | Tracking | Exemplos |
|---|---|---|
| Display grande (46–58 px) | `-0.05em` | `.heroTitle{letter-spacing:-0.05em}` DIG:85, RONDA:30 |
| Número de KPI (~39 px) | `-0.045em` | `.metricValue > span{letter-spacing:-0.045em}` DIG:351; RONDA:59 |
| Número médio (22–28 px) | `-0.04em` | `.donutCenter strong` DIG:597; `.compareRatio strong` DIG:1462; `.dailyTitle` DIG:2085 |
| Seção (~22–26 px) | `-.035em` | `.sectionTitle` SCR:450 |
| KV e termos (15–22 px) | `-.03em` | `.kv dd` RONDA:172; `.termText` DIG:1263 |
| Título de card e nome (18–22 px) | `-0.025em` | `.cardTitle` DIG:420; `.profileName` DIG:170 |
| Unidade ao lado do número | `-.02em` | `.metricValue small` RONDA:60 |
| Corpo | `-.01em` | `html,body{letter-spacing:-.01em}` RONDA:18; `--tracking-body: -.01em` FND:82 |
| Badge | `-.005em` | `badge.module.css:39` |
| Mono numérico | `0` / `.02em` | `.concentrationHead strong{letter-spacing:0}` DIG:825; `.pill{letter-spacing:.02em}` RONDA:217 |
| Mono caixa alta 9.5–10 px | `.06em`–`.1em` | `.profileKicker{letter-spacing:0.1em}` DIG:162; `.donutCenter span{0.08em}` DIG:605; `.compareMetricTop span{0.06em}` DIG:1414 |
| Mono caixa alta 11 px (eyebrow) | `.11em` | `.eyebrow{letter-spacing:0.11em}` DIG:74, SCR:440, RONDA:23 |
| Mono caixa alta 11 px (rótulo de KPI) | `.08em` | `.metricTop{letter-spacing:0.08em}` DIG:330 |

Os tokens da fundação são `--tracking-display: -.03em; --tracking-body: -.01em;` (FND:82).

### 1.5 Line-height

| Valor | Uso |
|---|---|
| `1` | Números do donut e da razão (DIG:598, DIG:1463) |
| `1.01` | Manchete (DIG:86) |
| `1.05` | KPI na Ronda (RONDA:59) |
| `1.1` | Nome, título diário (DIG:171, DIG:2086); `--leading-display: 1.1` (FND:83) |
| `1.25` | Título de card (DIG:421) |
| `1.4` | Eyebrow, subtítulo, corpo base (DIG:75, DIG:429); `--leading-body: 1.4` (FND:83) |
| `1.45` | Notas e rodapés (DIG:358, DIG:450) |
| `1.5`–`1.55` | Callouts, insights, lede (DIG:900, DIG:95) |
| `1.6`–`1.62` | Prosa e callout editorial (RONDA:195, RONDA:212) |

### 1.6 Eyebrow e rótulos: a receita canônica

```css
.eyebrow{margin:0;color:var(--text-muted);font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:.11em;line-height:1.4;text-transform:uppercase}
```
(RONDA:23, idêntica em DIG:68-77 e SCR:434-443)

Há quatro variações:
- **Rótulo de KPI.** Usa `--text-secondary` em vez de muted, com `.08em` (DIG:322-332).
- **Kicker.** É 10 px, `.1em`, peso 500 (DIG:157-164).
- **Cabeçalho de tabela e `dt`.** É 9.5 px, `.07em`–`.08em`, peso 400 ou 500 (RONDA:89, RONDA:154).
- **Rótulo de destaque.** Usa `color: var(--accent-strong)` (DIG:778-785). Na passada editorial, volta a `--text-muted` (RONDA:216).

O conteúdo dos rótulos segue um padrão: frases curtas com `·` como separador, por exemplo `Ronda diária · presença digital · 20 nov 2026` (RONDA:266).

### 1.7 Números

- **`font-variant-numeric: tabular-nums` aparece em todo número que se alinha ou muda.** Exemplos: `.networkValue` DIG:535, `.postValue` DIG:766, `.metricValue` RONDA:59, `.shift td` RONDA:156, `.badge` (badge.module.css:38), `.counter` (animated-counter.module.css:1).
- **Os números grandes são Sans Display, não Mono.** A receita é peso 500, tracking negativo forte e line-height ~1.
- **A unidade fica pequena e apagada ao lado do número.** `.metricValue small{font-size:.95rem;letter-spacing:-.02em;color:var(--text-muted);margin-left:6px}` (RONDA:60). No HTML: `75,8%<small>+11,9 p.p.</small>` (RONDA:270). Em linhas, a unidade vai em mono 10 px: `.postVal .unit{color:var(--text-muted);font-family:var(--mono);font-size:10px;font-weight:400}` (RONDA:235).
- **O sub-valor vai embaixo do número.** `.num small{display:block;color:var(--text-muted);font-family:var(--mono);font-size:10px;font-weight:400}` (RONDA:98).
- **O contador no app é animado.** O `AnimatedCounter` (Arc) faz cada dígito girar como roda: `font-size: var(--text-3xl); letter-spacing: var(--tracking-display); line-height: 1; font-variant-numeric: tabular-nums;`, com borda esmaecida `--feather: .16em` e uma máscara em gradiente (animated-counter.module.css:1-6).
- **O formato numérico é pt-BR.** Exemplos: `1.815.723`, `75,8%`, `26,5 mil` e `−108`, com sinal de menos tipográfico.

---

## 2. Cor

### 2.1 Neutros: o sistema é acromático

Todos os neutros têm croma zero em OKLCH (`FND:3-14`). Os hex abaixo são aproximações sRGB calculadas nesta nota.

| Token | Valor literal | ≈ hex |
|---|---|---|
| `--neutral-0` | `oklch(100% 0 0)` | `#ffffff` |
| `--neutral-1` | `oklch(99% 0 0)` | `#fcfcfc` |
| `--neutral-2` | `oklch(97.8% 0 0)` | `#f8f8f8` |
| `--neutral-3` | `oklch(95.8% 0 0)` | `#f1f1f1` |
| `--neutral-4` | `oklch(91.5% 0 0)` | `#e3e3e3` |
| `--neutral-5` | `oklch(84% 0 0)` | `#cacaca` |
| `--neutral-6` | `oklch(72% 0 0)` | `#a4a4a4` |
| `--neutral-7` | `oklch(59% 0 0)` | `#7d7d7d` |
| `--neutral-8` | `oklch(46% 0 0)` | `#585858` |
| `--neutral-9` | `oklch(34% 0 0)` | `#383838` |
| `--neutral-10` | `oklch(23% 0 0)` | `#1d1d1d` |
| `--neutral-11` | `oklch(15% 0 0)` | `#0b0b0b` |

### 2.2 Papéis semânticos (claro)

| Papel | Órbita (FND) | Ronda | ≈ hex |
|---|---|---|---|
| `--background` | `var(--neutral-0)` (FND:15) | `oklch(98.4% 0 0)` (RONDA:7) | `#ffffff` / **`#fafafa`** |
| `--surface` (card) | `var(--neutral-0)` | `var(--neutral-0)` | `#ffffff` |
| `--surface-muted` (trilho e hover) | `var(--neutral-2)` | `var(--neutral-2)` | `#f8f8f8` |
| `--foreground` (tinta) | `var(--neutral-11)` | idem | `#0b0b0b` |
| `--text-secondary` | `var(--neutral-8)` | idem | `#585858` |
| `--text-muted` | `var(--neutral-7)` | idem | `#7d7d7d` |
| `--border` | `oklch(93.5% 0 0)` | idem | `#e9e9e9` |
| `--border-subtle` (divisórias internas) | `oklch(96.5% 0 0)` | idem | `#f3f3f3` |
| `--border-strong` (neutro de dado e hover) | `oklch(82% 0 0)` | idem | `#c4c4c4` |

Na prática, a tinta tem **três níveis**: 15%, 46% e 59%. As bordas também têm três: 96.5% para linhas entre itens, 93.5% para contorno de card e 82% para ênfase ou dado "sem posição".

### 2.3 Acento violeta

O acento entra só como `data-accent="violet"`, nas linhas FND:142 e FND:150, e nos valores literais da Ronda (RONDA:9):

| Token | Claro | Escuro |
|---|---|---|
| `--accent` | `#7747ff` (≈ `oklch(56.7% .253 287.3)`) | `#a78bff` (≈ `oklch(71.2% .166 292.8)`) |
| `--accent-strong` | `#5528ce` | `#c7b7ff` |
| `--accent-subtle` | `rgb(119 71 255 / .13)` | `rgb(119 71 255 / .22)` |
| `--control-on` | `#7747ff` (FND:161) | `#8a66ff` (FND:169) |

**O violeta quase nunca é tinta de texto. Ele marca três coisas:**
1. **O sujeito.** A linha de Tereza no comparativo usa `.cmpRow.lead{…background:color-mix(in oklab,var(--accent) 5%,var(--surface-muted))}` (RONDA:186), e a barra dela é `.cmpM .bar>i{background:var(--accent)}` (RONDA:192).
2. **A seleção.** O item ativo da navegação usa `background: var(--accent-subtle); color: var(--accent-strong);` (SCR:226-229).
3. **Uma atmosfera mínima.** O hero recebe `radial-gradient(70% 130% at 100% 0%, color-mix(in oklab, var(--accent) 10%, transparent), transparent 62%)` e dois anéis de 1 px com `color-mix(in oklab, var(--accent) 11%, transparent)` e `7%` (DIG:20-57).

O ícone do KPI fica num círculo de 26 px com `background: var(--accent-subtle); color: var(--accent-strong)` (DIG:334-343).

### 2.4 Cores semânticas: o significado é para o sujeito

A família "tone" é pastel e fria, com luminosidade ~50% no claro para atingir AA sobre a própria tinta (FND:44-57):

| Tom | Claro | ≈ hex | Escuro (FND:119-125) | ≈ hex |
|---|---|---|---|---|
| teal | `oklch(50% .095 182)` | `#007467` | `oklch(79% .13 182)` | `#37d5c1` |
| sky | `oklch(51% .11 240)` | `#136d9e` | `oklch(79% .095 236)` | `#7cc4f0` |
| orchid | `oklch(52% .17 322)` | `#943fa2` | `oklch(76% .15 322)` | `#dd8fe9` |
| violet | `oklch(51% .16 290)` | `#6850b9` | `oklch(74% .125 290)` | `#aa9df4` |
| rose | `oklch(53% .18 10)` | `#bb2c54` | `oklch(71% .155 8)` | `#f0738f` |
| amber | `oklch(55% .12 68)` | `#9f6202` | `oklch(83% .12 78)` | `#f2bd68` |
| green | `oklch(50% .12 162)` | `#00774d` | `oklch(79% .14 162)` | `#55d69f` |

O mapeamento é `--success: var(--tone-green); --warning: var(--tone-amber); --danger: var(--tone-rose); --info: var(--tone-sky);` (FND:54-57; RONDA:11).

Há uma regra fina aqui. **A cor mostra o efeito sobre o sujeito, não a direção do número.** Na Ronda, `.up{color:var(--danger)}.down{color:var(--success)}` (RONDA:83): quando a rejeição sobe, o texto fica vermelho. O trio "a favor / contra / sem posição" é sempre `--success / --danger / --border-strong`; o neutro é cinza, nunca uma terceira cor (DIG:572-582; RONDA:82).

A fundação também documenta como tingir: misturar sempre em OKLab. Diz o comentário: `Tint them with color-mix(in oklab, …), never oklch` (FND:44-45); `All mixes run in oklab: oklch tints turn pink after the production build` (badge.module.css:7). As fórmulas de badge são `--badge-tint: 10%` no claro e `12%` no escuro, `--badge-ink: 84%` no claro e `94%` no escuro (badge.module.css:11-14, 47).

### 2.5 Cores de dados

- **Redes na Ronda (cores de marca).** `--net-instagram:#d6249f;--net-x:#111111;--net-facebook:#1877f2;--net-tiktok:#00a3a3;--net-youtube:#e62117` (RONDA:16). A cor aparece só no ícone, no tile (`color-mix(in oklab,var(--net) 8%,var(--surface))` com borda de 16%, RONDA:90) e na barra.
- **Redes no app (séries derivadas do acento).** `networkColor`: Instagram → `var(--series-2)`, Facebook → `var(--series-1)`, TikTok → `var(--series-4)`, YouTube → `var(--series-3)`, X → `var(--foreground)` (`MON/src/service/digital/data.ts:314-326`). As séries giram o matiz do acento (FND:177-196). Os comentários dizem que o conjunto foi validado em "CVD ΔE 9 and normal vision ΔE 17". O fallback sem cor relativa é `--series-1: #1f7dcf; --series-2: #7128a5; --series-3: #e58f00; --series-4: #009e84` no claro e `#55adff, #9c37be, #e66e00, #00a861` no escuro (FND:181-182). Com acento violeta, o cálculo desta nota dá aproximadamente s1 `#7747ff`, s2 `#96036e`, s3 `#a6a900` e s4 `#008cc9`. É uma aproximação: o navegador aplica gamut mapping.
- **Divergente em dois tons.** Verde à esquerda e rosa à direita, com 1 px de folga (DIG:966-987).
- **Base de comparação.** Usa `color-mix(in oklab,var(--text-muted) 45%,var(--surface))`, um cinza claro (RONDA:163). O "tom de apelo" usa `color-mix(in oklab,var(--danger) 35%,var(--surface))`, um rosa lavado (RONDA:298). **Intensidades da mesma cor substituem novas cores.**
- **Sparkline.** O total vai em `color-mix(in oklab,var(--accent) 30%,var(--surface))` e o subconjunto em `var(--accent)` sólido, encaixado dentro da mesma coluna (RONDA:174-175).

### 2.6 Variante escura (definida, não publicada)

Fonte: FND:93-139.

| Token | Valor | ≈ hex |
|---|---|---|
| `--background` | `oklch(19% 0 0)` | `#141414` |
| `--surface` | `oklch(21.5% 0 0)` | `#191919` |
| `--surface-raised` | `oklch(24% 0 0)` | `#1f1f1f` |
| `--surface-muted` | `oklch(26% 0 0)` | `#242424` |
| `--foreground` | `oklch(96% 0 0)` | `#f2f2f2` |
| `--text-secondary` | `oklch(77% 0 0)` | `#b4b4b4` |
| `--text-muted` | `oklch(64% 0 0)` | `#8c8c8c` |
| `--border` | `oklch(29% 0 0)` | `#2b2b2b` |
| `--border-subtle` | `oklch(25% 0 0)` | `#222222` |
| `--border-strong` | `oklch(40% 0 0)` | `#484848` |
| `--shadow-resting` | `0 1px 2px oklch(0% 0 0 / .18)` | — |
| `--shadow-raised` | `0 8px 22px oklch(0% 0 0 / .22)` | — |
| `--shadow-floating` | `0 22px 55px oklch(0% 0 0 / .34)` | — |

O escuro **não é preto**. O fundo fica em 19% e as camadas sobem em passos de ~2,5 pontos de L. **O texto também não é branco puro: fica em 96%.**

### 2.7 Gradiente de marca (Arc; não usado no Digital)

`--arc-gradient-from: oklch(90% .045 300); --arc-gradient-to: oklch(92% .045 65);` resulta em lavanda → pêssego (`#e2d8f8` → `#fadfc6`). Há variantes `-soft`, `-line` e `-ink` (FND:61-71). Fica registrado como recurso disponível; **o Digital não o usa**.

---

## 3. Espaço, grade, raios, bordas e sombras

### 3.1 Escala de espaço

O token é `--space-1: .25rem; --space-2: .5rem; --space-3: .75rem; --space-4: 1rem; --space-5: 1.25rem; --space-6: 1.5rem; --space-8: 2rem; --space-10: 2.5rem; --space-12: 3rem; --space-16: 4rem; --space-20: 5rem; --space-24: 6rem;` (FND:72-73).

Os componentes usam literais numa grade de 2 px para micro-ajuste e de 4 px para estrutura:

- **Micro:** `1px` (gap de barra divergente), `2px` (gap de stack), `3px` (padding-top do índice), `5px`, `6px`, `7px`, `8px`.
- **Linhas:** padding `7px 0` (tema), `8px 0` (rede), `9px 0` ou `9px 8px` (post), `12px 0` (comparativo), `6px 0` (tabela externa).
- **Cards:** padding `24px` (RONDA:65), `clamp(20px, 2.1vw, 26px)` (DIG:374), `18px` no diário (DIG:2114) e `16px` no PDF (DIG:2153).
- **Cabeçalho de card:** `margin-bottom:16px` (RONDA:67), 18 px no app e 12 px no diário.
- **Entre blocos internos:** `margin-top:16px; padding:14px 0 0` com divisória acima (RONDA:213).

### 3.2 Grade

| Elemento | Valor | Fonte |
|---|---|---|
| Página da Ronda | `.page{width:1080px;margin:0 auto;padding:28px 24px 36px;display:grid;gap:18px}` | RONDA:19 |
| Página do app | `max-width: 1200px; padding: 32px clamp(16px, 4vw, 32px) 64px; gap: 24px;` | SCR:378-385 |
| Barra lateral do app | `grid-template-columns: 264px minmax(0, 1fr)`; recolhida `80px` | SCR:101, SCR:246 |
| Grade de cards | `grid-template-columns:repeat(12,minmax(0,1fr));gap:18px` (Ronda) / `20px` (app) / `14px` (diário) | RONDA:64; DIG:363-368; DIG:2113 |
| Larguras | `.wide{grid-column:span 7}.narrow{grid-column:span 5}.full{grid-column:span 12}.half{grid-column:span 6}` | RONDA:66 |
| Diário | `grid-template-columns: minmax(0, 7fr) minmax(0, 5fr); grid-template-areas: "audience sentiment" "posts themes" "posts terms";` | DIG:2122-2134 |
| Hero | `grid-template-columns:minmax(0,1.3fr) minmax(300px,.7fr);gap:44px` | RONDA:25 |
| KPIs | `repeat(3,minmax(0,1fr))` numa única caixa, separados por `border-left:1px solid var(--border)` | RONDA:53-55 |

**A proporção 7/5 é a assinatura da composição:** a leitura principal fica à esquerda, a leitura de apoio à direita, e os blocos de largura total vêm depois.

### 3.3 Raios

| Token ou uso | Valor | px | Fonte |
|---|---|---|---|
| `--radius-control` | `1.125rem` | 18 | FND:75 |
| `--radius-panel` (card) | `1.625rem` | **26** | FND:75 |
| `--radius-surface` | `2.125rem` | 34 | FND:75 |
| `--radius-pill` | `9999px` | — | FND:75 |
| Hero | `calc(var(--radius-panel) + 4px)` | 30 | DIG:19 |
| Comparativo | `calc(var(--radius-panel) + 2px)` | 28 | DIG:1280 |
| Linha em destaque e citação antiga | `16px` | 16 | DIG:1350; RONDA:186 |
| Caixas internas (destaque, termos, facts) | `14px` | 14 | DIG:774, DIG:1194 |
| Thumb, insight, hover de linha | `12px` | 12 | DIG:732, DIG:470 |
| Hover de post, callout | `10px` | 10 | DIG:706, DIG:896 |
| Tile de rede | `9px` (8 px no PDF) | 9 | DIG:485 |
| Badge sm, md e lg | `5px`, `6px` e `7px` | — | badge.module.css:52-54 |
| Topo de barra do sparkline, `code` | `4px 4px 0 0` / `4px` | 4 | RONDA:174, RONDA:264 |
| Trilhos e barras | `999px` | pílula | DIG:516 |

O padrão que se vê: **raios externos grandes e internos ~½ a ⅓ do externo.** O card tem 26, as caixas internas 14–12 e os tiles 9.

### 3.4 Bordas e divisórias

- **Toda borda tem 1 px.** As exceções são intencionais: `border-left:2px solid var(--accent)` no callout antigo (DIG:895), que a passada editorial remove (RONDA:212); `border-left:3px` nas citações antigas, também removido (RONDA:231); `border: 2px dashed var(--align-color)` para posição incerta no painel (SCR:518).
- **Contorno de card:** `1px solid var(--border)` (93.5%).
- **Linhas entre itens:** `border-top:1px solid var(--border-subtle)` (96.5%), com `:first-child{border-top:0}` (RONDA:87-88, 121-122, 139-140).
- **Divisória de KV na Ronda.** É vertical e substitui caixas: `.kv div,.profileFacts div{padding:0 0 0 14px;border:0;border-left:1px solid var(--border);border-radius:0;background:none}` (RONDA:227).
- **Tracejado = provisório.** Aparece em `.pendingBox{…border:1px dashed var(--border-strong)…}` (RONDA:261), `.emptyState{border: 1px dashed var(--border)}` (DIG:1960) e no tracejado de dúvida do hemiciclo.
- **Separador branco entre segmentos:** `.compareBar > span + span { border-left: 1px solid var(--surface); }` (DIG:1447-1449).

### 3.5 Sombras

- **Em repouso a sombra é quase invisível:** `--shadow-resting: 0 1px 2px oklch(0% 0 0 / .035);` (FND:58).
- `--shadow-raised: 0 6px 18px oklch(0% 0 0 / .065), 0 1px 3px oklch(0% 0 0 / .035);` (FND:59). Só o `profileCard`, que flutua sobre o hero, recebe raised em repouso, junto com `backdrop-filter: blur(10px)` e `color-mix(in oklab, var(--surface) 84%, transparent)` (DIG:121-135).
- `--shadow-floating: 0 20px 48px oklch(0% 0 0 / .105), 0 3px 10px oklch(0% 0 0 / .045);` (FND:60) vale para modais e quick look.
- **O hover promove a sombra.** Um card sob o ponteiro passa a `border-color: var(--border-strong); box-shadow: var(--shadow-raised);` (card.module.css:3; SCR:490-495).

**A separação vem da borda; a sombra só dá peso.**

---

## 4. Componentes

### 4.1 Hero editorial

O hero tem três partes:
- **Cópia, à esquerda.** Eyebrow mono, manchete com uma frase de tese, lede com `<strong>` nos números-chave e meta com pontos de 3 px: `.metaDot{width:3px;height:3px;border-radius:50%;background:var(--border-strong)}` (RONDA:34).
- **Cartão de perfil, à direita.** Avatar de 64 px com anel `0 0 0 4px color-mix(in oklab,var(--surface) 68%,transparent)` (RONDA:37), kicker, nome, handle, facts em KV e uma faixa de chips de rede de 29 px.
- **Atmosfera.** Um gradiente radial violeta de 10% e dois anéis de 1 px (DIG:10-57).

**A manchete é uma conclusão, não um rótulo**: "Rejeição volta a 75,8%, e a base aplaude…" (RONDA:266).

### 4.2 Faixa de KPIs

São três KPIs numa caixa única, separados por réguas verticais (RONDA:53-62; DIG:300-359):

```
[ícone 26px em accent-subtle] RÓTULO MONO 11px .08em secondary
75,8%  +11,9 p.p.            ← display 2.45rem/500/-.045em + unidade .95rem muted
era 63,9% em 19/11 · …       ← nota 12px muted, com <b> em foreground
```

O padding é `20px 26px` e o gap interno 8 px. No diário fica em `15px 20px` e gap 4 (DIG:2111).

### 4.3 Cabeçalho de seção numerado ("01 … 07")

```css
.cardHeading{display:flex;align-items:flex-start;gap:10px;min-width:0}
.cardIndex{flex:none;padding-top:3px;color:var(--text-muted);font-family:var(--mono);font-size:10px;font-weight:500}
.cardTitle{margin:0;font-family:var(--font-display);font-size:1.12rem;font-weight:500;letter-spacing:-.025em;line-height:1.25;text-wrap:balance}
.cardSub{margin:3px 0 0;color:var(--text-muted);font-size:var(--text-xs);line-height:1.4}
```
(RONDA:68-71; no app, DIG:398-430 com `.cardIndex{letter-spacing: 0.02em}`)

- **O índice é mono de 10 px, cinza e baixado 3 px para alinhar à altura x do título.** Não há caixa, linha nem cor.
- **O subtítulo diz o recorte**, por exemplo "últimas 24h × 19/11 × diagnóstico 6–18/11", ou já traz a conclusão: "o card da Folha teve a maior rejeição do dia no Facebook (88%)".
- **A legenda fica à direita do cabeçalho.** Usa pontos de 6 px e texto de 11 px muted: `.legend i{display:inline-block;width:6px;height:6px;border-radius:50%}` (RONDA:81).
- **O rodapé de todo card informa fonte e definição.** `.cardFoot{display:flex;justify-content:space-between;gap:12px;margin-top:auto;padding-top:14px;border-top:1px solid var(--border-subtle);color:var(--text-muted);font-size:11px;line-height:1.45}` (RONDA:72). À esquerda vai a origem ou janela; à direita, a definição da métrica ("Interações = curtidas + comentários").

### 4.4 Linhas com barra (ranking e progresso)

**Rede.** A grade é `grid-template-columns:30px minmax(100px,.8fr) minmax(50px,1fr) 88px 92px 128px` (RONDA:240): tile, nome mais participação mono, barra, valor, delta e interações.
- O tile mede `30px`, com raio `9px`, fundo `8%` e borda `16%` da cor da rede (RONDA:90).
- A barra é `.bar{display:block;height:6px;overflow:hidden;border-radius:999px;background:var(--surface-muted)}` com `.bar>i{…border-radius:inherit;background:var(--net,var(--accent))}` (RONDA:95-96).
- O hover da linha no app usa `background: var(--surface-muted)` com raio 12 e margem negativa de 8 px, para que o realce "vaze" além da coluna (DIG:463-477).

**Espessuras de barra encontradas:**

| px | Uso |
|---|---|
| 4 | Tópicos de imprensa (DIG:1111) |
| 5 | Divergente no app (DIG:969); barras gêmeas na Ronda (RONDA:162) |
| 6 | Barra padrão e divergente na Ronda (RONDA:95, 147) |
| 7 | Comparativo (DIG:1426) |
| 9 | Barra de tom da imprensa (DIG:999) |
| 12 | Barra empilhada 100% (RONDA:116) |

**Barra empilhada 100%** (sentimento por período): `.stack{display:flex;height:12px;overflow:hidden;border-radius:999px;gap:2px;background:var(--surface-muted)}`. O rótulo mono de 84 px fica à esquerda e os percentuais em mono 10 px vão embaixo, alinhados às pontas (RONDA:113-118).

**Divergente com marcador de base.** A barra verde vem com raio `999px 0 0 999px` e a rosa com `0 999px 999px 0`, separadas por gap de 1 px. Um traço marca a base anterior: `.themeBar .mk{position:absolute;top:-4px;width:2px;height:14px;border-radius:2px;background:var(--foreground);opacity:.55}` (RONDA:147-150). O rodapé explica: "traço = 6–18/11".

**Barras gêmeas (antes × agora)** ficam dentro de uma tabela: duas barras de 5 px com 3 px de gap, a base em cinza 45% e o atual em `--danger` (RONDA:161-164).

### 4.5 Donut

O SVG é este (RONDA:275):

```html
<svg viewBox="0 0 160 160">
  <circle cx="80" cy="80" r="62" stroke="var(--surface-muted)"/>
  <circle … r="62" pathLength="100" stroke="var(--success)" stroke-dasharray="22.70 77.30" stroke-dashoffset="25.00"/>
  …
</svg>
```

- **Tamanho:** `.donut{position:relative;width:150px;flex:none;aspect-ratio:1}`; `.donut circle{fill:none;stroke-width:18}` (RONDA:101-103). Num viewBox de 160, o anel tem 18 de espessura (11% do diâmetro) e raio 62.
- **Pontas retas.** Não há `stroke-linecap`, então o padrão é `butt`. Os segmentos se encostam sem folga, sobre o trilho `--surface-muted`. A Ronda começa às 12h com `stroke-dashoffset=25`; o app usa `transform="rotate(-90 80 80)"` (`digital-view.tsx:212`).
- **Centro:** `.donutCenter strong{font-family:var(--font-display);font-size:1.7rem;letter-spacing:-.04em;line-height:1}` mais um rótulo mono de 10 px com `.08em` em caixa alta ("CONTRA"). Na Ronda, o número central recebe a cor semântica (`class="r"`).
- **Legenda lateral:** `grid-template-columns:8px minmax(0,1fr) auto 46px`, com ponto de 7 px, rótulo em secondary, contagem tabular e percentual mono de 11 px alinhado à direita (RONDA:108-112).

### 4.6 Tabelas

- **Sem zebra e sem bordas verticais.** Só há `border-top:1px solid var(--border-subtle)` por linha (RONDA:156).
- **O cabeçalho segue o padrão eyebrow.** `.shift th{color:var(--text-muted);font-family:var(--mono);font-size:9.5px;font-weight:500;letter-spacing:.08em;text-transform:uppercase;text-align:right;padding:0 0 8px}` (RONDA:154).
- **O rótulo tem duas linhas.** Nome em 500, mais um `small` de 10.5 px muted com um exemplo literal entre aspas (RONDA:157-158, 292).
- **Valores tabulares alinhados à direita.** O valor atual vai em `<b>` e a variação é um `mult` sem caixa: `.mult,.mult.dn,.mult.eq{padding:0;border-radius:0;background:none;font-size:11px}` (RONDA:219).

### 4.7 Pílulas, badges e chips

- **Antes da passada editorial:** `.pill{display:inline-flex;align-items:center;gap:4px;padding:2px 7px;border-radius:999px;font-family:var(--mono);font-size:10px;font-variant-numeric:tabular-nums}`, com fundo de 10% do tom (RONDA:133-136).
- **Depois da passada editorial, a pílula vira texto mono colorido sem fundo:** `.pill,.pill.r,.pill.g,.pill.n{padding:0;border-radius:0;background:none;font-size:10.5px;letter-spacing:.02em}` (RONDA:217). **Esta é a versão "limpa".**
- **Badge do app (Arc).** Alturas de 20, 24 e 28 px; raio de 5, 6 e 7 px, ou `pill`; `font-size: var(--text-xs); font-weight: 500; line-height: 1`. Recorta a caixa da linha em cap-height com `text-box: trim-both cap alphabetic` (badge.module.css:9-65). No Digital usa-se `<Badge color="violet" size="sm" pill>` (`digital-view.tsx:510`).
- **Chip de rede.** Círculo de 29 px com borda de 1 px e ícone de 14–15 px na cor da rede. No hover sobe 2 px (DIG:188-207).
- **Controle segmentado (Arc).** Trilho `--surface-muted` com borda de 1 px e padding de 3 px. A seleção é uma pastilha `--surface` com `--shadow-resting` que **desliza**; os rótulos nunca mudam de peso nem de escala. O comentário diz: `Items never scale or change weight; only the highlight travels` (segmented-control.module.css:8-12).

### 4.8 Notas, destaques, "Como ler" e rodapé

- **Callout editorial.** Na Ronda é só um parágrafo de 13.5 px em secondary, com `<strong>` em foreground e nenhuma caixa (RONDA:212). Fica logo abaixo do cabeçalho e **resume o card antes do gráfico**.
- **Insight e destaque.** Ficam ao pé do conteúdo, separados por régua: `display:block;margin-top:16px;padding:14px 0 0;border:0;border-top:1px solid var(--border-subtle)` (RONDA:213). O rótulo é mono de 10 px, `.1em`, caixa alta, muted ("DESTAQUE", RONDA:216). Um insight pode abrir com `<strong>Alerta.</strong>` (RONDA:306).
- **"Como ler".** Um bloco final só de texto: `.method{padding:16px 2px 0;border:0;border-top:1px solid var(--border);border-radius:0;font-size:11px}` com cor muted (RONDA:206-207, 221). Abre com `<strong>Como ler.</strong>` e explica a janela, as contagens, a régua de classificação e o que não é comparável (RONDA:320).
- **Rodapé do documento:** `.foot{display:flex;justify-content:space-between;color:var(--text-muted);font-family:var(--mono);font-size:10px;letter-spacing:.06em;text-transform:uppercase;padding:2px 4px}` (RONDA:208). À esquerda vai o sujeito e o produto; à direita, a janela e a data de emissão.
- **Pendência:** `.pendingBox{…border:1px dashed var(--border-strong);border-radius:var(--radius-control);background:var(--surface-muted)}` com selo mono violeta (RONDA:261-263).
- **Metodologia no app.** É um bloco `--surface-muted` com grade de 3 colunas de `dt` mono e `dd` de 12 px (DIG:1507-1567).

### 4.9 Citações (voz humana)

```css
.q{margin:0;padding:18px 0 20px;border:0;border-top:1px solid var(--border-subtle);border-radius:0;background:none;break-inside:avoid}
.q blockquote{margin:0;font-family:var(--serif);font-size:17px;line-height:1.45;letter-spacing:-.005em;color:var(--foreground);text-wrap:pretty;hanging-punctuation:first}
.q blockquote{text-indent:-.4em}
.q figcaption{display:flex;align-items:center;gap:7px;margin-top:10px;color:var(--text-muted);font-family:var(--mono);font-size:10px;letter-spacing:.04em}
```
(RONDA:223-233)

As citações ficam em duas colunas com `column-gap:44px` (RONDA:222). As aspas são pendentes, com `text-indent:-.4em`. **O lado da citação aparece só como um ponto de 6 px na legenda; a faixa lateral colorida foi removida.**

### 4.10 Gráfico de barras verticais (sparkline)

```css
.spark{display:flex;align-items:flex-end;gap:4px;height:64px;margin:6px 0 4px}
.spark i{flex:1;border-radius:4px 4px 0 0;background:color-mix(in oklab,var(--accent) 30%,var(--surface));position:relative}
.spark i b{position:absolute;inset:auto 0 0 0;border-radius:4px 4px 0 0;background:var(--accent)}
.sparkLbl{display:flex;gap:4px;color:var(--text-muted);font-family:var(--mono);font-size:9px}
```
(RONDA:173-177)

- **Não há eixo Y, linhas de grade nem valores nas barras.**
- **Só o topo é arredondado**, em 4 px.
- **O subconjunto fica sobreposto dentro da barra total**, e não ao lado dela.
- **A legenda está no próprio eyebrow:** "Menções por edição · roxo = citam Tereza" (RONDA:302).

### 4.11 Regras gerais de gráfico

1. **Não há eixos nem linhas de grade.** A escala é o próprio trilho `--surface-muted`, ou não existe.
2. **As barras são finas (4–12 px) e têm pontas em pílula.** Os segmentos se separam por gaps de 1–2 px ou por uma linha da cor da superfície.
3. **Os rótulos são diretos.** Os números ficam ao lado da barra em tabular ou mono, e as legendas usam pontos de 6–7 px.
4. **A cor é semântica ou de identidade, nunca decorativa.** Neutro é cinza, e intensidades da mesma cor substituem novas cores.
5. **A base histórica aparece como traço ou barra gêmea cinza**, sempre explicada no rodapé.

---

## 5. Movimento

### 5.1 Tokens

Os tokens CSS ficam em FND:84-90:

```css
--ease-enter: cubic-bezier(.16,1,.3,1);
--ease-standard: cubic-bezier(.22,1,.36,1);
--ease-exit: cubic-bezier(.7,0,.84,0);
--ease-in-out: cubic-bezier(.65,0,.35,1);
--ease-spring: linear(0, 0.0213, 0.0739, …, 0.9963, 1);   /* mola criticamente amortecida, sem overshoot */
--duration-instant: 120ms; --duration-fast: 160ms; --duration-standard: 240ms; --duration-considered: 480ms; --duration-spring: 580ms;
```

Os mesmos valores aparecem em JS para Motion em `MOT:2-24`:

```ts
duration: { instant: 0.12, fast: 0.16, exit: 0.18, standard: 0.24, considered: 0.48 },
ease: { enter: [0.16, 1, 0.3, 1], exit: [0.7, 0, 0.84, 0], standard: [0.22, 1, 0.36, 1], inOut: [0.65, 0, 0.35, 1] },
spring: {
  responsive: { type: "spring", stiffness: 520, damping: 44 },
  gentle: { type: "spring", stiffness: 340, damping: 34 },
  snappy: { type: "spring", visualDuration: 0.26, bounce: 0 },   // pressões, toggles, indicadores
  smooth: { type: "spring", visualDuration: 0.4, bounce: 0 },    // painéis, altura, layout
  morph:  { type: "spring", visualDuration: 0.42, bounce: 0 },   // morfologia, destaque compartilhado
},
stagger: { char: 0.016, word: 0.04, line: 0.08, item: 0.035 },   // "Keep total stagger under roughly 0.4s"
blur: { subtle: 2, soft: 4, text: 8 },
```

O laboratório antigo usava `--ease: cubic-bezier(0.2, 0.7, 0.2, 1)` e transições de `0.18s` em cor e borda e de `0.25s var(--ease)` em transform (`MON/src/design/tokens.css:29, 94-99`).

### 5.2 Onde o movimento aparece

| Efeito | Valor | Fonte |
|---|---|---|
| Barra entrando | `animation: bar-in 0.7s var(--ease-enter) both;` com `@keyframes bar-in { from { transform: scaleX(0); } to { transform: scaleX(1); } }` e `transform-origin: left` | DIG:526-527, DIG:1853-1860 |
| Barra mudando de valor | `transition: width 0.5s var(--ease-spring);` | DIG:528 |
| Barra do comparativo | `animation: bar-in 0.8s var(--ease-enter) both;` | DIG:1438 |
| Ranking reordenando | `motion.li layout` com `motionTokens.spring.smooth` | `digital-view.tsx:657-661` |
| Contador | Cada dígito gira com `spring.smooth` e revelação `{ ...smooth, visualDuration: 0.48 }`; os símbolos usam `spring.morph` | `animated-counter.tsx:21, 58, 61` |
| Texto trocando | `rise`: `opacity 0, y "0.3em", blur(4px)` → `1, 0, blur(0)` em 0.24 s `enter`; saída `y "-0.3em", blur(2px)` em 0.16 s `standard` | `animated-counter.tsx:19` |
| Hover de chip | `transform var(--duration-fast) var(--ease-enter)` + `translateY(-2px)` | DIG:197-206 |
| Hover de card ou cor | `var(--duration-fast)` / `var(--duration-standard)` com `--ease-standard` | card.module.css:1 |
| Tooltip | Entra de `translateY(3px) scale(.97)` em 160 ms `enter`; sai `scale(.98)` em 120 ms | tooltip.module.css:1-11 |
| Onda do hemiciclo | `x: "-70%" → "0%"` em 0.24 s `enter`, com atraso `order × (0.035/6)` | `app.tsx:223-245` |
| Barra lateral recolhendo | `grid-template-columns var(--duration-standard, 0.24s) var(--ease-enter, ease)` | SCR:107 |
| Movimento reduzido | Desliga animações e transições das barras; os componentes caem para `--duration-instant` | DIG:1862-1872; badge.module.css:102-104 |

**Doutrina:** entrar rápido e assentar devagar (`enter` = expo-out). **Nunca há overshoot**: todas as molas têm `bounce: 0`. Os blurs são de no máximo 8 px e breves. Pressões e indicadores levam 0,26 s, painéis 0,4 s. Nada que já está na tela pisca ou chama atenção sem motivo.

---

## 6. Princípios inferidos: por que parece "extremamente limpo"

1. **Uma base acromática; a cor é exceção e tem significado.** Os 12 neutros têm croma 0. O violeta marca o sujeito e a seleção; verde e rosa marcam efeito sobre o sujeito; a cor de rede marca identidade. Nada é colorido por decoração.
2. **Dois pesos e três tintas.** Os pesos são 400 e 500; as tintas, 15%, 46% e 59%. A hierarquia vem do tamanho e do tracking. Sem bold, a página não "grita".
3. **Três vozes tipográficas com papéis fixos.** O Sans traz o conteúdo, o Mono em caixa alta rotula ou mede, e o Serif aparece só quando uma pessoa fala. O leitor sabe o que é dado, o que é rótulo e o que é citação sem ler.
4. **Dois registros de escala.** O micro vai de 9 a 14 px (rótulos, linhas e notas) e o display de 39 a 58 px (manchete e KPIs). Quase nada fica no meio. O contraste de escala faz o trabalho que outros sistemas fazem com cor ou caixa.
5. **A borda separa, a sombra não.** A borda tem 1 px a 93.5% de L, e a sombra em repouso tem opacidade .035. As divisórias internas a 96.5% quase somem.
6. **A passada editorial: menos caixas.** A Ronda decide explicitamente "no tinted boxes, no side stripes, no chips" (RONDA:211). Callouts viram parágrafos, pílulas viram texto mono colorido, caixas de KV viram colunas com régua vertical, e citações perdem fundo e faixa. **Cada container a menos é ruído a menos.**
7. **Todo bloco tem a mesma anatomia:** índice, título, recorte ou conclusão, resumo em prosa, gráfico, nota e rodapé com fonte e definição. A previsibilidade faz a densidade parecer calma.
8. **Os números nunca aparecem sozinhos.** Cada número grande vem com a unidade em muted e uma linha de contexto ("era 63,9% em 19/11"). A comparação é estrutural: janela atual × ontem × base.
9. **Gráficos mínimos e honestos.** Não há eixos, grades nem 3D. As barras são finas com trilho, os rótulos diretos, e a base histórica aparece como traço. O método é explicitado em "Como ler".
10. **Densidade controlada por grade.** São 1080 px, 12 colunas em 7/5 e gaps de 18 px. Os tamanhos das linhas são fixos (`88px 92px 128px`) e os textos usam `white-space:nowrap` para não quebrar em lugares feios (RONDA:245-255).
11. **Os títulos afirmam.** A manchete e os subtítulos trazem a conclusão, não o nome da seção.
12. **O movimento é discreto e físico.** As barras crescem da esquerda, os números giram, nada quica, e tudo desliga com movimento reduzido.

---

## 7. Tradução para o Timbre (macOS, SwiftUI, notch preto)

O Timbre tem três superfícies, e cada token precisa de três valores: **Claro** (janelas e ajustes), **Escuro** (janelas no modo escuro do sistema) e **Notch**, uma superfície sempre preta que se funde ao recorte físico e aparece mesmo com o sistema no modo claro.

### 7.1 Unidades

- **1 px CSS = 1 pt AppKit/SwiftUI.** Em Retina, os dois equivalem a 2 pixels físicos. A borda de 1 px vira **1 pt**. A divisória `--border-subtle` pode ir a **0,5 pt** (`1 / displayScale`) dentro do notch, onde tudo é menor.
- **Tracking.** O `.tracking()` do SwiftUI usa pontos, não em: `tracking_pt = em × tamanho`. Exemplos: eyebrow 11 pt × 0,11 = **1,21 pt**; KPI 39 pt × −0,045 = **−1,76 pt**; manchete 46 pt × −0,05 = **−2,3 pt**.
- **Line-height.** Use `.lineSpacing((lh − 1) × tamanho)` como aproximação, porque o SwiftUI já aplica o leading da fonte. Para números em display com lh 1, use `.lineSpacing(0)` e meça.
- **Cor.** O sistema nasce em OKLCH. Para manter a fidelidade, guarde as cores no Asset Catalog com os hex acima (sRGB) ou calcule-as em Display P3 a partir do OKLCH. O violeta `#7747ff` está dentro do sRGB; os tons pastel escuros também.
- **`color-mix(in oklab, …)`.** Implemente um `Color.mix(_:_:in: .oklab)` próprio (OKLab ↔ sRGB linear, ~30 linhas) ou pré-calcule as misturas usadas. Misturar em RGB deixa as tintas acinzentadas, e a própria fundação avisa que misturar em OKLCH puxa para o rosa.

### 7.2 Tipografia

**Recomendação: embarcar Geist, Geist Mono e Geist Serif (OFL).** Use instâncias estáticas (Regular 400, Medium 500, Mono Regular e Medium, Serif Regular) registradas com `ATSApplicationFontsPath` ou `CTFontManagerRegisterFontsForURL`. O peso de fontes variáveis com `Font.custom` é menos previsível.

- **Alternativa sem dependência:** SF Pro e SF Mono com `.fontDesign(.monospaced)`. **Atenção:** o SF aplica tracking óptico automático por tamanho, e o Geist não. Com SF, **reduza os trackings negativos de display à metade** e confira visualmente.
- `tabular-nums` → `.monospacedDigit()`.
- `text-transform:uppercase` → `.textCase(.uppercase)`.
- **Números que mudam** (volume, dB, taxa de amostragem) → `.contentTransition(.numericText(value:))` + `.monospacedDigit()`. É o equivalente nativo do `AnimatedCounter`.

Escala proposta (pt):

| Token Timbre | Fonte | Tamanho | Peso | Tracking (pt) | Uso | Origem |
|---|---|---|---|---|---|---|
| `label.micro` | Geist Mono | 9 | 400 | +0,7 (≈.08em) | Eixo de EQ (Hz), horas | `.sparkLbl`, `.netHead` |
| `label.eyebrow` | Geist Mono | 10–11 | 500 | +1,1 / +1,21 (.11em) | Eyebrow em caixa alta | `.eyebrow` |
| `label.index` | Geist Mono | 10 | 500 | +0,2 | "01", "02" | `.cardIndex` |
| `value.mono` | Geist Mono | 10,5–11 | 400 | +0,2 | %, dB, unidade | `.pill`, `.share` |
| `text.caption` | Geist | 11 | 400 | −0,11 | Rodapé e notas | `.cardFoot` |
| `text.small` | Geist | 12 | 400/500 | −0,12 | Subtítulo, linha secundária | `--text-xs` |
| `text.body` | Geist | 13–14 | 400/500 | −0,14 | Nome de app, faixa, linhas | `--text-sm` |
| `title.card` | Geist | 17–18 | 500 | −0,45 (−.025em) | Título de painel | `.cardTitle` |
| `value.medium` | Geist | 22–27 | 500 | −0,9 / −1,1 (−.04em) | Centro de anel, valor de dial | `.donutCenter` |
| `value.display` | Geist | 34–39 | 500 | −1,6 / −1,76 (−.045em) | KPI, volume grande | `.metricValue` |
| `title.hero` | Geist | 44–46 | 500 | −2,3 (−.05em) | Só em janelas grandes (onboarding) | `.heroTitle` |
| `quote` | Geist Serif | 15–17 | 400 | −0,08 | Letra da música, citação | `.q blockquote` |

**No notch fechado** só cabem `label.eyebrow`, `value.mono` e `text.small`. **No notch expandido**, o máximo é `value.display` reduzido a 28–34 pt. O registro display de 39+ pt fica reservado a janelas.

### 7.3 Cor: três superfícies

Os tokens semânticos são os mesmos nas três; muda só o valor.

| Token | Claro | Escuro | Notch (sempre preto) | Racional |
|---|---|---|---|---|
| `bg.canvas` | `#fafafa` (98.4%, Ronda) | `#141414` (19%) | **`#000000`** | O notch precisa ser preto absoluto para fundir com o recorte físico |
| `bg.surface` (card) | `#ffffff` | `#191919` (21.5%) | `#000000` (sem card: o notch é o card) | No notch, as camadas se criam por linha e tinta, não por caixa |
| `bg.raised` (popover) | `#ffffff` + sombra raised | `#1f1f1f` (24%) | `white 7%` ≈ `#121212` | Só para submenus dentro do notch |
| `bg.track` (`--surface-muted`) | `#f8f8f8` | `#242424` (26%) | `white 12%` ≈ `#1f1f1f` | Trilho de barra, slider e anel |
| `ink.primary` | `#0b0b0b` (15%) | `#f2f2f2` (96%) | `#f2f2f2` | Nunca branco puro |
| `ink.secondary` | `#585858` (46%) | `#b4b4b4` (77%) | `#b4b4b4` | |
| `ink.muted` | `#7d7d7d` (59%) | `#8c8c8c` (64%) | `#7a7a7a` (~57%) | Sobre preto absoluto, 64% fica brilhante demais para rótulo; baixar ~7 pontos mantém a hierarquia |
| `line.default` | `#e9e9e9` (93.5%) | `#2b2b2b` (29%) | `white 11%` ≈ `#1c1c1c` | |
| `line.subtle` | `#f3f3f3` (96.5%) | `#222222` (25%) | `white 7%` ≈ `#121212` | Divisórias de linha |
| `line.strong` / `data.neutral` | `#c4c4c4` (82%) | `#484848` (40%) | `white 28%` ≈ `#484848` | Dado neutro, hover |
| `accent` | `#7747ff` | `#a78bff` | `#a78bff` | Violeta da Órbita |
| `accent.strong` | `#5528ce` | `#c7b7ff` | `#c7b7ff` | Texto e ícone ativo |
| `accent.subtle` | `rgb(119 71 255 / .13)` | `rgb(119 71 255 / .22)` | `rgb(119 71 255 / .26)` | Fundo de seleção |
| `positive` | `#00774d` | `#55d69f` | `#55d69f` | `--tone-green` |
| `negative` | `#bb2c54` | `#f0738f` | `#f0738f` | `--tone-rose` (clipping e saturação) |
| `warning` | `#9f6202` | `#f2bd68` | `#f2bd68` | `--tone-amber` (headroom baixo) |
| `info` | `#136d9e` | `#7cc4f0` | `#7cc4f0` | `--tone-sky` |

**Paleta categórica de dados.** Use os sete tons, na ordem violet, teal, amber, sky, orchid, green e rose, cada um com o par claro/escuro da §2.4. No notch, use sempre o valor escuro.

**Semântica para o Timbre (mesma regra da Ronda: a cor mostra o efeito sobre o ouvinte, não a direção do número):**
- **Ganho positivo do EQ não é "verde".** O acento marca a curva do usuário e o cinza (`data.neutral`) marca a curva de referência ou o alvo.
- **Rosa fica reservado a problemas reais:** clipping, latência acima do limite, perda de bit-perfect.
- **Verde só para estados bons verificáveis**, como bit-perfect ativo ou taxa casada.
- **Identidade de app ou dispositivo** pode usar a cor do ícone do app, sempre tingida a 8% no tile e a 16% na borda, como no `.netTile`.

### 7.4 Espaço, raios, bordas e sombras

| Token | Valor (pt) | Origem |
|---|---|---|
| `space` | 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 32 | Literais de DIG e RONDA; `--space-*` |
| `pad.panel` | 24 (janela), 16–18 (notch expandido), 10–12 (notch fechado) | `.card` 24, diário 18, PDF 16 |
| `gap.grid` | 18 (janela), 12–14 (notch) | `.grid` 18; diário 14 |
| `row.height` | Linhas com padding vertical de 7–9 pt; 44 pt para alvos clicáveis | `.themeRow`, `.netRow`, `.group a{min-height:44px}` SCR:201 |
| `radius.panel` | 26 (janela) | `--radius-panel` |
| `radius.surface` | 34 (sheet, quick look) | `--radius-surface` |
| `radius.control` | 18 (botão, segmentado) | `--radius-control` |
| `radius.inner` | 14 / 12 | Caixas internas e thumbs |
| `radius.tile` | 9 | `.netTile` |
| `radius.bar` | Capsule | Trilhos de 999px |
| `stroke.hairline` | 1 pt (janela), 0,5 pt (notch) | `border: 1px` |
| `shadow.resting` | `.shadow(color: .black.opacity(0.035), radius: 1, x: 0, y: 1)` | `0 1px 2px` (o raio do SwiftUI ≈ metade do blur CSS) |
| `shadow.raised` | `.shadow(.black.opacity(0.065), radius: 9, y: 6)` + `.shadow(.black.opacity(0.035), radius: 1.5, y: 1)` | `--shadow-raised` |
| `shadow.floating` | `.shadow(.black.opacity(0.105), radius: 24, y: 20)` + `.shadow(.black.opacity(0.045), radius: 5, y: 3)` | `--shadow-floating` |

- **Use `RoundedRectangle(cornerRadius:, style: .continuous)`.** A curva contínua parece menor que o círculo do CSS com o mesmo raio. Para manter a percepção, aumente ~8–10% (26 → 28) ou aceite o visual mais "Apple". É uma decisão de design system a registrar.
- **No notch, nenhuma sombra interna.** Sobre preto absoluto, sombra não aparece e só gasta GPU. A separação vem de `line.subtle` e da tinta. A sombra fica para a borda inferior do notch expandido sobre o desktop (`shadow.floating` no escuro: `0 22px 55px / .34`).
- **O raio inferior do notch expandido deve casar com o do recorte físico.** O raio de hardware não é documentado. Obtenha a geometria por `NSScreen.safeAreaInsets.top`, `auxiliaryTopLeftArea` e `auxiliaryTopRightArea` e calibre visualmente. Para o painel expandido, parta de `radius.panel` (26) e ajuste até a curva continuar a do recorte.

### 7.5 Componentes: de/para

| Órbita / Ronda | Timbre (SwiftUI) |
|---|---|
| Faixa de 3 KPIs numa caixa com réguas verticais | Notch expandido: **Volume · Saída · Formato** (ex. "−12 dB", "AirPods Pro", "24/96"), em `HStack(spacing: 0)` com `Divider` de 1 pt entre colunas. Rótulo `label.eyebrow`, número `value.display` com `.contentTransition(.numericText())` e unidade em `ink.muted` |
| Cabeçalho numerado `01 Título / sub` | Seções da janela de ajustes e do painel de EQ: índice `label.index` alinhado ao topo com `.padding(.top, 3)`, título `title.card` e sub em `text.small` muted. Os índices dão ordem de leitura, sem ícones coloridos |
| Linha de rede (tile, nome, %, barra, valor) | **Mixer por app**: tile de 30 pt raio 9 com o ícone do app sobre um tint de 8%, nome, % do total em mono, barra de 6 pt em cápsula sobre `bg.track` e valor em dB tabular. O hover realça a linha inteira em `bg.track` com raio 12 e −8 pt de margem |
| Barra divergente com marcador de base | **Ganho por banda** em torno de 0 dB: esquerda negativa, direita positiva, gap de 1 pt e traço de 2×14 pt com opacidade .55 marcando o preset anterior ou o AutoEQ |
| Barras gêmeas (base × agora) | Comparação A/B nivelada: barra cinza (`ink.muted` 45%) para "original", acento para "com EQ" |
| Donut (anel de 18/160, pontas retas, trilho) | **Anel de headroom/loudness** ou de uso de CPU do DSP: `Circle().trim(from:to:)` com `.stroke(style: StrokeStyle(lineWidth: diâmetro × 0.1125, lineCap: .butt))`, rotação −90° e valor central `value.medium` com rótulo mono |
| Barra empilhada de 12 pt com gap de 2 | Distribuição de saída por dispositivo ou por grupo |
| Sparkline (topo arredondado de 4, subconjunto embutido) | Histórico de pico ou loudness por minuto; o espectro em tempo real usa o mesmo estilo de barra (topo de 4 pt, gap de 2–4, sem eixo) |
| Pílula editorial (texto mono colorido, sem fundo) | Estados: "bit-perfect" em verde mono, "tap ativo" em muted mono, "clip" em rosa mono. **Sem cápsula colorida**; só o ponto de 6 pt mais o texto |
| Badge Arc (20/24/28, raio 5/6/7) | Use apenas quando houver interação (filtro, tag removível) |
| Controle segmentado (trilho muted, pastilha que desliza) | Alternância de saída ou preset: `matchedGeometryEffect` na pastilha com `spring.snappy`, rótulos sem mudança de peso |
| Callout e insight sem caixa | Linha explicativa embaixo da curva de EQ ("Grave +3 dB vs. alvo Harman"), em `text.small` secondary com `<strong>` em primary |
| "Como ler" e rodapé mono | Janela "Sobre o sinal": texto pequeno explicando o caminho do áudio (tap → DSP → dispositivo), a latência e o que é estimado |
| Citação serif | **Letras** no notch: Geist Serif 15–17 pt, aspas pendentes, linha atual em `ink.primary` e as vizinhas em `ink.muted` |
| Anéis concêntricos do hero (1 px a 11% e 7%) | Atmosfera do onboarding ou da janela "Sobre". **Nunca no notch** |

### 7.6 Movimento

| Token Órbita | SwiftUI |
|---|---|
| `ease.enter [0.16, 1, 0.3, 1]` | `.timingCurve(0.16, 1, 0.3, 1, duration: d)` |
| `ease.standard [0.22, 1, 0.36, 1]` | `.timingCurve(0.22, 1, 0.36, 1, duration: d)` |
| `ease.exit [0.7, 0, 0.84, 0]` | `.timingCurve(0.7, 0, 0.84, 0, duration: 0.18)` |
| `ease.inOut [0.65, 0, 0.35, 1]` | `.timingCurve(0.65, 0, 0.35, 1, duration: d)` |
| `spring.snappy { visualDuration: 0.26, bounce: 0 }` | `.spring(duration: 0.26, bounce: 0)` → toggles, pastilha do segmentado, press |
| `spring.smooth { visualDuration: 0.4, bounce: 0 }` | `.spring(duration: 0.4, bounce: 0)` → **expandir e recolher o notch**, reordenar o mixer |
| `spring.morph { visualDuration: 0.42, bounce: 0 }` | `.spring(duration: 0.42, bounce: 0)` → morfologia da forma do notch e `matchedGeometryEffect` |
| `spring.responsive { stiffness: 520, damping: 44 }` | `.interpolatingSpring(stiffness: 520, damping: 44)` → slider de volume seguindo o dedo |
| `spring.gentle { stiffness: 340, damping: 34 }` | `.interpolatingSpring(stiffness: 340, damping: 34)` |
| `duration.instant/fast/standard/considered` | 0,12 / 0,16 / 0,24 / 0,48 s |
| `stagger.item 0.035` (total < 0,4 s) | `.delay(Double(i) * 0.035)` nas linhas do mixer ao abrir |
| `blur.subtle/soft/text` 2/4/8 | `.blur(radius:)` em trocas de texto (faixa nova): sobe 0,3 em, sai de blur 4 → 0 em 0,24 s `enter` |
| `bar-in 0.7s enter` (scaleX de 0 a 1, origem à esquerda) | `.scaleEffect(x: appeared ? 1 : 0, anchor: .leading)` com `.timingCurve(0.16,1,0.3,1, duration: 0.7)` |
| `width 0.5s ease-spring` | `.spring(duration: 0.5, bounce: 0)` para mudanças de valor das barras |
| Contador de roda | `.contentTransition(.numericText(value:))` + `.animation(.spring(duration: 0.4, bounce: 0))` |
| `prefers-reduced-motion` | `@Environment(\.accessibilityReduceMotion)`: trocar tudo por fade de 0,12 s e desligar `bar-in` |

**O Dynamic Island da Apple usa molas com bounce.** O DNA da Órbita é **bounce 0** em tudo. Recomendação: manter bounce 0 para preservar o caráter "calmo e preciso", coerente com um produto audiófilo. Se testes mostrarem que a expansão do notch parece "morta", aceitar no máximo `bounce: 0.1` só nessa transição, e registrar a decisão.

### 7.7 Esboço de tokens em Swift (ponto de partida)

```swift
enum Surface { case light, dark, notch }

struct TimbreColors {
    let canvas, surface, raised, track: Color
    let inkPrimary, inkSecondary, inkMuted: Color
    let line, lineSubtle, lineStrong: Color
    let accent, accentStrong, accentSubtle: Color
    let positive, negative, warning, info: Color

    static let light = TimbreColors(
        canvas: Color(hex: 0xFAFAFA), surface: .white, raised: .white, track: Color(hex: 0xF8F8F8),
        inkPrimary: Color(hex: 0x0B0B0B), inkSecondary: Color(hex: 0x585858), inkMuted: Color(hex: 0x7D7D7D),
        line: Color(hex: 0xE9E9E9), lineSubtle: Color(hex: 0xF3F3F3), lineStrong: Color(hex: 0xC4C4C4),
        accent: Color(hex: 0x7747FF), accentStrong: Color(hex: 0x5528CE), accentSubtle: Color(hex: 0x7747FF).opacity(0.13),
        positive: Color(hex: 0x00774D), negative: Color(hex: 0xBB2C54), warning: Color(hex: 0x9F6202), info: Color(hex: 0x136D9E))

    static let dark = TimbreColors(
        canvas: Color(hex: 0x141414), surface: Color(hex: 0x191919), raised: Color(hex: 0x1F1F1F), track: Color(hex: 0x242424),
        inkPrimary: Color(hex: 0xF2F2F2), inkSecondary: Color(hex: 0xB4B4B4), inkMuted: Color(hex: 0x8C8C8C),
        line: Color(hex: 0x2B2B2B), lineSubtle: Color(hex: 0x222222), lineStrong: Color(hex: 0x484848),
        accent: Color(hex: 0xA78BFF), accentStrong: Color(hex: 0xC7B7FF), accentSubtle: Color(hex: 0x7747FF).opacity(0.22),
        positive: Color(hex: 0x55D69F), negative: Color(hex: 0xF0738F), warning: Color(hex: 0xF2BD68), info: Color(hex: 0x7CC4F0))

    static let notch = TimbreColors(
        canvas: .black, surface: .black, raised: .white.opacity(0.07), track: .white.opacity(0.12),
        inkPrimary: Color(hex: 0xF2F2F2), inkSecondary: Color(hex: 0xB4B4B4), inkMuted: Color(hex: 0x7A7A7A),
        line: .white.opacity(0.11), lineSubtle: .white.opacity(0.07), lineStrong: .white.opacity(0.28),
        accent: Color(hex: 0xA78BFF), accentStrong: Color(hex: 0xC7B7FF), accentSubtle: Color(hex: 0x7747FF).opacity(0.26),
        positive: Color(hex: 0x55D69F), negative: Color(hex: 0xF0738F), warning: Color(hex: 0xF2BD68), info: Color(hex: 0x7CC4F0))
}

enum TimbreMotion {
    static let enter    = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.24)
    static let standard = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)
    static let exit     = Animation.timingCurve(0.7, 0, 0.84, 0, duration: 0.18)
    static let snappy   = Animation.spring(duration: 0.26, bounce: 0)
    static let smooth   = Animation.spring(duration: 0.40, bounce: 0)
    static let morph    = Animation.spring(duration: 0.42, bounce: 0)
}

extension Text {
    /// Eyebrow canônico da Órbita: mono 11, peso 500, +.11em, caixa alta, tinta muted.
    func eyebrow(_ c: TimbreColors) -> some View {
        self.font(.custom("GeistMono-Medium", size: 11)).tracking(11 * 0.11)
            .textCase(.uppercase).foregroundStyle(c.inkMuted)
    }
}
```

O valor `inkMuted` do notch (`#7A7A7A`) e os alfas brancos são **propostas desta nota**, não valores da Órbita. Precisam de prova sobre um MacBook real com notch, de preferência em dois painéis: LCD mini-LED e o OLED novo.

### 7.8 Regras para manter o DNA no notch

1. **Preto absoluto e zero caixas.** No notch, a hierarquia é feita só por tinta (primary, secondary, muted) e por réguas de 0,5 pt. Isso é a "passada editorial" levada ao extremo.
2. **O violeta é usado uma vez por vista:** a curva do usuário, o item ativo ou o slider em foco. Nunca dois elementos violeta competindo.
3. **Mono em caixa alta só para rótulos e unidades** (HZ, DB, KHZ, BIT). Os valores ficam em Sans tabular.
4. **Cada número leva unidade e contexto.** "−12 dB" vem com "era −9 dB" ou "pico −0,3 dBFS" em muted.
5. **Barras finas** (4–6 pt no notch), pontas em cápsula, trilho `track`, sem eixos. O traço de referência tem opacidade .55.
6. **Bounce 0.** O notch abre com `smooth` (0,4 s) e o conteúdo entra com stagger de 0,035 s por linha, somando até 0,4 s.
7. **No máximo dois registros de tamanho por vista**: micro (9–13 pt) e um único valor display.

---

## 8. Limites desta nota

- **A página autenticada não foi vista.** A paridade entre local e publicado foi verificada pelo conjunto de classes CSS e pelo `dataset.accent="violet"` do bundle publicado em 21/11/2026, não por uma captura.
- **Os hex vindos de OKLCH são aproximações sRGB** calculadas com a matriz OKLab de referência e clipping simples. As séries `--series-*` com acento violeta dependem do gamut mapping do navegador e podem diferir em alguns pontos.
- **O PDF exportado da Ronda não foi lido.** Valem o HTML e as regras `@page{margin:0}` (RONDA:209) e `print-color-adjust:exact` (RONDA:18).
- **Os valores da superfície "notch" e as conversões de sombra e line-height são propostas**, não medições. Precisam de validação visual em hardware.
