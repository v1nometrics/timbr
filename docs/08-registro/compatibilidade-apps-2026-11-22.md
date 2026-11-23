# Compatibilidade com outros apps (2026-11-22)

> Classe de evidência indicada em cada item. Reproduzido em bancada (MacBook Air Apple Silicon, macOS 26).

## superwhisper

### 1. Aparecia como "tocando" sem emitir som — **Comprovado, corrigido**

O superwhisper mantém o motor de saída de áudio ligado (`kAudioProcessPropertyIsRunningOutput = 1`) por minutos, inclusive durante a transcrição, para tocar os sons de início e fim. Para o Core Audio, isso é "saída ativa". O Core Audio não informa o nível do som por processo, e medir o nível exigiria um tap, que piora o item 2.

**Correção:** `SilentOutputApps` (TimbreCore) lista apps de ditado com motor de saída silencioso (superwhisper, Wispr Flow, MacWhisper). Eles nunca contam como "tocando" e não aparecem no notch nem no Mixer.

### 2. "Meeting detected" quando o timbr processa áudio — **Comprovado; causa externa, mitigado**

Como reproduzimos:

- Com o Chrome aberto, rodamos `--selftest-audio`, que cria taps. Em 2 a 8 s o superwhisper mostrou o aviso "Meeting detected · Meeting" (janela de 436×168, camada 1001), junto com o ponto roxo do macOS.
- Enquanto existe um tap, o processo do timbr aparece com `IsRunningInput = 1`. O microfone não é usado (`DeviceIsRunningSomewhere = 0`). A "entrada" é o próprio stream do tap no agregado privado, e é assim que o macOS entrega áudio do sistema a qualquer app.
- O binário do superwhisper contém os logs `[MeetingDetection] attributed mic process` e `unattributed mic users`, e lista navegadores (Chrome, Safari, Arc, Edge, Firefox…) entre os apps de reunião suportados. Ou seja: com qualquer processo usando entrada que ele não atribui a um app de reunião, e um navegador aberto, ele conclui que há uma reunião no navegador.
- Testamos rodar o timbr como app comum (`.regular`, com ícone no Dock): o aviso continua. A política de ativação não importa.

**Conclusão:** qualquer app de volume por app no macOS (SoundSource, FineTune, timbr) dispara a mesma heurística, porque precisa ler um tap. Isso não se resolve no timbr sem abrir mão do volume por app.

**Mitigação no timbr:** o tap global (EQ, crossfeed, ducking) só existe enquanto há áudio tocando, com 10 s de folga. Sem som, ele é desmontado: o ponto roxo apaga e o superwhisper para de ver uma "entrada". Os taps por app continuam enquanto o app tiver volume diferente de 100%. Desmontá-los faria o app tocar no volume original por uma fração de segundo quando voltasse a tocar.

**Recomendação ao usuário:** no superwhisper, desligar a detecção automática de reuniões por app e usar só o calendário. Ou desligar o processamento do timbr (⌥⌘B) durante reuniões que se queira gravar com detecção automática.

## Chrome junto com Spotify

**Comprovado, sem defeito no build atual.** Com um tom tocando numa aba do Chrome, o processo `Google Chrome Helper (Aperitif)` aparece com `IsRunningOutput = 1`, é atribuído a "Google Chrome", e tanto o compacto (dois logos com recorte) quanto a espiada (volume **Geral** no topo + Spotify e Chrome em pé de igualdade abaixo, refinado em 2026-11-23) exibem os dois apps.

No momento do relato, a aba do YouTube não estava emitindo áudio: nenhum processo do Chrome tinha saída ativa em 10 s de observação, e não havia a trava de energia de reprodução do Chrome (`pmset -g assertions`).

O Chrome toca todas as abas por um único processo de áudio. O controle por aba depende da extensão.
