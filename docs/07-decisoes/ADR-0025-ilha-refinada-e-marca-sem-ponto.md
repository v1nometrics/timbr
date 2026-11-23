# ADR-0025 · Ilha refinada e marca sem ponto

- **Status:** Aceito · 2026-11-23
- **Substitui:** ADR-0022 integralmente e regras de símbolo/ponto nas ADRs 0014 e 0016.

## Contexto

Após avaliação de cinco variações híbridas notch/máscara, a versão original *Ilha refinada* se mostrou mais limpa, equilibrada e reconhecível em todos os tamanhos, sendo adotada em conjunto com a remoção do ponto final da assinatura da marca.

## Decisão

Marca pública **timbr**, caixa baixa, SF Pro Semibold, sem ponto final nem ponto de estado incorporado à assinatura. Pontuação gramatical e indicadores de estado independentes continuam existindo.

Símbolo: **Ilha refinada original**, sem redesenho: bloco `#F3F3F1`, contorno `#DEDED9`, pílula preta, olho quadrado arredondado e três barras `#F2F2F2`. Fonte canônica `Resources/Brand/timbr-icon.svg`; variante óptica original até 64 px em `timbr-icon-small.svg`. O gerador lê as coordenadas desses SVGs. As variações híbridas exploratórias foram descartadas.

Aplicações: ícone ICNS do app/Dock/Finder/instalador, tela Sobre, introdução, barra de menus com template monocromático, README e playground. Na barra, o recorte isolado da pílula com olho/barras mantém o mesmo desenho, sem o bloco de app. Processamento desligado atenua o ícone, sem alterar sua expressão. O visualizador dinâmico de cinco barras do notch continua sendo um medidor, não o símbolo da marca.

Identificadores técnicos (`com.timbr.app`, `dev.v1torres.timbr`, caminhos, SQLite, nomes de executável e URLs) permanecem estáveis para preservar permissões e dados. O nome público no bundle é `timbr`.

## Alternativas e trade-offs

As variações híbridas notch/máscara foram descartadas por adicionarem ruído visual em tamanhos pequenos. O ponto final foi retirado por não agregar função semântica à assinatura; a silhueta da ilha distingue a marca sem decoração adicional. Em 16 px há limite físico de legibilidade, atendido pela variante óptica dedicada (`timbr-icon-small.svg`).

## Evidência e revisão

Verificação de build, suíte de testes e capturas registrada em [`docs/08-registro/progresso.md`](../08-registro/progresso.md). A atualização visual preserva intactas todas as garantias de áudio e identificadores técnicos. Revisões futuras exigem nova ADR.
