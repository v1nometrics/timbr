# Plano de experimentos e provas de conceito

> Status: v1.0 · 2026-11-21. Cada experimento responde uma pergunta que **decide arquitetura** ou **derruba uma promessa**. Nenhum código de produto é escrito antes de os experimentos do Gate G1 terem resultado registrado.
>
> Regras: (1) cada experimento vive em `experiments/E-XX-nome/` com README, código descartável e `RESULTADO.md`; (2) resultados usam as classes de evidência do `AGENTS.md`; (3) "não deu tempo de medir" é um resultado válido, inventar número não é; (4) todo experimento registra máquina, versão exata do macOS, dispositivos e data.

## Bancada de referência (hardware do dono)

| Item | Uso nos experimentos |
|---|---|
| MacBook com notch (modelo e macOS registrados no início) | Plataforma principal |
| Sennheiser Momentum 4 Wireless | Bluetooth premium, protocolo do fabricante, cabo 3,5 mm, USB-C |
| AirPods Pro | Bluetooth Apple, troca automática entre aparelhos |
| Alto-falantes internos | Caso base |
| (desejável) DAC USB com fone com fio, ou interface de áudio | Bit-perfect, taxas altas, volume em software |
| (desejável) Monitor HDMI/DisplayPort com áudio | Volume em dispositivos sem controle de hardware |
| (desejável) Segundo Mac ou VM com macOS 14.4 | Piso de compatibilidade |
| BlackHole 2ch (instalado só na bancada) | Loopback para medições digitais |

## Ferramentas de medição

Ver `06-plano/estrategia-de-testes.md` para o método completo. Resumo: sinais de teste gerados (seno 997 Hz, varreduras log, ruído rosa, multitom), captura digital por loopback (BlackHole) para medições de bit e resposta, `sox`/`ffmpeg` (`astats`, `ebur128`), scripts Python (`numpy`, `scipy`) versionados no repositório, Instruments (Time Profiler, Energy Log) e `powermetrics` para CPU e energia.

---

## Gate G1: as seis provas de risco

O Gate G1 corresponde aos seis riscos que o dono priorizou. A arquitetura só é decidida (ADRs passam de "Proposto" para "Aceito") quando cada linha abaixo tiver resultado.

| Risco do dono | Experimentos | Critério para avançar |
|---|---|---|
| 1. Volume granular por app | E-01, E-02, E-03 | Volume por app sem glitch audível em 1 h de uso misto; fail-safe comprovado; estouro inicial medido e com mitigação escolhida |
| 2. Controle por aba e várias saídas | E-04, E-05 | Multissaída estável 1 h; extensão de pelo menos um navegador atenuando por aba; decisão documentada sobre boost/EQ/rota por aba |
| 3. DSP transparente em escala de sistema | E-01, E-06 | Null test do caminho neutro documentado; precisão do EQ dentro da tolerância; linguagem do núcleo DSP decidida |
| 4. Bluetooth confiável | E-07, E-08 | Matriz de capacidades preenchida para cada dispositivo; detecção de HFP funcionando; política anti-HFP validada |
| 5. Integração com o Momentum 4 | E-09 | Leitura segura de estado (bateria, ANC, EQ) funcionando no macOS, ou inviabilidade documentada |
| 6. Tudo junto sem conflito | E-10, E-11 | 24 h de soak com a cadeia completa e a matriz de coexistência preenchida |

---

## Experimentos

### E-01 · Transparência do caminho e fail-safe
- **Pergunta.** Um tap com ganho 1.0, taxa casada e sem filtros é bit-transparente? O que acontece quando o tap é criado/destruído durante a reprodução? O som volta se o processo morrer?
- **Por que decide.** Define se o "A/B neutro" pode manter o tap vivo (latência estável) ou se o neutro exige destruir o tap; valida o princípio P2.
- **Método.** App de teste toca um arquivo de referência (PCM 16/44.1, 24/96) em um player controlado; capturar a saída por BlackHole (a) sem tap, (b) com tap unitário, (c) com tap + EQ neutro, (d) com tap + EQ ativo; null test amostra a amostra após alinhamento. Criar/destruir o tap 100 vezes durante a reprodução e registrar picos/descontinuidades. `kill -9` no processo do motor 20 vezes e medir tempo até o som voltar e nível do primeiro bloco.
- **Sucesso.** (a)≡(b) bit a bit **ou** resíduo documentado e explicado; transições sem pico acima do nível do programa; som volta sem estouro.
- **Se falhar.** O botão "Desligar processamento" destrói o tap; A/B usa dois caminhos pré-aquecidos.

### E-02 · Mixer por app: topologia e estouro inicial
- **Pergunta.** Qual estratégia elimina os 200–500 ms iniciais sem processamento: tap preguiçoso (cria ao detectar `IsRunningOutput`), captura antecipada com ganho 1.0 (PerAppVolume), `bundleIDs` + `isProcessRestoreEnabled` (macOS 26), ou tap global com exclusão?
- **Método.** Para Music, Spotify, Safari, Chrome, Slack, Zoom: medir por loopback a janela entre o primeiro som e o primeiro bloco processado (EQ com corte forte em 1 kHz torna a janela visível no espectrograma). Testar mapeamento de processos auxiliares para o app pai.
- **Sucesso.** Estratégia com janela ≤ 1 buffer de IO em todos os apps testados no macOS 26+, e plano para 14.4–15.
- **Saídas.** ADR-0004 (topologia do motor) e ADR-0005 (piso de macOS).

### E-03 · Resiliência
- **Pergunta.** O motor sobrevive a sleep/wake, troca e desconexão de dispositivos, reinício do `coreaudiod`, buffers zerados do 26.x/27.x?
- **Método.** Roteiro automatizado de 24 h: ciclos de sleep/wake (`pmset`), `sudo killall coreaudiod`, conectar/desconectar fones, alternar saída padrão; detector de silêncio inesperado e de descontinuidades na captura de controle; watchdog com teardown/rebuild.
- **Sucesso.** Zero silêncio não intencional > 2 s sem recuperação automática; nenhum dispositivo ou aggregate órfão ao final; snapshot do sistema igual ao inicial.

### E-04 · Várias saídas, alinhamento e ducking
- **Pergunta.** A topologia "um motor por dispositivo físico" é estável com fio + Bluetooth ao mesmo tempo? Dá para alinhar latência? Dá para fazer ducking sem tapear o app de chamada?
- **Método.** Fonte em duas saídas (fone USB/3,5 mm + Momentum 4); medir drift em 1 h; testar compensação de atraso manual e por latência reportada; ducking de música disparado por `IsRunningOutput` do Zoom/Meet sem tap nele.
- **Sucesso.** 1 h sem glitch; drift controlado; ducking funcionando com rampa sem afetar o eco do app de chamada.

### E-05 · Controle por aba
- **Pergunta.** Até onde chegamos por aba em Safari, Chrome/Arc/Brave e Firefox: atenuação, boost, EQ, mute, rota para outra saída?
- **Método.** Três spikes: (1) Safari Web Extension que intercepta `HTMLMediaElement.volume` e fala com o app por canal autenticado em `127.0.0.1` ou native messaging; (2) extensão MV3 com `chrome.tabCapture` + offscreen document + `AudioContext` (ganho, EQ) + `setSinkId`; (3) Firefox com native messaging. Medir latência e a UX do gesto obrigatório.
- **Sucesso.** Pelo menos atenuação/mute por aba em Safari e Chrome com identificação da aba no notch. Boost/EQ/rota registrados como possível/impossível com evidência.

### E-06 · Núcleo DSP: precisão, desempenho e linguagem
- **Pergunta.** Float32 vs Float64 importa para EQs típicos de fone? Filtros casados vs RBJ? Qual implementação: Swift + `vDSP_biquadD`, C++ próprio, ou crate do CamillaDSP v5 sob MPL-2.0?
- **Método.** Golden tests offline: renderizar impulsos e varreduras pelo kernel e comparar com a resposta analítica (magnitude e fase) em 44,1/48/96/192 kHz; ruído e THD+N de um preset AutoEq típico e de um shelf de 20 Hz com Q alto; CPU por estéreo em buffer de 512 com 10 e 20 bandas; verificar se o crate `camilladsp` está publicado e utilizável.
- **Sucesso.** Erro de magnitude ≤ tolerância definida em `estrategia-de-testes.md` até 20 kHz; ruído adicionado abaixo do limiar documentado; CPU por instância dentro do RNF. Saída: ADR-0003 (núcleo DSP).

### E-07 · Sonda de capacidades de dispositivos
- **Pergunta.** Que propriedades cada dispositivo real expõe e permite gravar?
- **Método.** Ferramenta CLI que enumera todos os dispositivos e propriedades HAL (`HasProperty`, `IsPropertySettable`, valores, formatos, fontes de dados, latências) e salva JSON. Rodar em: interno, Momentum 4 (BT e USB e analógico, se aplicável), AirPods Pro, DAC USB, HDMI, aggregate.
- **Sucesso.** `03-viabilidade/matriz-de-dispositivos.md` preenchida com dados reais (não inferidos).

### E-08 · Guardião Bluetooth: HFP e codec
- **Pergunta.** Detectamos de forma confiável a queda A2DP→HFP? Conseguimos evitá-la? O codec é observável?
- **Método.** Abrir microfone em Zoom/Meet/FaceTime com o Momentum 4 e AirPods como saída; observar mudanças de formato/taxa/streams no HAL; testar política "entrada padrão = mic interno"; investigar `system_profiler SPBluetoothDataType` e `log stream` dos subsistemas Bluetooth para codec.
- **Sucesso.** Detector com zero falso negativo em 20 eventos; política documentada; codec classificado como observável/inferível/inacessível.

### E-09 · Momentum 4: protocolo no macOS (laboratório)
- **Pergunta.** Um app de Mac consegue falar o protocolo de controle do Momentum 4 enquanto ele está conectado para áudio?
- **Método.** Seguir `03-viabilidade/momentum4-laboratorio.md`: (1) descoberta SDP/serviços; (2) abrir o canal só para **leitura** (bateria, versão de firmware, estado de ANC, EQ); (3) só depois, escritas reversíveis e de baixo risco (ligar/desligar ANC), com restauração do estado inicial; (4) nunca tocar firmware, pareamento ou fábrica.
- **Sucesso.** Leituras funcionando e documentadas, ou bloqueio documentado com a causa.

### E-10 · Coexistência
- **Pergunta.** O Timbre convive com SoundSource, Loopback, FineTune, OBS, Zoom/Meet/Teams, Discord, BlackHole, players em hog mode, troca automática dos AirPods?
- **Método.** Matriz app × cenário (instalado, ativo, capturando), observando bloqueio de `AudioDeviceStart`, áudio duplicado, eco, quebra de troca automática.
- **Sucesso.** Matriz preenchida; lista de "ignorar por padrão" definida; avisos de conflito especificados.

### E-11 · Cadeia completa (dogfood)
- **Pergunta.** Tudo junto, no uso real do dono, funciona sem conflito?
- **Método.** Protótipo integrado (mixer + EQ + multissaída + guardião BT + leitura do M4) em 72 h de uso real + 24 h de soak automatizado; registro de cada incidente.
- **Sucesso.** Zero incidente de áudio corrompido não explicado; todos os incidentes com causa e plano.

### E-12 · Casca do notch: custo e geometria
- **Pergunta.** Qual o custo em repouso (CPU, energia, wakeups) da casca do notch? A geometria está correta em cada modelo? Como coexistir com a Dynamic Island do MacBook Pro OLED?
- **Método.** Instruments + `powermetrics` em repouso e em animação; medição em todos os modelos disponíveis; pesquisa/teste em hardware OLED se acessível.
- **Sucesso.** Metas do RNF de repouso atendidas; plano de superfície alternativa para o OLED.

### E-13 · Texto → EQ
- **Pergunta.** O modelo on-device da Apple (Foundation Models) gera deltas de EQ válidos e plausíveis? Como se compara a um modelo local (Ollama) e a um modelo de nuvem?
- **Método.** Conjunto de 60 pedidos em PT e EN ("menos sibilância", "graves mais firmes", "vocais mais à frente"); saída estruturada; validação de esquema; avaliação cega por dono + 2 ouvintes; registrar taxa de saída inválida e concordância.
- **Sucesso.** ≥ 95% de saídas válidas pelo esquema (proposta) e preferência ≥ neutro na maioria dos pedidos concretos.

### E-14 · Aprendizado de preferência (piloto)
- **Pergunta.** Em quantas comparações A/B cegas, com volume nivelado, o otimizador converge para o dono? O resultado se repete uma semana depois?
- **Método.** GP de preferência em 3 dimensões (graves, agudos, presença) sobre a correção AutoEq do Momentum 4; 20 comparações; reteste em 7 dias.
- **Sucesso.** Diferença entre sessões menor que o passo perceptível definido; tempo total < 10 min.

### E-15 · Now playing robusto
- **Pergunta.** O `mediaremote-adapter` é estável no 26.x/27.x? Várias sessões? Qual o fallback?
- **Método.** Rodar o adaptador com Music, Spotify, Safari, Chrome, TIDAL; registrar falhas; testar AppleScript como fallback.

### E-16 · Processo do motor (in-process vs helper)
- **Pergunta.** O motor de áudio deve rodar no mesmo processo da UI ou num helper (login item/XPC)? Como fica a atribuição da permissão TCC e o isolamento de falhas?
- **Método.** Dois protótipos mínimos; medir recuperação após crash da UI, prompts de permissão, consumo.
- **Saída.** ADR-0006.

### E-17 · Viabilidade de versão "lite" na Mac App Store (opcional, pós-MVP)
- **Pergunta.** A App Review aceita um build sandbox só com taps + EQ?
- **Método.** Submissão experimental mínima.

---

## Ordem e dependências

```
Semana 1–2   E-07 ─┐        E-12
                   ├─ E-01 ─ E-02 ─ E-03
Semana 2–4   E-06 ─┘                 └─ E-04 ─ E-10
Semana 3–5   E-08 ─ E-09          E-05   E-16
Semana 5–6                E-11 (integra tudo)  →  Gate G1
Pós-G1       E-13, E-14, E-15, E-17
```

Estimativas em semanas são indicativas para uma pessoa em tempo parcial e servem para ordenar, não para prometer.
