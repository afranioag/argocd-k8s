# V3 — ArgoCD & GitOps

Este é o **Passo 3** da jornada Kubernetes: da instalação manual (`v1`) para **GitOps com ArgoCD**.

## O que mudou

| Versão | Abordagem | Quem aplica as mudanças |
|--------|-----------|----------------------|
| **v1** | Manual | Você roda `kubectl apply` na mão |
| **v2** | *(não existe neste projeto)* | — |
| **v3** | **GitOps/ArgoCD** | Uma ferramenta observa o Git e aplica automaticamente |

---

## Conceitos — ArgoCD em 1 minuto

**ArgoCD** é um **operador Kubernetes** que funciona como um **robô vigia**:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Git Repo                  ArgoCD              Kubernetes       │
│  ┌──────────────┐          ┌────────┐         ┌──────────────┐  │
│  │ deployment   │          │        │         │              │  │
│  │ service.yml  │◄────────►│ ArgoCD │────────►│ Pods rodando │  │
│  │ config.yml   │ observa  │        │ aplica  │              │  │
│  └──────────────┘          └────────┘         └──────────────┘  │
│                                                                  │
│  "Estado desejado no Git" ──► "Realidade no cluster"            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**O fluxo:**

1. Você **muda algo no Git** (ex: atualiza a imagem Docker no `deployment.yml`)
2. ArgoCD **detecta a mudança** automaticamente (ou você avisa via webhook)
3. ArgoCD **aplica no cluster** (`kubectl apply` automático)
4. Se alguém mexer direto no cluster e desviar do Git, ArgoCD **corrige sozinho** (self-healing)

---

## Pré-requisitos

Tudo que usou em **v1**, mais:

| Ferramenta | Para quê | Verificar |
|---|---|---|
| **ArgoCD** | Operador GitOps no cluster | `argocd version` (depois de instalar) |
| **Git** | Versionamento e sincronização | `git --version` |
| **Repositório Git** | Armazenar os manifestos | GitHub / GitLab / etc |

---

## Estrutura da V3

```
v3/
├── app.py                  # Flask simples (mesmo de v1)
├── Dockerfile              # Imagem Docker (mesmo de v1)
├── templates/
│   └── index.html          # "Olá Mundo!" com visual ArgoCD
├── deployment.yml          # Deployment k8s + probes de health
├── service.yml             # Service LoadBalancer
├── config.yml              # Aplicação ArgoCD (a "receita" do sync)
└── README.md               # Este arquivo
```

---

## Passo a passo — Do Docker até ArgoCD sincronizando

### Passo 0 — Preparar o cluster

Se o cluster não está rodando:

```bash
minikube start --driver=docker
```

Valide:

```bash
kubectl get nodes
```

---

### Passo 1 — Buildar e enviar a imagem Docker

Construir a imagem (igual v1):

```bash
cd /caminho/para/v3
docker build -t seu-usuario-dockerhub/app-py-k8s:v3 .
```

Testar localmente:

```bash
docker run --rm -p 5000:5000 seu-usuario-dockerhub/app-py-k8s:v3
# Abra http://localhost:5000 — verá "Olá Mundo!" com badge ArgoCD
```

Enviar para Docker Hub (necessário para o cluster baixar):

```bash
docker login
docker push seu-usuario-dockerhub/app-py-k8s:v3
```

> ⚠️ **Não se esqueça de atualizar o campo `image` em `deployment.yml` com seu usuário.**

---

### Passo 2 — Colocar os manifestos no Git

1. **Inicie um repositório Git** (ou use um existente):

```bash
cd /caminho/para/seu/repo
git init
git add .
git commit -m "v3: ArgoCD + GitOps setup"
git remote add origin https://github.com/seu-usuario/seu-repo.git
git push -u origin main
```

2. **Certifique-se que o `v3/` está no Git**, junto com seus manifestos:
   - `deployment.yml`
   - `service.yml`
   - `config.yml`

A URL do repositório será usada no `config.yml` (próximo passo).

---

### Passo 3 — Instalar ArgoCD no cluster

ArgoCD é instalado como uma aplicação normal no cluster:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Espere os Pods do ArgoCD ficarem prontos:

```bash
kubectl get pods -n argocd -w
```

Quando todos estiverem `Running`, saia com `Ctrl+C`.

---

### Passo 4 — Acessar o Dashboard ArgoCD

O ArgoCD tem um dashboard web. Exponha-o com port-forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Acesse: **https://localhost:8080**

A senha inicial pode ser obtida de **duas formas**:

#### Opção A — Via CLI argocd (se instalado)

Se você já tem o CLI do argocd instalado:

```bash
argocd admin initial-password -n argocd
```

#### Opção B — Via kubectl (recomendado — sem dependências)

Se o CLI não está instalado ou você prefere não instalar:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Este comando extrai a senha do secret Kubernetes. Funciona sem instalar nada extra.

#### Instalar o CLI argocd (opcional)

Se quiser ter o CLI disponível para futuros comandos:

**Linux:**
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
argocd version  # verificar instalação
```

**macOS:**
```bash
brew install argocd
```

---

**Para fazer login no dashboard:**

- Username: `admin`
- Password: *(resultado de uma das opções acima)*

> 💡 Após login, é recomendável **mudar a senha** no dashboard: Settings → Accounts → Update password

---

### Passo 5 — Criar a Aplicação ArgoCD

Agora ArgoCD vai observar seu repositório Git e sincronizar automaticamente.

**Opção A — Via dashboard (GUI):**

1. Acesse https://localhost:8080
2. Clique em **"+ New App"**
3. Preencha:
   - **Application Name:** `v3-app`
   - **Project:** `default`
   - **Repository URL:** `https://github.com/seu-usuario/seu-repo.git`
   - **Revision:** `HEAD`
   - **Path:** `subindo-kubernetes-simples/v3`
   - **Destination Server:** `https://kubernetes.default.svc`
   - **Destination Namespace:** `default`
4. Ative **"Sync Policy → Automated"** para self-healing
5. Clique em **"Create"**

**Opção B — Via CLI (comandos):**

1. Instale o `argocd` CLI (se não tiver):

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

2. Faça login:

```bash
argocd login localhost:8080 --username admin --password <senha-do-passo-4>
```

3. Crie a aplicação (edite `config.yml` com sua URL de repo):

```bash
kubectl apply -f subindo-kubernetes-simples/v3/config.yml
```

---

### Passo 6 — Validar o Sync

Volte ao dashboard. Você verá a aplicação `v3-app`:

- **Sync Status:** `Synced` (verde) = cluster bate com Git ✓
- **Health Status:** `Healthy` (verde) = Pods estão vivos ✓

Ver os Pods rodando:

```bash
kubectl get pods -l app=v3-app
```

---

### Passo 7 — Acessar a aplicação

Abra a aplicação no navegador:

```bash
kubectl port-forward svc/v3-app-service 5000:5000
# Acesse http://localhost:5000
```

Ou via minikube:

```bash
minikube service v3-app-service
```

Verá: **"Olá Mundo!" com badge "ArgoCD Enabled ✓"**

---

## O "magic" do GitOps — Testando o Auto-Sync

### Teste 1: Mude a imagem no Git

1. Edite `deployment.yml` — mude a tag da imagem para `:v3-new`
2. Commit e push:

```bash
git add deployment.yml
git commit -m "bump image to v3-new"
git push origin main
```

3. **Aguarde 3 minutos** (ou force sync no dashboard) — ArgoCD detecta e aplica automaticamente.

### Teste 2: Delete um Pod no cluster

```bash
kubectl delete pod <nome-de-um-pod>
```

Espere alguns segundos — ArgoCD verá que cluster não bate com Git e recriará o Pod. **Self-healing!**

### Teste 3: Delete um recurso manualmente do cluster

```bash
kubectl delete service v3-app-service
```

ArgoCD detecta que Service sumiu e recria automaticamente. É o **estado desejado** em ação real.

---

## Workflow típico (v1 vs v3)

### V1 — Manual

```bash
# Você edita deployment.yml
vim deployment.yml

# Você manualmente aplica
kubectl apply -f deployment.yml

# Você verifica
kubectl get pods
```

### V3 — ArgoCD/GitOps

```bash
# Você edita deployment.yml
vim deployment.yml

# Você faz commit e push (só isso!)
git add deployment.yml
git commit -m "update replica count"
git push origin main

# ArgoCD ve a mudança no Git
# ArgoCD aplica no cluster automaticamente
# Você monitora no dashboard (ou não faz nada — está tudo sincronizado)
```

**Benefício:** Toda mudança fica versionada no Git. Auditoria total. Rollback é apenas um `git revert`.

---

## Comandos importantes (v3)

```bash
# Ver status da sincronização
argocd app get v3-app

# Forçar sincronização manual
argocd app sync v3-app

# Logs do ArgoCD observando mudanças
kubectl logs -f deployment/argocd-application-controller -n argocd

# Remover a aplicação ArgoCD (não deleta os recursos no cluster)
argocd app delete v3-app

# Deletar tudo (ArgoCD + Deployment + Service)
kubectl delete namespace argocd
kubectl delete -f deployment.yml
kubectl delete -f service.yml
```

---

## Próximos passos (pós-v3)

Conceitos que completam a história do GitOps:

- **ArgoCD Notifications** — enviar alertas para Slack/email quando sync falha
- **ApplicationSet** — gerenciar múltiplas aplicações (multi-cluster, multi-env)
- **Sealed Secrets** — guardar secrets criptografados no Git
- **Helm + ArgoCD** — usar templates parametrizados
- **Kustomize + ArgoCD** — gestão de manifestos com patches e overlays
- **Webhook GitHub** — ArgoCD sincroniza **na hora** que você faz push (sem esperar 3 min)

---

## Troubleshooting V3

| Sintoma | Causa | Como resolver |
|---|---|---|
| "Application not synced" (vermelho) | Diff entre Git e cluster | `argocd app diff v3-app` ou clique "Sync" no dashboard |
| ArgoCD vê o repo mas Pods não sobem | Imagem não existe ou não consegue baixar | `kubectl describe pod` → verify `image` field em `deployment.yml` |
| "Unable to connect to repository" | URL do Git errada ou sem permissão | Verifique URL em `config.yml`, use token SSH/HTTPS se privado |
| Dashboard ArgoCD lento ou preso | Muitos recursos para sincronizar | Verifique `kubectl logs` do application-controller |

---

## Resumo

| Aspecto | V1 | V3 |
|--------|-----|-----|
| **Como deploy sai?** | Você roda `kubectl apply` | Git + ArgoCD sincronizam |
| **Auditoria** | Histórico de seus comandos | Histórico completo no Git |
| **Rollback** | `kubectl rollout undo` | `git revert` + push |
| **Múltiplos envs** | Copiar manifesto N vezes | 1 config + Git branches |
| **Automação** | Manual | Automática (self-healing) |
| **Complexidade** | Baixa | Média (ArgoCD setup) |

**ArgoCD é o "Kubernetes self-service"** — você declara o estado no Git, e ele garante que cluster sempre bate com Git.

---

## Próxima iteração?

- **V4:** Helm + ArgoCD (templates reutilizáveis)
- **V5:** Multi-environment (dev/staging/prod com ArgoCD)
- **V6:** Canary deployments com ArgoCD + Flagger

