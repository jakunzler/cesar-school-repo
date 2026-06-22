# Fase 3 - SMO, interfaces abertas, dados e IA/ML

Guia de interpretacao associado:
[INTERPRETACAO_FASE3_SMO_OAM.md](INTERPRETACAO_FASE3_SMO_OAM.md).

## Objetivo

A Fase 3 adiciona um plano SMO isolado para:

- coletar dados por interfaces abertas de gestao e telemetria;
- armazenar topologia, eventos VES e KPMs em banco local;
- correlacionar dados O1/VES com KPMs das Fases 1/2;
- conduzir um workflow IA/ML simples que gera recomendacoes operacionais.

Ela nao substitui Fase 1 ou Fase 2. A Fase 3 pode rodar em paralelo porque usa
porta propria no host, rede Docker propria e volume proprio.

## Estado no projeto

| Item | Estado |
|------|--------|
| Compose SMO local | Implementado em `config/smo/docker-compose.yml` |
| API SMO aberta | Implementada em `smo-api` |
| O1/topologia simulada | Implementada em `o1-sim` |
| VES collector HTTP | Implementado em `/ves/v7/events` |
| Coleta KPM Fase 1/2 | Implementada em `kpm-collector` lendo `logs/xapp_kpm_lab.log` e `logs/xapp_oai_kpm.log` |
| Armazenamento | SQLite persistente no volume `oai-smo-lab-data` |
| Workflow IA/ML | Implementado em `ml-workflow` e `scripts/run_smo_ml_workflow.sh` |
| O1 real para gNB OAI | Nao suportado pelo gNB monolitico |
| Modo O-RAN SC OAM externo | Mantido via `SMO_MODE=external` |

## Arquitetura

```text
Fase 3 - SMO local

  +----------------------+      REST/JSON       +----------------------+
  | o1-sim               | -------------------> | smo-api              |
  | O-DU/O-RU/nearRT sim |  O1 topology + VES   | O1, VES, KPM, ML API |
  +----------------------+                      +----------+-----------+
                                                          |
  +----------------------+      REST/JSON                 | SQLite
  | kpm-collector        | -------------------------------+
  | logs Fase 1/Fase 2   |  KPM metrics
  +----------------------+
                                                          |
  +----------------------+      REST/JSON                 |
  | ml-workflow          | <-------------------------------+
  | decisao IA/ML        |  KPM + topologia + eventos
  +----------------------+

Fase 1/Fase 2 continuam independentes:

  Fase 1: FlexRIC :36421 + xApp KPM -> logs/xapp_kpm_lab.log
  Fase 2: O-RAN SC :36422 + xApp KPM -> logs/xapp_oai_kpm.log
```

## Isolamento

| Recurso | Fase 3 |
|---------|--------|
| Compose project | `oai-smo-lab` |
| Rede Docker | `oai-smo-lab-net` |
| Volume | `oai-smo-lab-data` |
| Porta no host | `SMO_API_PORT`, padrao `18080` |
| Portas E2 | Nao usa `36421` nem `36422` |
| Containers Fase 1/2 | Nao sao parados nem modificados |

Se `18080` estiver ocupada:

```bash
SMO_API_PORT=18081 ./scripts/up_smo_lab.sh
SMO_API_PORT=18081 ./scripts/test_smo_lab.sh
```

## Comandos principais

Preflight:

```bash
./scripts/test_smo_lab.sh --preflight
```

Subir:

```bash
./scripts/up_smo_lab.sh
```

Validar:

```bash
./scripts/test_smo_lab.sh
```

Executar um ciclo IA/ML manual:

```bash
./scripts/run_smo_ml_workflow.sh
```

Parar:

```bash
./scripts/down_smo_lab.sh
```

## Interfaces abertas

API padrao:

```bash
export SMO_API_URL=http://127.0.0.1:18080
```

| Endpoint | Metodo | Papel |
|----------|--------|-------|
| `/health` | GET | Health check |
| `/openapi` | GET | Descricao OpenAPI simplificada |
| `/o1/v1/nodes` | GET/POST | Inventario/topologia O1 |
| `/ves/v7/events` | GET/POST | Eventos VES |
| `/metrics/kpm` | GET/POST | Metricas KPM coletadas dos xApps |
| `/topology` | GET | Snapshot topologico + eventos recentes |
| `/ml/runs` | GET/POST | Decisoes do workflow IA/ML |

Exemplos:

```bash
curl "$SMO_API_URL/health"
curl "$SMO_API_URL/topology"
curl "$SMO_API_URL/metrics/kpm?limit=20"
curl "$SMO_API_URL/ml/runs?limit=5"
```

## Coleta de dados

### O1/VES

O container `o1-sim` publica periodicamente:

- nodes O-DU/O-RU/nearRT-RIC em `/o1/v1/nodes`;
- eventos VES de medicao em `/ves/v7/events`.

Isso demonstra o plano de gestao por interfaces abertas sem prometer O1 nativo
no gNB OAI.

### KPM das Fases 1/2

O container `kpm-collector` observa:

- `logs/xapp_kpm_lab.log` da Fase 1;
- `logs/xapp_oai_kpm.log` da Fase 2.

Quando encontra linhas como:

```text
DRB.UEThpDl = 16.44 [kbps]
RRU.PrbTotUl = 2 [%]
```

ele envia as amostras para `/metrics/kpm` e o `smo-api` persiste no SQLite.

## Workflow IA/ML

O `ml-workflow` roda periodicamente e usa uma baseline por limiar:

| Entrada | Uso |
|---------|-----|
| `DRB.UEThpDl` | detecta throughput DL baixo |
| `DRB.UEThpUl` | detecta throughput UL baixo |
| `RRU.PrbTotUl` | detecta ocupacao UL elevada |
| eventos/topologia | contexto operacional armazenado no SMO |

Recomendacoes possiveis:

| Recomendacao | Significado |
|--------------|-------------|
| `collect-more-data` | ainda nao ha dados suficientes |
| `keep-current-policy` | KPIs dentro da baseline |
| `investigate-low-downlink-throughput` | DL abaixo do limiar |
| `investigate-low-uplink-throughput` | UL abaixo do limiar |
| `scale-or-shift-uplink-load` | PRB UL acima do limiar |

Limiar customizado:

```bash
ML_THROUGHPUT_LOW_KBPS=10 ML_PRB_HIGH_PCT=70 ./scripts/up_smo_lab.sh
```

## Ordem recomendada de teste

| Prioridade | Comando | O que valida |
|------------|---------|--------------|
| P0 | `./scripts/test_smo_lab.sh --preflight` | Compose, sintaxe Python e porta SMO |
| P0 | `./scripts/up_smo_lab.sh` | SMO local, API, O1 sim, coletor KPM e ML workflow |
| P0 | `./scripts/test_smo_lab.sh` | Health, ingestao O1/VES/KPM, topologia e dados ML |
| P1 | `sudo ./scripts/test_e2_kpm.sh` + Fase 3 ativa | Coleta KPM real da Fase 1 pelo SMO |
| P1 | `KPM_TRAFFIC=1 ./scripts/run_xapp_oai_kpm.sh` + Fase 3 ativa | Coleta KPM real da Fase 2 pelo SMO |
| P1 | `./scripts/run_smo_ml_workflow.sh` | Ciclo IA/ML manual sobre dados armazenados |
| P2 | `curl "$SMO_API_URL/openapi"` | Contrato de API para integracoes externas |

## Modo externo O-RAN SC OAM

O modo antigo continua disponivel quando for necessario testar um checkout
oficial O-RAN SC OAM/SMO:

```bash
export SMO_MODE=external
export SMO_OAM_DIR=/path/para/o-ran-sc-oam
./scripts/test_smo_lab.sh --preflight
./scripts/up_smo_lab.sh
./scripts/down_smo_lab.sh
```

Esse modo nao e usado por padrao porque exige muitas imagens, portas e memoria.

## Limites atuais

- O gNB OAI monolitico do lab nao expoe O1 NETCONF nativo.
- O workflow IA/ML e uma baseline deterministica, criada para validar o caminho
  de dados antes de treinar modelos mais pesados.
- O closed loop completo ate A1/xApp/E2 ainda exige conectar a recomendacao do
  SMO a uma rApp/nonRT policy.
