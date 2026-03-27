## Core (Open5GS) - configurações do 5GC

Este diretório contém apenas arquivos de configuração YAML que devem ser usados pelo **core Open5GS** instalado no host como serviço (systemd) e cujos arquivos finais ficam em:

- `/etc/open5gs`

Os YAMLs em `core/config/*.yaml` referenciam endereços/portas em `127.0.x.x` (loopback). O **gNB (host)** usa esses valores para estabelecer:

- N2: NGAP / SCTP (AMF)
- N3: GTP-U (UPF)
- PFCP: SMF<->UPF, SGW-C<->SGW-U (conforme configuração do core)

### Endereços e parâmetros-chave (neste repo)

AMF (`core/config/amf.yaml`)

- SBI (serviços NF): `127.0.0.5:7777` (ngap usa outra seção)
- NGAP server (N2): `amf.ngap.server.address: 127.0.1.100` (porta padrão do Open5GS: `38412`)
- GUAMI/Tai/TAC: PLMN `001/01`, `tac: 7`
- Slice suportado: `sst: 1`

NRF (`core/config/nrf.yaml`)

- SBI: `127.0.0.10:7777`

NSSF (`core/config/nssf.yaml`)

- SBI: `127.0.0.14:7777`

SMF (`core/config/smf.yaml`)

- SBI: `127.0.0.4:7777`
- PFCP server: `127.0.0.4`
- GTP-C / GTP-U server: `127.0.0.4` (conforme YAML)
- DNN `internet`: UPF `127.0.0.7`

UPF (`core/config/upf.yaml`)

- PFCP server: `127.0.0.7`
- GTP-U server (N3): `127.0.1.100`
- Session subnet: `10.45.0.0/16`

SGWC/SGWU (quando habilitados)

- SGWC (gtpc/pfcp): `127.0.0.3`
- SGWU (gtpu/pfcp): `127.0.0.6`

### Como “verificar o funcionamento” (passos no host)

1. Aplicar os YAMLs:
   - copie (ou crie symlinks) de `core/config/*.yaml` para `/etc/open5gs/`
2. Reiniciar o core:
   - `sudo systemctl restart open5gs`
3. Acompanhar logs do AMF:
   - `sudo tail -f /var/log/open5gs/amf.log`

### Diagnóstico do erro do gNB (imagem)

Se o gNB logar algo como:

- `Failed to connect to AMF on 127.0.0.5:38412`

isso geralmente indica que o gNB está apontando para o **SBI do AMF** (`amf.sbi.server.address`) em vez do **endereço NGAP** (`amf.ngap.server.address`).

Neste repo:

- AMF NGAP esperado pelo gNB: `127.0.1.100:38412`
- AMF SBI (outro propósito): `127.0.0.5:7777`

A correção tipicamente é ajustar `ran/config/open5gs_gnb_x310.yml` para usar `cu_cp.amf.addr: 127.0.1.100`.

