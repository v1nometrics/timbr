# ADR-0009 · Formato de presets

- **Status:** Aceito · 2026-11-21

## Decisão

- **Formato nativo:** JSON versionado (`timbre.preset/v1`) que guarda a **intenção**, não coeficientes: tipo de filtro, Fc, ganho, Q (com a convenção declarada), método de desenho (RBJ, casado, sobreamostrado), preamp e política de preamp, alvo, fonte da medição, fone, camada (Correção ou Gosto), histórico de versões e hash. Coeficientes são recalculados para cada taxa de amostragem.
- **Intercâmbio (importar e exportar):**
  1. EqualizerAPO ParametricEQ (`Preamp:` / `Filter N: ON PK Fc … Gain … Q …`), o padrão de fato (AutoEq, REW, FineTune, Wavelet via conversão).
  2. AutoEq GraphicEQ (127 pontos), convertido para PEQ por otimização local.
  3. CamillaDSP YAML (filtros Biquad).
  4. WAV de resposta ao impulso (para convolução, quando existir).
- **Conversões Q/BW/slope explícitas**, com teste de ida e volta para cada formato.
- Parsers tratam entrada como não confiável: limites de tamanho, fuzzing no CI.

## Motivo

Guardar intenção permite recomputar com outro método de desenho ou taxa sem perda e torna o histórico legível. O formato do EqualizerAPO é o que a comunidade já usa.
