# ADR-0024 · Feedback por e-mail, local e visível

- **Status:** Aceito · 2026-11-23 (pedido do dono do produto: uma seção de feedback e sugestões, perto da doação, direcionada ao e-mail dele)

## Contexto

O dono quer receber sugestões, problemas e pedidos de fones ou apps. O timbr. promete **100% local, sem telemetria, sem conta**, e isso é parte do produto (e do `support.body` que a pessoa lê na própria página). Qualquer coleta automática, mesmo "inteligente", quebraria essa promessa.

## Decisão

1. **A pessoa escreve, vê tudo e decide.** O app não envia nada e não abre conexão de rede para isso. O botão **Enviar por e-mail** abre o app de e-mail da própria pessoa (`mailto:`) com a mensagem pronta. Se não houver app de e-mail configurado, o texto é copiado e a tela explica.
2. **Endereço:** `vinicius@v1torres.dev` (confirmado pelo dono; está no código aberto, constante em `FeedbackComposer.recipient`).
3. **Onde:** página **Sobre**, logo abaixo de "Código-fonte" e "Apoiar o projeto" (a doação), e item **Enviar feedback…** no menu de contexto do notch. Quem prefere o canal público tem o link para abrir uma issue no GitHub.
4. **"Coleta inteligente" = contexto mínimo, escolhido por quem envia.** Categorias (Sugestão, Problema, Fone ou app, Elogio, Outro) mudam o assunto do e-mail e a pergunta-guia do campo. Acompanham, cada uma com seu interruptor: versão do timbr., versão do macOS, **tipo** de saída (Bluetooth, fone com fio, alto-falante…), modo do equalizador e idioma. **Nunca:** nome do fone, áudio, histórico de eventos, caminhos, nome de usuário ou qualquer dado pessoal.
5. **Transparência:** o painel "O e-mail vai com exatamente isto" mostra o mesmo texto que será enviado (a função que monta o corpo é uma só, usada na tela e no `mailto:`).
6. **Eficiência:** mínimo de 10 e máximo de 1.500 caracteres (o `mailto:` precisa caber na URL), rascunho guardado neste Mac (um e-mail meio escrito sobrevive a fechar o app), sem pedir nota, sem lembretes e sem janelas. O conteúdo nunca vai para o histórico: só "abriu o e-mail de feedback (categoria)".
7. **Idioma do destinatário:** assunto e rótulos de contexto em português (quem lê é o dono), a mensagem no idioma que a pessoa escrever.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Enviar o feedback por um serviço (formulário, SMTP, API) | Exige rede, servidor, chave e privacidade; quebra "100% local". O `mailto:` não exige nada disso |
| Anexar o relatório de diagnóstico automaticamente | O `mailto:` não anexa arquivos, e o relatório contém nomes de dispositivos. Quem precisar exporta o diagnóstico em Ajustes e anexa à mão |
| Pedir avaliação ou pesquisa dentro do app | Interrompe; a pessoa vem quando quer, e o menu do notch está a um clique |
| Métricas de uso | Telemetria, fora de questão (ADR-0001, princípio P6) |

## Limites

- Depende de a pessoa ter um app de e-mail configurado (senão, copia). Webmail no navegador só funciona se estiver registrado como padrão para `mailto:`.
- O texto vai em claro pelo e-mail dela; o aviso na tela diz o que acompanha, mas o conteúdo da mensagem é dela.
- O endereço fica público no repositório: é um endereço de contato, escolhido pelo dono.

## Evidência

- `TimbreCoreTests`: o destinatário, a validação, a normalização, o assunto por categoria, cada interruptor isolado, "nome do dispositivo nunca entra", a URL `mailto:` (CRLF, `&`, `=`, acentos) e a decodificação que devolve exatamente o texto escrito.
- Captura real da seção (categoria, campo, contexto, preview, botões).
- `./scripts/ci_check.sh` verde (424 chaves PT/ES/EN em paridade).
