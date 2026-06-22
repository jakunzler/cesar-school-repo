# Fase 2 - nearRT O-RAN SC + A1 real

Guia de interpretacao associado:
[INTERPRETACAO_FASE2_ORAN_SC_A1.md](INTERPRETACAO_FASE2_ORAN_SC_A1.md).

## Objetivo

A Fase 2 substitui o nearRT FlexRIC por um nearRT O-RAN SC (`oran-sc-ric`) e
conecta o nonRT PMS ao A1 Mediator real. O foco e validar E2 com o gNB OAI em
porta `36422`, xApps no ambiente O-RAN SC e o caminho A1 nonRT -> nearRT.

## Conceitos

| Conceito | Papel nesta fase |
|----------|------------------|
| `ric_e2term` | Termina E2AP/SCTP vindo do gNB |
| `ric_e2mgr` | Registra e gerencia E2 nodes |
| `ric_submgr` | Gerencia subscriptions de xApps |
| `ric_a1mediator` | Expõe A1 para policies vindas do nonRT |
| RNIB/SDL | Inventario de E2 nodes, mantido no Redis/DBAAS |
| xApp KPM OAI | xApp Python ajustado para KPM Style 4 e S-NSSAI do lab |

## Arquitetura

```text
                         Fase 2 - O-RAN SC

  nonRT RIC perfil oran
  +-------------------------------------------------------+
  | PMS :8081 -> Gateway -> A1 endpoint ric_a1mediator   |
  +------------------------------+------------------------+
                                 |
                                 v A1
  nearRT O-RAN SC Docker         |
  +-------------------------------------------------------+
  | ric_a1mediator :10000                              |
  | ric_e2term :36422 <- E2AP SCTP <- gNB OAI          |
  | ric_e2mgr / ric_submgr / ric_dbaas / xApp runner   |
  +-------------------------------------------------------+

  5G
  +-------------------------------------------------------+
  | Core OAI + UPF-VPP <-NGAP/GTP-U-> gNB/nrUE OAI        |
  +-------------------------------------------------------+
```

## Diferencas em relacao a Fase 1

| Tema | Fase 1 | Fase 2 |
|------|--------|--------|
| nearRT | FlexRIC | O-RAN SC `oran-sc-ric` |
| E2 porta | `36421` | `36422` |
| A1 | Simuladores | A1 Mediator real |
| gNB binario | `nr-softmodem` | `nr-softmodem-oran-sc` |
| xApps | FlexRIC C examples | Python/xApp runner O-RAN SC |

## Comandos principais

Preparar binario OAI para O-RAN SC:

```bash
./scripts/build_e2_oran_sc.sh
```

Subir Fase 2 completa:

```bash
./scripts/down_e2_lab.sh
./scripts/up_oai_oran_lab.sh
```

Subir sem nonRT:

```bash
NONRT_RIC=0 ./scripts/up_oai_oran_lab.sh
```

Validar:

```bash
./scripts/test_oran_ric.sh
./scripts/test_oran_ric.sh --run-xapp
./scripts/explore_oran_ric.sh full
```

Rodar xApp KPM recomendado:

```bash
KPM_TRAFFIC=1 ./scripts/run_xapp_oai_kpm.sh
```

Por padrao, ao receber `Ctrl+C`, o xApp OAI encerra sem enviar
`RIC Subscription Delete`. Este e um workaround para preservar o gNB OAI neste
lab: o fluxo de unsubscribe pode acionar uma assertion no decoder E2AP do
`nr-softmodem-oran-sc` e derrubar a sessao RAN. Para testar explicitamente o
delete subscription, use:

```bash
XAPP_UNSUBSCRIBE_ON_EXIT=1 KPM_TRAFFIC=1 ./scripts/run_xapp_oai_kpm.sh
```

Neste modo experimental, se o gNB abortar, reinicie a RAN com
`./scripts/up_gnb_oai_oran.sh`.

Parar:

```bash
./scripts/down_oai_oran_lab.sh
```

## Ordem de validacao

| Ordem | Teste | Quando usar | Sucesso esperado |
|-------|-------|-------------|------------------|
| 1 | `./scripts/test_oran_ric.sh` | Sempre, logo apos subir a Fase 2 | containers `ric_*` ativos, A1 mediator TCP `:10000 OK`, RNIB/Redis acessivel |
| 2 | `KPM_TRAFFIC=1 ./scripts/run_xapp_oai_kpm.sh` | Principal evidencia KPM da Fase 2 | `RIC Indication` com `DRB.UEThpDl` e `DRB.UEThpUl` |
| 3 | `./scripts/test_oran_ric.sh --run-xapp` | Smoke test curto do runner O-RAN SC | xApp sem `503` e com atividade KPM |
| 4 | `./scripts/explore_oran_ric.sh full` | Diagnostico/exploracao de A1, E2, RNIB e xApp | resumo completo da stack |
| 5 | `./scripts/get_oran_e2_node_id.sh` | Quando o xApp precisar do node ID ou o RNIB estiver suspeito | `gnb_208_095_00000e00` ou ID equivalente |
| 6 | `./scripts/fix_oran_ric_rnib.sh` | Apenas quando RNIB/e2mgr/Redis ficam inconsistentes | stack O-RAN SC recriada parcialmente e pronta para novo gNB |

Considere `test_oran_ric.sh --run-xapp` como smoke test. Para evidencia de KPM
mais forte, use `run_xapp_oai_kpm.sh`, que foi ajustado para o gNB OAI, KPM
Style 4 e S-NSSAI `222/123`.

## Verificacoes importantes

E2:

```bash
grep -iE 'E2|RIC|setup|PORT = 36422' logs/gnb_oai_oran.log | tail -40
docker logs ric_e2term 2>&1 | tail -40
docker exec ric_dbaas redis-cli KEYS '{e2Manager},RAN:gnb_*'
./scripts/get_oran_e2_node_id.sh
```

A1:

```bash
curl -s http://127.0.0.1:10000/a1-p/healthcheck
curl -s http://127.0.0.1:10000/a1-p/policytypes/
curl -s http://127.0.0.1:8081/a1-policy/v2/rics
```

xApp KPM:

```bash
./scripts/run_xapp_oai_kpm.sh
grep -iE 'Subscribe|INDICATION|DRB\.|UEThp|Prb' logs/xapp_oai_kpm.log 2>/dev/null
```

Saida esperada do monitor:

```text
RIC Indication from gnb_208_095_00000e00 (sub N)
  receivedAt: 2026-06-15 HH:MM:SS UTC
  kpmTimeRaw: ...
  kpmTimeDecoded: 2026-06-15 HH:MM:SS UTC
  UE_id: ...
    DRB.UEThpDl: ... kbps
    DRB.UEThpUl: ... kbps
```

Use `receivedAt` como horario de observacao do xApp. O `kpmTimeDecoded` vem do
cabecalho E2SM-KPM `colletStartTime`; neste lab OAI v2.03 ele e decodificado a
partir de 4 bytes Unix seconds em little-endian, com fallback para big-endian em
capturas de outros stacks.

## KPMs e impacto esperado

| KPM | Unidade | Uso cotidiano | Como testar |
|-----|---------|---------------|-------------|
| `DRB.UEThpDl` / `DRB.UEThpUl` | `kbps` | experiencia de throughput do UE | iperf ou ping continuo pelo tunel UE |
| `DRB.PdcpSduVolumeDL` / `DRB.PdcpSduVolumeUL` | `Mb` | volume por DRB na janela KPM | carga sustentada |
| `RRU.PrbTotDl` / `RRU.PrbTotUl` | `%` | ocupacao de recursos de radio | aumentar streams/UDP rate |
| `DRB.RlcSduDelayDl` | `us` | atraso no caminho RLC | carga maior e comparacao baseline/stress |

Observacao: o xApp pode imprimir `μs`; nos resumos automatizados usamos `us`
para manter a saida ASCII.

## Riscos e cuidados

- O-RAN SC pode manter timeout de E2 por ~60s apos desconexao; aguarde antes de
  reiniciar o gNB.
- Se apos encerrar o xApp aparecer `Lost socket` no log da UE,
  `e2ap_dec_subscription_delete_request` no log do gNB ou `503 No E2 connection`
  no `ric_submgr`, a RAN foi derrubada pelo fluxo de delete subscription.
  Mantenha `XAPP_UNSUBSCRIBE_ON_EXIT=0` e reinicie o gNB/UE.
- `ric_dbaas` deve usar versao Redis compativel com `e2mgr/submgr`; o projeto ja
  inclui `fix_oran_ric_rnib.sh`.
- Nao rode FlexRIC em paralelo.
- Fase 2 nao deve sobrescrever o build da Fase 1; use o binario separado criado
  por `build_e2_oran_sc.sh`.
- Se `test_oran_ric.sh --run-xapp` retornar sucesso mas o log contiver `503`,
  trate como validacao parcial e rode `run_xapp_oai_kpm.sh` apos reiniciar o gNB.

## Voltar para Fase 1

```bash
./scripts/down_oai_oran_lab.sh
./scripts/up_e2_lab.sh
```
