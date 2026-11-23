# Segurança, Privacidade, Direitos e Distribuição

> **Produto:** **`timbr`** ([ADR-0014](../07-decisoes/ADR-0014-nome-identidade-e-i18n.md)) · **Princípios vinculados:** P7 (*Local primeiro, privado por padrão*), P3 (*Nunca deixar rastro*), P12 (*Open source sustentável*), [ADR-0001](../07-decisoes/ADR-0001-licenca.md), [ADR-0007](../07-decisoes/ADR-0007-distribuicao.md), [ADR-0008](../07-decisoes/ADR-0008-ia-propoe-dsp-decide.md).

---

## 0. Estado implementado (2026-11-23)

- **Acessibilidade** é usada para duas coisas: interceptar as teclas de volume, mudo e brilho (`CGEventTap`, com HUD no notch) e ler os menus do app em primeiro plano, para medir o espaço livre da barra (orelhas do notch). Sem ela, as teclas seguem o HUD do macOS e a orelha esquerda é tratada como ocupada.
- **A permissão é presa à assinatura (Comprovado).** Em builds ad-hoc, o TCC guarda o `cdhash`, e cada build novo perde a permissão em silêncio. Por isso existe `scripts/setup_dev_signing.sh`: identidade local num keychain próprio, com senha em `~/.timbr-dev/` (modo 600), nunca no repositório. Se o app percebe que a permissão sumiu, ele registra o evento e pede de novo.
- **Brilho** via `DisplayServices` (framework privado, buscado em runtime), com IOKit de reserva. Se não der para ler o brilho, a tecla segue para o macOS.
- **Gravação de áudio do sistema:** qualquer tap acende o ponto roxo do macOS e marca o processo do timbr como "usando entrada" (`IsRunningInput = 1`), sem usar o microfone. O tap global só existe com áudio tocando.
- **Helper XPC do motor completo (§3.2): não implementado**; o motor de áudio roda no processo do app. Existe um auxiliar dedicado e isolado (`timbr-mute-keeper`, ADR-0017) apenas para sustentar mutes persistentes em falha.
- **Alvo de sistema e verificação binária:** `build_app.sh` compila app, C++ e `timbr-mute-keeper` com `-target <arch>-apple-macosx15.0` e `Info.plist` em `15.0`, conferidos no CI por `scripts/check_deployment_target.py`.
- **Feedback local sem telemetria (ADR-0024):** a seção de feedback só abre o cliente de e-mail local do usuário (`mailto:`) com prévia transparente e contexto mínimo opcional (versão, macOS, tipo de saída, modo EQ, idioma) — nunca envia dados em segundo plano.

---

## 1. Privacidade e Processamento Local

1. **Processamento 100% local por padrão:** mixer, DSP, AutoEq em cache, otimização bayesiana (`PairwiseGP`), análise espectral e detecção de contexto rodam integralmente no Mac, sem exigir conta ou rede.
2. **Zero gravação de áudio:** buffers de áudio capturados via process taps ou microfone existem apenas em memória transitória (ring buffers de milissegundos). **É proibido gravar áudio em disco**, exceto mediante ação explícita de diagnóstico/exportação iniciada pelo usuário (e com arquivo salvo em pasta escolhida por ele).
3. **Minimização de dados locais:** histórico de preferências e eventos do Observatório ficam em banco SQLite local (Application Support), com opção de limpar histórico e exportar/deletar perfil em um clique.
4. **Inteligência e rede (opt-in explícito):**
   - Runtime primário: **Apple Foundation Models** on-device (sem saída de rede).
   - Runtime secundário local: Ollama / LM Studio em `127.0.0.1`.
   - Nuvem (chave do usuário, opt-in): envia **apenas texto do pedido + parâmetros numéricos de EQ**, nunca áudio, títulos privados ou dados de microfone.
5. **Reconhecimento e letras:**
   - ShazamKit envia apenas assinaturas acústicas (hashes espectrais), não áudio bruto, e só quando o usuário aciona o reconhecimento.
   - Letras (LRCLIB) buscam por artista/faixa somente se a função estiver ligada; fontes não oficiais ficam desligadas por padrão.

---

## 2. Gestão Transparente de Permissões (TCC / macOS)

Nenhuma permissão é solicitada no primeiro arranque. Cada pedido abre uma explicação curta antes do prompt do sistema dizendo **por que precisa**, **o que funciona sem ela** e **o que o Timbre nunca faz**:

| Permissão | Chave / Mecanismo | Quando pedir | Degradação graciosa se negada |
|---|---|---|---|
| **System Audio Recording Only** | `NSAudioCaptureUsageDescription` | Ao ativar pela 1ª vez volume por app, EQ ou espectro | Controle completo de dispositivos HAL + now playing continua funcionando; detector avisa se buffers vierem zerados |
| **Acessibilidade** | `AXIsProcessTrustedWithOptions` | Ao ligar "Controlar volume com teclas de mídia + HUD no notch" | Teclas continuam usando o HUD nativo do macOS |
| **Bluetooth** | `NSBluetoothAlwaysUsageDescription` | Ao habilitar um driver de fabricante (ex.: Momentum 4) | Fone opera normalmente como dispositivo HAL genérico |
| **Automation** | `NSAppleEventsUsageDescription` | Ao ativar controle de sessão não-eleita (Music/Spotify) | Controle apenas da sessão eleita via MediaRemote |
| **Microfone** | `NSMicrophoneUsageDescription` | Ao acionar Shazam pelo mic ou teste auditivo guiado | Reconhecimento continua disponível para o áudio do sistema |

---

## 3. Segurança do Código, Comunicação IPC e Parsers

1. **Comunicação com Extensões de Navegador:** se via WebSocket em `127.0.0.1`, exige token efêmero de sessão por arranque + validação estrita de `Origin` (apenas IDs conhecidos das extensões oficiais do Timbre); preferir **Native Messaging** quando disponível no navegador.
2. **Helper do Motor (ADR-0006):** comunicação XPC validada por code-signing requirement (`NSXPCConnection` verificando Team ID / `cdhash` idêntico entre UI e helper).
3. **Parsers como entrada não confiável (ADR-0009):** importadores de EqualizerAPO `.txt`, CamillaDSP `.yaml`, AutoEq e WAV IR impõem limite de tamanho de arquivo, profundidade máxima, validação de range finito (`!isNaN`, `!isInfinite`) e cobertura por fuzzing no CI.
4. **Thread de áudio isolada:** nenhuma alocação, chamada ObjC dinâmica ou I/O de arquivo na thread RT.

---

## 4. Direitos Autorais, DRM e APIs de Terceiros

- **DRM (FairPlay / Widevine):** process taps capturam o mixdown pós-decodificação do processo cliente dentro do Core Audio. Apps que bloqueiam captura por política de proteção de conteúdo ou entram em **hog mode** exclusivo são respeitados (não tentar burlar DRM).
- **Streaming APIs:** não depender da Web API do Spotify (restrita a 5 usuários em Dev Mode desde fev/2026). Usar controles locais do sistema e metadados públicos quando disponíveis.
- **Medições de Fones (AutoEq / squig.link / GraphWorks):** respeitar termos de cada banco; buscar índice sob demanda no dispositivo do usuário e exibir crédito visível da fonte e do equipamento de medição. Não redistribuir bancos pagos/restritos.
- **Letras:** LRCLIB não declara licença de texto das letras; buscar sob demanda no cliente, com cache temporário local e nunca redistribuir corpus.

---

## 5. Assinatura, Notarização, Atualizações e Cadeia de Suprimentos

- **Assinatura e Notarização:** `Developer ID Application` + **Hardened Runtime** + `notarytool` + `stapler` em todo release (obrigatório inclusive para que a identidade TCC dos taps permaneça estável entre atualizações).
- **Atualizações:** **Sparkle 2** com assinatura EdDSA obrigatória e appcast servido exclusivamente via HTTPS, com canais `stable` e `beta` opt-in.
- **Distribuição paralela:** cask oficial no Homebrew, checksums SHA-256 publicados e **SBOM** (Software Bill of Materials) anexado a cada tag.
- **Supply Chain:** dependências SwiftPM, Rust/Cargo e Python/npm pinadas por commit/hash exato (ex.: `libraries.dev`, `mediaremote-adapter`), sem tags móveis; builds reproduzíveis no GitHub Actions.
