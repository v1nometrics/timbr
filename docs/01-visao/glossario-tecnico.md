# Glossário técnico e vocabulário controlado

> Este documento define o que cada termo **significa tecnicamente** e **em que condições** podemos usá-lo na UI, nos docs e no marketing. Se uma condição não for satisfeita, o termo não pode aparecer.

## Termos de fidelidade

| Termo | Definição técnica | Quando o Timbre pode afirmar | Quando é proibido |
|---|---|---|---|
| **Bit-perfect** | As amostras que chegam ao conversor do dispositivo são idênticas, bit a bit, às amostras decodificadas da fonte. | Só quando: nenhum tap ativo no caminho daquele app, volume digital do app em 1.0 (ou volume em hardware), taxa do dispositivo igual à da fonte, nenhum mixer somando outra fonte, formato inteiro ou float com ganho unitário **comprovado** por null test (E-01). | Com qualquer EQ, volume por app ≠ 1.0, reamostragem, saída Bluetooth (o codec já recodifica), ou enquanto E-01 não provar transparência do caminho float. |
| **Lossless (sem perdas)** | Propriedade da **codificação da fonte** (ALAC, FLAC, PCM). Não descreve o caminho até o ouvido. | "Fonte sem perdas" quando o player informar (MusicKit `audioVariants`, TIDAL `mediaTags`, Music.app `sample rate`). | Para qualquer saída Bluetooth (AAC/SBC são codecs com perdas) e como adjetivo do app. |
| **Hi-Res** | Fonte com taxa > 48 kHz e/ou profundidade > 16 bits. | "Fonte Hi-Res 24/96" quando os metadados vierem de fonte confiável. | Para descrever o que o fone Bluetooth recebe. |
| **Transparente** | O processamento não produz diferença mensurável acima de um limiar definido em relação ao bypass. | Quando o null test residual estiver abaixo do limiar documentado em `06-plano/estrategia-de-testes.md`, com o método publicado. | Como afirmação genérica de qualidade. |
| **Bypass verdadeiro** | O nó de processamento é **removido** do grafo (o tap é destruído, o áudio volta ao caminho nativo). | Botão "Desligar processamento". | — |
| **Bypass unitário** | O nó continua no grafo com ganho 1.0 e filtros neutros. Serve para A/B sem trocar o grafo. | Sempre rotulado como "A/B (processamento neutro)". | Chamado de "bypass" sem qualificação. |
| **Hi-Fi** | Termo de marketing sem definição técnica. | Nunca na UI. Nos docs, só entre aspas para citar terceiros. | Sempre. |

## Termos de nível e ganho

| Termo | Definição | Observação |
|---|---|---|
| **dBFS** | Decibéis relativos ao fundo de escala digital (0 dBFS = maior valor representável). | Base de todos os medidores internos. |
| **dBTP (true peak)** | Pico estimado entre amostras, após sobreamostragem (ITU-R BS.1770). | Um sinal pode ter pico de amostra −0,1 dBFS e true peak +1,5 dBTP. |
| **LUFS / LKFS** | Loudness integrado ponderado K (ITU-R BS.1770 / EBU R128). | Medidores M (400 ms), S (3 s), I (integrado). |
| **Preamp / headroom** | Ganho negativo aplicado antes do EQ para que boosts não clipem. | Calculado pelo **máximo da resposta somada** dos filtros + margem, nunca pela maior banda. |
| **Gain staging** | A sequência de ganhos ao longo da cadeia: fonte → volume do app → EQ do app → soma → EQ do dispositivo → limiter → volume do dispositivo. | Cada estágio é exibido no Observatório. |
| **Volume alto (regra 60/60)** | Volume do Mac a partir de 60%, regra prática dos audiologistas: no máximo 60 minutos seguidos, depois 15 a 20 de descanso. | **Não é decibel.** Cada fone responde diferente; o timbr conta minutos e volume, nunca "dB". |
| **Silêncio medido** | Pico do nosso DSP abaixo de −75 dB por 1 s num tap ativo. | Só existe com tap; sem ele vale o aviso do macOS, que atrasa 2 a 8 s. |
| **dB SPL estimado** | Pressão sonora estimada a partir de dBFS + volume + sensibilidade do fone. | **Sempre "estimado"**. Erros de ±6 dB ou mais são esperados sem calibração. |

## Termos de DSP

| Termo | Definição |
|---|---|
| **Biquad** | Filtro IIR de 2ª ordem; bloco básico do EQ paramétrico. |
| **RBJ cookbook** | Fórmulas de Robert Bristow-Johnson para coeficientes de biquad via transformada bilinear (W3C Audio EQ Cookbook). |
| **Cramping** | Deformação da resposta perto de Nyquist causada pela transformada bilinear. |
| **Filtro casado (matched)** | Desenho que reproduz a magnitude analógica em pontos-chave (Vicanek, Orfanidis), reduzindo cramping. |
| **Fase mínima / fase linear** | Mínima: latência zero, fase varia com a frequência. Linear: fase constante, custa latência e pré-ringing. |
| **Q / BW / slope** | Três convenções para a largura de um filtro. Conversões explícitas, nunca implícitas (ver formatos de preset). |
| **Null test** | Inverter a fase de uma saída e somar com outra; o resíduo mede a diferença. |
| **THD+N** | Distorção harmônica total mais ruído, relativa ao sinal. |
| **Dither** | Ruído adicionado ao reduzir profundidade de bits para descorrelacionar o erro de quantização. |
| **SRC** | Conversão de taxa de amostragem (reamostragem). |

## Termos de plataforma

| Termo | Definição |
|---|---|
| **Process tap** | API do Core Audio (macOS 14.2+, `AudioHardwareCreateProcessTap`) que captura a saída de processos e, com `mutedWhenTapped`, silencia o original. |
| **Aggregate device privado** | Dispositivo virtual criado por um processo, invisível aos outros apps, que combina taps e dispositivos reais. Desaparece quando o processo morre. |
| **AudioServerPlugIn (HAL plug-in)** | Driver em espaço de usuário carregado pelo `coreaudiod`; cria dispositivos virtuais visíveis a todos. Exige instalação como admin. |
| **Hog mode** | Um processo toma posse exclusiva de um dispositivo. |
| **A2DP / HFP** | Perfis Bluetooth: A2DP é estéreo de alta qualidade só de saída; HFP é bidirecional para chamadas, mono e com banda estreita. |
| **GAIA** | Protocolo de controle de fones com chip Qualcomm, usado por vários fabricantes sobre RFCOMM ou BLE. |
| **TCC** | Transparency, Consent and Control: o sistema de permissões do macOS. |

## Vocabulário de UI (como chamamos as coisas)

| Nome | O que é |
|---|---|
| **Notch** | Superfície principal: estados repouso, compacto, espiada e expandido. |
| **Estúdio** | Janela de configuração avançada (EQ detalhado, perfis, drivers, preferências). |
| **Observatório** | Painel de diagnóstico do caminho do sinal. |
| **Guardião** | O serviço que detecta degradações e avisa. |
| **Fonte** | App, processo ou aba que produz áudio. |
| **Destino** | Dispositivo de saída físico ou grupo de saídas. |
| **Cena** | Perfil salvo: volumes, rotas, EQs e regras, aplicável manualmente ou por regra. |
| **Correção** | A curva objetiva do fone (AutoEq/medição). |
| **Gosto** | A camada subjetiva do usuário sobre a correção. Correção e Gosto nunca se misturam no armazenamento. |
