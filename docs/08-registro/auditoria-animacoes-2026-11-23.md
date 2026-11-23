# Auditoria de animações · 2026-11-23

> Método: o roteiro de auditoria de animações (oito categorias: propósito e frequência, curvas e durações, fisicidade e origem, interrompibilidade, desempenho, acessibilidade, coesão, oportunidades perdidas), aplicado a todo o código de movimento do app (`withAnimation`, `.animation`, `.transition`, `TimelineView`, `contentTransition`), mais **perfil de amostragem** (`sample`) do app parado e tocando, e medições na janela real do notch.

## Resultado em uma frase

O movimento do app já estava no ponto certo na maior parte (frequência decide se anima, molas interrompíveis, notch assimétrico, números com `numericText`). Os achados reais foram **um token que contradizia a própria regra**, **três lacunas de acessibilidade**, **valores soltos que fugiam dos tokens** e **um custo de CPU que eu mesmo tinha introduzido**.

## Achados e o que foi feito

| # | Sev. | Categoria | Achado | Resolução |
|---|---|---|---|---|
| 1 | Alta | Curvas | O token `exit` era `cubic-bezier(.7,0,.84,0)`, um **ease-in**, proibido pelo §6 do documento de movimento (nenhuma view o usava, mas estava disponível) | Virou `cubic-bezier(.23,1,.32,1)`, 160 ms. O gerador agora **recusa** qualquer ease-in |
| 2 | Média | Acessibilidade | Só 18 referências a "Reduzir movimento" no app inteiro; mola do corpo do notch (blur 8→0, escala 0,8→1), a abertura pelo controlador e quase todos os `snappy`/`smooth` ignoravam a opção | Todos os tokens passaram a ser calculados e viram um fade de 120 ms; o corpo do notch só faz fade; testado token a token no CI (`TimbreTokensTests`) |
| 3 | Média | Coesão | 12 valores à mão nas views: `.easeOut(0.12)`, `.easeOut(0.09)`, `.easeOut(0.14)`, `.spring(0.36)`, `.interactiveSpring(0.16, 0.86)` (2×), `.linear(0.06/0.07/0.08/0.09)` | Tokens `fade`, `fadeOut`, `tab`, `meter`, `dismissFollow`; `smooth` no lugar da mola solta |
| 4 | Média | Desempenho | O vigia de 250 ms da detecção de pausa traduzia PIDs para objetos do Core Audio a cada tick (uma ida ao `coreaudiod` por processo). No perfil, era o maior item do app: 148 de 2.968 amostras da thread principal tocando (5,0%), 91 parado | Traduz uma vez por reavaliação e a cada tick só relê a flag de saída. Depois: 40 amostras (1,3%); `translatePIDsToProcessObjects` de 113 para 8 |
| 5 | Baixa | Oportunidade | A faixa de aviso do Estúdio (`statusBanner`) aparecia de uma vez e empurrava a página sem transição | Fade com deslocamento de 8 pt e a página desce junto (`standard`) |
| 6 | Baixa | Oportunidade | Linhas do mixer do Estúdio apareciam e sumiam de uma vez quando uma fonte começava ou parava (o notch já animava) | Fade e reordenação com `smooth` |

## O que a auditoria **não** encontrou (e foi verificado, não suposto)

- **Telemetria de 30 Hz redesenhando a interface:** hipótese inicial descartada. O perfil mostrou zero custo de SwiftUI na thread principal, portanto o loop foi preservado sem alteração.
- **Animação em ação de teclado ou de alta frequência:** nenhuma. A troca de aba é um fade de 140 ms, e o `Reveal` do notch (blur 8, abaixo do limite de 20) só roda em abrir e fechar.
- **`ease-in`, `scale(0)`, `transition: all` ou propriedades de layout animadas:** nenhum em uso.
- **Reação ao parar o som:** não regrediu (2,74 s e 8,14 s depois da otimização, contra 2,60 s e 8,07 s antes; o resto é o tempo do macOS, ADR-0021).

## Medições (macOS 26.6, MacBook Air)

- Perfil da thread principal tocando: `pollPlayback` 5,0% → 1,3%; `translatePIDs` 113 → 8 amostras.
- CPU pelo `top` (oscila ±2 pontos entre medições, então o perfil é a evidência): parado 2,2 a 6,5%, tocando 6,9 a 8,8%, contra 3,2 a 3,9% e 8,2 a 9,9% antes.
- Reduzir movimento: **não medi visualmente.** Tentei contar quadros de transição pela janela do notch, mas a captura (~0,15 s por quadro) não resolve uma transição de 0,12 a 0,4 s e os números variaram sem padrão; descartei a medição. A garantia é o teste automático.

## Limites e o que fica para depois

- "Reduzir movimento" mantém um fade curto em vez de zero animação, de propósito (reduz, não elimina).
- As animações do notch dependem da sensação, que o código sozinho não decide: vale ver ao vivo com `Timbr --reduce-motion` e `Timbr --demo`.
- `MiniMeter` redesenha a 12 Hz enquanto algo toca; a amplitude é de ~1 pt, então poderia cair para 8 Hz sem diferença visível, mas o perfil não mostrou custo, então ficou como está.
