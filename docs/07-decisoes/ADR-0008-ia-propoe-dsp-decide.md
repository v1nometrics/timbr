# ADR-0008 · IA propõe, DSP decide

- **Status:** Aceito · 2026-11-21

## Contexto

Pesquisa 2025–2026 (LLM2Fx da Sony, estudo da B&O) mostra modelos de ~3B parâmetros quase no nível do GPT-4o ao mapear texto para parâmetros de EQ. Descritores abstratos ("quente", "brilhante") têm alta variância entre pessoas (SocialEQ, SAFE). Nenhum estudo validou EQ gerado por LLM com audiófilos em teste cego.

## Decisão

1. A IA **nunca** processa áudio. Ela recebe texto + estado atual (alvo, correção, gosto, fone) e devolve um **delta tipado** num esquema fechado: lista de no máximo N operações (`adjust_band`, `add_filter`, `remove_filter`, `set_tilt`), cada uma com limites duros.
2. **Limites aplicados por código, não pelo modelo:** ganho por filtro ±6 dB (proposta, alinhada ao estudo B&O), Q entre 0,3 e 6, frequência 20 Hz–20 kHz, no máximo 3 filtros novos por pedido, preamp recalculado automaticamente.
3. **Todo delta é aplicado na camada Gosto** (ADR-0010), nunca na Correção; vira uma versão nova do preset; abre um A/B cego com volume nivelado; tem desfazer em um toque.
4. **Ordem de runtimes:** Foundation Models on-device (macOS 26) → modelo local via Ollama/LM Studio (opt-in) → nuvem com chave do usuário (opt-in). Só texto e parâmetros saem do Mac; nunca áudio nem histórico de escuta.
5. Pedidos abstratos ("mais quente") retornam **duas ou três variantes** para A/B, não uma curva única.
6. A resposta inclui uma justificativa em linguagem simples ("reduzi 2,5 dB em 6,8 kHz, região de sibilância") que a UI mostra junto do delta.
