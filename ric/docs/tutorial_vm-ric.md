# Tutorial — Acesso SSH, criação de usuário e execução de projeto OAI em VM Ubuntu no GCP

## 1. Objetivo

Este tutorial orienta a preparação e uso de uma máquina virtual Ubuntu no Google Cloud Platform para:

1. criar um usuário individual na VM;
2. gerar uma chave SSH no computador local;
3. liberar acesso SSH usando chave pública;
4. copiar um projeto OAI local para a VM;
5. executar o projeto usando Docker e Docker Compose.

---

# Parte A — Criação do usuário na VM

Esta parte deve ser executada por quem tem acesso administrativo à VM.

## 2. Criar um usuário Linux na VM

Acesse a VM como usuário administrador:

```bash
ssh USUARIO_ADMIN@IP_DA_VM
```

Crie o usuário do aluno:

```bash
sudo adduser <nome_do_usuario>
```

Exemplo:

```bash
sudo adduser <nome_do_usuario>
```

O sistema pedirá uma senha. Se o acesso for somente por chave SSH, a senha poderá ser bloqueada depois.

---

## 3. Preparar diretório SSH do usuário

Crie o diretório `.ssh`:

```bash
sudo mkdir -p /home/<nome_do_usuario>/.ssh
```

Crie o arquivo `authorized_keys`:

```bash
sudo touch /home/<nome_do_usuario>/.ssh/authorized_keys
```

Ajuste o dono:

```bash
sudo chown -R <nome_do_usuario>:<nome_do_usuario> /home/<nome_do_usuario>/.ssh
```

Ajuste permissões:

```bash
sudo chmod 700 /home/<nome_do_usuario>/.ssh
sudo chmod 600 /home/<nome_do_usuario>/.ssh/authorized_keys
```

Exemplo:

```bash
sudo mkdir -p /home/<nome_do_usuario>/.ssh
sudo touch /home/<nome_do_usuario>/.ssh/authorized_keys
sudo chown -R <nome_do_usuario>:<nome_do_usuario> /home/<nome_do_usuario>/.ssh
sudo chmod 700 /home/<nome_do_usuario>/.ssh
sudo chmod 600 /home/<nome_do_usuario>/.ssh/authorized_keys
```

---

## 4. Opcional: bloquear senha local do usuário

Se o objetivo for permitir acesso somente por chave SSH:

```bash
sudo passwd -l <nome_do_usuario>
```

Exemplo:

```bash
sudo passwd -l jonas_kunzler
```

Depois disso, o usuário não conseguirá acessar usando senha. O acesso será feito apenas com chave SSH.

---

# Parte B — Geração da chave SSH no computador do aluno

Esta parte deve ser executada no computador local do aluno.

## 5. Criar uma chave SSH RSA

No Linux, abra o terminal e execute:

```bash
ssh-keygen -t rsa -b 4096 -C "<nome_do_usuario>@gmail.com" -f ~/.ssh/ric_vm_<nome_do_usuario>
```

Exemplo:

```bash
ssh-keygen -t rsa -b 4096 -C "jonas_kunzler@gmail.com" -f ~/.ssh/ric_vm_jonas_kunzler
```

Quando aparecer:

```text
Enter passphrase:
```

O aluno pode pressionar `Enter` para deixar a chave sem senha, se a atividade exigir simplicidade.

Serão criados dois arquivos:

```text
~/.ssh/ric_vm_<nome_do_usuario>
~/.ssh/ric_vm_<nome_do_usuario>.pub
```

O arquivo sem `.pub` é a chave privada.

O arquivo com `.pub` é a chave pública.

---

## 6. Mostrar a chave pública

O aluno deve executar:

```bash
cat ~/.ssh/ric_vm_<nome_do_usuario>.pub
```

Exemplo:

```bash
cat ~/.ssh/ric_vm_jonas_kunzler.pub
```

A saída será parecida com:

```text
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... <nome_do_usuario>@gmail.com
```

O aluno deve enviar somente essa chave pública para o professor ou administrador.

Atenção: nunca envie a chave privada.

Arquivo correto para enviar:

```text
ric_vm_<nome_do_usuario>.pub
```

Arquivo que não deve ser enviado:

```text
ric_vm_<nome_do_usuario>
```

---

# Parte C — Instalar a chave pública na VM

Esta parte deve ser executada pelo administrador na VM.

## 7. Adicionar a chave pública ao usuário

Na VM, abra o arquivo `authorized_keys` do usuário:

```bash
sudo nano /home/<nome_do_usuario>/.ssh/authorized_keys
```

Exemplo:

```bash
sudo nano /home/jonas_kunzler/.ssh/authorized_keys
```

Cole a chave pública enviada pelo aluno, em uma única linha.

Exemplo:

```text
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... jonas_kunzler@gmail.com
```

Salve com:

```text
Ctrl + O
Enter
Ctrl + X
```

Depois ajuste permissões novamente:

```bash
sudo chown -R <nome_do_usuario>:<nome_do_usuario> /home/<nome_do_usuario> /home/<nome_do_usuario>/.ssh
sudo chmod 700 /home/<nome_do_usuario>/.ssh
sudo chmod 600 /home/<nome_do_usuario>/.ssh/authorized_keys
```

Exemplo:

```bash
sudo chown -R jonas_kunzler:jonas_kunzler /home/jonas_kunzler /home/jonas_kunzler/.ssh
sudo chmod 700 /home/jonas_kunzler/.ssh
sudo chmod 600 /home/jonas_kunzler/.ssh/authorized_keys
```

---

## 8. Testar se o usuário existe e está configurado

Na VM, o administrador pode verificar:

```bash
id <nome_do_usuario>
ls -la /home/<nome_do_usuario>/.ssh
sudo cat /home/<nome_do_usuario>/.ssh/authorized_keys
```

Exemplo:

```bash
id jonas_kunzler
ls -la /home/jonas_kunzler/.ssh
sudo cat /home/jonas_kunzler/.ssh/authorized_keys
```

O resultado esperado para permissões é:

```text
drwx------ .ssh
-rw------- authorized_keys
```

---

# Parte D — Acesso SSH do aluno

## 9. Acessar a VM usando a chave SSH

No computador local do aluno:

```bash
ssh -i ~/.ssh/ric_vm_<nome_do_usuario> <nome_do_usuario>@IP_DA_VM
```

Exemplo:

```bash
ssh -i ~/.ssh/ric_vm_jonas_kunzler jonas_kunzler@IP_DA_VM
```

Na primeira conexão, poderá aparecer uma mensagem como:

```text
Are you sure you want to continue connecting?
```

Digite:

```text
yes
```

---

## 10. Diagnóstico se o acesso falhar

Se aparecer:

```text
Permission denied (publickey)
```

verifique:

1. o aluno está usando o usuário correto;
2. o aluno está usando a chave privada correta;
3. a chave pública foi colada em `/home/nome_do_usuario/.ssh/authorized_keys`;
4. o arquivo `authorized_keys` está com permissão `600`;
5. o diretório `.ssh` está com permissão `700`.

O aluno pode testar com modo detalhado:

```bash
ssh -vvv -i ~/.ssh/ric_vm_<nome_do_usuario> <nome_do_usuario>@IP_DA_VM
```

Exemplo:

```bash
ssh -vvv -i ~/.ssh/ric_vm_jonas_kunzler jonas_kunzler@IP_DA_VM
```

---

# Parte E — Preparação da VM para OAI com Docker

Esta parte normalmente é executada uma única vez na VM.

## 11. Atualizar o sistema

```bash
sudo apt update
sudo apt upgrade -y
```

Instale ferramentas básicas:

```bash
sudo apt install -y \
  git \
  curl \
  wget \
  vim \
  nano \
  htop \
  net-tools \
  iproute2 \
  iputils-ping \
  traceroute \
  tcpdump \
  ca-certificates \
  gnupg \
  lsb-release \
  unzip \
  zip \
  rsync \
  make \
  jq
```

---

## 12. Instalar Docker Engine

Remova versões antigas, se existirem:

```bash
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt remove -y "$pkg" 2>/dev/null || true
done
```

Instale dependências:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
```

Crie o diretório de chaves:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Adicione a chave GPG oficial do Docker:

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Ajuste permissões:

```bash
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Adicione o repositório Docker:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Atualize:

```bash
sudo apt update
```

Instale Docker e Docker Compose:

```bash
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

Ative o Docker:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Teste:

```bash
sudo docker run hello-world
```

---

## 13. Permitir usar Docker sem sudo

Adicione seu usuário ao grupo `docker`:

```bash
sudo usermod -aG docker $USER
```

Saia da VM:

```bash
exit
```

Entre novamente:

```bash
ssh -i ~/.ssh/ric_vm_<nome_do_usuario> <nome_do_usuario>@IP_DA_VM
```

Teste:

```bash
docker ps
docker compose version
```

---

## 14. Configurar rede e kernel para containers

Carregue módulos:

```bash
sudo modprobe br_netfilter
sudo modprobe overlay
sudo modprobe sctp || true
```

Configure carregamento automático:

```bash
sudo tee /etc/modules-load.d/oai.conf > /dev/null <<'EOF'
br_netfilter
overlay
sctp
EOF
```

Configure parâmetros de rede:

```bash
sudo tee /etc/sysctl.d/99-oai.conf > /dev/null <<'EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.forwarding=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
```

Aplique:

```bash
sudo sysctl --system
```

Verifique:

```bash
sysctl net.ipv4.ip_forward
lsmod | grep -E 'br_netfilter|overlay|sctp'
```

O esperado é:

```text
net.ipv4.ip_forward = 1
```

---

## 15. Instalar ferramentas úteis para testes

```bash
sudo apt install -y \
  tshark \
  wireshark-common \
  iperf3 \
  iptables \
  nftables \
  bridge-utils \
  socat \
  python3 \
  python3-pip \
  python3-venv \
  python3-yaml \
  python3-requests
```

Essas ferramentas são úteis para diagnóstico de rede, captura de pacotes, testes de conectividade e automação.

---

# Parte F — Copiar o projeto OAI do computador local para a VM

## 16. Criar diretório de trabalho na VM

Na VM:

```bash
mkdir -p ~/projects/oai
mkdir -p ~/logs
mkdir -p ~/datasets
```

---

## 17. Copiar o projeto usando rsync

Este comando deve ser executado no computador local do aluno, não dentro da VM.

Formato geral:

```bash
rsync -avz --progress \
  /CAMINHO/LOCAL/DO/PROJETO/ \
  nome_do_usuario@IP_DA_VM:~/projects/oai/meu-projeto-oai/
```

Exemplo:

```bash
rsync -avz --progress \
  ~/Documents/GitHub/meu-projeto-oai/ \
  jonas_kunzler@IP_DA_VM:~/projects/oai/meu-projeto-oai/
```

Se o acesso usa uma chave SSH específica:

```bash
rsync -avz --progress \
  -e "ssh -i ~/.ssh/ric_vm_jonas_kunzler" \
  ~/Documents/GitHub/meu-projeto-oai/ \
  jonas_kunzler@IP_DA_VM:~/projects/oai/meu-projeto-oai/
```

---

## 18. Copiar ignorando arquivos pesados

Para evitar copiar arquivos temporários ou de compilação:

```bash
rsync -avz --progress \
  --exclude '.git' \
  --exclude 'build' \
  --exclude '__pycache__' \
  --exclude '*.o' \
  --exclude '*.so' \
  --exclude '.cache' \
  -e "ssh -i ~/.ssh/ric_vm_<nome_do_usuario>" \
  /CAMINHO/LOCAL/DO/PROJETO/ \
  <nome_do_usuario>@IP_DA_VM:~/projects/oai/meu-projeto-oai/
```

---

## 19. Verificar arquivos na VM

Na VM:

```bash
cd ~/projects/oai
ls -la
```

Entre no projeto:

```bash
cd ~/projects/oai/meu-projeto-oai
ls -la
```

Procure arquivos Docker Compose:

```bash
find . -maxdepth 4 -iname '*compose*' -o -iname 'docker-compose*.yml' -o -iname 'docker-compose*.yaml'
```

---

# Parte G — Executar o projeto com Docker Compose

## 20. Validar o Docker Compose

No diretório onde está o arquivo `docker-compose.yml`:

```bash
docker compose config
```

Se o arquivo tiver outro nome:

```bash
docker compose -f NOME_DO_ARQUIVO.yaml config
```

Exemplo:

```bash
docker compose -f docker-compose-basic-nrf.yaml config
```

---

## 21. Subir o projeto

Se o arquivo se chama `docker-compose.yml`:

```bash
docker compose up -d
```

Se o arquivo tem outro nome:

```bash
docker compose -f NOME_DO_ARQUIVO.yaml up -d
```

Exemplo:

```bash
docker compose -f docker-compose-basic-nrf.yaml up -d
```

---

## 22. Verificar containers

```bash
docker ps
```

Ver todos os containers:

```bash
docker ps -a
```

Ver status do Compose:

```bash
docker compose ps
```

Se usou arquivo específico:

```bash
docker compose -f NOME_DO_ARQUIVO.yaml ps
```

---

## 23. Acompanhar logs

Todos os serviços:

```bash
docker compose logs -f
```

Serviço específico:

```bash
docker compose logs -f NOME_DO_SERVICO
```

Exemplo:

```bash
docker compose logs -f amf
docker compose logs -f smf
docker compose logs -f upf
```

---

## 24. Parar o projeto

```bash
docker compose down
```

Se usou arquivo específico:

```bash
docker compose -f NOME_DO_ARQUIVO.yaml down
```

Para remover volumes:

```bash
docker compose down -v
```

Atenção: `down -v` pode remover dados persistentes, como bancos de dados.

---

# Parte H — Comandos úteis de diagnóstico

## 25. Docker

```bash
docker ps
docker ps -a
docker images
docker network ls
docker volume ls
docker system df
```

---

## 26. Logs de container

```bash
docker logs NOME_DO_CONTAINER
```

---

## 27. Entrar em um container

```bash
docker exec -it NOME_DO_CONTAINER bash
```

Se não houver `bash`:

```bash
docker exec -it NOME_DO_CONTAINER sh
```

---

## 28. Ver portas abertas

```bash
sudo ss -tulnp
```

---

## 29. Ver redes Docker

```bash
docker network ls
docker network inspect NOME_DA_REDE
```

---

## 30. Ver uso de disco

```bash
df -h
docker system df
```

---

## 31. Limpar recursos Docker

Ver uso de espaço:

```bash
docker system df
```

Remover containers, redes e imagens não utilizadas:

```bash
docker system prune
```

Remover também imagens não utilizadas:

```bash
docker system prune -a
```

Remover volumes não utilizados:

```bash
docker volume prune
```

Use esses comandos com cuidado.

---

# Parte I — Problemas comuns

## 32. Erro: Permission denied no SSH

Verifique:

```bash
ssh -vvv -i ~/.ssh/ric_vm_<nome_do_usuario> <nome_do_usuario>@IP_DA_VM
```

Possíveis causas:

1. usuário errado;
2. chave privada errada;
3. chave pública não instalada na VM;
4. permissões incorretas em `.ssh`;
5. IP da VM incorreto;
6. firewall bloqueando SSH.

---

## 33. Erro: Docker permission denied

Verifique grupos:

```bash
groups
```

Se não aparecer `docker`:

```bash
sudo usermod -aG docker $USER
```

Depois saia e entre novamente.

---

## 34. Erro: docker compose não encontrado

Teste:

```bash
docker compose version
```

Se falhar:

```bash
sudo apt update
sudo apt install -y docker-compose-plugin
```

---

## 35. Containers sobem e param

Veja logs:

```bash
docker compose logs
```

Ou:

```bash
docker logs NOME_DO_CONTAINER
```

---

# Parte J — Fluxo resumido

## No computador local

Gerar chave:

```bash
ssh-keygen -t rsa -b 4096 -C "<nome_do_usuario>@gmail.com" -f ~/.ssh/ric_vm_<nome_do_usuario>
```

Mostrar chave pública:

```bash
cat ~/.ssh/ric_vm_<nome_do_usuario>.pub
```

Acessar VM:

```bash
ssh -i ~/.ssh/ric_vm_<nome_do_usuario> <nome_do_usuario>@IP_DA_VM
```

Copiar projeto:

```bash
rsync -avz --progress \
  -e "ssh -i ~/.ssh/ric_vm_<nome_do_usuario>" \
  /CAMINHO/LOCAL/DO/PROJETO/ \
  <nome_do_usuario>@IP_DA_VM:~/projects/oai/meu-projeto-oai/
```

## Na VM

Entrar no projeto:

```bash
cd ~/projects/oai/meu-projeto-oai
```

Subir containers:

```bash
docker compose up -d
```

Verificar:

```bash
docker ps
docker compose logs -f
```

---

# Resultado esperado

Ao final, o aluno deverá conseguir:

1. acessar a VM usando chave SSH;
2. copiar arquivos do projeto local para a VM;
3. executar Docker sem `sudo`;
4. subir o projeto com Docker Compose;
5. verificar containers e logs;
6. diagnosticar problemas básicos de rede, containers e permissões.
