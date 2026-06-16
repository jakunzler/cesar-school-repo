# OAI CN + gNB + FlexRIC (E2)

Laboratório da disciplina **RAN Intelligent Controller (RIC)** — Aulas 04–06.

Pilha **OpenAirInterface** (5G Core em Docker + gNB/nrUE nativos com **RFSIM**) integrada ao **FlexRIC** como Near-RT RIC, com **interface E2** e xApps de referência (E2SM-KPM, E2SM-RC).

## Documentação

| Documento | Conteúdo |
|-----------|----------|
| [docs/E2_FLEXRIC.md](docs/E2_FLEXRIC.md) | Build, deploy, scripts, troubleshooting E2 |
| [docs/E2_SERVICE_MODELS.md](docs/E2_SERVICE_MODELS.md) | KPM, RC, custom SMs e testes |
| [../../docs/labs/02-oai-cn-gnb-flexric-e2.md](../../docs/labs/02-oai-cn-gnb-flexric-e2.md) | Roteiro da disciplina e entregáveis Projeto 2 |

## Início rápido

```bash
cd ric/code/oai-cn-gnb-e2

# Build (uma vez; ~30–60 min)
./scripts/build_e2.sh
./scripts/build_flexric_tools.sh

# Subir laboratório completo
./scripts/up_e2_lab.sh

# Testar E2
./scripts/test_e2_sm.sh cust      # MAC/RLC/PDCP/GTP
./scripts/test_e2_kpm.sh            # E2SM-KPM (slice 222/123)
./scripts/test_e2_rc_attach.sh      # E2SM-RC (attach fresco)
./scripts/verify_e2_lab.sh           # checagem automatizada

# Parar
./scripts/down_e2_lab.sh            # mantém Core
./scripts/down_e2_lab.sh --all      # Core + RAN + RIC
```

## Estrutura

```
oai-cn-gnb-e2/
├── oai-cn5g-fed/          # 5G Core OAI (docker-compose)
├── openairinterface5g/    # RAN OAI + submodule FlexRIC (E2AP)
├── flexric-lib/           # Service Models (.so) — gerado pelo build
├── config/flexric/        # flexric.conf do nearRT-RIC
├── scripts/               # automação build/deploy/testes E2
└── logs/                  # gnb_oai.log, nearRT-RIC.log, xapp_*.log
```

Referência upstream: [OAI E2 tutorial](openairinterface5g/openair2/E2AP/README.md).
