# Configurações do experimento FH / OFH / CPRI / eCPRI (gNB + X310)

Arquivos YAML para os cenários **A0–A6** descritos em `../../../docs/ROTEIRO_REGISTRO_FH_OFH_CPRI_eCPRI.md`.

## Antes de usar

1. **Ajuste obrigatório:** em todos os arquivos, alinhe `ru_sdr.device_args` (`addr=...`) ao IP do seu USRP e `cu_cp.amf` ao AMF do Open5GS.
2. **Validação srsRAN:** taxas `srate` / `master_clock_rate` devem ser **aceitas pelo seu build** do srsRAN Project. Se o gNB recusar iniciar, consulte a documentação ou exemplos oficiais para o par **BW × SCS** e corrija o YAML (registre a falha na ficha).
3. **RF / regulatório:** `dl_arfcn`, `tx_gain` e `rx_gain` devem estar dentro da licença e dos limites da daughterboard.

## Índice de arquivos

| Arquivo | Cenário | Ideia |
|---------|---------|--------|
| `gnb_exp_A0_baseline.yml` | **A0** | Baseline n78, 20 MHz, SCS 30 kHz, 1T1R (referência). |
| `gnb_exp_A1_bw20_scs30.yml` | **A1** | Mesma BW que A0; tipicamente **2T2R** — mais streams no enlace host ↔ USRP. |
| `gnb_exp_A2_bw40_scs30.yml` | **A2** | Escada de BW em n78: **40 MHz**, SCS 30 kHz. |
| `gnb_exp_A3_bw80_scs30.yml` | **A3** | Escada de BW em n78: **80 MHz**, SCS 30 kHz. |
| `gnb_exp_A4_bw100_scs30.yml` | **A4** | **100 MHz** em n78, SCS 30 kHz — alto débito no “fronthaul de bancada”. |
| `gnb_exp_A5_band77_bw100_scs30.yml` | **A5** | **n77**, 100 MHz, SCS 30 kHz — variar portadora RF (ajustar `dl_arfcn`). |
| `gnb_exp_A6_bw100_scs30_2t2r.yml` | **A6** | Perfil nominal **100 MHz + 2T2R**; confirmar `nof_antennas_*` no YAML. |

**Teste opcional 1 GbE × 10 GbE (Aula 04):** não há YAML dedicado — repetir **A4** ou **A6** alterando apenas a interface Ethernet host ↔ X310.

**Nota:** Alguns campos `log.filename` nos YAML podem ainda usar sufixos antigos (`A2a`, `A3`, …); confira o bloco `log:` antes de recolher troncos.

## Comando típico

```bash
cd /caminho/para/srsRAN  # diretório onde está o binário gnb
sudo ./build/apps/gnb -c /caminho/testbed-open5gs-x310/ran/config/experimentos/gnb_exp_A0_baseline.yml
```

(Ajuste o caminho do binário `gnb` conforme sua instalação.)

