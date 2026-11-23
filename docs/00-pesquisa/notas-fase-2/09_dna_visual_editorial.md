# Nota 09 · DNA Visual Editorial e Fundações de Superfície

> **Status histórico:** esta nota consolida os princípios editoriais que originaram o design system v1 do `timbr` (2026-11-21). Duas decisões posteriores substituíram partes da especificação inicial:
> - **[ADR-0015](../../07-decisoes/ADR-0015-tipografia-de-sistema.md):** no app nativo macOS, a tipografia usa famílias do sistema (`SF Pro`, `SF Mono`, `New York`), reservando `Geist` apenas para web/documentação/playground.
> - **[ADR-0016](../../07-decisoes/ADR-0016-identidade-acromatica.md):** a identidade do produto é **100% acromática** (sem cor de marca; ênfase por tinta, peso e espessura; cor reservada exclusivamente a estados semânticos).
> - **[ADR-0025](../../07-decisoes/ADR-0025-ilha-refinada-e-marca-sem-ponto.md):** marca pública `timbr` (sem ponto) e símbolo *Ilha refinada*.
>
> Para os valores vigentes em código, consulte sempre [`docs/05-design-system/`](../../05-design-system/00-biblia-do-design-system.md) e [`design-system/tokens/`](../../../design-system/tokens/).

---

## 1. Princípios Editoriais Adotados

1. **Neutros puros sem matiz fria:** superfícies claras em papel quente (`#FAFAFA` / `#FFFFFF`) e superfícies escuras em carbono puro (`#141414` / `#191919`), sem cinza azulado e sem gradientes decorativos.
2. **Hierarquia por tinta e régua, não por caixas:** evitar cartões empilhados com bordas grossas ou fundos coloridos; separar conteúdo por hierarquia de tinta (`ink.primary`, `ink.secondary`, `ink.muted`, `ink.faint`) e `Hairline` de `0,5 pt`.
3. **Mistura de cores em OKLab, nunca em OKLCH direto:** interpolar cores com chroma em OKLCH pode girar o matiz pelo eixo magenta/rosa; tinturas programáticas operam em OKLab ou opacidade controlada sobre a superfície.
4. **Estrutura editorial numerada:** páginas do Estúdio usam cabeçalhos numerados (`01`, `02`, …), eyebrows em mono maiúsculo com tracking aberto, frase-resumo objetiva, blocos de KPI tabulares e notas explicativas discretas ("como ler").
5. **Números sempre tabulares e com contexto:** toda grandeza numérica usa dígitos monoespaçados (`tnum`), unidade separada em mono e contexto explícito (sem valores órfãos).
6. **Preto absoluto no notch (`#000000`):** o notch funde-se ao hardware da tela sem contorno (`.stroke` proibido por trava de CI); toda hierarquia interna vem de contraste de tinta e superfícies elevadas sutis.
7. **Cor apenas com significado:** verde (neutro/bit-perfect/seguro), âmbar (atenção/mudo/limiter/HFP), vermelho (erro/clipping), azul (informativo). Nenhuma matiz decorativa.

---

## 2. Regras de Movimento Herdadas

- **Sem `ease-in` em UI:** curvas de saída e entrada usam desaceleração rápida (`ease-out`) ou molas físicas; o gerador de tokens recusa automaticamente qualquer curva `ease-in`.
- **Assimetria abrir/fechar:** abrir pode ter presença orgânica (`notchOpen`); fechar é sempre mais rápido e sem bounce (`notchClose`).
- **Manipulação direta:** faders, knobs e arraste de valores seguem o ponteiro 1:1, sem atraso perceptível; atalhos de teclado não animam.
- **Respeito estrito a *Reduzir movimento*:** todos os tokens de movimento degradam automaticamente para crossfade curto quando a preferência de acessibilidade do macOS está ativa.
