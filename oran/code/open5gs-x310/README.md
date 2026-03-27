# Laboratório Open5GS + USRP X310

Laboratório 5G com **núcleo (5GC)** e **RAN real** usando rádio **Ettus USRP X310** no host.

O projeto utiliza **um CORE instalado no host como serviço systemd**:

- **SBI (Core)**: `open5gs.service` — NFs do control plane, UPFs, MongoDB, DN, WebUI

O **gNB** roda no **host**, com stack de software 5G **srsRAN**, usando o X310 como front-end de RF. O **UE** é tipicamente um **termina móvel físico** (smartphone compatível 5G SA, modem USB, outro UE de laboratório).

## 📋 Índice

1. [Pré-requisitos](#pre-requisitos)
2. [Arquitetura](#arquitetura)
3. [Estrutura de Diretórios](#estrutura-de-diretórios)
4. [Início Rápido](#início-rápido)
5. [Scripts Disponíveis](#scripts-disponíveis)
6. [Testes](#testes)
7. [Adicionar Novas UPFs](#adicionar-novas-upfs)
8. [Troubleshooting](#troubleshooting)

---

## Pré-requisitos

### Núcleo (systemd)

- Ubuntu 22.04+ (recomendado no host do gNB)
- ~4GB RAM livre

### Rádio USRP X310

- Hardware **USRP X310** com cabeamento e alimentação adequados
- **UHD** (USRP Hardware Driver) compatível com a imagem FPGA/revisão do equipamento
- Ferramentas típicas: `uhd_find_devices`, `uhd_usrp_probe` (validar enumeracao e taxa de amostragem)
- Conforme seu setup: cabo de **clock/reference** compartilhado ou **GPSDO**, e atenuadores na cadeia RF se necessário para proteger o front-end
- Stack **gNB** instalada e compilada no host (ex.: srsRAN com suporte NR), com perfil MIMO/banda alinhado ao que o X310 e as antenas suportam

### Conectividade CORE ↔ host do gNB

- O host onde roda o gNB precisa alcançar as sub-redes **N2** e **N3** usadas pelo CORE (por exemplo `127.0.0.101/16` e `127.0.0.102/16`), via interface de loopback.

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
        |            ┌─────┴─────┐      ┌───────────┐
        │            │    UPF    │──────│    DN     │
        |            │           │   N6 │ (Internet)│
        |            └─────┬─────┘      └───────────┘
        |                  |N3
        |                  |(GTP-U)
        |   ┌──────────────┴───────────────────────┐
        |   │  Host com gNB + drivers UHD (X310)   |
        |   │  ┌────────┐         ┌─────────────┐  │
        └───│  │  gNB   │--10GbE--│  USRP X310  │  │
            │  │        │         │             │  |
            │  └────────┘         └──────┬──────┘  │
            └────────────────────────────┼─────────┘
                                         │
                                         │ Uu (5G NR)
                                   ┌─────┴─────┐
                                   │   UE      │ 
                                   │           │
                                   └───────────┘
```

### Estrutura dos Serviços

| Serviço        | Arquivo              | Descrição                                                                        |
| -------------- | -------------------- | ------------------------------------------------------------------------------- |
| **SBI (Core)** | `/etc/open5gs/open5gs.service`    | MongoDB, NRF, SCP, AMF, SMF, AUSF, UDM, UDR, PCF, NSSF, UPF-A, UPF-B, DN, WebUI |
| **RAN (gNB)** | `/opt/srsran/config/x310.yaml`    | srsRAN com suporte NR |

---

## Estrutura de Diretórios

Estrutura sugerida quando o núcleo é copiado ou referenciado a partir de `open5gs-containerized`:

```
open5gs-x310/
├── core/
|   ├── config/
|   |   └── *.yaml              # YAMLs Open5GS (SBI)
|   └── README.md                  # Documentação do CORE (Open5GS)
├── ran/                     # Configuração do gNB (srsRAN)
|   ├── config/
|   |   └── *.yaml              # YAMLs Open5GS (SBI)
|   └── README.md                  # Documentação do RAN (srsRAN)
├── scripts/
│   ├── systemd_open5gs_down.sh
│   ├── systemd_open5gs_up.sh
│   └── ...
├── ue/
|   └── README.md                  # Documentação do UE físico
└── README.md                    # Este arquivo (cenário X310)
```

---

## Início Rápido

### 1. Entrar no diretório do núcleo

Use o diretório onde está o `open5gs-x310`:

```bash
cd open5gs-x310
```

### 2. Subir/ativar o CORE (5GC)

O core é executado no host como serviço `open5gs` (systemd). Garanta que os YAMLs de `code/open5gs-x310/core/config/*.yaml` foram aplicados em `/etc/open5gs` e reinicie o serviço:

```bash
sudo systemctl restart open5gs
sudo systemctl status open5gs --no-pager
sudo journalctl -u open5gs -f --no-pager
```

### 3. Conectar o host do X310 às redes N2/N3

Configure interfaces IP e rotas no host do gNB para que o tráfego NGAP/SCTP (N2) e GTP-U (N3) alcance os endpoints expostos pelo Open5GS. Neste cenário, os NFs do core usam enderecos em `127.0.0.0/24` e `127.0.1.0/24` (loopback), então o essencial é o gNB conseguir abrir SCTP/`38412` para o AMF em `127.0.1.100`. O restante (GTP-U/PFCP/rotas N6) depende do subnet de `session` configurado no `core/config/smf.yaml` (ex.: `10.45.0.0/16`).

### 4. Verificar o X310

```bash
uhd_find_devices
uhd_usrp_probe --args="type=x310"
```

### 5. Iniciar o gNB com o X310

Inicie o binário do gNB (ex.: `gnb` do srsRAN) com o perfil de RF/amostragem adequado ao X310, **bind** nas interfaces/IPs N2 e N3 configurados no passo 3, e **AMF** apontando para o endpoint NGAP do AMF (neste repo: `127.0.1.100:38412`). Para evitar inconsistência, confira também `ran/config/open5gs_gnb_x310.yml`.

### 6. Ligar e registrar o UE físico

Use SIM/perfil coerente com o **HPLMN** e assinaturas configuradas no Open5GS (AUSF/UDM). Verifique no AMF/SMF os logs de registro e sessão PDU.

### 7. Verificar saúde dos serviços do CORE

```bash
sudo systemctl is-active open5gs
sudo journalctl -u open5gs -n 200 --no-pager
```

### 8. Parar o laboratório

Pare o gNB no host primeiro (libera o X310). Depois:

```bash
./scripts/systemd_open5gs_down.sh
```

---

## Troubleshooting

### X310 não é detectado

- Cabo USB3/Thunderbolt ou **10 GbE** SFP+ conforme seu link;
- Permissões **udev** para dispositivos UHD;
- Mesma versão de **UHD** entre toolchain e imagem FPGA carregada.

### gNB não associa ao AMF

- Rota/SCTP até **IP N2 do AMF** (neste repo: `127.0.1.100:38412`);
- Plano de **PLMN** e **TAC** iguais entre gNB e `amf.yaml`;
- **Slice (S-NSSAI)** suportado pelo AMF/NSSF.

#### Erro comum: `Failed to connect to AMF ...:38412`

Quando o gNB falha ao conectar ao AMF, normalmente é porque `cu_cp.amf.addr` em `ran/config/open5gs_gnb_x310.yml` não corresponde a `amf.ngap.server.address` no `/etc/open5gs/amf.yaml`.
Neste repo o AMF NGAP está em `127.0.1.100`, então o gNB deve apontar para `127.0.1.100:38412`.

### Uplink/Downlink instável ou EVM ruim

- Níveis de potência e **atenuação**; vazamentos de LO; uso de **clock** comum;

### UE tem IP mas sem internet

- Verifique UPF, PFCP, rota **N6** até o DN e configuração de NAT;
- No UE físico, confira DNS e APN/perfil de dados.

## Status atual (cenário X310)

O laboratório considera:

- **Núcleo:** Open5GS instalado no host (systemd).
- **RAN:** gNB no host com **USRP X310** e **UE real por rádio**.

Validação fim-a-fim depende do stack gNB escolhido, calibração RF e do terminal 5G SA utilizado.

---

**Última atualização:** 2026-03-27
