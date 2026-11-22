# ADR-0013 · Superfícies de interface

- **Status:** Aceito · revisão em E-12 para o MacBook Pro OLED · revisado em 2026-11-23 (item da barra de menus condicional)
- **Data:** 2026-11-21

## Decisão

| Superfície | Papel | Densidade |
|---|---|---|
| **Notch** (primária) | Estado e controle imediato: volume da fonte em foco, saída, EQ ligado/desligado, alertas do Guardião, HUD de volume | Mínima |
| **Pílula** | Substitui o notch em Macs sem notch, monitores externos e tampa fechada | Mínima |
| **Item da barra de menus** | Fallback: aparece só quando o notch não é a entrada (sem tela com notch, notch desligado, modo só barra de menus) ou por opção em Ajustes | Média |
| **Estúdio** (janela) | EQ detalhado, Correção/Gosto, perfis e regras, drivers, presets, preferências | Alta |
| **Observatório** (aba do Estúdio, ou destacável) | Caminho do sinal, medidores, histórico de eventos | Alta |
| **Live Activity** (macOS 27.3+) | Estado resumido no Mac com Dynamic Island nativa ou na barra de menus | Mínima |

Regra: **o notch nunca contém configuração**; contém estado e ações diretas. Tudo que precisa de mais de dois níveis vai para o Estúdio.

## Motivo

A Dynamic Island nativa do MacBook Pro OLED pode impedir overlays de terceiros; o now playing básico tende a ser absorvido pelo sistema. Ancorar o produto em várias superfícies coerentes protege o valor central (mixer e EQ), que não depende do formato do notch.

## Revisão 2026-11-23 · Ícone da barra de menus condicional

O dono apontou que, com o notch ativo, o ícone na barra de menus é redundante. Decisão:

- Com o notch ativo, o ícone fica **oculto por padrão**.
- Os acessos que só ele dava passam para o próprio notch, via **menu de contexto** (clique direito: Abrir Estúdio, Ajustes…, Mostrar ícone na barra de menus, Sair).
- **Reabrir o app** abre o Estúdio, e **⌘,** abre os Ajustes do Estúdio.

Implementação: `NSStatusItem` + `NSPopover` (`MenuBarIconController`) em vez do `MenuBarExtra` do SwiftUI. Controlar `MenuBarExtra(isInserted:)` pelo estado do app deixou o SwiftUI reconstruindo o menu principal em laço (100 % de CPU, o app não fechava). Esse defeito foi medido em `sample` e registrado em `descobertas.md`.
