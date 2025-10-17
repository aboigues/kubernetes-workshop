# TP07 - Namespaces et isolation

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Comprendre l'utilité des Namespaces
- Créer et gérer des Namespaces
- Organiser les ressources par environnement
- Implémenter des quotas de ressources
- Isoler le réseau avec NetworkPolicies
- Mettre en place une architecture multi-équipes

## Concepts clés

### Qu'est-ce qu'un Namespace ?

Un Namespace est un **cluster virtuel** dans votre cluster physique. C'est comme avoir plusieurs "espaces de travail" isolés.

**Analogie :** Si Kubernetes est un immeuble, les Namespaces sont les appartements. Chaque appartement est isolé mais partage l'infrastructure (électricité, eau = ressources du cluster).

**Utilité :**
- **Isolation logique** : Séparer dev/staging/production
- **Organisation** : Par équipe, par projet, par client
- **Sécurité** : Contrôle d'accès via RBAC
- **Quotas** : Limiter les ressources par namespace
- **Nommage** : Éviter les conflits de noms

### Namespaces par défaut

Kubernetes crée automatiquement ces namespaces :

**default**
- Namespace par défaut quand rien n'est spécifié
- Ressources des utilisateurs

**kube-system**
- Composants système de Kubernetes
- CoreDNS, kube-proxy, metrics-server, etc.
- **Ne jamais y déployer vos applications**

**kube-public**
- Ressources publiques lisibles par tous
- Rarement utilisé

**kube-node-lease**
- Heartbeat des nœuds (santé du cluster)
- Gestion interne

```bash
# Lister tous les namespaces
kubectl get namespaces
# ou
kubectl get ns
```

**Sortie :**
```
NAME              STATUS   AGE
default           Active   10d
kube-node-lease   Active   10d
kube-public       Active   10d
kube-system       Active   10d
```

---

## Exercice 1 - Créer et utiliser des Namespaces

### Objectif
Créer des namespaces pour différents environnements et déployer des applications.

### Contexte
Organisation classique : un namespace par environnement (dev, staging, production).

### Instructions détaillées

**Étape 1 : Créer des namespaces**

**Méthode 1 : En ligne de commande**

```bash
# Créer les namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production

# Lister
kubectl get namespaces
```

**Méthode 2 : Via YAML (recommandé)**

Créez `manifests/namespaces.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    env: development
    team: platform
    cost-center: "engineering"
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    env: staging
    team: platform
    cost-center: "engineering"
---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    env: production
    team: platform
    cost-center: "production"
    critical: "true"
```

**Explications :**

**labels** : Métadonnées pour organiser et filtrer
- `env` : Environnement (development, staging, production)
- `team` : Équipe propriétaire
- `cost-center` : Centre de coût pour la facturation
- `critical` : Marque les namespaces critiques

```bash
kubectl apply -f manifests/namespaces.yaml

# Voir les labels
kubectl get namespace --show-labels

# Filtrer par label
kubectl get namespace -l env=production
```

**Sortie :**
```
NAME         STATUS   AGE   LABELS
dev          Active   10s   cost-center=engineering,env=development,team=platform
staging      Active   10s   cost-center=engineering,env=staging,team=platform
production   Active   10s   cost-center=production,critical=true,env=production,team=platform
```

**Étape 2 : Déployer une application dans un namespace**

Créez `manifests/app-in-dev.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: dev  # Spécifie le namespace
  labels:
    app: myapp
    env: dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: dev
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
```

**Important :** `namespace: dev` dans `metadata` spécifie où créer la ressource.

```bash
kubectl apply -f manifests/app-in-dev.yaml

# Lister les ressources dans dev
kubectl get all -n dev

# Sans -n, on voit le namespace default
kubectl get all
```

**Sortie (dans dev) :**
```
NAME                         READY   STATUS    RESTARTS   AGE
pod/myapp-5d4f8c9b7d-abc12   1/1     Running   0          30s
pod/myapp-5d4f8c9b7d-def34   1/1     Running   0          30s

NAME                    TYPE        CLUSTER-IP      PORT(S)   AGE
service/myapp-service   ClusterIP   10.96.123.45    80/TCP    30s

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/myapp   2/2     2            2           30s
```

**Étape 3 : Changer le namespace par défaut**

Au lieu de toujours taper `-n dev`, changez le namespace par défaut :

```bash
# Voir le context actuel
kubectl config current-context

# Voir les détails du context
kubectl config get-contexts

# Changer le namespace par défaut
kubectl config set-context --current --namespace=dev

# Maintenant, toutes les commandes utilisent dev
kubectl get pods
# Équivalent à : kubectl get pods -n dev

# Revenir à default
kubectl config set-context --current --namespace=default
```

**Étape 4 : Déployer la même app dans tous les environnements**

```bash
# Créer dans staging
kubectl apply -f manifests/app-in-dev.yaml -n staging

# Créer dans production avec plus de répliques
kubectl apply -f manifests/app-in-dev.yaml -n production
kubectl scale deployment myapp -n production --replicas=5

# Voir toutes les instances
kubectl get pods --all-namespaces | grep myapp
# ou
kubectl get pods -A | grep myapp
```

**Sortie :**
```
dev          myapp-xxx   1/1   Running   0   5m
dev          myapp-yyy   1/1   Running   0   5m
staging      myapp-zzz   1/1   Running   0   2m
staging      myapp-aaa   1/1   Running   0   2m
production   myapp-bbb   1/1   Running   0   1m
production   myapp-ccc   1/1   Running   0   1m
production   myapp-ddd   1/1   Running   0   1m
production   myapp-eee   1/1   Running   0   1m
production   myapp-fff   1/1   Running   0   1m
```

**Étape 5 : Comparer les environnements**

```bash
# Nombre de Pods par namespace
echo "Dev: $(kubectl get pods -n dev --no-headers | wc -l)"
echo "Staging: $(kubectl get pods -n staging --no-headers | wc -l)"
echo "Production: $(kubectl get pods -n production --no-headers | wc -l)"

# Ressources utilisées (si metrics-server est actif)
kubectl top pods -n dev
kubectl top pods -n production
```

---

## Exercice 2 - Communication entre Namespaces

### Objectif
Comprendre comment les services communiquent entre namespaces via DNS.

### Contexte
Le DNS Kubernetes permet l'accès aux services d'autres namespaces avec un nom qualifié.

### Format DNS

**Nom court (même namespace) :**
```
<service-name>
```

**Nom avec namespace :**
```
<service-name>.<namespace>
```

**Nom complet (FQDN) :**
```
<service-name>.<namespace>.svc.cluster.local
```

**Exemples :**
- `myapp-service` : même namespace
- `myapp-service.dev` : namespace dev
- `myapp-service.dev.svc.cluster.local` : nom complet

### Instructions détaillées

**Étape 1 : Tester la résolution DNS**

```bash
# Créer un Pod de test dans dev
kubectl run test-dev -n dev --image=busybox --rm -it --restart=Never -- sh

# Dans le Pod, tester les résolutions DNS :

# Nom court (même namespace)
nslookup myapp-service
# Fonctionne car on est dans dev

# Nom avec namespace
nslookup myapp-service.staging
# Accède au service dans staging

# Nom complet
nslookup myapp-service.production.svc.cluster.local
# Accède au service dans production

# Voir le serveur DNS utilisé
cat /etc/resolv.conf

exit
```

**Sortie de nslookup :**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      myapp-service.staging
Address 1: 10.96.234.56 myapp-service.staging.svc.cluster.local
```

**Étape 2 : Communication inter-namespace**

```bash
# Depuis dev, accéder à staging
kubectl run test -n dev --image=busybox --rm -it --restart=Never -- sh

# Dans le Pod :
wget -qO- myapp-service.staging
# Fonctionne !

# Accéder à production
wget -qO- myapp-service.production

exit
```

**Étape 3 : Créer une architecture multi-namespace**

Créez `manifests/multi-namespace-app.yaml` :

```yaml
# Frontend dans dev
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        env:
        # Référence au backend dans staging
        - name: BACKEND_URL
          value: "http://backend-service.staging"
---
# Backend dans staging
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: staging
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: httpd
        image: httpd:alpine
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: staging
spec:
  selector:
    app: backend
  ports:
  - port: 80
```

**Le frontend dans dev peut appeler le backend dans staging via DNS !**

```bash
kubectl apply -f manifests/multi-namespace-app.yaml

# Vérifier
kubectl get pods -n dev
kubectl get pods -n staging
```

---

## Exercice 3 - ResourceQuota (quotas de ressources)

### Objectif
Limiter les ressources disponibles dans un namespace pour éviter la sur-utilisation.

### Contexte
Sans quotas, un namespace peut consommer toutes les ressources du cluster. Les quotas permettent de :
- Limiter CPU/RAM total
- Limiter le nombre de ressources (Pods, Services, PVC)
- Garantir l'équité entre namespaces
- Contrôler les coûts

### Instructions détaillées

**Étape 1 : Créer des ResourceQuotas**

Créez `manifests/resource-quotas.yaml` :

```yaml
# Quota pour dev (généreux pour le développement)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    # Ressources compute
    requests.cpu: "4"           # Max 4 CPU demandés
    requests.memory: 8Gi        # Max 8Gi RAM demandés
    limits.cpu: "8"             # Max 8 CPU limites
    limits.memory: 16Gi         # Max 16Gi RAM limites
    
    # Nombre de ressources
    pods: "20"                  # Max 20 Pods
    services: "10"              # Max 10 Services
    persistentvolumeclaims: "5" # Max 5 PVC
    configmaps: "10"
    secrets: "10"
---
# Quota pour staging (modéré)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-quota
  namespace: staging
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
    services: "5"
---
# Quota pour production (strict mais suffisant)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: production
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    pods: "50"
    services: "20"
    configmaps: "20"
    secrets: "20"
```

**Explications :**

**requests vs limits :**
- `requests` : Ressources garanties au Pod (réservées)
- `limits` : Maximum que le Pod peut utiliser

**Stratégie par environnement :**
- **dev** : Généreux (développement, tests)
- **staging** : Modéré (pré-production)
- **production** : Plus de ressources mais contrôlé

```bash
kubectl apply -f manifests/resource-quotas.yaml

# Voir les quotas
kubectl get resourcequota -n dev
kubectl describe resourcequota dev-quota -n dev
```

**Sortie :**
```
Name:                   dev-quota
Namespace:              dev
Resource                Used  Hard
--------                ----  ----
configmaps              0     10
limits.cpu              400m  8
limits.memory           512Mi 16Gi
persistentvolumeclaims  0     5
pods                    2     20
requests.cpu            200m  4
requests.memory         256Mi 8Gi
secrets                 1     10
services                1     10
```

**Lecture :** 
- `Used` : Ressources actuellement utilisées
- `Hard` : Limite maximale
- `pods: 2/20` : 2 Pods sur 20 autorisés

**Étape 2 : Tester le quota (limite de Pods)**

```bash
# Essayer de créer trop de Pods
kubectl create deployment test -n dev --image=nginx --replicas=30

# Attendre un peu
sleep 10

# Vérifier
kubectl get pods -n dev
```

**Résultat :** Seulement 20 Pods maximum (quota respecté).

```bash
# Voir les événements
kubectl get events -n dev --sort-by=.metadata.creationTimestamp | tail -10

# Vous verrez : "exceeded quota"
```

**Étape 3 : Tester le quota (ressources CPU/RAM)**

```yaml
# Ce Pod sera REFUSÉ si le quota est dépassé
apiVersion: v1
kind: Pod
metadata:
  name: big-pod
  namespace: dev
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: "5"        # Dépasse le quota dev (4 CPU)
        memory: 2Gi
```

```bash
kubectl apply -f manifests/big-pod.yaml
```

**Erreur attendue :**
```
Error from server (Forbidden): pods "big-pod" is forbidden: 
exceeded quota: dev-quota, requested: requests.cpu=5, 
used: requests.cpu=200m, limited: requests.cpu=4
```

**Étape 4 : Quota avec Pods sans ressources**

**Important :** Si un quota existe, TOUS les Pods doivent spécifier resources.

```yaml
# Ce Pod sera REFUSÉ
apiVersion: v1
kind: Pod
metadata:
  name: no-resources
  namespace: dev
spec:
  containers:
  - name: app
    image: nginx
    # MANQUE : resources requests/limits
```

**Erreur :**
```
Error: pods "no-resources" is forbidden: failed quota: dev-quota: 
must specify limits.cpu,limits.memory,requests.cpu,requests.memory
```

**Solution :** Toujours spécifier les ressources quand un quota existe.

---

## Exercice 4 - LimitRange (limites par défaut)

### Objectif
Définir des limites par défaut et des contraintes sur les ressources individuelles.

### Contexte
LimitRange complète ResourceQuota en :
- Définissant des valeurs par défaut (si non spécifiées)
- Imposant des min/max par conteneur ou Pod
- Simplifiant la vie des développeurs

### Instructions détaillées

**Étape 1 : Créer des LimitRanges**

Créez `manifests/limit-ranges.yaml` :

```yaml
# LimitRange pour dev
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev
spec:
  limits:
  # Limites pour les conteneurs
  - type: Container
    default:  # Limites par défaut (si non spécifiées)
      cpu: 500m
      memory: 512Mi
    defaultRequest:  # Requêtes par défaut
      cpu: 200m
      memory: 256Mi
    max:  # Maximum autorisé
      cpu: "2"
      memory: 2Gi
    min:  # Minimum requis
      cpu: 50m
      memory: 64Mi
  
  # Limites pour les Pods (somme de tous les conteneurs)
  - type: Pod
    max:
      cpu: "4"
      memory: 4Gi
---
# LimitRange pour production (plus strict)
apiVersion: v1
kind: LimitRange
metadata:
  name: prod-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: "1"
      memory: 1Gi
    min:
      cpu: 100m
      memory: 128Mi
    maxLimitRequestRatio:  # Ratio max limit/request
      cpu: 2    # limit peut être 2x request
      memory: 2
```

**Explications :**

**default** : Valeurs appliquées si `limits` non spécifiées
**defaultRequest** : Valeurs appliquées si `requests` non spécifiées
**max** : Maximum autorisé (rejet si dépassé)
**min** : Minimum requis (rejet si inférieur)
**maxLimitRequestRatio** : Évite les limites trop hautes par rapport aux requests

```bash
kubectl apply -f manifests/limit-ranges.yaml

# Voir les LimitRanges
kubectl describe limitrange dev-limits -n dev
```

**Étape 2 : Créer un Pod sans ressources**

Avec un LimitRange, les valeurs par défaut sont appliquées automatiquement.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: auto-limits
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    # Pas de ressources spécifiées !
```

```bash
kubectl apply -f manifests/auto-limits-pod.yaml

# Vérifier que les limites ont été appliquées automatiquement
kubectl describe pod auto-limits -n dev | grep -A 5 "Limits"
```

**Sortie :**
```
Limits:
  cpu:     500m      ← default
  memory:  512Mi     ← default
Requests:
  cpu:     200m      ← defaultRequest
  memory:  256Mi     ← defaultRequest
```

**Les valeurs par défaut du LimitRange ont été appliquées !**

**Étape 3 : Tester les violations**

**Pod trop grand :**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: too-big
  namespace: dev
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: "3"  # Dépasse max: 2
```

**Erreur :**
```
Error: pods "too-big" is forbidden: 
maximum cpu usage per Container is 2, but requested 3
```

**Pod trop petit :**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: too-small
  namespace: dev
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: 10m  # Inférieur à min: 50m
```

**Erreur :**
```
Error: pods "too-small" is forbidden: 
minimum cpu usage per Container is 50m, but requested 10m
```

---

## Exercice 5 - NetworkPolicy (isolation réseau)

### Objectif
Isoler le trafic réseau entre namespaces pour la sécurité.

### Contexte
Par défaut, **tous les Pods peuvent communiquer** entre eux, même dans différents namespaces. NetworkPolicy permet de contrôler ce trafic.

**Exemple d'utilisation :**
- Bloquer dev → production
- Autoriser staging → production
- Isoler complètement un namespace sensible

### Instructions détaillées

**Étape 1 : Tester la communication par défaut**

```bash
# Créer un Pod dans dev
kubectl run client -n dev --image=busybox --rm -it --restart=Never -- sh

# Accéder au service production
wget -qO- myapp-service.production --timeout=5
# Fonctionne ! (par défaut, pas d'isolation)

exit
```

**Étape 2 : Créer une NetworkPolicy (tout bloquer)**

Créez `manifests/network-policy-deny-all.yaml` :

```yaml
# Bloquer tout le trafic ENTRANT dans production
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}  # S'applique à TOUS les Pods
  policyTypes:
  - Ingress
  # Pas de règle ingress = tout bloqué
```

**Explications :**

**podSelector: {}** : Sélectionne tous les Pods du namespace
**policyTypes: [Ingress]** : Contrôle le trafic entrant
**Pas de règle ingress** : Tout est bloqué par défaut (deny-all)

```bash
kubectl apply -f manifests/network-policy-deny-all.yaml

# Tester depuis dev → production (BLOQUÉ maintenant)
kubectl run client -n dev --image=busybox --rm -it --restart=Never -- \
  wget -qO- myapp-service.production --timeout=5

# Timeout ! Le trafic est bloqué
```

**Étape 3 : Autoriser le trafic depuis le même namespace**

Créez `manifests/network-policy-allow-same-ns.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}  # Tous les Pods du même namespace
```

```bash
kubectl apply -f manifests/network-policy-allow-same-ns.yaml

# Tester depuis production → production (AUTORISÉ)
kubectl run client -n production --image=busybox --rm -it --restart=Never -- \
  wget -qO- myapp-service

# Fonctionne !

# Depuis dev → production (toujours BLOQUÉ)
kubectl run client -n dev --image=busybox --rm -it --restart=Never -- \
  wget -qO- myapp-service.production --timeout=5

# Timeout
```

**Étape 4 : Autoriser le trafic depuis staging**

Créez `manifests/network-policy-allow-staging.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-staging
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: myapp  # Seulement pour l'app myapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          env: staging  # Depuis les namespaces avec label env=staging
    ports:
    - protocol: TCP
      port: 80
```

**Explications :**

**namespaceSelector** : Filtre par labels de namespace
**ports** : Autorise seulement le port 80

```bash
kubectl apply -f manifests/network-policy-allow-staging.yaml

# Tester depuis staging → production (AUTORISÉ maintenant)
kubectl run client -n staging --image=busybox --rm -it --restart=Never -- \
  wget -qO- myapp-service.production

# Fonctionne !
```

**Étape 5 : NetworkPolicy complexe (Ingress + Egress)**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  
  # Trafic ENTRANT
  ingress:
  # Depuis le frontend
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
  
  # Depuis staging
  - from:
    - namespaceSelector:
        matchLabels:
          env: staging
  
  # Trafic SORTANT
  egress:
  # Vers la base de données
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  
  # Vers le DNS (obligatoire pour la résolution)
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

**Cette policy permet :**
- **Ingress** : frontend + staging
- **Egress** : database + DNS
- **Tout le reste est bloqué**

---

## Bonnes pratiques

### Stratégie de nommage

**Par environnement (simple) :**
```
dev
staging
production
```

**Par équipe (isolation équipe) :**
```
team-platform
team-backend
team-frontend
```

**Combinaison (recommandé) :**
```
team-platform-dev
team-platform-prod
projecta-staging
projectb-production
```

### Sécurité

**1. Toujours définir des NetworkPolicies en production**

```yaml
# Deny all par défaut
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**2. Quotas sur tous les namespaces**

**3. LimitRange pour les valeurs par défaut**

**4. Labels cohérents pour RBAC**
```yaml
labels:
  env: production
  team: platform
  critical: "true"
  compliance: "pci-dss"
```

### Gestion

**1. Un namespace par environnement**

**2. Dupliquer les ressources entre environnements**
```bash
# Export depuis dev
kubectl get deployment myapp -n dev -o yaml > myapp.yaml

# Modifier le namespace
sed -i 's/namespace: dev/namespace: staging/' myapp.yaml

# Import dans staging
kubectl apply -f myapp.yaml
```

**3. Utiliser des outils de templating**
- **Helm** : Gestionnaire de packages
- **Kustomize** : Gestion de configurations
- **Jsonnet** : Templating

---

## Commandes de référence rapide

```bash
# Namespaces
kubectl get namespaces
kubectl get ns --show-labels
kubectl create namespace <n>
kubectl delete namespace <n>
kubectl describe namespace <n>

# Utiliser un namespace
kubectl get pods -n <n>
kubectl apply -f file.yaml -n <n>
kubectl config set-context --current --namespace=<n>

# Tous les namespaces
kubectl get pods --all-namespaces
kubectl get pods -A

# Quotas
kubectl get resourcequota -n <n>
kubectl describe resourcequota <n> -n <n>

# LimitRanges
kubectl get limitrange -n <n>
kubectl describe limitrange <n> -n <n>

# NetworkPolicies
kubectl get networkpolicy -n <n>
kubectl describe networkpolicy <n> -n <n>

# Supprimer tout dans un namespace
kubectl delete all --all -n <n>
```

---

## Points clés à retenir

1. **Namespaces = isolation logique** : Pas physique
2. **default != production** : Toujours créer des namespaces dédiés
3. **DNS inter-namespace** : `service.namespace.svc.cluster.local`
4. **Quotas essentiels** : Évitent la monopolisation
5. **NetworkPolicy optionnel** : Mais recommandé en production
6. **Labels cohérents** : Facilitent la gestion

