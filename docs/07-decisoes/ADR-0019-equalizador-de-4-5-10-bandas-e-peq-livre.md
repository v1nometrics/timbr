# ADR-0019 · Equalizador de 4, 5 ou 10 bandas, e a correção do PEQ livre

- **Status:** Aceito · 2026-11-23
- **Relaciona-se com:** [ADR-0010](ADR-0010-correcao-e-gosto.md) (correção e gosto em camadas), [ADR-0009](ADR-0009-formato-de-presets.md) (formato de preset)

## Contexto

O equalizador simples oferecia apenas **quatro** ajustes fixos (Graves 105 Hz, Calor 250 Hz, Presença 3 kHz, Ar 10 kHz) e, no outro extremo, o PEQ livre. Era necessário permitir alternar entre mais ou menos bandas fixas e corrigir dois defeitos no PEQ livre: a curva não acompanhava os pontos 1–4 durante o arraste e faltava ação de resetar os filtros com a mesma facilidade do modo simples.

## O que se sabe do mercado (e o que não se sabe)

- **Sennheiser Smart Control (Momentum 4 / True Wireless 3):** o equalizador gráfico passou de **três para cinco bandas** na versão 4.3 do app, junto com um modo interativo de personalização do som (TechRadar, hifi.de). A Sennheiser agora dirige os recursos novos ao Smart Control Plus, com EQ, personalização e presets. **Não encontrei** as frequências centrais das cinco bandas, nem notas de versão de 2026: as frequências do nosso layout de 5 bandas são escolha nossa, não cópia.
- **Audiófilos:** o wiki do AutoEq diz que **10 filtros paramétricos** corrigem a maioria dos fones, e um fork dele observa que 5 já podem bastar. Dez bandas em oitavas é também o formato gráfico clássico. Não achei o número padrão exato que o gerador do AutoEq usa, então não afirmo isso.

## Decisão

1. **Quatro modos, num seletor só:** `4 · 5 · 10 · PEQ Livre`.
   - **4** é o equalizador de sempre, sem mudança (Graves/Calor/Presença/Ar).
   - **5** (80 Hz shelf, 250, 1 k, 4 k Hz e 10 kHz shelf) iguala a granularidade da Sennheiser.
   - **10** são as oitavas ISO de 31,5 Hz a 16 kHz (shelf nas pontas, Q 1,41 nas demais).
   - Nos três, só o ganho mexe, por cartão (valor + fader, duplo clique zera), pelo ponto na curva (arraste vertical) ou pelo botão **Zerar**. A excursão de ganho é menor com menos bandas, porque cada banda larga mexe mais no espectro: ±6 dB (4), ±9 dB (5), ±12 dB (10).
   - **PEQ Livre** continua com tipo, frequência, ganho e Q por filtro.
2. **Cada layout guarda os próprios ganhos.** Trocar de 4 para 10 e voltar não perde nada. O 4 continua em `simpleTaste`; 5 e 10 ficam em `layoutGains`. **Não há conversão automática** da curva entre layouts: com bandas em lugares diferentes, qualquer conversão seria aproximada, e isso fica dito aqui em vez de escondido.
3. **Entrar no PEQ Livre** parte da curva que você ouve agora, com **todos os filtros ligados** (zero dB é neutro).
4. **Compatibilidade:** presets salvos antes não têm `layout` nem `layoutGains` e carregam como o EQ de 4 bandas, com os mesmos ganhos (testado).

### Nomes das bandas

Português primeiro, o termo do meio audiófilo entre parênteses: **Graves (Bass)**, **Médios-graves (Warmth)**, **Médios-agudos (Presence)**, **Agudos (Air)** no EQ de 4; no de 5, **Médios (Midrange)** entra no meio; no de 10, cada banda mostra a frequência e, abaixo, o nome da região (Sub-grave, Graves, Corpo, Médios-graves, Médios, Médios altos, Presença, Brilho, Agudos). Com o app em inglês aparece só o termo. Um pequeno botão "i" no canto superior direito de cada cartão abre, ao clicar, uma frase que explica o termo e o que acontece em excesso (a dica ao passar o mouse foi trocada por ele: era fácil de disparar sem querer e ninguém a via sem pairar o mouse) (por exemplo "Calor, em torno de 250 Hz: dá corpo às vozes. Demais deixa o som embolado"). Os autores não concordam nas fronteiras das regiões (headphones.com e RTINGS diferem), por isso o nome **rotula** a banda e a frequência exata fica sempre à vista.

### Defeito 1 — a curva não acompanhava os pontos (causa: Comprovado, reproduzido em teste)

Ao entrar no PEQ livre, os quatro filtros nasciam **desligados** (`enabled = abs(ganho) > 0.01`, e o ganho era 0). O ponto era arrastado, o ganho mudava, mas o filtro seguia desligado, então o DSP ignorava e a curva ficava parada. O teste de motor reproduz o sintoma contra o DSP real (banda desligada em +6 dB: resposta 0 dB) e confirma a correção (+6 dB). Correção em duas partes: (a) a semente do PEQ nasce com tudo ligado; (b) **ajustar** frequência, ganho ou Q de um filtro desligado o liga (alternar o interruptor e trocar só o tipo continuam exatamente como o usuário pôs).

### Defeito 2 — sem reset no PEQ livre

Botão **Resetar filtros** no cabeçalho dos filtros: volta aos quatro filtros planos nas posições padrão, com **um nível de desfazer** (**Desfazer** aparece ao lado e some na próxima edição). Fica desativado quando já está no padrão (um filtro movido, mesmo com ganho 0, conta como alterado).

### Ajustes de quebra

- **Adicionar filtro** agora cai no maior intervalo livre do eixo de frequência (antes caía sempre em 1 kHz, empilhando).
- **Limite coerente:** o DSP roda no máximo 32 bandas entre correção (AutoEq) e gosto, e cortava o excesso em silêncio. O teto dos filtros livres agora é `min(24, 32 − bandas de correção)`, com dica no botão. Antes a UI dizia 20 e o código 24.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Um controle deslizante de "número de bandas" que reamostra a curva | Reamostrar muda o som do que o usuário já acertou; layouts fixos com ganhos próprios são previsíveis |
| Só 5 e 10 além do PEQ livre | O 4 é o que o app sempre teve e o usuário já conhece |
| Copiar as frequências do Smart Control | Não achei as frequências deles; inventar e dizer que são deles seria falso |
| Reset que apaga todos os filtros | Deixa a tela sem pontos para arrastar; voltar ao padrão plano mantém a curva reta e a tela usável |

## Verificação

- `TimbreCoreTests`: layouts (contagem, frequências, ordem), ganho com passo de 0,5 e limites por layout, ganhos independentes por layout, compatibilidade com preset antigo e ida e volta, as regras de edição (ligar ao ajustar, respeitar desligar e troca de tipo), reset, posição de novo filtro e teto de bandas.
- `TimbreEngineTests`, contra o DSP real: a banda desligada deixa a curva plana, a mesma edição agora liga e a curva sobe +6 dB; em cada layout, subir uma banda levanta a curva no centro dela.
- Capturas reais do Estúdio (10 bandas e PEQ livre): os pontos numerados ficam sobre a curva, e os cartões, o botão Resetar filtros e o seletor aparecem inteiros.
- `./scripts/ci_check.sh` verde.

## Limites

- A resposta somada das bandas fixas de oitava não é plana quando vizinhas se sobrepõem (é assim em qualquer EQ gráfico de oitava); o pré-amplificador automático compensa o pico.
- Os modos 5 e 10 não têm Q ajustável; quem precisa disso usa o PEQ livre.
- Não medi o efeito de áudio por ouvido; a verificação é a resposta calculada pelo próprio DSP.
