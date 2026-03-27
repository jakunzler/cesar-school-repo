## RAN (gNB) - srsRAN + USRP X310

Este diretório contém a configuração do **gNB em srsRAN** usando a interface **USRP Ettus X310** (rádio real no host).

O gNB deve se registrar no **core Open5GS** via **N2 (NGAP / SCTP)** e encaminhar o tráfego via **N3 (GTP-U)**.

### Arquivo de configuração do gNB

O arquivo principal é:

- `ran/config/open5gs_gnb_x310.yml`

Principais parâmetros relevantes para o core:

- `cu_cp.amf.addr`: endereço do AMF para NGAP (neste repo: `127.0.1.100`)
- `cu_cp.amf.port`: porta NGAP (neste repo: `38412`)
- `cu_cp.amf.bind_addr`: endereço local usado pelo gNB para a associação SCTP (loopback em geral funciona)

Parâmetros relevantes para a célula:

- `cell_cfg.band`: `78`
- `cell_cfg.dl_arfcn`: `650000`
- `cell_cfg.channel_bandwidth_MHz`: `100`
- `cell_cfg.common_scs`: `30` kHz
- `cell_cfg.plmn`: `00101`
- `cell_cfg.tac`: `7`

### Subir o gNB

O comando exato depende da sua versão/build do srsRAN. Exemplo (ajuste o caminho do binário):

```bash
sudo ./build/gnb -c ran/config/open5gs_gnb_x310.yml
```

Durante a inicialização, verifique no log se o gNB:

1. Detecta o X310 (UHD / parâmetros de clock/sync)
2. Consegue estabelecer associação com o AMF em `127.0.1.100:38412`

### Verificação rápida (quando o gNB não associa)

Se aparecer algo como:

- `Failed to connect to AMF on <ip>:38412`

verifique se:

1. `cu_cp.amf.addr` no `open5gs_gnb_x310.yml` bate com `amf.ngap.server.address` em `/etc/open5gs/amf.yaml` (neste repo: `127.0.1.100`)
2. a porta `38412` é a que o AMF está aceitando (no Open5GS, NGAP é tipicamente `38412`)
3. `amf.yaml` tem `tac: 7` e `plmn_support`/`tai` compatíveis com `cell_cfg.tac` e `cell_cfg.plmn`

