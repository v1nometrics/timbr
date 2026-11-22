# Especificação funcional

> Status: v1.2 · 2026-11-23 (§3 reescrita com o comportamento implementado; §4, §10 e §11 atualizadas) · Produto: **`timbr.`** ([ADR-0014](../07-decisoes/ADR-0014-nome-identidade-e-i18n.md)) · Localização v1: **`PT / ES / EN`**. Descreve **comportamento**. A aparência está no design system (`05-design-system/`). Os IDs RF-xxxx vêm do PRD.

## 1. Modelo de domínio

```
Fonte (app | processo auxiliar | aba)
  ├─ volume (0…1, boost até +12 dB), mute, solo
  ├─ rotas → [Destino]                     (1..n)
  └─ EQ da fonte (opcional, P1)

Destino (dispositivo físico | grupo de saídas)
  ├─ volume do destino, mute, balanço
  ├─ Correção (fone + alvo + fonte de medição)   ← ADR-0010
  ├─ Gosto (controles semânticos | PEQ livre)
  ├─ Proteções (limiter true-peak)
  └─ Capacidades (sondadas em runtime)

Dispositivo (UID estável) ── Driver de fabricante (opcional)
Cena = snapshot {fontes, destinos, rotas, EQs, regras}
Regra = gatilho → condição → ação
Evento = registro imutável na linha do tempo do Observatório
```

Identidade: dispositivos por **UID** (nunca por `AudioObjectID`, que muda); apps por **bundle ID**; abas por (navegador, id da aba, origem). Preferências persistem por essas chaves.

## 2. Ciclo de vida do processamento (P1, P2, P3)

| Situação | O que o motor faz |
|---|---|
| Fonte em 100%, sem EQ de fonte, na saída padrão, destino sem EQ | **Nenhum tap.** Caminho nativo do macOS. |
| Destino com EQ ativo | Tap global do destino (exclui o próprio Timbre e a lista "nunca tocar"), um motor por destino |
| Fonte com volume ≠ 100%, mute, rota diferente ou EQ próprio | Tap da fonte no motor do destino |
| Usuário aperta "Desligar processamento" | Todos os taps destruídos com rampa de saída; sistema volta ao estado nativo |
| Motor morre | O mute dos taps acaba e o som volta direto (garantia da plataforma); a UI mostra "processamento interrompido" e o watchdog tenta reconstruir uma vez a cada 30 s no máximo |
| App encerrado normalmente | Rampa de saída, destrói taps e aggregates, restaura dispositivo padrão e volumes do snapshot inicial se tiverem sido alterados pelo Timbre |

**Snapshot do sistema:** no primeiro start e antes de cada mudança de configuração do sistema feita pelo Timbre (dispositivo padrão, taxa, volume de hardware), o estado anterior é gravado. Sair/desinstalar restaura o snapshot do que o Timbre alterou, e apenas disso.

## 3. Notch: estados e transições

> Comportamento implementado e verificado em 2026-11-23. Geometria, motion e regra das asas em [`05-design-system/03`](../05-design-system/03-superficies-e-anatomia.md) e [`02`](../05-design-system/02-motion-e-fisica.md).

| Estado | Gatilho de entrada | Conteúdo | Saída |
|---|---|---|---|
| **Repouso** | Padrão | Nada além do hardware (o desenho fica invisível) | Hover, clique, atalho, evento |
| **Compacto** | Áudio tocando + preferência "mostrar atividade" | Orelhas só no espaço **medido como livre** da barra de menus: ícone da fonte em foco (com o segundo app atrás, se houver) e medidor. Sem espaço livre: queixo de 20 pt abaixo do notch | 3 s depois que o áudio para |
| **HUD** | Teclas de volume, mudo ou **brilho** (com permissão de Acessibilidade) | Ícone (alto-falante ou sol) e valor nas asas; barra de nível abaixo | 1,2 s após o último evento |
| **Espiada** | Hover: "pop" imediato, abre após 150 ms de permanência | Fonte em foco nas asas (ícone, nome, volume, mudo) e fader; cada outro app tocando ganha uma linha com fader; se a saída está muda ou em 0 %, aviso "Saída sem som" com **Ativar som**. Sem nada tocando: a espiada controla a **saída** (dispositivo, volume de hardware, mudo) | O ponteiro se afasta (o fechamento segue o ponteiro) |
| **Expandido** | Clique no notch, clique na espiada fora de um controle, atalho ⌥⌘V | Asas: app em foco (clicável: traz o app para a frente) e ícone do dispositivo de saída (menu de saídas). Abaixo: "Tocando em <dispositivo>", volume grande, fader, outras fontes, faixa **Geral** (volume e mudo da saída), alerta do Guardião, rodapé (processamento, A/B neutro, Estúdio) | Ponteiro se afasta, clique fora, Esc, atalho |
| **Estúdio** | "Estúdio" no rodapé, menu de contexto, reabrir o app | Janela separada | — |

Regras:
- O notch **nunca rouba foco** do app do usuário (painel não ativante); aceita o primeiro clique sem "clique de foco". Teclado só é capturado no Expandido.
- **Clique direito** no notch (fechado ou aberto): Abrir Estúdio, Ajustes…, Mostrar ícone na barra de menus, Sair do timbr.
- **Barra de menus:** o estado persistente (compacto) nunca cobre menus de outros apps. Os estados abertos são transitórios, abertos por intenção, e cobrem a barra enquanto abertos. Se o ponteiro vai para a faixa da barra, o fechamento acontece em 30 pt.
- **Ícone na barra de menus:** só existe quando o notch não é a entrada do app: sem tela com notch, notch desligado, modo "só barra de menus" ou opção ligada em Ajustes.
- **Volume geral:** aumentar um app, tirar um app do mudo ou subir o fader geral tira a saída do mudo, como o macOS faz com as teclas.
- Tela cheia: o painel acompanha os espaços (`fullScreenAuxiliary`).
- Vários monitores: o notch vive na tela com notch; sem tela com notch, a forma vira uma pílula flutuante e o ícone da barra de menus aparece.
- Dois apps de notch competindo: o timbr. detecta apps conhecidos e oferece o modo "só barra de menus".

## 4. Mixer (Expandido e Estúdio)

- Ordem das fontes: tocando agora (a que começou por último primeiro, ordem estável enquanto ambas tocam) → silenciadas manualmente → tocaram nos últimos 10 min ("Tocou há N minutos"). Fontes inativas há mais de 10 min saem da lista.
- **O que é uma fonte:** o app que o usuário reconhece, não o processo. Processos auxiliares (Chromium/Electron, WebKit GPU, serviços XPC) são atribuídos ao app responsável. Serviços do macOS sem app viram grupos com nome e ícone: Sons do sistema, Siri e Ditado, Chamadas (protegidas como VoIP), Leitura em voz alta, Visualização Rápida, Outros sons do macOS.
- **Apps de ditado** (superwhisper, Wispr Flow, MacWhisper) mantêm o motor de saída ligado em silêncio e nunca contam como "tocando".
- **Detecção:** por evento do Core Audio (lista de processos, `IsRunning`, `IsRunningOutput`); sons curtos, como um alerta de 0,3 s, também aparecem. Varredura de reserva a cada 2 s.
- Cada linha: ícone, nome, medidor (se habilitado), slider de volume, mute, seletor de destino (chip com o nome curto do dispositivo). Arrastar a linha para um chip de destino roteia.
- Slider: arrastar 1:1; `⌥` + arrastar = ajuste fino (1/10); duplo clique = 100%; rolagem do trackpad sobre a linha ajusta; acima de 100% a trilha muda de cor e aparece "+x dB · pode clipar".
- Mudanças de volume no motor usam rampa de 10 ms (sem clique).

## 5. Destinos e multissaída

- Seletor de destino de uma fonte permite múltipla seleção (P1).
- Compensação de atraso por destino em ms (P2), com ferramenta assistida: toca um clique em todas as saídas e o usuário ajusta até soar junto.
- Desconexão: aplica a política do RF-0205 e registra evento; reconexão restaura rotas pelo UID.

## 6. EQ

### 6.1 Camadas e cadeia
`Soma → Correção → Gosto → Preamp automático (aplicado antes) → Limiter → Volume do destino (se em software) → Saída`. O preamp é calculado sobre o máximo da resposta combinada de Correção + Gosto + EQ de fonte mais margem de 0,5 dB (proposta, a validar em E-06).

### 6.2 Editor (Estúdio)
- Gráfico com eixo de frequência log (20 Hz–20 kHz), dB linear (±12 padrão, ±24 com zoom), curvas: Correção, Gosto, Resultado; espectro ao vivo opcional atrás.
- Alças de banda arrastáveis: horizontal = frequência, vertical = ganho, rolagem/pinça = Q; `⇧` trava eixo; duplo clique zera a banda.
- Tabela numérica sincronizada com o gráfico (Fc, ganho, Q, tipo, método).
- Indicadores: preamp atual, headroom, limiter atuando, latência do destino.

### 6.3 Gosto simples (padrão para novos usuários)
Quatro controles semânticos, cada um mapeado para filtros fixos e documentados: **Graves** (low shelf 105 Hz, Q 0,7), **Calor** (peaking 250 Hz, Q 0,9), **Presença** (peaking 3 kHz, Q 1,0), **Ar** (high shelf 10 kHz, Q 0,7); faixa ±6 dB, passo 0,5 dB. O modo avançado mostra o PEQ livre (a conversão é sem perda: os controles simples viram filtros editáveis).

### 6.4 A/B
- **A/B neutro**: compara Resultado vs. Correção-apenas vs. sem EQ, com loudness igualado por LUFS de curto prazo medido no próprio sinal (ou ganho calculado pela curva quando não há sinal).
- **Modo cego**: rótulos X/Y embaralhados; o usuário escolhe; dentro do A/B cego, A e B mantêm **tap ativo e latência equalizada** com crossfade de `20 ms` (evitando diferença de latência de ~2,7 ms denunciar o bypass); o resultado vira dado para o treinador (P1) e não muda o preset sem confirmação.

## 7. Correção de fone

1. Ao conectar um dispositivo novo, o Timbre sugere o modelo pelo nome do dispositivo (ex.: "MOMENTUM 4" → "Sennheiser Momentum 4 Wireless") e pede confirmação.
2. Busca no índice do AutoEq (cache 7 dias), lista fontes disponíveis (oratory1990, crinacle, Rtings…) com equipamento de medição.
3. Usuário escolhe fonte e alvo; o Timbre baixa a medição/curva e gera o PEQ localmente.
4. A Correção é associada ao UID do dispositivo e, para Bluetooth, ao transporte (o mesmo fone com cabo pode ter outra Correção).
5. Crédito visível da fonte da medição em todo lugar onde a Correção aparece.

## 8. Guardião (regras do MVP+)

| Regra | Detecção | Mensagem (tom calmo) | Ação sugerida |
|---|---|---|---|
| G-01 HFP | Saída BT mudou para formato de chamada | "O Momentum 4 entrou em modo chamada (som mono e reduzido) porque o Zoom abriu o microfone do fone." | Usar mic interno como entrada |
| G-02 Reamostragem | Taxa da fonte conhecida ≠ taxa do destino | "A faixa é 96 kHz; o DAC está em 48 kHz." | Ajustar taxa |
| G-03 Clipping | Limiter atuou > N vezes/min | "O EQ está pedindo mais que o headroom." | Aumentar margem do preamp |
| G-04 EQ duplicado | Driver informa EQ interno ≠ neutro + Correção ativa | "O fone também tem EQ ligado." | Zerar EQ interno |
| G-05 Volume em software evitável | Volume do destino em software com dispositivo que aceita volume de hardware | — | Usar volume de hardware |
| G-06 Dispositivo trocado | Saída padrão mudou sem ação do usuário | "A saída mudou para Alto-falantes porque o fone desconectou." | Voltar quando reconectar |
| G-07 Conflito de captura | Outro app de taps/loopback detectado | — | Ver matriz de coexistência |

Alertas: no máximo um visível por vez; agrupados; "não mostrar de novo para este caso"; todos ficam na linha do tempo.

## 9. Observatório

Por destino, um diagrama horizontal: **Fontes** (ícones e níveis) → **Mixer** (soma, n fontes) → **Correção** → **Gosto** → **Proteção** → **Dispositivo** (nome, transporte, taxa/formato reportados) → **Fone** (modelo, driver, estado). Cada nó mostra: latência do estágio (reportada ou medida), ganho aplicado e selo de origem. Clique num nó abre detalhes e eventos relacionados.

## 10. Permissões

| Permissão | Quando é pedida | Para quê | Sem ela |
|---|---|---|---|
| System Audio Recording Only | Primeiro uso de volume por app ou EQ | Taps | Só controle de dispositivos |
| Acessibilidade | Na Introdução ou em Ajustes | `CGEventTap` (teclas de volume e brilho com HUD no notch) e leitura dos menus do app em primeiro plano (orelhas medidas) | Teclas seguem o HUD do macOS; a orelha esquerda é tratada como ocupada |
| Automation (por app) | Ao ativar controles de Music/Spotify | AppleScript | Só now playing genérico |
| Bluetooth | Ao ativar um driver de fabricante | Protocolos do fone | Fone funciona como dispositivo genérico |
| Microfone | Ao usar reconhecimento pelo microfone ou medição | ShazamKit / medição | Reconhecimento só do som do sistema |

Nunca pedir permissão no primeiro start sem contexto. Toda tela de permissão diz o que **não** fazemos (não gravamos, não enviamos).

## 11. Atalhos padrão (editáveis)

| Ação | Atalho |
|---|---|
| Abrir/fechar notch expandido | ⌥⌘V |
| Alternar processamento (bypass verdadeiro) | ⌥⌘B |
| A/B neutro | ⌥⌘A |
| Próxima saída | ⌥⌘O |
| Mute do microfone global | ⌥⌘M |
| Abrir Estúdio | ⌥⌘, |
| Ajustes do Estúdio (com o Estúdio em foco) | ⌘, |

Ações por teclado nunca animam (design system §motion).
