# Requisitos Não Funcionais (RNFs) e Fronteira Local vs. Rede

> **Princípios vinculados:** P2 (*Fidelidade antes de tudo*), P3 (*Nunca deixar rastro*), P7 (*Local primeiro, privado por padrão*), [Nota 10](../00-pesquisa/notas-fase-2/10_engenharia_de_audio_qualidade_e_testes.md).
> **Regra de evidência:** Todos os números abaixo são **Metas de Projeto (Targets)** a serem medidas e validadas nos experimentos da Fase 0 e suítes do `estrategia-de-testes.md`. Nenhum número aqui é apresentado como já medido em hardware antes da execução dos testes.

---

## 1. Metas Quantitativas de Desempenho, Áudio e Confiabilidade

| Categoria | ID | Métrica | Meta (Target) | Condição de Medição / Ferramenta |
|---|---|---|---|---|
| **Transparência / Null** | RNF-01 | Caminho neutro (tudo em flat, ganho `1.0`) | **0 taps** criados quando sem fonte/EQ ativo; diferença digital `≤ −140 dBFS` quando atravessando pipeline `Float64 → Float32` a ganho `1.0` | Null test automatizado (`96 kHz/24-bit`, sweep + ruído rosa) |
| **Precisão de Filtro** | RNF-02 | Erro de magnitude do EQ paramétrico (`20 Hz–20 kHz`) | **`≤ ±0,05 dB`** em relação à curva teórica da topologia selecionada (Matched/Orfanidis ou RBJ) | Resposta ao impulso (`65536`-pt FFT) em `44.1 / 48 / 96 kHz` |
| **Distorção & Ruído** | RNF-03 | THD+N adicionado pelo motor DSP (`Float64`) | **`< −130 dB`** (abaixo do piso de 24-bit); **0 aliasing** fora de banda | Farina ESS + tom `1 kHz @ −1 dBFS` sob janela `AES17 20 kHz` |
| **Segurança de Pico** | RNF-04 | Teto True-Peak pós-limiter (`ITU-R BS.1770-5 Annex 2`) | **`≤ 0,0 dBTP`** com oversampling `4×` (100% das amostras), mesmo com entrada `+4,5 dBTP` + ganho `+6 dB` | Golden vector inter-sample stress test |
| **Tempo Real (RT)** | RNF-05 | Violações de RT safety (alocação, lock, ObjC/ARC, syscall) | **`0` violações** no callback de áudio | Build C++/Rust com **`-fsanitize=realtime` (RTSan)** no CI |
| **Estabilidade RT** | RNF-06 | Overloads / xruns em carga | **`0` overloads** por hora com 8 apps ativos + 10 bandas PEQ + FFT 120 Hz com buffer de `128 frames` | Xcode Instruments (**Audio System Trace**) |
| **Latência** | RNF-07 | Latência adicional introduzida pelo motor | **`≤ 1 buffer`** (`~2,67 ms` a `48 kHz / 128`) em modo IIR Fase Mínima; fase linear opt-in exibe latência exata em `ms` | Medição por impulso loopback |
| **CPU** | RNF-08 | Consumo de CPU do motor de áudio (Apple Silicon) | **Idle (sem áudio ativo):** `< 0,1%`; **Carga típica (2 apps + 10 bandas PEQ + notch fechado):** `< 1,5%` de 1 core; **Notch aberto com espectro 60 Hz:** `< 4%` | `powermetrics` / Instruments Time Profiler |
| **Memória** | RNF-09 | Consumo de RAM (footprint residente) | Motor de áudio `< 35 MB`; App UI + Estúdio fechado `< 90 MB`; crescimento em 24h soak `< 5 MB` | `vmmap` / Instruments Allocations |
| **Energia** | RNF-10 | Impacto energético em bateria | Impacto **`< 2%` extra de descarga/hora** com mixer + EQ ativos e notch em Repouso/Compacto (`0` timers quando sem reprodução) | `powermetrics --samplers tasks` / Energy Log |
| **Recuperação** | RNF-11 | Tempo de retorno do áudio em falha (`kill -9` no helper/app) | **`≤ 1,0 s`** para o som retornar diretamente aos apps sem intervenção manual | Experimento E-01 / Soak test automatizado |
| **Confiabilidade** | RNF-12 | Taxa de sessões sem crash & soak contínuo | Motor: `≥ 99,5%` crash-free; UI: `≥ 99,0%`; **24h soak contínuo** sem leak de `AudioObjectID` ou tap órfão | Telemetria opt-in / soak suite local |
| **UI & Motion** | RNF-13 | Fluidez visual & resposta de entrada | `60–120 fps` em gráficos/espectro; `0 ms` delay em atalhos de teclado; transições de UI `≤ 300 ms` | Instruments Core Animation / SwiftUI checklist |
| **Localização (i18n)** | RNF-14 | Idiomas completos na v1 (`MVP` → `1.0`) | **100% da interface, alertas do Guardião, onboarding, prompts TCC e catálogo de strings em `PT` (pt-BR), `ES` e `EN`** via Apple String Catalog (`.xcstrings`), com fallback seguro e formatação numérica/unidades consistente | Verificação automatizada de chaves sem tradução no CI |

---

## 2. Arquitetura Explícita: 100% Local em Essência vs. Dependências de Rede/Nuvem

> **Princípio P7 (Local primeiro, privado por padrão):** O **`timbr.`** funciona integralmente com o cabo de rede desconectado (modo avião). **Nenhuma funcionalidade central de áudio, EQ, mixagem, drivers, automação ou interface depende de nuvem, login ou telemetria.** Recursos que exigem acesso externo são **explicitamente opcionais (opt-in ou acionamento manual)** e degradam de forma silenciosa e útil offline.

| Camada / Funcionalidade | Modo de Execução | Rede Necessária? | Dependência Externa | Comportamento Offline (Sem Internet) |
|---|---|---|---|---|
| **Mixer por app / Process Taps / Multissaída** | **100% Local** (Core Audio HAL + DSP) | **Nunca** | Nenhuma | Funciona 100% idêntico. |
| **Motor DSP `Float64` (PEQ, Matched, Limiter, Crossfeed, FIR)** | **100% Local** (RT em memória) | **Nunca** | Nenhuma | Funciona 100% idêntico. |
| **Observatório da Cadeia + Medidores EBU R128 / dBTP + FFT** | **100% Local** | **Nunca** | Nenhuma | Funciona 100% idêntico. |
| **Guardião de Qualidade (G-01..G-07) + Snapshot/Restore** | **100% Local** | **Nunca** | Nenhuma | Funciona 100% idêntico. |
| **Drivers Bluetooth/USB (Momentum 4 GAIA v3, HAL)** | **100% Local** (`IOBluetooth` / `CoreAudio`) | **Nunca** | Nenhuma (apenas link local com o fone) | Funciona 100% idêntico. |
| **Extensões de Navegador (Safari/Chrome volume por aba)** | **100% Local** (`127.0.0.1` / Native Messaging) | **Nunca** | Nenhuma (loopback local) | Funciona 100% idêntico. |
| **Cenas, Automações, Presets JSON, SQLite & Treinador Bayesiano (`PairwiseGP`)** | **100% Local** | **Nunca** | Nenhuma | Funciona 100% idêntico. |
| **Assistente IA de EQ (modo primário)** | **100% Local** | **Nunca** | **Apple Foundation Models** (on-device) ou **Ollama / LM Studio** (`127.0.0.1`) | Funciona 100% offline com modelos locais. |
| **Perfis AutoEq em cache + presets embutidos** | **Local** (cache TTL 7d + pacote básico embutido) | Não após cache | Cache local em `Application Support` | Usa base embutida + perfis já baixados em cache. |
| **Sincronização do catálogo completo AutoEq (`EP-04`)** | **Rede sob demanda (opt-in)** | Sim (HTTPS GET read-only) | Repositório/índice público AutoEq | Mostra aviso *"Offline — usando catálogo local em cache"*; nunca bloqueia uso do EQ. |
| **Letras sincronizadas (`EP-11`, RF-1104)** | **Rede sob demanda (opt-in)** | Sim (HTTPS GET por artista/faixa) | **LRCLIB API** | Exibe cache local se já buscado antes; senão oculta aba de letra graciosamente. |
| **Reconhecimento acústico (`EP-11`, RF-1105)** | **Híbrido (assinatura local → match remoto)** | Sim, apenas ao clicar *"Identificar"* | **Apple ShazamKit** (envia apenas hash espectral, nunca áudio bruto) | Botão informa *"Sem conexão para identificar faixa"*. |
| **Scrobbling opcional (`EP-11`, RF-1106)** | **Rede opt-in** | Sim (HTTPS POST com token do usuário) | **ListenBrainz** / Last.fm | Enfileira localmente ou desativa sem perda de reprodução. |
| **LLM em Nuvem BYOK (`EP-12`, fallback opcional)** | **Rede opt-in com chave do usuário** | Sim (HTTPS API do provedor escolhido) | OpenAI / Anthropic / Google (chave própria do usuário) | Volta automaticamente para Apple Foundation Models / Ollama ou sugestões determinísticas locais. |
| **Atualizações automáticas (`EP-14`)** | **Rede opt-in (Sparkle 2 HTTPS + EdDSA)** | Sim (check periódico ou manual) | Appcast HTTPS assinado (`timbr.`) + Homebrew | Ignora silenciosamente até próxima conexão; nunca impede abertura do app. |

---

## 3. Segurança Operacional e Privacidade (Resumo NFR)

- **Zero áudio em disco:** nenhum buffer PCM capturado pode ser persistido em arquivo sem ação explícita de diagnóstico iniciada pelo usuário.
- **Zero conta / login obrigatório:** o app abre direto em produção local sem cadastro, sem telemetria obrigatória e sem SDKs de analytics de terceiros.
- **Sandbox e permissões justificadas:** cada pedido TCC exibe pré-modal explicando escopo e degradação graciosa antes do prompt nativo da Apple.
