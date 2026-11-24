# Instalar e atualizar o timbr

O timbr requer um Mac com Apple Silicon e macOS 15 ou posterior. A primeira versão com assinatura Developer ID e notarização Apple está em preparação. As versões anteriores em GitHub Releases são betas de desenvolvimento. Aguarde a confirmação da versão notarizada para recomendar o download a outras pessoas.

## Primeira instalação

1. Na página da versão aprovada, baixe **Timbr.dmg**. Abra o arquivo em **Downloads**. O Finder monta um disco com o app e um atalho para **Aplicativos**. O DMG abre diretamente, sem extração.
2. Arraste **Timbr** para **Aplicativos**. Abra a cópia que está em **Aplicativos** e ejete o disco de instalação pelo Finder.
3. Na introdução, conceda apenas as permissões dos recursos que deseja usar. Você pode voltar a elas em **Estúdio → Ajustes → Permissões**.

| Recurso | Onde autorizar | Passo |
|---|---|---|
| Teclas de volume e brilho no notch | **Acessibilidade** | Ative **timbr**. Se estiver ausente, use **+** e selecione a cópia de **Aplicativos**. Volte ao timbr e teste uma tecla. |
| Mixer por app e equalizador | **Gravação do Áudio do Sistema e da Tela** | Ative **timbr** se estiver na lista. Se estiver ausente, reproduza áudio em outro app e ajuste o volume dele no Mixer do timbr para que o macOS apresente a solicitação de captura de áudio. Siga qualquer pedido de reabertura mostrado pelo macOS. |
| Leitura de dados de fones compatíveis | **Bluetooth** | Conceda apenas se quiser usar bateria e demais informações disponíveis para o seu fone. |

Os botões do timbr abrem a lista da permissão. Se precisar chegar até ela manualmente, comece em **Ajustes do Sistema → Privacidade e Segurança** e escolha a categoria da tabela. O timbr processa áudio localmente.

### Se você já usa uma beta sem notarização

A primeira troca de assinatura para Developer ID pode exigir aprovação de permissões uma vez. Para um DMG beta que você já decidiu testar e baixou da página oficial, abra primeiro a cópia de **Aplicativos**. Se o macOS bloquear a abertura, o botão **Abrir Mesmo Assim** aparece em **Ajustes do Sistema → Privacidade e Segurança**, no fim da seção **Segurança**, após a tentativa. A Apple documenta esse fluxo no [guia do macOS](https://support.apple.com/102445). O controle dessa tela pertence ao macOS.

## Atualizações

Abra **Estúdio → Ajustes → Atualizações → Verificar agora**. O menu de contexto do notch também oferece **Verificar atualizações…**.

O timbr verifica o download e a assinatura antes de trocar o app. Em **Aplicativos**, a troca automática exige que a nova build satisfaça o requisito de assinatura da instalada. Se faltar essa condição, o timbr salva o instalador e oferece **Abrir DMG**. Nesse caso, feche o timbr, substitua a cópia em **Aplicativos** e abra novamente. Suas preferências e o histórico são guardados separadamente do app.
