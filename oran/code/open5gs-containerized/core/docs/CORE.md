# Documentação Consolidada - 5G Core (Open5GS)

Documento único com as principais informações do Core 5G containerizado.

---

## 1. Arquitetura

### Visão Geral

Laboratório 5G Core totalmente containerizado com Open5GS. Cada Network Function (NF) roda em container Docker separado.

### Componentes

#### Control Plane (SBI: 10.10.0.0/16)


| NF   | Container    | IP SBI      | Função                       |
| ---- | ------------ | ----------- | ---------------------------- |
| NRF  | open5gs-nrf  | 10.10.0.10  | Descoberta e registro de NFs |
| SCP  | open5gs-scp  | 10.10.0.200 | Roteamento e proxy entre NFs |
| AMF  | open5gs-amf  | 10.10.0.11  | Acesso e mobilidade          |
| SMF  | open5gs-smf  | 10.10.0.12  | Gerenciamento de sessões PDU |
| AUSF | open5gs-ausf | 10.10.0.13  | Autenticação                 |
| UDM  | open5gs-udm  | 10.10.0.14  | Dados de assinantes          |
| UDR  | open5gs-udr  | 10.10.0.15  | Repositório (MongoDB)        |
| PCF  | open5gs-pcf  | 10.10.0.16  | Políticas (MongoDB)          |
| NSSF | open5gs-nssf | 10.10.0.17  | Seleção de slices            |


#### User Plane


| UPF | IP N3      | IP N4      | IP N6      | Pool UE      |
| --- | ---------- | ---------- | ---------- | ------------ |
| UPF | 10.30.0.21 | 10.40.0.21 | 10.50.0.21 | 10.60.0.0/16 |


#### Infraestrutura

- **MongoDB**: 10.10.0.20
- **DN (Data Network)**: 10.50.0.100

### Interfaces 5G


| Interface | Rede         | Protocolo     | Conecta              |
| --------- | ------------ | ------------- | -------------------- |
| N2        | 10.20.0.0/16 | NGAP (38412)  | gNB ↔ AMF            |
| N3        | 10.30.0.0/16 | GTP-U (2152)  | gNB ↔ UPF            |
| N4        | 10.40.0.0/16 | PFCP (8805)   | SMF ↔ UPF            |
| N6        | 10.50.0.0/16 | IP            | UPF ↔ DN             |
| SBI       | 10.10.0.0/16 | HTTP/2 (7777) | NFs do control plane |


---

## 2. Endereçamento IP

- **SBI**: 10.10.0.x — NFs sequenciais (10–17), MongoDB (20), SCP (200)
- **N2**: 10.20.0.x — AMF (11), gNB (100)
- **N3**: 10.30.0.x — UPF (21), gNB (11)
- **N4**: 10.40.0.x — SMF (12), UPF (21)
- **N6**: 10.50.0.x — UPF (21), DN (100)
- **UE**: 10.60.0.0/16 — Pool de IPs para UEs

---

## 3. Fluxo de Comunicação

### Registro de UE

1. UE → gNB → AMF (N2)
2. AMF → AUSF → UDM → UDR (SBI)
3. AMF → SMF (SBI)
4. SMF → UPF (N4, PFCP)
5. AMF → gNB (N2) — confirmação

### Encaminhamento de Dados

UE → gNB (N3, GTP-U) → UPF → DN (N6) → Internet

---

## 4. Status e Configuração

### Versões

- **Open5GS**: 2.7.6
- **PLMN**: MCC=001, MNC=01
- **TAC**: 7
- **S-NSSAI**: SST=1

### Correções Aplicadas

1. **Binários**: `/opt/open5gs/bin/open5gs-`*
2. **Logs**: Diretórios `logs/{nrf,amf,smf,...}` montados
3. **freeDiameter**: Volume `./configs/open5gs/freeDiameter` no SMF
4. **SMF**: Apenas `session` com `dnn: internet`
5. **PCF/UDR**: Scripts `init-pcf.sh` e `init-udr.sh` — entrada em `/etc/hosts` para `mongo` → `mongodb`, aguardam MongoDB
6. **UPF**: `devices: /dev/net/tun`, variáveis TUN e NAT
7. **NRF Healthcheck**: Verificação via `pgrep` e `netstat`/`ss`

### PCF/UDR (MongoDB)

Open5GS usa `mongodb://mongo/open5gs` por padrão. Solução: scripts de inicialização que adicionam `10.10.0.20 mongo mongodb` em `/etc/hosts` e aguardam MongoDB antes de iniciar.

---

## 5. WebUI — Criação do Usuário Admin

Esta seção documenta em detalhes como o usuário admin do WebUI é criado no ambiente containerizado, permitindo discussão sobre diferenças entre instalação bare metal e Docker.

### 5.1 Credenciais Padrão

- **URL:** [http://localhost:9999](http://localhost:9999)
- **Usuário:** `admin`
- **Senha:** `1423`

### 5.2 Onde o Admin é Armazenado

O WebUI Open5GS armazena contas na coleção `accounts` do banco `open5gs` no MongoDB. Cada documento possui:


| Campo      | Descrição                                           |
| ---------- | --------------------------------------------------- |
| `username` | Nome do usuário (ex.: admin)                        |
| `salt`     | Salt criptográfico para derivação da chave (PBKDF2) |
| `hash`     | Hash da senha (PBKDF2, ~512 caracteres)             |
| `roles`    | Array de papéis (ex.: `['admin']`)                  |
| `__v`      | Campo de versão do Mongoose                         |


A senha não é armazenada em texto claro; o WebUI valida o login comparando o hash derivado da senha informada com o hash armazenado.

### 5.3 Bare Metal vs. Containerizado


| Aspecto       | Bare Metal (instalação tradicional)  | Containerizado (este laboratório)        |
| ------------- | ------------------------------------ | ---------------------------------------- |
| **Quando**    | Pós-instalação, via script `install` | Inicialização do MongoDB (condicional)   |
| **Como**      | `mongosh open5gs ./mongo-init.js`    | Script em `docker-entrypoint-initdb.d`   |
| **Condição**  | Sempre executa uma vez na instalação | Só executa quando o volume está vazio    |
| **Resultado** | Admin criado em toda instalação      | Admin criado apenas na primeira execução |


### 5.4 Por Que a Diferença?

**Bare metal:** O script de instalação do Open5GS inclui uma etapa `postinstall` que roda explicitamente `mongosh open5gs mongo-init.js` contra o MongoDB já em execução. É um passo fixo do processo de instalação.

**Containerizado:** Usamos o mecanismo nativo do MongoDB: arquivos em `/docker-entrypoint-initdb.d/` são executados automaticamente pelo entrypoint da imagem oficial. Porém, esse entrypoint só roda esses scripts quando detecta que o diretório de dados (`/data/db`) está vazio — ou seja, na primeira inicialização do container. Se o volume já existir (por exemplo, de execuções anteriores ou de outros dados como subscribers), os scripts de init **não são executados**.

### 5.5 Fluxo de Criação no Ambiente Containerizado

```
┌─────────────────────────────────────────────────────────────────┐
│  docker compose up                                              │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  MongoDB inicia                                                 │
│  Entrypoint verifica: /data/db está vazio?                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
     ┌────────────────┐              ┌────────────────┐
     │ SIM (vazio)    │              │ NÃO (tem dados)│
     │                │              │                │
     │ Executa scripts│              │ Pula initdb.d  │
     │ em initdb.d/   │              │ Admin NÃO é    │
     │ Admin criado   │              │ criado         │
     └────────────────┘              └────────────────┘
```

### 5.6 Arquivos Envolvidos


| Arquivo                             | Função                                                              |
| ----------------------------------- | ------------------------------------------------------------------- |
| `configs/webui/mongo-init-admin.js` | Script MongoDB que insere o admin se `accounts` estiver vazia       |
| `docker-compose.yml`                | Monta o script em `/docker-entrypoint-initdb.d/02-webui-admin.js`   |
| `scripts/add-webui-admin.sh`        | Script de fallback para criar o admin manualmente quando necessário |


### 5.7 Script mongo-init-admin.js

O script é idempotente: só insere se a coleção `accounts` estiver vazia.

```javascript
db = db.getSiblingDB('open5gs');
if (db.accounts.countDocuments({}) === 0) {
  db.accounts.insertOne({
    salt: <valor_salt>,
    hash: <valor_hash>,
    username: 'admin',
    roles: ['admin'],
    __v: 0
  });
}
```

O `salt` e o `hash` são os mesmos usados na instalação oficial do Open5GS (fonte: [open5gs/docs/assets/webui/mongo-init.js](https://github.com/open5gs/open5gs/blob/main/docs/assets/webui/mongo-init.js)).

### 5.8 Fallback: add-webui-admin.sh

Quando o volume já contém dados e o `initdb.d` não roda, use:

```bash
cd core
./scripts/add-webui-admin.sh
```

O script:

1. Localiza o container do MongoDB
2. Verifica se o admin já existe
3. Insere o documento na coleção `accounts` se estiver vazio
4. É idempotente: pode ser executado várias vezes sem duplicar o admin

### 5.9 Pontos para Discussão em Sala

1. **Por que o MongoDB só executa o initdb.d quando o volume está vazio?**
  Evitar sobrescrever ou alterar dados existentes em ambientes já em uso.
2. **Alternativas para garantir o admin em toda subida:**
  Serviço de init separado, entrypoint customizado no WebUI ou script no `up_core.sh`.
3. **Segurança:**
  Credenciais padrão (admin/1423) são conhecidas; em produção é essencial alterar a senha após o primeiro login.
4. **Consistência entre ambientes:**
  Como manter o mesmo comportamento entre bare metal, Docker e Kubernetes.

---

## 6. Scripts de Teste

### test_ue_connection.sh

- IP do UE
- Ping (8.8.8.8, 8.8.4.4, 1.1.1.1)
- DNS, HTTP
- Rota padrão
- Conexões N2 e PFCP

### test-system-status.sh

- Status dos containers
- NG Setup
- Estado do UE
- Sessão PDU
- Recomendações

### healthcheck.sh

- Processos e portas
- NG Setup
- Associação PFCP
- Status do UE

---

## 7. Sessão PDU e ogstun

- Sessão PDU é estabelecida implicitamente com tráfego
- Interface `ogstun` na UPF: gateway 10.60.0.1
- Rotas: `10.60.0.0/16 dev ogstun`
- Verificação: `docker compose exec upf ip addr show ogstun`

---

## 8. Troubleshooting

### UE sem IP

- Verificar gNB, AMF, SMF
- Logs: `docker compose logs ueransim-ue`
- Executar `test-system-status.sh`

### Ping falha

- Verificar UPF e DN
- Rota no UE: `docker compose exec ueransim-ue ip route`
- Logs SMF: `grep "PFCP associated"`

### NRF não responde

- NRF escuta em 10.10.0.10:7777 (não localhost)
- Usar `pgrep`/`netstat` no healthcheck (curl falha com HTTP/2 puro)

### PDU session establishment reject

- **Causa:** SMF não encontra UPF com associação PFCP ativa ("No UPFs are PFCP associated")
- **Solução:** Verificar se `upf.yaml` usa IPs da rede Docker (10.40.0.21, 10.40.0.12) e não localhost (127.0.0.x). UPF e SMF estão em containers diferentes e não se comunicam via 127.0.0.x.
- **Verificação:** `docker compose logs upf | grep "PFCP associated"` — deve mostrar associação com 10.40.0.12

### WebUI — login admin/1423 não funciona

- Executar `./scripts/add-webui-admin.sh` (admin criado apenas quando volume MongoDB está vazio; ver seção 5)

### PCF/UDR reiniciando

- Verificar scripts `init-pcf.sh` e `init-udr.sh`
- Entrada em `/etc/hosts` para `mongo`
- MongoDB acessível antes do início

---

## 9. Referências

- [Open5GS](https://open5gs.org/)
- [Open5GS GitHub](https://github.com/open5gs/open5gs)

---

*Última atualização: 2026-03*