# ADR-0013 · Superfícies de interface

- **Status:** Aceito · revisão em E-12 para o MacBook Pro OLED
- **Data:** 2026-11-21

## Decisão

| Superfície | Papel | Densidade |
|---|---|---|
| **Notch** (primária) | Estado e controle imediato: volume da fonte em foco, saída, EQ ligado/desligado, alertas do Guardião, HUD de volume | Mínima |
| **Pílula** | Substitui o notch em Macs sem notch, monitores externos e tampa fechada | Mínima |
| **Item da barra de menus** | Acesso por teclado e por quem esconde o notch; fallback universal | Média |
| **Estúdio** (janela) | EQ detalhado, Correção/Gosto, perfis e regras, drivers, presets, preferências | Alta |
| **Observatório** (aba do Estúdio, ou destacável) | Caminho do sinal, medidores, histórico de eventos | Alta |
| **Live Activity** (macOS 27.3+) | Estado resumido no Mac com Dynamic Island nativa ou na barra de menus | Mínima |

Regra: **o notch nunca contém configuração**; contém estado e ações diretas. Tudo que precisa de mais de dois níveis vai para o Estúdio.

## Motivo

A Dynamic Island nativa do MacBook Pro OLED pode impedir overlays de terceiros; o now playing básico tende a ser absorvido pelo sistema. Ancorar o produto em várias superfícies coerentes protege o valor central (mixer e EQ), que não depende do formato do notch.
