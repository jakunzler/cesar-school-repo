# Laboratórios — Open5GS + UERANSIM (Interfaces e Protocolos)

Roteiros para execução em sala ou de forma autônoma e para elaboração do **relatório de entrega**.

| Documento | Conteúdo |
|-----------|----------|
| [01 — Infraestrutura e Core 5GC (Open5GS)](01-core-open5gs.md) | Docker, subida do core, assinante, WebUI, verificações iniciais |
| [02 — UERANSIM: N2/N3 e teste E2E](02-ueransim-n2-n3-e2e.md) | gNB + UE em container, NGAP, GTP-U, testes e capturas N3/N6 |
| [Relatório, entrega e avaliação](04-relatorio-entrega-avaliacao.md) | O que entregar, evidências obrigatórias, rubrica |

**Pré-requisitos:** Linux com Docker e Docker Compose v2, usuário com permissão para `docker` (e eventualmente `sudo` para `sysctl` na inicialização do core e para `tcpdump` no *host*, se fizer capturas avançadas).

**Raiz do projeto (convenção nos comandos):** `open5gs-containerized/` — ajuste os `cd` se o seu clone estiver em outro caminho (ex.: `code/open5gs-containerized`).

**Referência técnica:** [README.md](../../README.md), [core/docs/CORE.md](../../core/docs/CORE.md), [ueransim/docs/RAN.md](../../ueransim/docs/RAN.md).
