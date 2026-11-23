# Estratégia Open Source, Governança e Sustentabilidade

> **Princípio vinculado:** **P12 (Open source sustentável)** — licença, contribuição e manutenção decididas antes do primeiro commit de código ([ADR-0001](../07-decisoes/ADR-0001-licenca.md)).

---

## 1. Posição de Licenciamento e Fronteira Copyleft

Com a aprovação da [ADR-0001](../07-decisoes/ADR-0001-licenca.md) (**Aceito**), o projeto é distribuído sob **Mozilla Public License 2.0 (`MPL-2.0`)** com **DCO (`Signed-off-by`)**, sob fronteira rígida contra copyleft forte:
- **Permitido:** estudar arquitetura, protocolos e fórmulas públicas de projetos GPL/AGPL (`FineTune`, `boring.notch`, `Atoll`, `LosslessSwitcher`, `BlackHole`, `LibrePods`).
- **Proibido:** copiar, traduzir linha a linha ou portar trechos de código de repositórios GPL/AGPL/LGPL-incompatíveis para a árvore do `timbr` (verificado na etapa 3 do CI).

### 1.1 Fundamentos da escolha: `MPL-2.0 + DCO`
- **Copyleft em nível de arquivo:** qualquer modificação nos arquivos `.swift`, `.cpp`, `.rs` ou `.json` do Timbre permanece aberta sob MPL-2.0, evitando apropriação fechada do núcleo do projeto.
- **Compatibilidade estratégica:** permite vincular `CamillaDSP v5` (que adotou licença dupla `GPL-3.0 OR MPL-2.0`), bibliotecas `MIT`/`BSD-2`/`BSD-3`/`0BSD`/`Apache-2.0`, e não fecha a porta para uma eventual edição *Pro* ou versão *lite* na Mac App Store com módulos proprietários isolados em arquivos separados.
- **DCO (`Signed-off-by`) no lugar de CLA:** dispensa transferência jurídica de copyright (que costuma afastar contribuidores experientes de áudio e Swift) enquanto documenta a origem legítima de cada commit.

---

## 2. Regras de Higiene de Dependências e Terceiros

1. **Verificação automatizada de licenças no CI:** todo `Package.swift`, `Cargo.toml` ou `package.json` adicionado exige auditoria de licença antes do merge (`MIT`, `BSD-2-Clause`, `BSD-3-Clause`, `ISC`, `0BSD`, `Apache-2.0`, `MPL-2.0`, `SIL OFL 1.1` para fontes).
2. **Proibição de empacotamento indevido de dados:**
   - Banco de medições `AutoEq`: baixado sob demanda em runtime com cache local e atribuição obrigatória ao autor e equipamento de medição (ver `descobertas.md` §8 — dados `oratory1990` têm direitos de terceiros).
   - Letras sincronizadas (`LRCLIB`): apenas consulta em runtime, sem redistribuição de banco local em releases.
   - Fontes: o app usa as fontes do sistema (SF Pro, SF Mono, New York, ADR-0015) e não embarca nenhuma. `Geist` (OFL) aparece só na web (docs, site, playground), com o `OFL.txt` preservado onde for distribuída.
3. **Nomes e marcas registradas:** respeitar marcas de terceiros (`Sennheiser`, `Momentum`, `Apple`, `AirPods`, `AutoEq`, `FabFilter`) utilizando-as exclusivamente de forma descritiva/nominativa na documentação de compatibilidade.

---

## 3. Modelo de Contribuição Modular

Para escalar sem sobrecarregar mantenedores principais, o repositório separa explicitamente o **núcleo crítico de áudio** das **extensões da comunidade**:

| Área | Política de contribuição | Requisitos de merge |
|---|---|---|
| **Núcleo RT & DSP (`TimbreDSP`)** | Alta barra de revisão (2 aprovações após 1.0); zero regressão em golden tests e RTSan | Golden tests numéricos, zero alocação/lock em callback RT, benchmarks E-06 |
| **Drivers de Hardware (`DeviceDrivers`)** | Protocolo `DeviceDriver` isolado por capacidade (ADR-0011) | Declaração explícita de `read`/`readWrite`, aderência à lista negra (zero DFU/pairing/factory reset), testes de isolamento de timeout |
| **Extensões de Navegador** | Pacotes isolados (`safari/`, `chromium/`, `firefox/`) sob contrato único de mensagens | Manifesto mínimo de permissões, teste de latência de atenuação `< 150 ms` |
| **Design System (`design-system/`)** | Tokens em JSON (`ADR-0012`) + gerador Swift/CSS | Regerar `TimbreTokens.swift` e `tokens.css` e validar 100% no checklist de `00-biblia-do-design-system.md` |
| **Documentação e Localização** | `PT-BR`, `ES` e `EN` obrigatórios na v1 (`.xcstrings`); docs técnicas canônicas em PT-BR + README/guias em EN | Seguir glossário técnico (`01-visao/glossario-tecnico.md`) e taxonomia de evidências |

---

## 4. Pipeline Reproduzível, Segurança de Release e Cadeia de Suprimentos

- **Builds determinísticos / auditáveis:** releases oficiais compiladas exclusivamente via GitHub Actions em runners macOS assinados, com geração de **SBOM** (SPDX/CycloneDX) anexada à release.
- **Assinatura e Notarização:** Developer ID Application + `notarytool` + EdDSA (Sparkle 2 `appcast.xml`).
- **Homebrew Cask oficial:** fórmula verificada com `sha256` apontando diretamente para o artefato assinado do GitHub Releases.
- **Templates e Política de Segurança (`SECURITY.md`):** canal privado para vulnerabilidades (ex.: helper XPC, token localhost de extensões, parser de presets/EQ) e triagem explícita de relatórios de áudio com formulário de diagnóstico exportado do Observatório.

---

## 5. Estratégia de Lançamento e Comunidade

1. **Fase 0–1 (Privado ou Público "Lab/Alpha"):** repositório aberto ou aberto na entrada do MVP após assinatura de `ADR-0001`, com aviso claro de "em laboratório — sujeito aos resultados dos experimentos E-01..E-16".
2. **Release MVP (Gate G2):** foco total em **Mixer por fonte + EQ 64-bit + Notch + Observatório v1**, posicionado honestamente contra FineTune (evidenciando processamento `Float64`, bypass sem tap e Observatório) e SoundSource (open source, sem driver virtual invasivo).
3. **Chamado para drivers da comunidade (pós-MVP):** guia "Como escrever um `DeviceDriver` read-first" usando o driver do Momentum 4 como implementação de referência.
