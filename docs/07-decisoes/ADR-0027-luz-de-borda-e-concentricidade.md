# ADR-0027 · Luz de borda, lente e concentricidade (vidro sem translucidez)

- **Status:** Aceito · 2026-11-26 (pedido explícito do responsável: "o notch sobre um app totalmente preto precisa de algo diferente?" e "mais glass, arredondado, late 2026, sem desrespeitar o design system")
- **Altera:** lei L1 (o notch continua preto absoluto, sem contorno, sem blur e sem alpha no preenchimento; ganha uma luz de borda inferior enquanto aberto) e a seção de elevação de `01-fundacoes-tokens.md`
- **Relacionado:** [ADR-0013](ADR-0013-superficies.md), [ADR-0016](ADR-0016-identidade-acromatica.md)

## Contexto

Sobre conteúdo claro, o notch aberto se destaca pela sombra preta. Sobre um app totalmente preto (terminal, player em tela escura, IDE escura), a sombra some e a forma desaparece: o conteúdo parece flutuar sem contêiner, e fica difícil saber onde a ilha termina, o que importa para o "fechar seguindo o ponteiro". Captura de revisão em 2026-11-26 (`--notch expanded` sobre fundo preto): nenhum pixel separa a forma do fundo.

Ao mesmo tempo, o pedido de um visual "mais glass" esbarra em um limite físico: o notch desenhado continua o vazio preto do hardware. Qualquer preenchimento translúcido, cinza ou com blur mostraria a costura entre os pixels e a câmera, sobretudo em LCD. É o mesmo motivo de a Dynamic Island da Apple continuar preta.

## Decisão

1. **A casca do notch não muda: preto absoluto `sRGB 0,0,0`, sem contorno e sem translucidez.** Glassmorphism no preenchimento foi descartado.
2. **Luz de borda (`glass.edgeLight`, só na superfície `notch`, branco a 15%).** Enquanto aberto, uma borda interna de 0,75 pt acompanha a silhueta inferior. A intensidade vai de zero na altura da barra de menus até o máximo na borda de baixo, então os ombros e o topo continuam fundidos ao hardware. Ela é multiplicada pela abertura (some ao fechar e ao seguir o ponteiro) e anima na mesma mola da forma. Sobre conteúdo claro fica sob a sombra; sobre preto é o que desenha a ilha. Implementação: `NotchEdgeLight` em `DSComponents.swift`.
3. **Sombra em duas camadas enquanto aberto:** contato (preto 30%, raio 2, y 1) e ambiente (preto 42%, raio 22, y 12). Substitui a sombra única (50%, raio 14, y 6), que deixava um halo cinza borrado sobre fundos claros.
4. **Lente nos controles elevados (`glass.specular` → `glass.rim`).** Chips, botões secundários, o polegar do segmentado e o `MenuChip` ganham uma borda de 0,75 pt iluminada por cima e assentada embaixo. É o vidro possível sem translucidez: a luz descreve o material e o fundo continua opaco. Valores por superfície:

   | Token | Claro | Escuro | Notch |
   |---|---|---|---|
   | `glass.specular` | `rgba(17,17,17,.07)` | `rgba(255,255,255,.11)` | `rgba(255,255,255,.15)` |
   | `glass.rim` | `rgba(17,17,17,.17)` | `rgba(255,255,255,.035)` | `rgba(255,255,255,.04)` |
   | `glass.edgeLight` | `0` | `0` | `rgba(255,255,255,.15)` |

5. **Concentricidade e formas de 2026.** Raio interno = raio externo − margem. O expandido passa de 24 para 28 pt de raio, e o rodapé usa chips de 28 pt (raio 14) a 14 pt da lateral e da base (14 + 14 = 28). Espiada 20 → 24 (`notchPeek`), HUD 14 → 16 (`notchHud`). Botões (`TButtonStyle`) e o segmentado viram cápsulas, como os controles do macOS 26. O `IconButton` ganha placa circular.
6. **Uma margem de conteúdo no notch (18 pt):** asas, faders, linhas e hairlines compartilham a mesma borda, inclusive o hairline do rodapé, que antes ficava a 14 pt. O HUD mantém 14 pt porque a asa dele tem 58 pt e "Muted" não caberia.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Preenchimento translúcido ou com blur (glassmorphism) | Revela a costura com o notch físico; quebra L1 e o "parece parte do Mac" |
| Contorno completo (como a v1, 11% de branco) | Desenha o topo e os ombros contra a moldura; foi o defeito que a v2.0 removeu |
| Contorno adaptativo à luminância do que está atrás | Exige captura de tela (permissão de gravação) só para decorar; viola P7 e L10 |
| Não fazer nada (a Dynamic Island da Apple também some em fundo preto) | No iPhone a ilha é pequena e o conteúdo é mínimo; o expandido do timbr tem 460 pt de largura e controles, e precisa de borda legível para o fechar seguindo o ponteiro |

## Trade-offs

- A luz é mais forte que um hairline do notch (15% contra 9%), de propósito: precisa ser vista sobre preto. Em LCD (MacBook Air), em sala escura, ela aparece um pouco mais que em mini-LED ou OLED. Compensa porque só existe enquanto o notch está aberto e só na metade de baixo.
- Sobre fundo claro, a borda interna aparece como um fio cinza muito sutil na base da silhueta (visível nas capturas a 2×). Foi aceito: lê como borda de vidro, não como contorno.

## Evidência

- Capturas de revisão de 2026-11-26 (`--notch expanded|peek` com `--review-multi` e `--review-empty`, sobre fundo preto, branco e dividido): antes, a forma some no preto; depois, a silhueta inferior aparece e o topo continua fundido.
- Gravação de `--demo` sobre fundo preto (folha de contato a 12 fps): a luz acompanha a forma ao abrir, seguir o ponteiro e fechar, sem clarão nas laterais.
- **Não medido:** aparência em OLED (MacBook Pro 2026) e em sala escura com fotômetro.

## Consequências

- A etapa 3b do CI continua reprovando `stroke`/`strokeBorder` em `NotchOverlay.swift`: a casca nunca é contornada ali. A luz de borda vive num único componente revisado (`NotchEdgeLight`), com o token `glass.edgeLight` zerado fora do notch.
- Bíblia v2.6; documentos 01, 03 e 04 atualizados.
