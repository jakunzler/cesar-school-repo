# Laboratório de Redes e Computação em Nuvem

## Acesso à Nova Máquina Virtual (VM)

Foi disponibilizada uma nova máquina virtual para utilização nas atividades práticas da disciplina.

**Endereço IP da VM:** `34.173.36.112`

## Usuários Disponíveis

Cada aluno deverá utilizar exclusivamente o usuário que lhe foi atribuído:

| Usuário          |
| ---------------- |
| cristianowa1150  |
| efs2+equipe3     |
| felipebarth      |
| gilmar.silva.gms |
| lacs             |
| lcsr             |

---

## 1. Geração da Chave SSH

Caso ainda não possua uma chave SSH para esta atividade, execute em seu computador:

```bash
ssh-keygen -t rsa -b 4096 -C "seu_email" -f ~/.ssh/ric_vm_<usuario>
```

Exemplo:

```bash
ssh-keygen -t rsa -b 4096 -C "aluno@email.com" -f ~/.ssh/ric_vm_felipebarth
```

Serão criados dois arquivos:

```text
~/.ssh/ric_vm_<usuario>
~/.ssh/ric_vm_<usuario>.pub
```

**Importante:**

* Arquivo `.pub` → chave pública (pode ser enviada ao professor)
* Arquivo sem `.pub` → chave privada (não deve ser compartilhada)

Caso sua chave pública ainda não tenha sido enviada, execute:

```bash
cat ~/.ssh/ric_vm_<usuario>.pub
```

e encaminhe o conteúdo ao professor.

---

## 2. Acesso à Máquina Virtual

Após a chave ser cadastrada, conecte-se utilizando:

```bash
ssh -i ~/.ssh/ric_vm_<usuario> <usuario>@34.173.36.112
```

Exemplo:

```bash
ssh -i ~/.ssh/ric_vm_felipebarth felipebarth@34.173.36.112
```

Na primeira conexão será exibida a mensagem:

```text
Are you sure you want to continue connecting?
```

Digite:

```text
yes
```

---

## 3. Verificação

Após o login, o terminal deverá exibir algo semelhante a:

```text
usuario@vm-ric:~$
```

---

## 4. Em Caso de Problemas

Para diagnosticar falhas de autenticação:

```bash
ssh -vvv -i ~/.ssh/ric_vm_<usuario> <usuario>@34.173.36.112
```

Os erros mais comuns são:

* utilização de usuário incorreto;
* chave privada incorreta;
* chave pública não cadastrada na VM;
* permissões incorretas na pasta `.ssh`.

---

**Professor Responsável:**
Dr. Jonas Augusto Kunzler

**Observação:** O acesso à VM é realizado exclusivamente por autenticação via chave SSH.
