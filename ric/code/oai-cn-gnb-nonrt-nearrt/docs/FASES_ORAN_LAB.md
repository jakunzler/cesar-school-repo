# Fases do lab O-RAN sobre OAI

Este documento e o indice operacional das tres fases do projeto
`oai-cn-gnb-nonrt-nearrt`, laboratorio avancado da disciplina **RIC / Open RAN**
(Cesar School). Evolui o lab base [`oai-cn-gnb-e2`](../oai-cn-gnb-e2) com nonRT RIC,
nearRT O-RAN SC e SMO/OAM. A ideia central e manter cenarios isolados: cada fase
tem comandos, portas, objetivos e limites claros, para que um experimento nao
quebre outro.

## Visao rapida

| Fase | Nome curto | Objetivo | nearRT | nonRT | SMO/OAM | Estado |
|------|------------|----------|--------|-------|---------|--------|
| 1 | nonRT + FlexRIC | Validar PMS/A1 simulados em paralelo ao E2 FlexRIC | FlexRIC `:36421` | PMS + A1 simulators | Nao | Implementada |
| 2 | O-RAN SC + A1 | Substituir FlexRIC por nearRT O-RAN SC e ligar A1 real | `oran-sc-ric` `:36422` | PMS -> A1 Mediator | Nao | Base implementada |
| 3 | SMO + IA/ML | Adicionar plano de gestao, interfaces abertas, dados e workflow IA/ML | Opcional | Opcional | SMO local + O1/VES/KPM/ML | Implementada |

## Regras de isolamento

1. Fase 1 e Fase 2 nao devem rodar nearRT ao mesmo tempo.
2. Fase 3 nao para nem altera Fase 1/Fase 2; ela usa compose project, rede,
   volume e porta HTTP proprios.
3. Builds da Fase 2 usam binario separado (`nr-softmodem-oran-sc`) para nao
   sobrescrever o build FlexRIC da Fase 1.
4. Logs e artefatos runtime ficam em `logs/` e seguem ignorados pelo git.

## Documentos por fase

| Documento | Conteudo |
|-----------|----------|
| [FASE1_NONRT_FLEXRIC.md](FASE1_NONRT_FLEXRIC.md) | Conceitos, arquitetura, comandos e validacao da Fase 1 |
| [FASE2_ORAN_SC_A1.md](FASE2_ORAN_SC_A1.md) | Conceitos, arquitetura, comandos e validacao da Fase 2 |
| [FASE3_SMO_OAM.md](FASE3_SMO_OAM.md) | Conceitos, arquitetura, comandos e processo inicial da Fase 3 |
| [INTERPRETACAO_FASE1_NONRT_FLEXRIC.md](INTERPRETACAO_FASE1_NONRT_FLEXRIC.md) | Como interpretar resultados e pensar aplicacao real da Fase 1 |
| [INTERPRETACAO_FASE2_ORAN_SC_A1.md](INTERPRETACAO_FASE2_ORAN_SC_A1.md) | Como interpretar resultados e pensar aplicacao real da Fase 2 |
| [INTERPRETACAO_FASE3_SMO_OAM.md](INTERPRETACAO_FASE3_SMO_OAM.md) | Como interpretar resultados e pensar aplicacao real da Fase 3 |
| [PLANO_INTEGRACAO_NONRT_RIC_SMO.md](PLANO_INTEGRACAO_NONRT_RIC_SMO.md) | Plano geral e decisoes de integracao |

## Fluxos recomendados

### Fase 1

```bash
./scripts/up_e2_lab.sh
./scripts/test_nonrt_ric.sh --seed
sudo ./scripts/test_e2_kpm.sh
./scripts/explore_e2_sm.sh quick
./scripts/stress_ue_observe_apps.sh
```

### Fase 2

```bash
./scripts/down_e2_lab.sh
./scripts/build_e2_oran_sc.sh
./scripts/up_oai_oran_lab.sh
./scripts/test_oran_ric.sh --run-xapp
KPM_TRAFFIC=1 ./scripts/run_xapp_oai_kpm.sh
```

### Fase 3

```bash
./scripts/test_smo_lab.sh --preflight
./scripts/up_smo_lab.sh
./scripts/test_smo_lab.sh
./scripts/run_smo_ml_workflow.sh
```

## Matriz de validacao

Use esta matriz como ordem de relevancia. Os testes de prioridade P0/P1 sao os
que demonstram o funcionamento minimo de cada fase; P2/P3 sao aprofundamento,
diagnostico ou carga.

### Fase 1 - nonRT + FlexRIC

| Prioridade | Comando | O que valida | Evidencia esperada | Log principal |
|------------|---------|--------------|--------------------|---------------|
| P0 | `./scripts/test_nonrt_ric.sh --seed` | PMS, Gateway, Control Panel, A1 simulators e criacao de policy/service | health checks `OK`; HTTP `201` ou `200` no seed | `logs/nonrt_ric_up.log` |
| P0 | `sudo ./scripts/test_e2_kpm.sh` | Core, gNB, nrUE, PDU session, FlexRIC, xApp KPM e KPIs | `Connected E2 nodes = 1`, `Successfully subscribed`, `KPM INDICATIONs recebidas` | `logs/xapp_kpm_lab.log`, `logs/gnb_oai.log`, `logs/ue_oai.log` |
| P1 | `./scripts/test_e2_sm.sh cust` | Service Models customizados MAC/RLC/PDCP/GTP via FlexRIC | xApp conectado e indications/leituras por SM | `logs/xapp_cust_moni.log` |
| P1 | `./scripts/explore_e2_sm.sh quick` | Smoke test E2 e resumo rapido dos SMs | `Connected E2 nodes = 1` e `Successfully subscribed` | `logs/xapp_*.log` |
| P2 | `./scripts/test_e2_rc_attach.sh` | E2SM-RC com xApp ativo antes do attach do UE | subscription RC e indication de attach/RRC | `logs/xapp_rc_attach.log` |
| P2 | `UE_SOURCE=nrue ./scripts/stress_ue_observe_apps.sh` | baseline/stress/recovery com KPM e snapshots nonRT | aumento de throughput/PRB durante stress | `logs/ue_stress_*/` |
| P3 | `UE_SOURCE=nrue ./scripts/test-vpp-throughput.sh` | Plano de usuario e throughput do tunel UE | iperf/ping com taxa medida | saida do terminal |
| Diagnostico | `./scripts/diagnose-ue-connection.sh` | Problemas de subscriber, PDU session e tunel UE | causas provaveis e comandos de correcao | saida do terminal |
| Diagnostico | `./scripts/observe_oai_radio_kpis.sh` | KPIs de radio extraidos do log OAI, fora do E2SM-KPM | RSRP/SNR/BLER/MCS para correlacao | `logs/gnb_oai.log` |

Notas da Fase 1:

- `test_e2_kpm.sh` precisa permissao para iniciar gNB/nrUE e criar `oaitun_ue*`;
  use `sudo` quando houver processos OAI como `root` ou quando a interface de UE
  precisar ser recriada.
- O nonRT da Fase 1 usa A1 simulators. Ele nao recebe KPM do FlexRIC e nao fecha
  loop rApp -> A1 -> xApp real.

### Fase 2 - nearRT O-RAN SC + A1

| Prioridade | Comando | O que valida | Evidencia esperada | Log principal |
|------------|---------|--------------|--------------------|---------------|
| P0 | `./scripts/test_oran_ric.sh` | Containers O-RAN SC, A1 mediator, RNIB/Redis e E2 observado em log | `ric_e2term running`, `ric_a1mediator running`, TCP `:10000 OK` | `logs/gnb_oai_oran.log` |
| P0 | `KPM_TRAFFIC=1 ./scripts/run_xapp_oai_kpm.sh` | xApp KPM OAI Style 4 com S-NSSAI do lab | `RIC Indication`, `DRB.UEThpDl`, `DRB.UEThpUl` | `logs/xapp_oai_kpm.log` |
| P1 | `./scripts/test_oran_ric.sh --run-xapp` | Smoke test curto com xApp dentro do runner O-RAN SC | atividade de xApp; sem `503` do subscription manager | `logs/test_oran_ric_xapp.log` |
| P1 | `./scripts/explore_oran_ric.sh full` | Exploracao de E2, A1, RNIB e xApp | resumo completo da stack | saida do terminal e logs O-RAN SC |
| P2 | `./scripts/fix_oran_ric_rnib.sh` | Recuperacao de RNIB/e2mgr/Redis quando a stack fica inconsistente | reinicio limpo de `dbaas`, `e2mgr`, `submgr`, `a1mediator` | saida do terminal |
| Diagnostico | `./scripts/get_oran_e2_node_id.sh` | Descoberta do E2 node registrado no RNIB | `gnb_208_095_00000e00` ou equivalente | saida do terminal |

Notas da Fase 2:

- A Fase 2 deve rodar sem FlexRIC ativo. Pare a Fase 1 com
  `./scripts/down_e2_lab.sh` antes de usar O-RAN SC.
- `test_oran_ric.sh --run-xapp` e uma validacao curta. Para evidencia KPM mais
  forte, prefira `run_xapp_oai_kpm.sh`.
- Se aparecer `503 No E2 connection` ou RNIB vazio, reinicie o gNB O-RAN ou use
  `fix_oran_ric_rnib.sh` antes de repetir o teste.

### Fase 3 - SMO, interfaces abertas, dados e IA/ML

| Prioridade | Comando | O que valida | Evidencia esperada |
|------------|---------|--------------|--------------------|
| P0 | `./scripts/test_smo_lab.sh --preflight` | Compose local, sintaxe Python, porta HTTP e estrutura da Fase 3 | `OK docker compose config`, `OK sintaxe Python SMO` |
| P0 | `./scripts/up_smo_lab.sh` | SMO API, O1 sim, coletor KPM e workflow IA/ML | containers `smo-api`, `smo-o1-sim`, `smo-kpm-collector`, `smo-ml-workflow` ativos |
| P0 | `./scripts/test_smo_lab.sh` | Health, ingestao O1/VES/KPM, armazenamento e leitura de decisoes ML | `/health` OK, topologia, metricas KPM e `ml/runs` respondendo |
| P1 | `sudo ./scripts/test_e2_kpm.sh` com Fase 3 ativa | Coleta KPM real da Fase 1 pelo SMO | novas amostras em `/metrics/kpm` |
| P1 | `KPM_TRAFFIC=1 ./scripts/run_xapp_oai_kpm.sh` com Fase 3 ativa | Coleta KPM real da Fase 2 pelo SMO | novas amostras de `xapp_oai_kpm.log` em `/metrics/kpm` |
| P1 | `./scripts/run_smo_ml_workflow.sh` | Ciclo IA/ML manual sobre dados armazenados | recomendacao `keep-current-policy`, `investigate-*` ou `scale-*` |
| P2 | `curl http://127.0.0.1:18080/openapi` | Contrato HTTP para integracoes externas | descricao OpenAPI simplificada |

Notas da Fase 3:

- A API local padrao fica em `http://127.0.0.1:18080`; use `SMO_API_PORT=18081`
  se a porta estiver ocupada.
- O gNB OAI monolitico deste lab nao expoe O1 NETCONF nativo; a Fase 3 usa
  simulador O1/O-DU/O-RU e correlaciona isso com KPM real das Fases 1/2.
- O modo externo O-RAN SC OAM continua disponivel com `SMO_MODE=external` e
  `SMO_OAM_DIR=/path/para/o-ran-sc-oam`.

## Como voltar a um estado conhecido

Fase 1:

```bash
./scripts/down_e2_lab.sh
./scripts/up_e2_lab.sh
```

Fase 2:

```bash
./scripts/down_oai_oran_lab.sh
./scripts/up_oai_oran_lab.sh
```

Fase 3:

```bash
./scripts/down_smo_lab.sh
```
