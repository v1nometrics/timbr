# Visão do produto e princípios inegociáveis

> Status: v1.1 · 2026-11-21 · Dono: Vinicius · Nome oficial: **`timbr`** *(codinome de repositório: Timbre; ver [ADR-0014](../07-decisoes/ADR-0014-nome-identidade-e-i18n.md))*

## 1. A frase

**Timbre é a central de controle de áudio do Mac para quem leva som a sério. O notch é a porta de entrada; a cadeia de sinal é o produto.**

Não é mais uma Dynamic Island. Existem mais de 25 apps de notch e a Apple já trouxe uma Dynamic Island nativa ao MacBook Pro OLED (28/10/2026) e Live Activities à barra de menus (macOS 27.3). O "now playing bonito" vai ser absorvido pelo sistema. O que a Apple não faz, e ninguém faz bem junto, é: **volume e roteamento por fonte, equalização de fidelidade verificável, e transparência total sobre o caminho do sinal**, numa superfície que está sempre a um gesto de distância.

## 2. Para quem

| Público | Situação | O que ganha |
|---|---|---|
| **Primário: audiófilo de fone no MacBook** | Usa fones Bluetooth premium (Momentum 4, AirPods Pro, Sony XM, Bose) e/ou DAC USB com fone com fio; ouve streaming (Apple Music, Spotify, TIDAL, Qobuz) | Correção de fone (AutoEq) + EQ paramétrico de 64 bits + controle do fone + saber exatamente o que chega no ouvido |
| **Secundário: "controlador do som"** | Reunião + música + vídeo ao mesmo tempo; vários dispositivos | Volume por app, roteamento por saída, perfis automáticos, nada de surpresas ao trocar de dispositivo |
| **Terciário: criadores e devs de áudio** | Interfaces de áudio, monitores, gravação | Medidores honestos, signal path, roteamento, exportação de configurações |

O autor do projeto atua como usuário-zero em dogfood diário: audiófilo exigente, Momentum 4 como fone principal e AirPods Pro como secundário.

## 3. O problema, em uma tabela

| Dor (evidência na pesquisa) | Quem resolve hoje | Por que não basta |
|---|---|---|
| macOS não tem volume por app | SoundSource (US$ 49), FineTune (GPL, grátis) | SoundSource só tem EQ gráfico de 10 bandas; FineTune processa em Float32 e tem 248 issues abertas |
| macOS não tem EQ de sistema | eqMac, SoundSource, EQBase | eqMac fechou o código novo; ninguém mostra o caminho do sinal nem garante bypass transparente |
| DAC USB sem controle de volume (teclas cinzas) | eqMac, SoundSource, Proxy Audio Device | Resolvido de forma dispersa |
| Apple Music não troca a taxa de amostragem do DAC | LosslessSwitcher | App separado, lê logs do sistema |
| Fone Bluetooth cai para HFP (mono, ruim) quando um app abre o microfone | Ninguém de forma explícita | Usuário nem sabe por que o som piorou |
| Controle do fone (ANC, EQ interno) exige o app do celular | Apps de fabricante, só no celular | Nenhum app de Mac fala com o Momentum 4 |
| Apps de áudio quebram a cada versão do macOS, estalam, "estouram" no início | Todos sofrem | Confiabilidade é o eixo competitivo real |

## 4. Proposta de valor

1. **Mixer de fontes de verdade**: volume, mute, saída e EQ por app; por aba de navegador via extensão; várias saídas ao mesmo tempo.
2. **EQ em que um audiófilo confia**: 64 bits, filtros casados perto de Nyquist, preamp calculado pela resposta somada, limiter visível, A/B cego com volume nivelado, bypass que sai do caminho.
3. **Caminho do sinal explicado**: da fonte ao ouvido, cada etapa com o que é **medido**, **reportado pelo sistema** ou **inferido**, e um Guardião de Qualidade que avisa quando algo degrada o som (HFP, reamostragem, clipping, EQ duplicado).
4. **Hardware-aware**: o núcleo funciona com qualquer dispositivo; drivers por fabricante liberam extras (Momentum 4 primeiro).
5. **Inteligência que obedece**: a IA traduz intenção ("vocais mais quentes") em deltas pequenos, tipados e reversíveis; o DSP continua determinístico.
6. **Notch como superfície principal, calma**: um gesto para o essencial; o resto em camadas.

## 5. Princípios inegociáveis

Cada princípio tem um teste. Se uma decisão viola o teste, ela está errada, mesmo que pareça boa.

| # | Princípio | Teste objetivo |
|---|---|---|
| P1 | **Fidelidade antes de recursos.** Quando nada precisa ser processado, o app não toca no áudio. | Com EQ, volume por app e efeitos neutros, nenhum tap existe (verificável no diagnóstico). |
| P2 | **Falhar em segurança.** Se o app travar ou for morto, o som volta, intacto, sem estouro. **Exceção ([ADR-0017](../07-decisoes/ADR-0017-mudo-a-prova-de-falha.md)):** um app que o usuário silenciou (mudo ou 0 %) continua em silêncio. | Teste de `kill -9` durante reprodução: o áudio continua em ≤ 1 s, sem pico acima do nível anterior; app mudo continua mudo (`selftest_mute_persistence.sh` + `listen_mute_crash.sh`). |
| P3 | **Nunca deixar rastro.** O sistema fica como estava ao sair ou desinstalar. | Após sair/desinstalar: dispositivo padrão, volumes e lista de dispositivos idênticos ao snapshot de antes. |
| P4 | **Verdade no caminho do sinal.** Nenhuma métrica inferida aparece como medida. | Todo número na UI tem um selo de origem: medido, reportado, inferido. |
| P5 | **Evidência antes de promessa.** Nenhum recurso entra no roadmap como "certo" sem prova de viabilidade. | Todo item do backlog aponta para uma linha da matriz de viabilidade com classe de evidência. |
| P6 | **IA propõe, DSP decide.** Nenhum modelo generativo toca o áudio. | Toda saída de IA é um delta validado por esquema, com limites, A/B e desfazer em um toque. |
| P7 | **Local primeiro, privado por padrão.** Nada sai do Mac sem pedido explícito; nada é gravado sem consentimento. | Sem rede, todas as funções centrais funcionam. Áudio nunca é persistido sem ação do usuário. |
| P8 | **Duas coisas excelentes antes de vinte boas.** Mixer por fonte e EQ de fidelidade vêm primeiro e precisam ser os melhores do Mac. | Nenhuma feature de fase posterior entra antes do gate de qualidade do MVP. |
| P9 | **Calma no notch.** O notch mostra o essencial e some. | Em repouso, o notch é indistinguível do hardware; CPU em repouso dentro da meta (ver RNF). |
| P10 | **Craft é requisito.** Estética, motion e tipografia seguem o design system como lei. | Toda tela passa pelo checklist do design system antes de merge. |
| P11 | **Agnóstico ao dispositivo, consciente do hardware.** Nenhum controle aparece se o hardware não o suporta. | Controles são gerados a partir da matriz de capacidades sondada em runtime. |
| P12 | **Open source sustentável.** Licença, contribuição e manutenção decididas antes do código. | ADR-0001 aceito antes do primeiro commit de código. |

## 6. O que o `timbr` **não** é

- Não é um separador de stems (Liland/HTDemucs). Separação sintética degrada a fidelidade, que é o oposto do produto.
- Não é um player de música. Ele controla e melhora o que os players tocam.
- Não é um "efeito mágico 3D" (Boom 3D, FxSound). Nada de realce de graves por padrão, nada de "som melhor" sem explicação.
- Não é um substituto de DAW ou de room correction profissional (Dirac, SoundID Reference). Pode integrar-se a eles.
- Não é um app que precisa da nuvem.

## 7. Nome, Identidade, Idiomas & Fronteira Local (`timbr`)

- **Nome oficial:** **`timbr`** (wordmark em caixa baixa com ponto final — ver [ADR-0014](../07-decisoes/ADR-0014-nome-identidade-e-i18n.md) e [05 · Assets e Referências](../05-design-system/05-assets-iconografia-e-referencias.md)).
- **Taglines:** *Sound, precisely yours.* (EN) · *Som, precisamente seu.* (PT) · *Sonido, precisamente tuyo.* (ES).
- **Idiomas na v1:** suporte nativo completo a **Português (`pt-BR`), Espanhol (`es`) e Inglês (`en`)** desde o MVP.
- **Essência 100% Local:** todo o motor de áudio, mixer, DSP `Float64`, Observatório, Guardião, drivers Bluetooth/USB e IA on-device funcionam **100% sem internet**; apenas recursos opt-in (sincronização de catálogo AutoEq, letras LRCLIB, ShazamKit, ListenBrainz, Sparkle ou LLM BYOK) acessam rede (matriz completa em [requisitos-nao-funcionais.md](../04-engenharia/requisitos-nao-funcionais.md)).

## 8. Como saberemos que deu certo

| Horizonte | Sinal |
|---|---|
| Gate de viabilidade (fim da Fase 1) | As 6 provas de risco têm resultado documentado (passou, passou com ressalva, falhou) |
| MVP | Uso diário contínuo como único mixer e EQ por 14 dias seguidos sem desligá-lo por problema |
| Beta | 50 testadores externos; zero relatos de áudio corrompido não reproduzível; crash-free ≥ meta |
| 1.0 | Comparado ao SoundSource e ao FineTune num teste cego, a cadeia do Timbre é preferida ou indistinguível no modo neutro, e superior em recursos de verificação |
