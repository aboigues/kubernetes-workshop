# TP03 - Services et exposition

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Comprendre le rôle des Services dans Kubernetes
- Créer et utiliser les différents types de Services
- Exposer des applications en interne et en externe
- Comprendre le DNS interne de Kubernetes
- Implémenter une architecture multi-tiers

## Concepts clés

### Pourquoi les Services ?

**Le problème sans Service :**
- Les Pods ont des IPs dynamiques (changent à chaque redémarrage)
- Impossible de se connecter de manière fiable
- Pas de load balancing entre répliques

**La solution : les Services**
- IP stable et fixe (ClusterIP)
- Nom DNS stable (myapp-service.default.svc.cluster.local)
- Load balancing automatique entre tous les Pods du selector
- Découverte de service simplifiée

### Comment fonctionne un Service ?

```
Client
  ↓
Service (IP virtuelle stable : 10.96.0.10)
  ↓
Load Balancer (kube-proxy)
  ↓
Pod 1 (10.244.0.5) ← ou → Pod 2 (10.244.0.6) ← ou → Pod 3 (10.244.0.7)
```

Le Service distribue le trafic entre tous les Pods correspondant à son selector.

### Les types de Services

**ClusterIP (défaut)**
- IP interne au cluster uniquement
- Accessible depuis les autres Pods
- Pas d'accès externe

**NodePort**
- Ouvre un port sur tous les nœuds
- Accessible depuis l'extérieur via `<NodeIP>:<NodePort>`
- Port entre 30000-32767

**LoadBalancer**
- Crée un load balancer externe (cloud provider)
- IP publique fournie par le cloud
- Non disponible dans Minikube (utilise NodePort)

**ExternalName**
- Alias DNS vers un service externe
- Exemple : base de données externe au cluster

---

## Exercice 1 - Service ClusterIP

### Objectif
Créer un Service interne pour permettre la communication entre Pods.

### Contexte
C'est le type de Service le plus courant. Il rend votre application accessible uniquement à l'intérieur du cluster.

### Instructions détaillées

**Étape 1 : Déployer une application**

Créez `manifests/backend-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f manifests/backend-deployment.yaml
kubectl get pods -l app=backend
```

**Étape 2 : Créer le Service ClusterIP**

Créez `manifests/backend-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  labels:
    app: backend
spec:
  type: ClusterIP        # Type par défaut, peut être omis
  selector:
    app: backend         # DOIT correspondre aux labels des Pods
  ports:
  - protocol: TCP
    port: 80             # Port du Service
    targetPort: 80       # Port du conteneur dans le Pod
```

**Explication des ports :**
- `port` : Port sur lequel le Service écoute
- `targetPort` : Port du conteneur (peut être différent)
- `protocol` : TCP ou UDP

**Exemple avec ports différents :**
```yaml
ports:
- port: 8080           # On accède au Service sur le port 8080
  targetPort: 80       # Qui redirige vers le port 80 du conteneur
```

```bash
kubectl apply -f manifests/backend-service.yaml
kubectl get service backend-service
```

**Sortie attendue :**
```
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
backend-service   ClusterIP   10.96.123.45    <none>        80/TCP    10s
```

**Étape 3 : Tester la connectivité**

**Méthode 1 : Depuis un Pod temporaire**

```bash
# Créer un Pod de test
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh

# Dans le shell du Pod :
wget -qO- backend-service
# Vous devriez voir le HTML de nginx

# Tester plusieurs fois pour voir le load balancing
for i in 1 2 3 4 5; do wget -qO- backend-service | grep title; done

exit
```

**Méthode 2 : Utiliser le DNS complet**

Le Service est accessible via plusieurs noms DNS :

```bash
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh

# Nom court (dans le même namespace)
wget -qO- backend-service

# Nom complet
wget -qO- backend-service.default.svc.cluster.local

# Format : <service>.<namespace>.svc.cluster.local
```

**Étape 4 : Observer les Endpoints**

Les Endpoints sont les IPs réelles des Pods derrière le Service :

```bash
# Voir les Endpoints
kubectl get endpoints backend-service

# Comparer avec les IPs des Pods
kubectl get pods -l app=backend -o wide
```

**Sortie :**
```
NAME              ENDPOINTS                                    AGE
backend-service   10.244.0.5:80,10.244.0.6:80,10.244.0.7:80   5m
```

Les IPs correspondent exactement aux Pods !

**Étape 5 : Tester le load balancing**

```bash
# Ajouter un header personnalisé pour identifier les Pods
kubectl exec -it <pod-1> -- sh -c "echo 'Pod 1' > /usr/share/nginx/html/index.html"
kubectl exec -it <pod-2> -- sh -c "echo 'Pod 2' > /usr/share/nginx/html/index.html"
kubectl exec -it <pod-3> -- sh -c "echo 'Pod 3' > /usr/share/nginx/html/index.html"

# Tester plusieurs fois
kubectl run test --image=busybox --rm -it --restart=Never -- sh -c "for i in 1 2 3 4 5 6; do wget -qO- backend-service; echo; done"
```

**Résultat attendu :** Vous verrez Pod 1, Pod 2, Pod 3 dans un ordre aléatoire.

### Questions de compréhension
1. Que se passe-t-il si un Pod est supprimé ?
2. Le Service peut-il pointer vers des Pods dans un autre namespace ?
3. Pourquoi utiliser un Service plutôt que l'IP directe d'un Pod ?

**Réponses :**
1. Les Endpoints sont mis à jour automatiquement, le Service continue de fonctionner
2. Non, le selector fonctionne uniquement dans le même namespace
3. Les IPs de Pods changent, le Service fournit une IP stable et du load balancing

---

## Exercice 2 - Service NodePort

### Objectif
Exposer une application à l'extérieur du cluster sur un port spécifique.

### Contexte
NodePort ouvre un port sur tous les nœuds du cluster, permettant l'accès externe.

### Instructions détaillées

**Étape 1 : Créer le Service NodePort**

Créez `manifests/frontend-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
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
        ports:
        - containerPort: 80
```

Créez `manifests/frontend-service-nodeport.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodeport
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80              # Port du Service (interne)
    targetPort: 80        # Port du Pod
    nodePort: 30080       # Port ouvert sur les nœuds (30000-32767)
```

**Si vous omettez nodePort**, Kubernetes en assigne un automatiquement.

```bash
kubectl apply -f manifests/frontend-deployment.yaml
kubectl apply -f manifests/frontend-service-nodeport.yaml
kubectl get service frontend-nodeport
```

**Sortie :**
```
NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend-nodeport   NodePort   10.96.234.56    <none>        80:30080/TCP   10s
```

Le format `80:30080` signifie : port Service 80 → NodePort 30080

**Étape 2 : Accéder au Service depuis l'extérieur**

**Avec Minikube :**

```bash
# Obtenir l'URL complète
minikube service frontend-nodeport --url

# Ouvrir dans le navigateur
minikube service frontend-nodeport
```

**Ou manuellement :**

```bash
# Obtenir l'IP de Minikube
minikube ip
# Exemple : 192.168.49.2

# Accéder via curl
curl http://192.168.49.2:30080
```

**Sur un cluster réel :**

```bash
# Utiliser l'IP de n'importe quel nœud
curl http://<node-ip>:30080
```

**Étape 3 : Comprendre les 3 niveaux de ports**

```
Client externe → NodePort (30080) sur n'importe quel nœud
                        ↓
                 Service (port 80)
                        ↓
                 Pod (targetPort 80)
```

**Exemple de flux :**
1. Vous accédez à `192.168.49.2:30080`
2. Le nœud redirige vers le Service sur le port 80
3. Le Service balance vers un Pod sur le port 80

**Étape 4 : Test de haute disponibilité**

```bash
# Identifier les Pods
kubectl get pods -l app=frontend -o wide

# Supprimer un Pod pendant que vous faites des requêtes
kubectl delete pod <pod-name>

# Le Service continue de fonctionner avec le Pod restant
curl http://$(minikube ip):30080
```

### Avantages et inconvénients du NodePort

**Avantages :**
- Simple à mettre en place
- Fonctionne sans cloud provider
- Utile pour le développement

**Inconvénients :**
- Ports limités (30000-32767)
- Exposition de tous les nœuds
- Pas de nom DNS automatique
- Pas idéal pour la production

**Quand l'utiliser ?**
- Développement local
- Tests
- Petits clusters sans load balancer

---

## Exercice 3 - Application multi-tiers

### Objectif
Implémenter une architecture avec frontend, backend et simulation de base de données.

### Architecture cible

```
Internet
   ↓
Frontend (NodePort 30090)
   ↓
Backend Service (ClusterIP)
   ↓
Backend Pods
   ↓
Database Service (ClusterIP)
   ↓
Database Pod
```

### Instructions détaillées

**Étape 1 : Créer la "base de données"**

Créez `manifests/multi-tier-app.yaml` :

```yaml
# Base de données (simulée avec Redis)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  labels:
    app: database
    tier: data
spec:
  replicas: 1  # Base de données = 1 seule réplique généralement
  selector:
    matchLabels:
      app: database
      tier: data
  template:
    metadata:
      labels:
        app: database
        tier: data
    spec:
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
---
# Service pour la base de données
apiVersion: v1
kind: Service
metadata:
  name: database-service
  labels:
    app: database
spec:
  type: ClusterIP  # Interne uniquement
  selector:
    app: database
    tier: data
  ports:
  - port: 6379
    targetPort: 6379
---
# Backend API
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
    tier: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
      tier: api
  template:
    metadata:
      labels:
        app: backend
        tier: api
    spec:
      containers:
      - name: api
        image: httpd:alpine
        ports:
        - containerPort: 80
        env:
        # L'application utilise cette variable pour se connecter à la DB
        - name: DATABASE_HOST
          value: database-service  # Nom du Service
        - name: DATABASE_PORT
          value: "6379"
---
# Service pour le backend
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  labels:
    app: backend
spec:
  type: ClusterIP
  selector:
    app: backend
    tier: api
  ports:
  - port: 8080
    targetPort: 80
---
# Frontend Web
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
    tier: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        # L'application utilise cette variable pour appeler le backend
        - name: BACKEND_URL
          value: http://backend-service:8080
---
# Service pour le frontend (exposé)
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  labels:
    app: frontend
spec:
  type: NodePort
  selector:
    app: frontend
    tier: web
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30090
```

**Étape 2 : Déployer l'architecture complète**

```bash
# Tout déployer d'un coup
kubectl apply -f manifests/multi-tier-app.yaml

# Vérifier les ressources créées
kubectl get deployments
kubectl get services
kubectl get pods
```

**Sortie attendue :**
```
# Deployments
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
database    1/1     1            1           30s
backend     3/3     3            3           30s
frontend    2/2     2            2           30s

# Services
NAME                TYPE        CLUSTER-IP       PORT(S)
database-service    ClusterIP   10.96.10.10      6379/TCP
backend-service     ClusterIP   10.96.20.20      8080/TCP
frontend-service    NodePort    10.96.30.30      80:30090/TCP
```

**Étape 3 : Tester la communication inter-services**

```bash
# Tester que le frontend peut joindre le backend
kubectl exec -it <frontend-pod> -- sh

# Dans le Pod frontend :
wget -qO- backend-service:8080
# Devrait fonctionner

# Tester que le backend peut joindre la database
exit
kubectl exec -it <backend-pod> -- sh

# Dans le Pod backend :
nc -zv database-service 6379
# Connection to database-service 6379 port [tcp/*] succeeded!

exit
```

**Étape 4 : Accéder à l'application depuis l'extérieur**

```bash
# Obtenir l'URL du frontend
minikube service frontend-service --url

# Ouvrir dans le navigateur
minikube service frontend-service
```

**Étape 5 : Observer le réseau avec des diagrammes**

```bash
# Voir tous les services et leurs endpoints
kubectl get services -o wide
kubectl get endpoints

# Tracer le flux complet
echo "=== Architecture déployée ==="
kubectl get all --show-labels
```

### Exercice : Tester la résilience

**Test 1 : Supprimer un Pod backend**
```bash
kubectl delete pod <bd-pod>
# Le Service continue de fonctionner avec les 2 autres Pods
```

**Test 2 : Scaler le backend**
```bash
kubectl scale deployment backend --replicas=5
# Le Service découvre automatiquement les nouveaux Pods
kubectl get endpoints backend-service
```

**Test 3 : Simuler une panne de database**
```bash
kubectl delete pod <database-pod>
# Le backend ne peut plus se connecter
# Kubernetes recrée automatiquement le Pod database
```

### Questions de compréhension
1. Pourquoi la database n'est-elle pas exée en NodePort ?
2. Comment le backend sait-il où trouver la database ?
3. Que se passe-t-il si vous renommez un Service ?

**Réponses :**
1. Sécurité : la database doit être accessible uniquement depuis le cluster
2. Via le DNS Kubernetes : database-service se résout automatiquement
3. Il faut mettre à jour les variables d'environnement dans tous les Pods qui l'utilisent

---

## Exercice 4 - DNS Kubernetes

### Objectif
Comprendre le fonctionnement du DNS interne de Kubernetes.

### Contexte
Kubertègre un serveur DNS (CoreDNS) qui :
- Crée automatiquement des entrées pour chaque Service
- Permet la résolution par nom plutôt que par IP
- Fonctionne dans tout le cluster

### Format des noms DNS

**Nom court (même namespace) :**
```
<service-name>
```

**Nom complet :**
```
<service-name>.<namespace>.svc.cluster.local
```

**Exemples :**
- `backend-service` (même namespace)
- `backend-service.default` (depuis un autre namespace)
- `backend-service.default.svc.cluster.local` (nom complet)

### Inons détaillées

**Étape 1 : Explorer le DNS**

```bash
# Créer un Pod pour tester le DNS
kubectl run dns-test --image=busybox --rm -it --restart=Never -- sh

# Dans le Pod, tester les résolutions DNS :

# Nom court
nslookup backend-service

# Nom avec namespace
nslookup backend-service.default

# Nom complet
nslookup backend-service.default.svc.cluster.local

# Voir le serveur DNS utilisé
cat /etc/resolv.conf
```

**Sortie de nslookup :**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-ssvc.cluster.local

Name:      backend-service
Address 1: 10.96.20.20 backend-service.default.svc.cluster.local
```

**Étape 2 : DNS pour les Pods**

Les Pods ont aussi des entrées DNS (optionnel) :

Format : `<pod-ip-avec-tirets>.<namespace>.pod.cluster.local`

```bash
# Obtenir l'IP d'un Pod
kubectl get pod <backend-pod> -o wide
# Exemple IP : 10.244.0.5

# Résoudre depuis un autre Pod
kubectl run dns-test --image=busybox --rm -it --restart=Never -- sh
nslookup 10-244-0-5.default.pod.cluster.local
```

tape 3 : Créer un service sans selector (ExternalName)**

Créez `manifests/external-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
```

**Utilité :** Permet de référencer un service externe (base de données hébergée) via un nom interne.

```bash
kubectl apply -f manifests/external-service.yaml

# Tester
kubectl run test --image=busybox --rm -it --restart=Never -- sh
nslookup external-db
# Retourne : db.exa
```

**Étape 4 : Communication entre namespaces**

```bash
# Créer un namespace de test
kubectl create namespace testing

# Créer un service dans ce namespace
kubectl create deployment app --image=nginx --namespace=testing
kubectl expose deployment app --port=80 --namespace=testing

# Depuis le namespace default, accéder au service
kubectl run test --image=busybox --rm -it --restart=Never -- sh
wget -qO- app.testing
```

### Résolution des problèmes DNS courants

**Problème 1 : "Could not resolve ho``bash
# Vérifier que CoreDNS fonctionne
kubectl get pods -n kube-system | grep coredns

# Vérifier les logs CoreDNS
kubectl logs -n kube-system <coredns-pod>
```

**Problème 2 : Mauvais namespace**
```bash
# Toujours utiliser le nom complet si différent namespace
wget -qO- service-name.namespace-name
```

**Problème 3 : Service sans endpoints**
```bash
# Vérifier que le Service a des Pods
kubectl get endpoints service-name
# Si vide : vérifier les selectors
```

---

## Exercice 5 - Session Affinitybjectif
Comprendre comment router le même client vers le même Pod.

### Contexte
Par défaut, le load balancing est round-robin (répartition équitable). Parfois, on veut que le même client soit toujours routé vers le même Pod (sessions, cache).

### Instructions détaillées

**Étape 1 : Service sans affinity (défaut)**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-random
spec:
  selector:
    app: myapp
  ports:
  - port: 80
  sessionAffinity: None  # Défaut
```

**Comportement :** e peut aller vers un Pod différent.

**Étape 2 : Service avec session affinity**

Créez `manifests/service-with-affinity.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-sticky
spec:
  selector:
    app: myapp
  ports:
  - port: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300  # 5 minutes
```

**Comportement :** Toutes les requêtes de la même IP client vont vers le même Pod pendant 5 minutes.

```bash
kubectl apply -f manifests/serviceaffinity.yaml

# Tester
kubectl run test --image=busybox --rm -it --restart=Never -- sh
for i in 1 2 3 4 5 6 7 8 9 10; do
  wget -qO- app-sticky
  echo "---"
done
```

**Vous verrez toujours le même Pod répondre.**

### Quand utiliser session affinity ?

**Cas d'usage :**
- Applications avec sessions en mémoire
- WebSockets qui nécessitent une connexion persistante
- Cache local dans les Pods

**Alternative moderne :** Utiliser un cache distribué (Redis, Memcached) pour partager l'état.

---

## Exerc- Headless Service

### Objectif
Comprendre les Services sans ClusterIP pour la découverte directe des Pods.

### Contexte
Un Headless Service ne crée pas d'IP de Service. Le DNS retourne directement les IPs de tous les Pods.

**Utilité :**
- Bases de données avec réplication (choisir le master ou un slave)
- Applications stateful qui ont besoin de connaître tous les Pods
- Service mesh

### Instructions détaillées

**Étape 1 : Créer un Headless Service**

Créez `manifests/headless-service.yaml` apiVersion: apps/v1
kind: Deployment
metadata:
  name: stateful-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stateful
  template:
    metadata:
      labels:
        app: stateful
    spec:
      containers:
      - name: app
        image: nginx:alpine
---
apiVersion: v1
kind: Service
metadata:
  name: stateful-service
spec:
  clusterIP: None  # Headless !
  selector:
    app: stateful
  ports:
  - port: 80
```

```bash
kubectl apply -f manifests/headless-service.yaml
kubectl get service stateful-service
```

**Sortie :**
```
NAME                TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
stateful-service    ClusterIP   None         <none>        80/TCP    10s
```

**ClusterIP = None !**

**Étape 2 : Tester la résolution DNS**

```bash
kubectl run test --image=busybox --rm -it --restart=Never -- sh

# Résoudre le service headless
nslookup stateful-service
```

**Sortie :**
```
Name:      stateful-service
Address 1: 10.244.0.10 10-244-0-10.stateful-service.default.svc.cluster.lo
Address 2: 10.244.0.11 10-244-0-11.stateful-service.default.svc.cluster.local
Address 3: 10.244.0.12 10-244-0-12.stateful-service.default.svc.cluster.local
```

**Le DNS retourne toutes les IPs des Pods !**

**Avec un Service normal (ClusterIP), vous obtenez une seule IP virtuelle.**

**Étape 3 : Accéder à un Pod spécifique**

Avec un Headless Service, chaque Pod a un nom DNS prévisible :

Format : `<pod-name>.<service-name>.<namespace>.svc.cluster.local`

```bash
# Lister les Pods
kubectl get pods -lstateful

# Accéder à un Pod spécifique
kubectl run test --image=busybox --rm -it --restart=Never -- sh
wget -qO- stateful-app-xxx.stateful-service.default.svc.cluster.local
```

### Cas d'usage réels

**Base de données PostgreSQL avec réplication :**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
```

**Application cliente :**
- Écritures → `postgres-master-0.postgres`
- Lectures → `postgres-replica-0.u `postgres-replica-1.postgres`

---

## Commandes de référence rapide

### Gestion des Services
```bash
# Créer un Service
kubectl expose deployment nginx --port=80 --type=ClusterIP
kubectl expose deployment nginx --port=80 --type=NodePort --name=nginx-np

# Lister
kubectl get services
kubectl get svc nginx -o yaml

# Décrire
kubectl describe service nginx

# Voir les endpoints
kubectl get endpoints nginx

# Supprimer
kubectl delete service nginx
```

### Accès aux Services
```bash
# Via Minikube (Nod)
minikube service <service-name>
minikube service <service-name> --url

# Port forwarding (pour ClusterIP)
kubectl port-forward service/nginx 8080:80
# Accès via localhost:8080

# Depuis un Pod temporaire
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- service-name
```

### DNS et debugging
```bash
# Tester le DNS
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup service-name

# Tracer le réseau
kubectl run netshoot --image=nicolaka/netshoot --rm -it --resta=Never -- bash
# Puis utiliser : curl, dig, ping, traceroute, etc.

# Voir les événements réseau
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## Points clés à retenir

1. **Service = abstraction réseau stable** : IP et DNS fixes pour un ensemble de Pods
2. **ClusterIP pour l'interne** : Communication inter-services dans le cluster
3. **NodePort pour l'externe (dev)** : Exposition simple pour tests et développement
4. **DNS automatique** : Utilisez les noms de Service plutôt que
5. **Selector = lien** : Le selector du Service doit matcher les labels des Pods
6. **Endpoints dynamiques** : Automatiquement mis à jour quand les Pods changent

---

## Troubleshooting commun

### Service ne fonctionne pas

**Vérifications :**
```bash
# 1. Le Service existe ?
kubectl get service <name>

# 2. Des Pods matchent le selector ?
kubectl get pods -l <selector>

# 3. Des endpoints existent ?
kubectl get endpoints <service-name>
# Si vide : problème de selector

# 4. Les Pods sont Ready ?
kube get pods -l <selector>
# Si pas Ready : problème de readiness probe

# 5. Le port est correct ?
kubectl describe service <name>
# Vérifier port vs targetPort

# 6. DNS fonctionne ?
kubectl run test --image=busybox --rm -it -- nslookup <service-name>
```

### Impossible d'accéder à un NodePort

```bash
# 1. Le Service est bien de type NodePort ?
kubectl get service <name>

# 2. Firewall bloque le port ?
# Sur Minikube, utiliser : minikube service <name>

# 3. Le bon port ?
kubectl get service <name>
# Rder la colonne PORT(S) : 80:30080/TCP
#                                     ^^^^^ C'est le NodePort
```

---

## Pour aller plus loin

### Prochaine étape
Dans le TP04, vous apprendrez à gérer la **configuration** avec ConfigMaps et Secrets.

### Ressources
- Documentation Services : https://kubernetes.io/docs/concepts/services-networking/service/
- DNS for Services and Pods : https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
