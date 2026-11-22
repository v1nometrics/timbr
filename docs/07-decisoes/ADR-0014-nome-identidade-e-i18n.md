# ADR-0014 · Nome Definitivo (`timbr.`), Identidade Visual × `v1torres.dev` e Idiomas da v1 (`PT / ES / EN`)

- **Status:** Aceito (definição direta do dono)
- **Data:** 2026-11-21
- **Substitui / Fecha:** §7 de `01-visao/visao-e-principios.md` ("Nome em aberto") e `RF-1405` original ("Português e inglês").

---

## Contexto

1. O projeto operava sob o codinome provisório *"Timbre"* (mantido no caminho do repositório local `timbre/` e nos prefixos internos `TimbreTokens` / `TimbreDSP` quando conveniente).
2. O dono definiu a marca oficial **`timbr.`** com wordmark tipográfico validado em captura de tela (`timbr.` em caixa baixa, peso geométrico firme `#FFFFFF`/`#F2F2F2` sobre fundo escuro neutro `#141414`/`#191919`, seguido pela tagline `"Sound, precisely yours."` em cinza neutro).
3. Foi avaliado se o logotipo e a identidade visual do `timbr.` devem referenciar o design system pessoal do autor em **`v1torres.dev`** (repositório `v1dev app`, `DESIGN_SYSTEM.md` v3.0: monocromático `#09090b`/`#fafafa`, 100% lowercase, `Geist Mono`, bordas pontilhadas, zero gradientes, marca `›v1_`).
4. O dono exigiu que a **primeira versão (`v1` / MVP–1.0)** já nasça totalmente localizada em **Português (`pt-BR`), Espanhol (`es`) e Inglês (`en`)**.

---

## Decisão

### 1. Nome e Wordmark Oficiais
- **Nome público do produto:** **`timbr.`** (escrito em caixa baixa com ponto final na identidade visual e cabeçalhos; em texto corrido técnico aceita `timbr.` ou `Timbr` quando exigido por identificadores de sistema/bundle como `dev.v1torres.timbr` ou `Timbr`).
- **Taglines oficiais (v1 trilíngue):**
  - **EN:** *Sound, precisely yours.*
  - **PT:** *Som, precisamente seu.*
  - **ES:** *Sonido, precisamente tuyo.*

### 2. Avaliação & Recomendação: Alinhamento `timbr.` × `v1torres.dev`
Adotamos **parentesco filosófico e tipográfico direto com `v1torres.dev`, mantendo separação deliberada de meio** (web/terminal editorial vs. instrumento nativo macOS de áudio):

| Eixo | `v1torres.dev` (`v1dev app`) | Decisão para o `timbr.` | Justificativa |
|---|---|---|---|
| **Wordmark & Caixa** | `›v1_` lowercase com pontuação de terminal | **`timbr.` lowercase com ponto final `.`** | Cria assinatura inequívoca do mesmo autor sem parecer port de site CLI. |
| **Família Tipográfica** | `Geist Mono` integral | ~~`Geist` (UI/wordmark) + `Geist Mono` (unidades, Hz, dB, eyebrows) + `Geist Serif` (letras)~~ **Substituído pela ADR-0015: SF Pro / SF Mono / New York no app; Geist só na web** | Preserva o DNA Geist do autor, mas dá conforto de leitura no Estúdio e Notch. |
| **Superfícies Neutras** | `#09090b` / `#18181b` / `#fafafa` monocromático sem azul | **Neutros OKLCH croma 0 (`#0D0D0D`, `#141414`, `#191919`, `#000000` no notch)** | Paridade total com o `DESIGN_SYSTEM.md` de `v1torres.dev` e com a captura da wordmark `timbr.`. |
| **Uso de Cor** | Proibido qualquer acento colorido | ~~Monocromático estrutural + 1 acento violeta (`#7747FF`) + semântica de sinal~~ **Substituído pela ADR-0016: acromático, sem cor de marca, só semântica de sinal** | Áudio de precisão exige alerta inequívoco de clipping (`> 0 dBTP`), HFP (âmbar) e bit-perfect (verde). |
| **Geometria & Bordas** | `border-radius: 0` + `border-dotted` | **Raios concêntricos Apple HIG** no Notch/janelas; **hairlines e linhas pontilhadas sutis** no Observatório/Estúdio | `radius: 0` entraria em conflito físico com o notch arredondado e o macOS 26/27. |
| **Ícone do App (`.icns`)** | Não aplicável | **Monólito neutro `#111111` com glifo geométrico da curva paramétrica + ponto `.` (ou monograma `t.` em escala pequena)** | Em `16×16` e `32×32`, texto de 6 letras (`timbr.`) vira borrão; o glifo `curva + .` referencia tanto o áudio quanto o ponto final da wordmark. |

### 3. Internacionalização Trilíngue Obrigatória na v1 (`PT`, `ES`, `EN`)
- Todo texto visível ao usuário (Notch, Pílula, MenuBar, Estúdio, Observatório, Guardião, Onboarding, avisos pré-TCC e CLI/ajuda) usa Apple **String Catalog (`Localizable.xcstrings`)** com tradução completa e revisada para **`pt-BR`**, **`es`** e **`en`** desde o MVP.
- Unidades técnicas universais (`Hz`, `kHz`, `dB`, `dBFS`, `dBTP`, `LUFS`, `ms`) permanecem invariantes em fonte mono (SF Mono no app, ADR-0015); separadores decimais respeitam o locale ou configuração explícita do Estúdio (padrão técnico tabular consistente).

---

## Consequências
- `README.md`, `PRD.md`, `visao-e-principios.md` e `05-design-system/*` passam a adotar **`timbr.`** como nome oficial.
- Pastas internas já estruturadas (`Documents/timbre/`) e identificadores de código existentes (`TimbreTokens`) não exigem renomeação destrutiva imediata para preservar histórico, devendo o bundle final de produto usar **`timbr.` / `Timbr.app`**.
- Todo snapshot test de UI na Fase 1+ deve rodar nos três idiomas (`pt-BR`, `es`, `en`) para evitar truncamento no notch compacto.
