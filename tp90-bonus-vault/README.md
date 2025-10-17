# Tutoriel Vault avec Kubernetes sur AlmaLinux et Minikube

## Prérequis

- AlmaLinux installé
- Minikube fonctionnel
- kubectl configuré
- Helm installé

## Installation de Vault

### 1. Démarrer Minikube

```bash
minikube start --driver=docker
```

### 2. Ajouter le dépôt Helm de HashiCorp

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

### 3. Installer Vault en mode développement

```bash
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true"
```

Vérifier le déploiement :

```bash
kubectl get pods
```

## Configuration de base

### 4. Accéder au pod Vault

```bash
kubectl exec -it vault-0 -- /bin/sh
```

### 5. Activer le moteur de secrets KV

```bash
vault secrets enable -path=secret kv-v2
```

### 6. Créer un secret

```bash
vault kv put secret/webapp/config username="admin" password="secretpass123"
```

Vérifier le secret :

```bash
vault kv get secret/webapp/config
```

## Configuration de l'authentification Kubernetes

### 7. Activer l'authentification Kubernetes

```bash
vault auth enable kubernetes
```

### 8. Configurer l'authentification

```bash
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
```

### 9. Créer une politique d'accès

```bash
vault policy write webapp - <<EOF
path "secret/data/webapp/config" {
  capabilities = ["read"]
}
EOF
```

### 10. Créer un rôle Kubernetes

```bash
vault write auth/kubernetes/role/webapp \
    bound_service_account_names=webapp-sa \
    bound_service_account_namespaces=default \
    policies=webapp \
    ttl=24h
```

Sortir du pod :

```bash
exit
```

## Déploiement d'une application test

### 11. Créer un ServiceAccount

```bash
kubectl create serviceaccount webapp-sa
```

### 12. Créer un déploiement d'application

Créer le fichier `webapp-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "webapp"
        vault.hashicorp.com/agent-inject-secret-config.txt: "secret/data/webapp/config"
    spec:
      serviceAccountName: webapp-sa
      containers:
      - name: webapp
        image: nginx:alpine
        ports:
        - containerPort: 80
```

Appliquer le déploiement :

```bash
kubectl apply -f webapp-deployment.yaml
```

### 13. Vérifier l'injection des secrets

```bash
kubectl get pods
kubectl exec -it <webapp-pod-name> -c webapp -- cat /vault/secrets/config.txt
```

Vous devriez voir les secrets injectés dans le conteneur.

## Opérations courantes

### Lister les secrets

```bash
kubectl exec -it vault-0 -- vault kv list secret/webapp
```

### Mettre à jour un secret

```bash
kubectl exec -it vault-0 -- vault kv put secret/webapp/config \
  username="admin" password="newpassword456"
```

### Vérifier les logs du sidecar Vault Agent

```bash
kubectl logs <webapp-pod-name> -c vault-agent-init
```

## Nettoyage

Pour supprimer les ressources :

```bash
kubectl delete deployment webapp
kubectl delete serviceaccount webapp-sa
helm uninstall vault
```

## Points importants

Le mode développement utilisé ici ne persiste pas les données. Pour un environnement de production, configurez Vault avec un backend de stockage persistent et activez le mode haute disponibilité. Les secrets sont automatiquement injectés dans les pods via le sidecar Vault Agent, ce qui évite de les exposer dans les variables d'environnement ou les ConfigMaps.



