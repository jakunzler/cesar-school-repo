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
| 3 | SMO/OAM | Adicionar plano de gestao, O1 simulado e inventario/topologia | Opcional | Opcional | SMO OAM + simuladores | Scaffold inicial |

## Regras de isolamento

1. Fase 1 e Fase 2 nao devem rodar nearRT ao mesmo tempo.
2. Fase 3 nao para nem altera Fase 1/Fase 2; os scripts de SMO abortam se
   detectarem stacks ativas, a menos que `SMO_ALLOW_SHARED_HOST=1` seja usado.
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
./scripts/explore_e2_sm.sh quick
./scripts/stress_ue_observe_apps.sh
```

### Fase 2

```bash
./scripts/down_e2_lab.sh
./scripts/build_e2_oran_sc.sh
./scripts/up_oai_oran_lab.sh
./scripts/test_oran_ric.sh --run-xapp
```

### Fase 3

```bash
export SMO_OAM_DIR=/path/para/o-ran-sc-oam
./scripts/test_smo_lab.sh --preflight
./scripts/up_smo_lab.sh
./scripts/test_smo_lab.sh
```

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
