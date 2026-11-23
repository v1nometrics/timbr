# ADR-0020 · Sons curtos do sistema não acordam o notch

- **Status:** Aceito · 2026-11-23 (pergunta do dono do produto)

## Contexto

Qualquer processo com saída de áudio ativa virava "tocando". Os daemons do macOS tocam sons curtos (o clique de ação inválida ao apertar algo que não pode ser apertado, alertas, o som do carregador), e o notch respondia a cada um abrindo o compacto com o ícone de Ajustes do Sistema e fechando 3 s depois. Esse ícone não diz nada à pessoa, e o gesto repete a cada clique inválido.

## Decisão

- As fontes `timbr.system.sounds` (Sons do sistema) e `timbr.system.other` (Outro áudio do macOS) **nunca** contam como "tocando" para o notch: compacto, espiada (peek) e a fonte principal do console expandido. Regra única em `NotchActivityPolicy.forNotch`, usada por todas as superfícies do notch.
- Elas **continuam** no Mixer e no Estúdio, com volume ajustável, e continuam contando para o áudio (tap global, medidores). Só deixam de acordar o notch.
- Siri e ditado, chamadas, conteúdo falado, Quick Look e qualquer app de verdade seguem contando.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Esperar N segundos de som contínuo antes de mostrar qualquer fonte | Atrasaria o notch ao dar play em música, que é o caso mais comum |
| Só esconder o ícone de Ajustes | O notch ainda abriria e fecharia sem dizer nada |
| Ignorar os sons do sistema também no Mixer | Tiraria do usuário o controle de volume dos alertas |

## Limites

- Um som do sistema longo (ex.: alarme de timer) também não acorda o notch. O macOS mostra a própria interface para eles.
- Siri e ditado fazem bipes curtos e ainda acordam o notch; só mudo se isso incomodar na prática.

## Evidência

- Medição no notch real (janela do notch capturada a cada 0,25 s, 24 quadros): build antiga, 3 bipes do sistema, 7 quadros diferentes (animou); build nova, 3 bipes do sistema, 24 quadros idênticos; build nova com um app tocando (controle), animou normalmente.
- `TimbreCoreTests`: sons do sistema silenciados para o notch; Siri, chamadas e apps preservados; música + clique resolve para a música; a fonte original fica intacta.
