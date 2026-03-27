# Laboratório Open5GS Containerizado

Laboratório 5G totalmente containerizado usando Open5GS com suporte a UPF para testes de conexão fim-a-fim com UERANSIM.

O projeto utiliza **docker-compose** separado para o Core e outro para o RAN + UE:

- **SBI (Core)**: `core/docker-compose.yml` — NFs do control plane, UPF, MongoDB, DN, WebUI
- **GNB (RAN)**: `ueransim/docker-compose.yaml` — gNB e UE (UERANSIM)

## 📋 Índice

1. [Pré-requisitos](#pre-requisitos)
2. [Arquitetura](#arquitetura)
3. [Estrutura de Diretórios](#estrutura-de-diretórios)
4. [Início Rápido](#início-rápido)
5. [Scripts Disponíveis](#scripts-disponíveis)
6. [Testes](#testes)
7. [Troubleshooting](#troubleshooting)

---

## Pré-requisitos

- Docker 20.10+
- Docker Compose 2.0+
- Ubuntu 22.04+ (recomendado)
- ~4GB RAM livre
- Acesso à internet (para pull de imagens)

---

## Arquitetura

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   MongoDB   │     │     NRF      │     │     SCP     │
│             │     │  (Discovery) │     │  (Routing)  │
└─────────────┘     └──────────────┘     └─────────────┘
       └───────────────────┴────────────────────┘
                           │
                    ┌──────┴──────────┐
                    │  SBI Network    │
                    │  (10.10.0.0/16) │
                    └──────┬──────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────┴────┐       ┌─────┴─────┐      ┌─────┴─────┐
   │   AMF   │       │    SMF    │      │  AUSF/UDM │
   │         │       │           │      │  UDR/PCF  │
   └────┬────┘       └─────┬─────┘      └───────────┘
        │                  │
        │ N2               │ N4
        │ (NGAP)           │ (PFCP)
        │                  │
   ┌────┴─────┐      ┌─────┴─────┐
   │   gNB    │ N3   │    UPF    │
   │(UERANSIM)│------│           │
   └────┬─────┘GTP-U └─────┬─────┘
        │                  │
        │  Uu              │ N6
        │ (PHY)            │ (Data)
        │                  │
   ┌────┴─────┐      ┌─────┴─────┐
   │   UE     │      │    DN     │
   │(UERANSIM)│      │ (Internet)│
   └──────────┘      └───────────┘
```

### Estrutura dos Docker Compose


| Compose        | Arquivo                        | Serviços                                                               |
| -------------- | ------------------------------ | ---------------------------------------------------------------------- |
| **SBI (Core)** | `core/docker-compose.yml`      | MongoDB, NRF, SCP, AMF, SMF, AUSF, UDM, UDR, PCF, NSSF, UPF, DN, WebUI |
| **GNB (RAN)**  | `ueransim/docker-compose.yaml` | UERANSIM (gNB + UE em um único container)                              |


O compose GNB usa as redes externas `open5gs-containerized_net-n2` e `open5gs-containerized_net-n3` criadas pelo compose SBI. Por isso o CORE deve ser iniciado primeiro.

### Redes Docker

- **net-sbi** (10.10.0.0/16): Interface SBI entre NFs do control plane
- **net-n2** (10.20.0.0/16): Interface N2 (NGAP) entre AMF e gNB
- **net-n3** (10.30.0.0/16): Interface N3 (GTP-U) entre gNB e UPF
- **net-n4** (10.40.0.0/16): Interface N4 (PFCP) entre SMF e UPF
- **net-n6** (10.50.0.0/16): Interface N6 (Data) entre UPF e DN
- **ue-subnet** (10.60.0.0/16): Subnet para IPs dos UEs

---

## Estrutura de Diretórios

```
open5gs-containerized/
├── core/
│   └── configs/
│   |   └── open5gs/          # Configurações Open5GS (SBI)
│   |       ├── nrf.yaml
│   |       ├── amf.yaml
│   |       ├── smf.yaml
│   |       ├── upf.yaml
│   |       └── freeDiameter/
|   ├── docs/
|   |   └── CORE.md          # Documentação consolidada do Core
|   ├── logs/
|   ├── scripts/
|   └── docker-compose.yml   # Compose SBI (CORE)
├── ueransim/             # RAN (gNB + UE)
│   ├── docs/
│   |   └── RAN.md         # Documentação consolidada da RAN
│   ├── configs/
│   │   ├── gnb.yaml
│   │   ├── ue.yaml
│   │   └── entrypoint.sh
|   ├── scripts/
|   |   ├── up_ran.sh
|   |   ├── down_ran.sh
|   |   ├── healthcheck.sh
|   |   └── test_ue_connection.sh
│   ├── docker-compose.yaml   # Compose do RAN (usa redes externas)
└── README.md              # Este arquivo
```

---

## Início Rápido

### 1. Clonar e entrar no diretório

```bash
git clone https://github.com/jakunzler/cesar-school-repo.git
```

### 2. Iniciar o laboratório (ordem recomendada)

**Passo 1 — Iniciar o CORE (SBI):**

```bash
cd code/open5gs-containerized/core
./scripts/up_core.sh
```

**Passo 2 — Iniciar o RAN (gNB + UE):**

```bash
cd code/open5gs-containerized/ueransim
./scripts/up_ran.sh
```

> A RAN depende das redes Docker criadas pelo CORE (net-n2, net-n3). Sempre inicie o CORE primeiro.

### 3. Verificar status

```bash
cd code/open5gs-containerized/core
./scripts/healthcheck.sh
```

### 4. Testar conexão do UE

```bash
cd code/open5gs-containerized/ueransim
./scripts/test_ue_connection.sh
```

### 5. Acessar o WebUI

- **URL:** http://localhost:9999
- **Login padrão:** `admin` / `1423`

O usuário admin é criado automaticamente na inicialização do MongoDB (script em `docker-entrypoint-initdb.d`), **apenas quando o volume de dados está vazio** (primeira execução).

**Se não conseguir fazer login** (ex.: volume já existia antes da configuração), execute:

```bash
cd code/open5gs-containerized/core
./scripts/add-webui-admin.sh
```

Depois de criar o usuário admin, você pode acessar o WebUI em http://localhost:9999 com o login `admin` e a senha `1423`.

A partir daqui, você pode usar o WebUI para gerenciar o Open5GS. Na tela inicial, clique em "ADD A SUBSCRIBER" para adicionar um novo UE. Utilize as informações do UE para adicionar o novo UE:

```json
{
  "supi": "imsi-001010000000002",
  "mcc": "001",
  "mnc": "01",
  "key": "465B5CE8B199B49FAA5F0A2EE238A6B0",
  "opType": "OPC",
  "op": "E8ED289DEBA952E4283B54E88E6183B8",
  "amf": "8000"
}
```

### 6. Parar o laboratório

Para parar tudo (ordem sugerida: RAN primeiro, depois CORE):

```bash
cd code/open5gs-containerized/ueransim
./scripts/down_ran.sh
cd code/open5gs-containerized/core
./scripts/down_core.sh
```

> **Nota:** O script `configs/webui/mongo-init-admin.js` é executado pelo MongoDB em `docker-entrypoint-initdb.d` na primeira inicialização (volume vazio).

---

## Scripts Disponíveis

### `up_core.sh`

Inicia o CORE Open5GS (SBI): MongoDB, NRF, SCP, AMF, SMF, AUSF, UDM, UDR, PCF, NSSF, UPF, DN e WebUI. Usa `core/docker-compose.yml`.

```bash
cd code/open5gs-containerized/core
./scripts/up_core.sh
```

### `up_ran.sh`

Inicia o RAN (gNB + UE) via UERANSIM. Usa `ueransim/docker-compose.yaml` e depende das redes criadas pelo CORE (net-n2, net-n3). **Execute após `up_core.sh`.**

```bash
cd code/open5gs-containerized/ueransim
./scripts/up_ran.sh
```

### `down_ran.sh`

Para o RAN (gNB + UE) do compose `ueransim/docker-compose.yaml`.

```bash
cd code/open5gs-containerized/ueransim
./scripts/down_ran.sh
```

### `down_core.sh`

Para os serviços do CORE (SBI) e remove containers/redes do `docker-compose.yml`.

```bash
cd code/open5gs-containerized/core
./scripts/down_core.sh
```

### `healthcheck.sh`

Verifica o status de todos os serviços e conectividade de rede.

```bash
cd code/open5gs-containerized/core
./scripts/healthcheck.sh
```

### `test_ue_connection.sh`

Testa a conexão end-to-end do UE:

- Verifica IP do UE
- Testa ping para servidores DNS públicos
- Testa resolução DNS
- Testa acesso HTTP
- Verifica rota padrão
- Verifica conectividade com UPF
- Verifica sessão PDU

```bash
cd code/open5gs-containerized/ueransim
./scripts/test_ue_connection.sh
```

---

## Testes

### Teste de Conexão End-to-End

```bash
cd code/open5gs-containerized/ueransim
./scripts/test_ue_connection.sh
```

**O que é testado:**

- ✅ IP do UE atribuído
- ✅ Ping para internet (8.8.8.8, 8.8.4.4, 1.1.1.1)
- ✅ Resolução DNS
- ✅ Acesso HTTP
- ✅ Rota padrão
- ✅ Sessão PDU estabelecida

---

## Troubleshooting

### PCF/UDR não estão rodando

**Problema:** PCF e UDR reiniciando continuamente.

**Solução:**

1. Verificar se MongoDB está healthy: `docker ps ps mongodb`
2. Verificar logs: `docker logs pcf udr`
3. Verificar conectividade: `docker exec pcf ping -c 1 mongodb`

**Causa comum:** Open5GS tenta conectar em `mongodb://mongo/open5gs` (valor padrão). A entrada em `/etc/hosts` deve resolver "mongo" para "mongodb".

### UE não consegue acessar internet

**Problema:** UE tem IP mas não consegue fazer ping.

**Solução:**

1. Verificar se UPF está healthy: `docker ps ps upf`
2. Verificar logs do SMF: `docker logs smf | grep PFCP`
3. Verificar logs do UPF: `docker logs upf | grep PFCP`
4. Verificar rota no UE: `docker exec ueransim ip route` (container do compose GNB)

### gNB não consegue estabelecer conexão com AMF

**Problema:** `NG Setup procedure is failed. Cause: slice-not-supported`

**Solução:**

1. Verificar TAC do gNB corresponde ao AMF: `ueransim/configs/gnb.yaml`
2. Verificar PLMN (MCC/MNC) corresponde: `ueransim/configs/gnb.yaml` e `configs/open5gs/amf.yaml`
3. Remover SD do slice se AMF não suportar: `ueransim/configs/gnb.yaml`

### PDU session establishment reject / UPF não associa PFCP

**Problema:** SMF não consegue associar com UPF. Erros: "No UPFs are PFCP associated", "No associated UPF".

**Causa:** O `upf.yaml` usava endereços localhost (127.0.0.x). UPF e SMF estão em containers diferentes e não se comunicam via 127.0.0.x.

**Solução:**

1. Verificar se `upf.yaml` usa IPs da rede Docker: pfcp.server 10.40.0.21, pfcp.client.smf 10.40.0.12, gtpu.server 10.30.0.21
2. Verificar conectividade N4: `docker exec open5gs-smf-containerized ping -c 1 10.40.0.21`
3. Verificar logs: `docker compose logs upf | grep "PFCP associated"`
4. Verificar se TUN está configurada: `docker exec open5gs-upf-containerized ip addr show ogstun`

---

## Variáveis de Ambiente

Criar arquivo `.env` (opcional):

```bash
OPEN5GS_IMAGE=gradiant/open5gs:2.7.6
MONGODB_IMAGE=mongo:7.0
UERANSIM_IMAGE=gradiant/ueransim:3.2.7
DN_IMAGE=alpine:latest
```

---

## Documentação Adicional

- `docs/labs/INDICE.md`: Roteiros de laboratório (core, UERANSIM, N2/N3, E2E, relatório)
- `core/docs/CORE.md`: Documentação consolidada do Core (arquitetura, IPs, correções, scripts, **WebUI admin**, troubleshooting)
- `ueransim/docs/RAN.md`: Documentação consolidada da RAN (UERANSIM, gNB, UE, configuração, troubleshooting)

---

## Status Atual

### ✅ Serviços Funcionando (100%)

- NRF, SCP, AMF, SMF, AUSF, UDM, NSSF
- UPF
- MongoDB, DN
- UERANSIM gNB, UERANSIM UE

### ✅ Conectividade

- ✅ Conexão end-to-end funcionando
- ✅ UE consegue acessar internet
- ✅ Todas as interfaces de rede funcionando

---

**Última Atualização:** 2026-03-15