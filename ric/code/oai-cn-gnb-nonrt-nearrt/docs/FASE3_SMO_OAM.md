# Fase 3 - SMO/OAM e topologia completa

Guia de interpretacao associado:
[INTERPRETACAO_FASE3_SMO_OAM.md](INTERPRETACAO_FASE3_SMO_OAM.md).

## Objetivo

A Fase 3 inicia o plano de gestao O-RAN: SMO/OAM, O1 com simuladores,
inventario/topologia e, opcionalmente, integracao com nonRT/nearRT ja validados.
Ela nao substitui Fase 1 ou Fase 2; e uma camada adicional e isolada.

## Estado no projeto

| Item | Estado |
|------|--------|
| Documentacao de arquitetura | Implementada neste guia |
| Scripts `up/down/test_smo_lab.sh` | Scaffold inicial |
| Compose SMO embutido no repo | Nao incluído |
| O1 real para gNB OAI | Nao suportado pelo gNB monolitico |
| O1 via simuladores O-DU/O-RU | Caminho recomendado |

Os scripts da Fase 3 exigem um checkout externo O-RAN SC OAM/SMO via
`SMO_OAM_DIR`. Isso evita baixar dependencias ou subir dezenas de containers sem
controle.

## Conceitos

| Conceito | Papel |
|----------|-------|
| SMO | Service Management and Orchestration; plano de gestao superior |
| OAM | Operacao, administracao e manutencao |
| O1 | Interface de gestao entre SMO e RAN/nearRT, tipicamente NETCONF/HTTP |
| SDNC | Controller usado no OAM para configuracao/NETCONF |
| VES Collector | Recebe eventos/telemetria VES |
| Keycloak | Identidade/autenticacao para componentes SMO |
| Kafka/Zookeeper | Barramento/eventos e dependencias comuns |
| TEIV | Topology and Inventory; inventario/topologia |
| NTSIM/ntsim-ng | Simuladores O-RU/O-DU para O1 quando nao ha equipamento real |

## Arquitetura alvo

```text
                         Fase 3 - management plane

  SMO/OAM
  +-------------------------------------------------------------+
  | Keycloak / Kafka / Zookeeper                                |
  | SDNC / VES Collector / optional TEIV                        |
  +----------------------------+--------------------------------+
                               |
                               v O1 / VES / topology
  Simuladores O1
  +-------------------------------------------------------------+
  | ntsim-ng O-DU / O-RU / topology sources                     |
  +-------------------------------------------------------------+

  Planos ja existentes
  +-------------------------------------------------------------+
  | Fase 1: nonRT + FlexRIC, ou Fase 2: nonRT + O-RAN SC nearRT |
  | Core OAI + gNB/nrUE + xApps/KPM                             |
  +-------------------------------------------------------------+
```

## Politica de isolamento

Por padrao, `up_smo_lab.sh` aborta se detectar containers/processos de Fase 1
ou Fase 2 ativos. Isso e conservador: SMO costuma usar portas comuns como
`8080`, `8181`, `8443`, `9092` e pode colidir com nonRT/nearRT.

Para permitir execucao compartilhada:

```bash
SMO_ALLOW_SHARED_HOST=1 ./scripts/up_smo_lab.sh
```

Use isso apenas depois de revisar portas no compose externo.

## Preparacao

1. Obtenha um checkout O-RAN SC OAM/SMO fora deste repositório.
2. Exporte o path:

```bash
export SMO_OAM_DIR=/path/para/o-ran-sc-oam
```

3. Revise os compose files esperados:

```bash
ls "$SMO_OAM_DIR"/infra/docker-compose.yaml
ls "$SMO_OAM_DIR"/smo/common/docker-compose.yaml
ls "$SMO_OAM_DIR"/smo/oam/docker-compose.yaml
```

4. Rode preflight:

```bash
./scripts/test_smo_lab.sh --preflight
```

## Comandos

Subir common + OAM:

```bash
SMO_OAM_DIR=/path/para/o-ran-sc-oam ./scripts/up_smo_lab.sh
```

Subir tambem simuladores de rede/O1, se o checkout tiver `network/docker-compose.yaml`:

```bash
SMO_WITH_NETWORK=1 SMO_OAM_DIR=/path/para/o-ran-sc-oam ./scripts/up_smo_lab.sh
```

Subir TEIV, se o checkout tiver `smo/teiv/docker-compose.yaml`:

```bash
SMO_WITH_TEIV=1 SMO_OAM_DIR=/path/para/o-ran-sc-oam ./scripts/up_smo_lab.sh
```

Testar:

```bash
SMO_OAM_DIR=/path/para/o-ran-sc-oam ./scripts/test_smo_lab.sh
```

Parar:

```bash
SMO_OAM_DIR=/path/para/o-ran-sc-oam ./scripts/down_smo_lab.sh
```

## O que verificar

| Verificacao | Sinal esperado |
|-------------|----------------|
| containers common | Kafka/Zookeeper/Keycloak ativos |
| OAM | SDNC e VES collector ativos |
| O1 simulado | containers NTSIM/O-DU/O-RU ativos |
| VES | endpoint HTTP/HTTPS respondendo |
| topologia | TEIV ou inventario com entidades simuladas |
| isolamento | Fase 1/2 nao parada nem alterada automaticamente |

## Relacao com KPM, rApps e xApps

Fase 3 nao substitui xApps/KPM. Ela observa/gerencia o dominio por OAM/O1,
enquanto:

- KPM/E2 continua sendo observado por xApps da Fase 1 ou Fase 2;
- policies A1 continuam vindo do nonRT;
- O1 traz inventario, configuracao e eventos de gestao;
- closed loop completo exige uma ponte de decisao: rApp/policy -> A1 -> xApp -> E2.

KPMs que continuam relevantes ao correlacionar eventos SMO/OAM com trafego UE:

| KPM | Unidade | Interpretacao na Fase 3 |
|-----|---------|--------------------------|
| `DRB.UEThpDl` / `DRB.UEThpUl` | `kbps` | throughput percebido pelo UE durante eventos ou mudancas de gestao |
| `DRB.PdcpSduVolumeDL` / `DRB.PdcpSduVolumeUL` | `Mb` | volume de dados por DRB na janela KPM |
| `DRB.RlcSduDelayDl` | `us` | atraso RLC que pode ser comparado com eventos O1/VES |
| `RRU.PrbTotDl` / `RRU.PrbTotUl` | `%` | ocupacao de recursos de radio durante carga ou degradacao |

## Limites atuais

- O gNB OAI monolitico usado neste lab nao expoe O1 NETCONF nativo.
- O1 deve ser demonstrado com simuladores O-DU/O-RU.
- O SMO full pode exigir 24-32 GB RAM e muitas imagens externas.
- O scaffold nao clona repositorios nem baixa imagens por conta propria.

## Proximos passos de implementacao

1. Escolher release O-RAN SC OAM/SMO e fixar commit.
2. Adicionar `vendor/o-ran-sc-oam/` como submodule ou documentar checkout externo.
3. Criar overlay de portas em `config/smo/` para evitar conflitos locais.
4. Automatizar preflight de memoria, portas e imagens.
5. Adicionar teste VES/O1 com simulador NTSIM minimo.
6. Relacionar eventos O1 com snapshots nonRT e KPM do script de estresse de UE.
