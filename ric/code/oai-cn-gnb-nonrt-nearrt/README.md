# OAI CN + gNB + Stack O-RAN (nonRT + nearRT + SMO)

Laboratório avançado da disciplina **RAN Intelligent Controller (RIC)** / **Open RAN** — evolução do [Projeto 2 (E2 + FlexRIC)](../oai-cn-gnb-e2).

Pilha **OpenAirInterface** (5G Core em Docker + gNB/nrUE com **RFSIM**) estendida com os planos de controle **O-RAN**: **nonRT RIC**, **nearRT RIC** (FlexRIC ou O-RAN SC) e scaffold **SMO/OAM**, em três fases isoladas e reproduzíveis.

## Proposta na disciplina

| Aspecto | Conteúdo |
|---------|----------|
| **Pré-requisito** | Lab E2 funcional em [`oai-cn-gnb-e2`](../oai-cn-gnb-e2) (interface E2, E2SM-KPM/RC, xApps FlexRIC) |
| **Objetivo** | Percorrer a arquitetura O-RAN além do nearRT: políticas A1 (nonRT), nearRT O-RAN SC e gestão SMO/OAM |
| **Abordagem** | Três fases com stacks isoladas — cada fase tem portas, scripts e documentação próprios |
| **Entregável** | Evidências de validação por fase (logs, health checks, subscrições E2/KPM, policies A1) |

### Fases do laboratório

| Fase | Foco | nearRT | nonRT | Documento |
|------|------|--------|-------|-----------|
| **1** | nonRT RIC + FlexRIC em paralelo | FlexRIC `:36421` | PMS + A1 simulators | [docs/FASE1_NONRT_FLEXRIC.md](docs/FASE1_NONRT_FLEXRIC.md) |
| **2** | nearRT O-RAN SC + A1 real | `oran-sc-ric` `:36422` | PMS → A1 Mediator | [docs/FASE2_ORAN_SC_A1.md](docs/FASE2_ORAN_SC_A1.md) |
| **3** | SMO/OAM (gestão e O1 simulado) | Opcional | Opcional | [docs/FASE3_SMO_OAM.md](docs/FASE3_SMO_OAM.md) |

Índice operacional: [docs/FASES_ORAN_LAB.md](docs/FASES_ORAN_LAB.md) · Plano de integração: [docs/PLANO_INTEGRACAO_NONRT_RIC_SMO.md](docs/PLANO_INTEGRACAO_NONRT_RIC_SMO.md).

## Documentação

| Documento | Conteúdo |
|-----------|----------|
| [docs/FASES_ORAN_LAB.md](docs/FASES_ORAN_LAB.md) | Índice das três fases, regras de isolamento e fluxos |
| [docs/E2_FLEXRIC.md](docs/E2_FLEXRIC.md) | Build, deploy e troubleshooting E2 (Fase 1) |
| [docs/E2_SERVICE_MODELS.md](docs/E2_SERVICE_MODELS.md) | KPM, RC, custom SMs e testes |
| [docs/NONRT_RIC.md](docs/NONRT_RIC.md) | nonRT RIC O-RAN SC (PMS, A1 simulators, Control Panel) |
| [docs/ORAN_RIC_FASE2.md](docs/ORAN_RIC_FASE2.md) | nearRT O-RAN SC + A1 Mediator |
| [docs/XAPP_KPM_OAI_ORAN.md](docs/XAPP_KPM_OAI_ORAN.md) | xApp KPM com nearRT O-RAN SC |

## Início rápido

```bash
cd ric/code/oai-cn-gnb-nonrt-nearrt

# Fase 1 — nonRT + FlexRIC (recomendado para começar)
./scripts/build_e2.sh
./scripts/build_flexric_tools.sh
./scripts/up_e2_lab.sh
./scripts/up_nonrt_ric.sh
./scripts/test_nonrt_ric.sh --seed
./scripts/explore_e2_sm.sh quick

# Fase 2 — nearRT O-RAN SC (parar Fase 1 antes)
./scripts/down_e2_lab.sh
./scripts/build_e2_oran_sc.sh
./scripts/up_oai_oran_lab.sh
./scripts/test_oran_ric.sh --run-xapp

# Parar
./scripts/down_e2_lab.sh            # mantém Core
./scripts/down_nonrt_ric.sh         # nonRT RIC
./scripts/down_oai_oran_lab.sh      # Fase 2
```

## Estrutura

```
oai-cn-gnb-nonrt-nearrt/
├── oai-cn5g-fed/           # 5G Core OAI (docker-compose)
├── openairinterface5g/     # RAN OAI + submodule FlexRIC (E2AP)
├── flexric-lib/            # Service Models (.so) — gerado pelo build
├── config/
│   ├── flexric/            # nearRT-RIC FlexRIC (Fase 1)
│   ├── nonrtric/           # nonRT RIC O-RAN SC (Fase 1)
│   ├── oran-ric/           # nearRT O-RAN SC (Fase 2)
│   └── smo/                # SMO/OAM (Fase 3)
├── vendor/oran-sc-ric/     # Referência O-RAN SC (xApps Python)
├── scripts/                # automação por fase
└── logs/                   # artefatos de execução (gitignored)
```

Relação com o lab base: [`ric/code/oai-cn-gnb-e2`](../oai-cn-gnb-e2) cobre E2 + FlexRIC; este projeto adiciona nonRT, O-RAN SC e SMO sem substituir o roteiro do Projeto 2.
