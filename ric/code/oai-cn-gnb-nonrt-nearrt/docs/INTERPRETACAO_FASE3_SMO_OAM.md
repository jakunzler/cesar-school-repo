# Interpretacao - Fase 3 SMO, dados e IA/ML

Este guia explica como interpretar a Fase 3 e como pensar sua aplicacao real.
Ele complementa [FASE3_SMO_OAM.md](FASE3_SMO_OAM.md).

## Pergunta que a Fase 3 responde

A Fase 3 responde:

> Consigo adicionar um plano SMO isolado para observar topologia, receber eventos
> de gestao, armazenar KPMs reais e executar um workflow IA/ML sem prejudicar
> Fase 1 ou Fase 2?

Ela nao promete:

> O gNB OAI monolitico sera gerenciado por O1 NETCONF real.

O caminho realista no lab e O1 com simuladores O-DU/O-RU, mais ingestao de KPM
real produzido pelos xApps das Fases 1/2.

## Evidencias principais

| Evidencia | Onde ver | Interpretacao |
|-----------|----------|---------------|
| preflight passa | `test_smo_lab.sh --preflight` | compose local, Python e porta SMO estao prontos |
| `smo-api` saudavel | `/health` | API aberta disponivel |
| topologia aparece | `/topology` | O1 simulado publicou O-DU/O-RU/nearRT |
| eventos VES aparecem | `/ves/v7/events` | plano de telemetria de gestao esta recebendo eventos |
| KPMs aparecem | `/metrics/kpm` | coletor leu logs reais ou dados de teste |
| decisoes aparecem | `/ml/runs` | workflow IA/ML executou sobre os dados |
| Fase 1/2 nao alterada | containers/processos existentes | isolamento preservado |

## Como interpretar a implementacao

Os scripts de Fase 3 sobem uma implementacao local de SMO no repositorio. Ela
nao baixa repositorios externos e nao depende do checkout O-RAN SC OAM para o
fluxo principal.

Leitura dos resultados:

| Resultado | Interpretacao |
|-----------|---------------|
| `test_smo_lab.sh --preflight` passa | Fase 3 pode ser iniciada |
| erro de porta `SMO_API_PORT` | porta HTTP local ocupada; escolha outra |
| `/topology` vazio logo apos subir | aguarde o `o1-sim` publicar ou veja logs do container |
| `/metrics/kpm` tem apenas dados de teste | Fase 1/2 ainda nao gerou KPM novo nos logs monitorados |
| `/ml/runs` mostra `collect-more-data` | workflow subiu, mas ainda precisa de mais metricas |

## Relacao com KPM

SMO nao substitui KPM. A correlacao correta e:

```text
O1/VES/topologia dizem "o que a rede e como ela esta configurada"
KPM/E2 dizem "como o RAN esta performando agora"
A1/policies dizem "qual objetivo ou restricao deve ser aplicada"
```

KPMs a correlacionar com eventos OAM:

| KPM | Unidade | Correlacao real |
|-----|---------|-----------------|
| `DRB.UEThpDl` | `kbps` | throughput antes/depois de mudanca de configuracao |
| `DRB.UEThpUl` | `kbps` | impacto em cargas de uplink |
| `DRB.PdcpSduVolumeDL` | `Mb` | volume transportado durante janela de evento |
| `DRB.PdcpSduVolumeUL` | `Mb` | volume UL durante janela de evento |
| `DRB.RlcSduDelayDl` | `us` | atraso antes/depois de falha, alarme ou mudanca |
| `RRU.PrbTotDl` | `%` | ocupacao DL relacionada a topologia/capacidade |
| `RRU.PrbTotUl` | `%` | ocupacao UL relacionada a carga/interferencia |

## Padroes esperados

### Fase 3 saudavel

- `test_smo_lab.sh --preflight` valida compose e sintaxe;
- `up_smo_lab.sh` sobe quatro containers isolados;
- `test_smo_lab.sh` injeta O1/VES/KPM de teste e le de volta;
- `ml-workflow` grava recomendacoes em `/ml/runs`;
- Fase 1/2 continua igual apos `down_smo_lab.sh`.

Conclusao: plano de gestao, dados e IA/ML podem ser explorados sem destruir o
lab RAN/RIC.

### OAM sobe, mas nao ha eventos

Possiveis causas:

- container `smo-o1-sim` ainda nao publicou;
- API `smo-api` nao ficou saudavel;
- houve erro de rede interna no compose.

Acao:

```bash
docker compose -p oai-smo-lab -f config/smo/docker-compose.yml logs --tail=80 smo-o1-sim
curl http://127.0.0.1:18080/topology
```

### KPM muda, mas SMO nao mostra nada

Possiveis causas:

- Fase 3 foi iniciada depois do KPM e o coletor ainda nao viu linhas novas;
- o xApp usado gravou em outro arquivo;
- o arquivo de log esta vazio ou sem padrao `METRIC = value [unit]`.

Acao:

```bash
sudo ./scripts/test_e2_kpm.sh
curl "http://127.0.0.1:18080/metrics/kpm?limit=20"
./scripts/run_smo_ml_workflow.sh
```

## Modo externo O-RAN SC OAM

O modo externo continua util quando a meta for testar os composes oficiais do
projeto O-RAN SC OAM:

```bash
SMO_MODE=external SMO_OAM_DIR=/path/para/oam ./scripts/test_smo_lab.sh --preflight
SMO_MODE=external SMO_OAM_DIR=/path/para/oam ./scripts/up_smo_lab.sh
```

Nesse modo, a interpretacao volta a depender de SDNC, VES collector, Keycloak,
Kafka e simuladores do checkout externo.

## Como pensar em aplicacao real

A Fase 3 e a base para operacao de rede, inventario, historico e closed loop de
gestao. Aplicacoes reais:

- correlacionar alarmes VES com queda de `DRB.UEThp*`;
- usar topologia para saber qual celula/DU/RU esta afetada;
- disparar rApp que cria policy A1 quando `RRU.PrbTot*` fica alto por janela longa;
- documentar mudancas de configuracao e medir impacto em KPM;
- simular falha O-DU/O-RU e observar se o inventario/eventos explicam a degradacao.

Fluxo conceitual:

```text
evento O1/VES -> contexto topologico -> workflow IA/ML -> rApp/nonRT -> policy A1
             -> xApp nearRT -> acao E2 -> KPM confirma impacto
```

## Como validar aplicacao real com o lab

1. Suba Fase 3.
2. Gere baseline KPM na Fase 1 ou Fase 2.
3. Confira se `/metrics/kpm` recebeu as amostras.
4. Confira se `/topology` e `/ves/v7/events` tem contexto de gestao.
5. Rode `run_smo_ml_workflow.sh`.
6. Guarde a recomendacao de `/ml/runs`.
7. Se houver rApp/policy, valide se a policy foi criada no PMS e chegou no A1.

Artefatos para guardar:

| Artefato | Para que serve |
|----------|----------------|
| dump `/metrics/kpm` | efeito no plano radio |
| dump `/ves/v7/events` | evento de gestao |
| dump `/topology` | escopo do impacto |
| dump `/ml/runs` | decisao IA/ML |
| dump PMS policies | decisao nonRT, quando conectada |
| logs xApp | acao nearRT |

## Criterio de maturidade

| Nivel | Descricao |
|-------|-----------|
| 0 | preflight SMO passa |
| 1 | SMO local sobe isolado |
| 2 | simulador O1 gera topologia/evento observavel |
| 3 | KPM real das Fases 1/2 e armazenado no SMO |
| 4 | workflow IA/ML cria recomendacao baseada em dados |
| 5 | recomendacao vira policy A1/rApp e xApp aplica acao E2 |
