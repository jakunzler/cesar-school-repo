## UE físico (ex.: Telit FN990)

Este diretório não contém ficheiro de configuração YAML para o modem: o **Telit FN990** é configurado por **perfil no cartão (SIM/USIM)**, **comandos AT** e **APN** no sistema anfitrião (NetworkManager, `mmcli`, Windows, etc.), não pelo mesmo fluxo que o **UERANSIM** (`code/open5gs-containerized/ueransim/configs/ue.yaml`).

### Alinhamento com o Open5GS (laboratório X310)

| Parâmetro | Onde entra |
| --- | --- |
| IMSI / SUPI | SIM e subscritor em MongoDB (`imsi` no documento de `subscribers`) |
| K, OPc, AMF (`8000`) | SIM e `security.k`, `security.opc`, `security.amf` no MongoDB (ver `scripts/reset-db-and-add-subscribers.sh`) |
| PLMN | **001 / 01** (célula + `amf.yaml` / `cell_cfg.plmn` no gNB) |
| TAC | **7** (gNB e `amf.yaml` `tai`) |
| DNN / dados | **internet** (SMF/UPF e APN no UE) |
| Slice | Neste projeto o core está preparado para **SST=1 sem SD** |

Os valores de autenticação devem ser **idênticos** entre o perfil gravado no SIM (K, OPc, AMF) e a base Open5GS; caso contrário o registo falha (por exemplo após `Security mode command`).

### FN990 em 5G SA

- Confirme no manual Telit que o modem está em modo **5G SA** (ou NSA+SA conforme o laboratório), e que o **APN** de dados corresponde ao DNN **internet**.
- O **NAS slice** pedido pelo modem vem do **SIM** e da configuração do módulo: como o core aqui usa só **SST 1**, o cartão/perfil não deve forçar um **SD** que o core não anuncia (se usar outro slice no SIM, alinhe o core e o gNB ou ajuste o perfil).

### Referência de projeto

O ficheiro `open5gs-containerized/ueransim/configs/ue.yaml` serve apenas ao cenário **UERANSIM em Docker**, não ao FN990.
