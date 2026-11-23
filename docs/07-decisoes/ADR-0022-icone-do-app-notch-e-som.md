# ADR-0022 · Ícone do app: o notch e o som que ele controla

- **Status:** Substituído por [ADR-0025](ADR-0025-ilha-refinada-e-marca-sem-ponto.md) · 2026-11-23
- **Substitui:** a linha "Ícone do App (`.icns`)" da [ADR-0014](ADR-0014-nome-identidade-e-i18n.md) e o item "Ícone do app" da [ADR-0016](ADR-0016-identidade-acromatica.md). Decisão histórica; símbolo e assinatura vigentes estão na ADR-0025.

## Contexto

O ícone inicial (fundo `#141414`, cinco barras de onda brancas e um ponto) era genérico demais em relação a outros utilitários de áudio. Duas rodadas de exploração visual levaram à seguinte síntese:

- **Rodada 1 (ponto final como símbolo, curvas de Lissajous, "t" com fader):** descartadas por se afastarem da linguagem minimalista do produto (ponto isolado abstrato demais, Lissajous excessivamente ornamental e "t" com fader associado a apps de DJ).
- **Rodada 2:** o ponto saiu do ícone (ele continua no nome escrito, onde passa precisão). Propus três: A (notch + som), B ("t" serifado) e C (a ilha). A recomendação foi a A.

## Decisão

Aplicar a **A**: um bloco de papel quente (`#F3F3F1`) com o **notch pendurado na borda de cima** (preto) e, abaixo dele, as **cinco barras** da silhueta harmônica que o app já desenha ao lado do notch (tinta `#141414`). Diz em meio segundo o que o app é (som controlado a partir do notch) e nenhum app de áudio usa isso. Continua sem cor de marca (ADR-0016).

- Desenhado analiticamente (distâncias com sinal) em `scripts/generate_icns.py`, na grade de 1024 pt da Apple (o bloco ocupa 100–924), sem dependências.
- **Variante forte até 64 px:** notch maior e barras mais grossas, para o notch e as barras sobreviverem em 32 px.
- Fundo claro de propósito: é o oposto do ícone anterior e do notch preto, e se destaca no Dock escuro.

## Limites

- Aplicado como solução intermediária antes da definição final da marca (posteriormente substituído pela [ADR-0025](ADR-0025-ilha-refinada-e-marca-sem-ponto.md)).
- Em 16 px as barras viram uma faixa cinza: o notch preto continua sendo o reconhecível.
- O ícone da barra de menus (que só aparece sem notch) não mudou.
