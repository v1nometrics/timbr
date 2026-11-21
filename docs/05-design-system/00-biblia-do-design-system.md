# 00 · Bíblia do Design System — `timbr.`

> **Status:** Lei de projeto (Princípio P10 · [ADR-0012](../07-decisoes/ADR-0012-tokens-fonte-unica.md) · [ADR-0013](../07-decisoes/ADR-0013-superficies.md))
> **Última revisão:** 2026-11-21
> **Fontes primárias:** [DNA visual da Órbita e Ronda](../00-pesquisa/notas-fase-2/09_dna_visual_orbita_e_ronda.md), [Referências de UI e componentes](../00-pesquisa/notas-fase-2/08_referencias_ui_componentes.md), Apple HIG (Liquid Glass, Materials, Live Activities), diretrizes `$apple-design` e `$emil-design-eng`.

---

## 1. Tese estética: Precisão Editorial + Calma Audiófila

O Timbre é um instrumento de precisão que mora na barra superior do Mac. Ele não tem a aparência de um plugin de estúdio cheio de metal escovado e parafusos, nem a de um utilitário genérico de notch cheio de widgets e brilho gratuito.

A direção estética une **três linhagens** em uma gramática única:

1. **Disciplina editorial da Órbita (SIP) e da Ronda Diária:** base 100% acromática (croma zero em OKLCH), dois pesos tipográficos (`400` e `500`), três vozes tipográficas com papéis fixos (`Geist` conteúdo, `Geist Mono` rótulo/unidade, `Geist Serif` letra/citação), contraste por escala (micro + display) em vez de caixas, réguas finas no lugar de cartões aninhados, e um único acento violeta (`#7747FF` / `#A78BFF`) usado com parcimônia cirúrgica.
2. **Física e contenção da Apple (`$apple-design` + HIG macOS 26/27):** molas criticamente amortecidas (`bounce: 0` por padrão), continuidade de velocidade ao soltar um gesto, janelas não-ativantes que respeitam o foco do usuário, transparência/Liquid Glass **apenas sob interação** em controles nativos, e preto contínuo `#000000` para fundir com o recorte físico do hardware.
3. **Engenharia de detalhes invisíveis (`$emil-design-eng`):** ações iniciadas por teclado **nunca animam**, interações ficam abaixo de `300 ms`, popovers escalam a partir do gatilho (`transform-origin` real), nunca há `scale(0)`, botões respondem ao toque (`scale(0.97)`), e transições imperfeitas entre estados usam `blur(2–4 px)` para não sobrepor dois objetos duros.

---

### Parentesco com `v1torres.dev` e Wordmark `timbr.`

A marca **`timbr.`** (caixa baixa com ponto final, tagline *"Sound, precisely yours."* sobre fundo neutro `#141414`/`#191919`) herda a disciplina tipográfica e monocromática do ecossistema pessoal do autor ([`v1torres.dev`](https://v1torres.dev): tipografia Geist, ausência de gradientes decorativos, superfícies neutras puras, hierarquia por espaço e contraste). Divergimos propositalmente de `v1torres.dev` apenas onde a física de um instrumento de áudio macOS exige: **raios concêntricos ao hardware do notch** (no lugar de `radius: 0`), `Geist Sans` + `Geist Mono` juntos, e **1 acento violeta funcional + semântica de sinal** (clipping/HFP/bit-perfect). Ver [ADR-0014](../07-decisoes/ADR-0014-nome-identidade-e-i18n.md).

## 2. Estrutura desta Bíblia

| Documento | Conteúdo | Quando consultar |
|---|---|---|
| [00 · Índice e Governança](00-biblia-do-design-system.md) | Tese estética, 12 regras de ouro, governança, evolução e checklist de merge | Antes de propor qualquer nova tela ou mudança visual |
| [01 · Fundações e Tokens](01-fundacoes-tokens.md) | Fonte única DTCG (`design-system/tokens/`), 3 superfícies (`Claro`, `Escuro`, `Notch`), escala de cor OKLCH/OKLab, tipografia, grade 7/5, raios concêntricos, bordas e sombras | Sempre que definir cor, fonte, espaço, raio ou texto numérico |
| [02 · Motion e Física](02-motion-e-fisica.md) | Árvore de decisão por frequência, molas SwiftUI, curvas de easing, *velocity handoff*, micro-interações e `Reduce Motion` | Ao criar ou revisar qualquer animação, transição ou gesto |
| [03 · Superfícies e Anatomia](03-superficies-e-anatomia.md) | Especificação espacial das 6 superfícies: Notch (5 estados), Pílula, MenuBarExtra, Estúdio, Observatório e Live Activity | Ao desenhar fluxos, janelas ou geometria do notch |
| [04 · Componentes e Visualização de Áudio](04-componentes-e-visualizacao-audio.md) | Gráfico PEQ (padrão Pro-Q 4), medidores normativos (EBU Tech 3341, PPM/VU, dBTP), sliders físicos, controles pro-audio, reatividade `libraries.dev` e stack web (`shadcn`/`Bencho`/`Spell`) | Ao construir gráficos, sliders, listas de mixer, letras ou o site/docs |
| [05 · Assets, Iconografia e Referências](05-assets-iconografia-e-referencias.md) | Fontes embarcadas, SF Symbols 8 (`variableValue`), ícones de dispositivo, pacote de referências masters e matriz de reuso | Ao gerenciar fontes, ícones ou dependências visuais |

Os tokens executáveis residem na raiz do repositório em `design-system/tokens/*.tokens.json` (ver [ADR-0012](../07-decisoes/ADR-0012-tokens-fonte-unica.md)).

---

## 3. As 12 regras inegociáveis do Design System

1. **Zero literais visuais no código.** Cores, fontes, tracking, raios, espaçamentos e curvas de animação vêm exclusivamente do módulo gerado `TimbreTokens` (`Tokens.swift` / `tokens.css`). Lint de CI bloqueia hex ou durações soltas.
2. **Base acromática; cor significa estado ou dado.** Neutros têm croma zero. O sistema nunca usa cor por decoração.
3. **Um violeta por vista.** O violeta marca o elemento em foco, a curva do usuário (`Gosto`) ou o sujeito ativo. Nunca há dois elementos violeta competindo pelo olhar na mesma vista.
4. **Cor semântica segue o efeito sobre o sinal, não a direção do número.** Clipping, HFP forçado ou reamostragem indesejada = `negative` (`danger`). Ganho positivo que causa clipping é vermelho; redução de preamp que protege o sinal não é vermelha.
5. **Preto absoluto `#000000` e zero caixas no notch.** No notch, a hierarquia nasce de três níveis de tinta (`ink.primary`, `ink.secondary`, `ink.muted`) e réguas de `0,5 pt` (`line.subtle`), não de cards dentro de cards.
6. **Dois registros de escala, dois pesos.** Pesos `400` e `500` (sem bold estridente). Escala concentrada no micro (`9–13 pt`) e no display (`22–46 pt`), quase sem tamanhos intermediários.
7. **Todo número tem unidade, contexto e alinhamento tabular.** `.monospacedDigit()` obrigatório; unidade em `Geist Mono` ou atenuada ao lado; contexto explícito (`−12,0 dB · preamp −3,5 dB` ou `era −9,0 dB`); separador `·` entre metadados.
8. **Verdade visual no caminho do sinal (P4).** Nenhum gráfico ou rótulo apresenta métrica inferida como medição. Selos `MEDIDO`, `REPORTADO` e `INFERIDO` usam estilos distintos; efeitos decorativos (`VoiceRingKit`/`VoiceGlowKit`) nunca substituem medidores calibrados.
9. **O notch nunca contém configuração (ADR-0013).** Apenas estado atual e ações imediatas (até 2 níveis). Tudo que exige edição profunda vai para o Estúdio.
10. **Ações de teclado nunca animam.** Atalhos globais (`⌥⌘V`, `⌥⌘B`, `⌥⌘A`, `⌥⌘M`), navegação por setas e tooltips subsequentes são instantâneos (`0 ms`).
11. **Bounce zero por padrão.** Molas criticamente amortecidas (`bounce: 0`). O único candidato a bounce mínimo (`≤ 0,1`) é um gesto de arraste com inércia explícita, sujeito a validação em hardware.
12. **Todo estado degradado e toda acessibilidade são de primeira classe.** `Reduce Motion` troca movimento por fade `120 ms`; alto contraste, VoiceOver (inclusive sobre `Canvas` via views acessíveis sobrepostas) e `Dynamic Type` / escala do sistema são obrigatórios.

---

## 4. Evolução planejada do Design System

| Versão | Escopo visual | Entregáveis | Critério de saída |
|---|---|---|---|
| **DS 0.1 · Fundação (atual)** | Bíblia escrita + tokens JSON DTCG + gerador `Tokens.swift` e `tokens.css` | Docs `00–05` + `design-system/tokens/` + preview/catálogo mínimo | Tokens gerando sem erro; validação visual em protótipo E-12 |
| **DS 0.2 · MVP Notch & Estúdio** | Estados do Notch (Repouso, Compacto, HUD, Espiada, Expandido), Pílula, MenuBar, Editor PEQ, Medidor TP/Peak, Observatório v1 | Componentes SwiftUI + `Canvas` testados em LCD mini-LED e display externo | Passa 100% do checklist (§5) + `Reduce Motion` + VoiceOver |
| **DS 1.0 · Refino, OLED & Web** | Live Activity (macOS 27.3+ / Dynamic Island OLED), medidores EBU R128/PPM, Letras (`Geist Serif`), reatividade `VoiceGlowKit` opt-in, site/docs em React (`shadcn` + `Bencho` + `Spell` + `DSSSP`) | Paridade visual verificada entre app nativo e web; guia de contribuição visual | Zero desvios de token; auditado em tela OLED e LCD |

---

## 5. Checklist obrigatório de revisão de UI (antes de merge — P10)

Nenhuma tela ou componente novo entra na `main` sem responder **Sim** a todos os itens aplicáveis:

- [ ] **Tokens:** zero cores hex, tamanhos soltos ou curvas de animação fora de `TimbreTokens`?
- [ ] **Superfície:** respeita a paleta da superfície correta (`Claro`, `Escuro`, `Notch #000000`), sem caixas aninhadas no notch?
- [ ] **Acento:** há no máximo **um** foco violeta na vista?
- [ ] **Tipografia:** pesos apenas `400`/`500`, `Geist Mono` em caixa alta apenas para rótulos/unidades, `.monospacedDigit()` em todos os números dinâmicos ou alinhados?
- [ ] **Hierarquia numérica:** cada métrica tem unidade explícita, sinal tipográfico `−` (U+2212) para negativos, e selo `MEDIDO` / `REPORTADO` / `INFERIDO` quando vem do áudio?
- [ ] **Motion:** atalhos de teclado têm `0 ms` de animação? Transições de UI ficam `≤ 300 ms`? Nenhum `scale(0)`? Popovers escalam do gatilho? `accessibilityReduceMotion` testado?
- [ ] **Foco e janelas:** o painel do notch é não-ativante e não rouba foco de apps em tela cheia ou edição de texto?
- [ ] **Acessibilidade:** elementos sobre `Canvas` (alças do EQ, sliders customizados) possuem equivalentes acessíveis para VoiceOver e navegação por teclado (`Tab` / setas / `⌥` fino)?
- [ ] **i18n (`PT / ES / EN`):** layout validado nos três idiomas da v1 (sem truncamento em textos ~20% mais longos que EN)?
- [ ] **Contenção:** nenhum controle de hardware é exibido sem capacidade confirmada pela sonda (P11)?
