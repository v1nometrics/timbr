# ADR-0023 · Tempo de escuta e volume alto, sem fingir decibéis

- **Status:** Aceito · 2026-11-23 (o dono pediu um jeito de saber se a escuta é saudável; apliquei a opção que propus, sem tap)
- **Relaciona-se com:** RF-0707 do PRD (estimativa de dB SPL, continua **não implementada**)

## Contexto

O AirPods mostra decibéis no iPhone porque a Apple controla a cadeia inteira (volume absoluto, amplificador, sensor). Para outros fones, a própria Apple diz que o número é uma estimativa a partir do volume. No Mac, o HealthKit não tem repositório de dados, e o timbr. só vê o sinal digital quando há um tap. Sem a sensibilidade do fone e o ganho do amplificador, o nível que chega ao ouvido tem erro de **±6 dB ou mais**, que é o dobro da pressão sonora e muda a dose segura de horas para minutos. Dizer "saudável" com esse erro é pior que não dizer nada.

## Decisão

1. **Nenhum "dB SPL" na interface.** O RF-0707 segue como está: só com sensibilidade e impedância informadas, rotulado `INFERIDO`.
2. **Contar o que o app sabe de verdade:** tempo tocando em equipamento de escuta pessoal (fone, earbud, headset: Bluetooth, jack, USB headset; não alto-falantes, monitores, HDMI ou soundbar) e quanto desse tempo o volume do Mac esteve alto (≥ 60%, com histerese de 5 pontos). Não usa tap, não captura nada.
3. **Referência: a regra prática 60/60 dos audiologistas** (Mayo Clinic): até 60% do volume por até 60 minutos, depois 15 a 20 de descanso. Não é a norma WHO-ITU H.870 (80 dBA por 40 h/semana), que exige nível medido, e a interface diz isso.
4. **Aviso** quando o volume alto passa de 60 minutos seguidos: no Observatório (seção "Audição", com os números de hoje, a sequência atual e uma barra por dia dos últimos 7), e **discreto no notch** (as barras do indicador ficam âmbar e a linha de contexto do console diz "Volume alto há 1 h 12 min · hora de uma pausa"). Baixar o volume apaga o aviso na hora; só 15 minutos longe do volume alto zeram a sequência.
5. Persistência local em `listening_days` (segundos por dia), somada a cada 30 s; "Apagar histórico" também zera. Passos maiores que 6 s (suspensão do Mac) não contam.
6. Instâncias de revisão, smoke e self-test não contam nem gravam.

## Limites

- **O volume do Mac não é decibel.** O mesmo 60% é mais alto num fone sensível. O aviso é um lembrete, não uma medição, e o texto da tela diz isso.
- Fones sem controle de volume pelo Mac (volume absoluto sem leitura) contam como escuta, mas não como "alto".
- A identificação de "fone" é por transporte e nome do dispositivo: um alto-falante Bluetooth conta como escuta pessoal.
- A fronteira de 60% e de 60 minutos é uma regra prática de audiologistas, sem número oficial por trás; a fonte é um conselho clínico, não uma norma.

## Evidência

- `TimbreCoreTests`: classificação de dispositivos, sequência de 60 min, histerese, descanso de 15 min, passo de suspensão, volume desconhecido, virada do dia e armazenamento.
- Captura real da seção e do aviso (dados de exemplo, nada gravado), `./scripts/ci_check.sh` verde.
