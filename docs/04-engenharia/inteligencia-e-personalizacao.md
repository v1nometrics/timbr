# Arquitetura da Camada de Inteligência e Personalização

> **Princípio inviolável (P6 · [ADR-0008](../07-decisoes/ADR-0008-ia-propoe-dsp-decide.md)):** a IA **nunca** processa áudio e **nunca** escreve coeficientes diretos sem passar pelo validador determinístico do DSP. Toda personalização atua exclusivamente na camada **Gosto** ([ADR-0010](../07-decisoes/ADR-0010-correcao-e-gosto.md)).

---

## 0. Estado implementado (2026-11-23)

- **"Descreva o som"** (`AIAssistantRouter`, TimbreCore) tenta, nesta ordem: Apple Foundation Models no aparelho (macOS 26+, se disponível) → Ollama local, só com opt-in → variantes determinísticas por palavras-chave. A saída é sempre um delta tipado (`EQDeltaProposal`), validado com limites rígidos (±6 dB, Q 0,3–6, até 3 operações) antes de chegar ao DSP (ADR-0008). Classe: **Comprovado** (código e teste de limites no CI); a qualidade das sugestões **não foi avaliada** (E-13).
- **Treinador de gosto** (`PairwiseGPTrainer`): rodadas A/B registradas na linha do tempo; convergência testada em dados sintéticos no CI. Estabilidade teste-reteste com pessoas **não medida** (E-14).

---

## 1. Arquitetura em Três Componentes

```
  Pedido em texto ("vocais mais presentes, menos sibilância")
         │
         ▼
  [1. Tradutor LLM] ──(JSON Schema estrito: EqDelta)──▶ [2. Guardrail Determinístico]
   • Apple Foundation Models (macOS 26, ~3B)             • Valida ranges (Fc, Q, Gain, N)
   • Ollama / LM Studio (opt-in local)                   • Clamps rígidos (±6 dB/op)
   • Nuvem BYOK (opt-in explícito)                       • Recalcula preamp somado
                                                         • Gera nova versão no histórico
         ▲                                                      │
         │ (preferência explícita / A/B)                        ▼
  [3. Otimizador Bayesiano (PairwiseGP + EUBO)] ◀── [Teste A/B Cego Nivelado]
   • Espaço de 2–4 dimensões (Graves, Agudos, Presença, Tilt)
   • Kernel produto: parâmetros de EQ × contexto (fone, tipo conteúdo, volume)
   • Questionário inicial entra como prior, nunca como regra rígida
```

---

## 2. Tradutor Texto → Delta de EQ (`EqDelta`)

Baseado nas conclusões de *LLM2Fx* (2025), *B&O* (2026) e *LILO* (2026):
1. **Operação sobre delta, não do zero:** o modelo recebe a âncora atual (resumo da curva `Gosto` + fone + até 4 bandas ativas) e devolve uma lista limitada de operações:
   - `adjust_semantic(axis: bass | warmth | presence | air, deltaDb: Float)`
   - `adjust_band(bandId, deltaFcHz, deltaGainDb, deltaQ)`
   - `add_filter(type: peaking | lowShelf | highShelf, fcHz, gainDb, q)`
   - `remove_filter(bandId)`
2. **Desambiguação de termos vagos:** quando o prompt usa adjetivos de alta variância na literatura (*SAFE* / *SocialEQ*, como `"quente"`, `"aberto"`, `"natural"`), em vez de impor uma única curva arriscada, o sistema gera **duas interpretações candidatas A e B** e abre o comparador nivelado para o usuário escolher em 5 segundos.
3. **Orçamento de contexto (Apple Foundation Models):** janela máxima de **4.096 tokens** (`TN3193`). O prompt de sistema + estado compacto do EQ ocupa < 700 tokens, garantindo inferência rápida on-device via `@Generable` sem fallback oculto para nuvem.
4. **Explicação transparente e desfazer:** toda mudança aplicada exibe o que mudou em português claro (*"−2,5 dB em 6,8 kHz (Q 2,2) para reduzir sibilância; preamp ajustado para −4,1 dB"*) com botão **Desfazer** e **A/B antes/depois**.

---

## 3. Aprendizado Contínuo por Otimização Bayesiana (`PairwiseGP`)

### Por que 2–4 dimensões (e não 10 bandas livres)?
A literatura de preferência da Harman (Olive & Welti) e os estudos com `PairwiseGP` (Widex SoundSense Learn, Nielsen et al., Ni et al.) mostram que a preferência pessoal sobre uma correção neutra converge em **10–20 comparações A/B** quando o espaço é compacto (2–4 eixos perceptuais), enquanto 10+ bandas livres sofrem maldição da dimensionalidade e inconsistência do ouvinte.

### Espaço de busca e Kernel
- **Dimensões:**
  1. `bass_shelf_db` (`−6` a `+9 dB` em `~105 Hz`)
  2. `treble_tilt_db` (`−6` a `+6 dB` em inclinação de agudos)
  3. `presence_db` (`−4` a `+4 dB` em `~3 kHz`)
  4. (Opcional no modo estendido) `warmth_db` (`−4` a `+4 dB` em `~250 Hz`)
- **Função de aquisição:** EUBO (*Expected Utility of the Best Option*) escolhendo o próximo par `(x_A, x_B)` a partir de um Processo Gaussiano com verossimilhança probit (modelando ruído humano $\sigma$ explicitamente).
- **Hierarquia de contexto:**
  1. **Fone + transporte** (âncora mais forte)
  2. **Tipo de conteúdo** (estéreo musical vs. espacial/binaural vs. voz/reunião — sustentado por Engel et al. 2020)
  3. **Faixa de volume** (compensação perceptual em escuta baixa)
  4. **Gênero musical:** só entra se dados reais do próprio usuário mostrarem divergência consistente (evidência científica populacional é fraca, p = 0,19).

### Questionário Inicial e Perfil Auditivo Relativo
- **Questionário (onboarding opcional):** coleta apenas idade aproximada, preferência declarada de graves/brilho e sensibilidade à fadiga. Entra **exclusivamente como prior** deslocando a média inicial da busca bayesiana.
- **Teste auditivo relativo (pós-1.0):** gera tons senoidais para mapear **assimetrias L/R** e **limiares relativos** entre bandas (nunca exibe "dB HL" nem alega diagnóstico médico). Serve como teto de segurança (ex.: não impulsionar +8 dB numa região onde o usuário tem sensibilidade elevada ou queda acentuada).
