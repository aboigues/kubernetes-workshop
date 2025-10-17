# TP08 - Monitoring et observabilité

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Activer et utiliser metrics-server
- Consulter les métriques des ressources (CPU, RAM)
- Configurer des probes de santé efficaces
- Mettre en place l'autoscaling horizontal (HPA)
- Comprendre et analyser les logs
- Débugger des applications en production
- Utiliser le dashboard Kubernetes

## Concepts clés

### Les trois piliers de l'observabilité

**1. Métriques** : Données numériques agrégées
- CPU, RAM, requêtes/seconde
- Trend analysis, alerting
- Exemples : Prometheus, Grafana

**2. Logs** : Événements textuels
- Que s'est-il passé ?
- Debugging, audit
- Exemples : ELK, Loki

**3. Traces** : Parcours des requêtes
- Flux de requêtes dans les microservices
- Performance, latence
- Exemples : Jaeger, Zipkin

### Métriques dans Kubernetes

**Metrics Server** : Collecte les métriques basiques
- CPU, RAM par Pod/Node
- Utilisé par HPA et `kubectl top`
- Données en mémoire (pas de stockage long terme)
- Scraping toutes les 15-60 secondes

**Prometheus** (hors scope de ce TP) : Solution complète
- Métriques applicatives personnalisées
- Alerting
- Stockage long terme avec requêtes PromQL

---

## Exercice 1 - Metrics Server

### Objectif
Activer metrics-server et consulter les métriques de ressources.

### Contexte
Metrics-server collecte les métriques CPU/RAM depuis les kubelets de chaque nœud et les expose via l'API Kubernetes. C'est la fondation du monitoring basique.

### Instructions détaillées

**Étape 1 : Activer metrics-server dans Minikube**

```bash
# Activer l'addon
minikube addons enable metrics-server

# Vérifier que c'est actif
kubectl get deployment metrics-server -n kube-system

# Attendre que metrics-server soit prêt (1-2 minutes)
kubectl get pods -n kube-system | grep metrics-server

# Vérifier que les métriques sont disponibles
kubectl top nodes
```

**Si erreur "Metrics API not available" :**
```bash
# Attendre quelques minutes puis réessayer
sleep 120
kubectl top nodes

# Vérifier les logs si problème persiste
kubectl logs -n kube-system deployment/metrics-server
```

**Sortie attendue :**
```
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
minikube   250m         12%    1500Mi          38%
```

**Étape 2 : Consulter les métriques des nœuds**

```bash
# Métriques des nœuds
kubectl top nodes
```

**Explications des colonnes :**
- **CPU(cores)** : Millicores utilisés (1000m = 1 CPU complet)
- **CPU%** : Pourcentage de la capacité totale du nœud
- **MEMORY(bytes)** : RAM utilisée en MiB ou GiB
- **MEMORY%** : Pourcentage de la RAM totale

**Étape 3 : Consulter les métriques des Pods**

```bash
# Tous les Pods du namespace par défaut
kubectl top pods

# Tous les Pods de tous les namespaces
kubectl top pods --all-namespaces

# Trier par CPU
kubectl top pods --sort-by=cpu

# Trier par mémoire
kubectl top pods --sort-by=memory

# Pods d'un namespace spécifique
kubectl top pods -n kube-system

# Avec plus de détails
kubectl top pods -n kube-system --containers
```

**Sortie exemple :**
```
NAME                     CPU(cores)   MEMORY(bytes)
myapp-5d4f8c9b7d-abc12   5m           64Mi
myapp-5d4f8c9b7d-def34   3m           58Mi
nginx-7d8f9c6b5a-xyz78   12m          128Mi
```

**Interpréter les métriques :**
- `5m` = 0.005 CPU (très peu)
- `100m` = 0.1 CPU (10% d'un core)
- `500m` = 0.5 CPU (50% d'un core)
- `1000m` = 1 CPU complet

**Étape 4 : Métriques par conteneur**

Pour les Pods multi-conteneurs :

```bash
# Voir les métriques de chaque conteneur
kubectl top pod <pod-name> --containers
```

**Sortie :**
```
POD                      NAME       CPU(cores)   MEMORY(bytes)
myapp-5d4f8c9b7d-abc12   nginx      5m           64Mi
myapp-5d4f8c9b7d-abc12   sidecar    2m           32Mi
```

**Étape 5 : Observer l'évolution en temps réel**

```bash
# Observer en continu avec watch
watch kubectl top pods

# Ou avec une boucle bash
while true; do
  clear
  date
  echo "=== Nodes ==="
  kubectl top nodes
  echo ""
  echo "=== Pods ==="
  kubectl top pods --sort-by=memory
  sleep 5
done
```

**Étape 6 : Comparer avec les requests/limits**

```bash
# Voir les ressources demandées vs utilisées
kubectl describe pod <pod-name> | grep -A 5 "Limits\|Requests"
kubectl top pod <pod-name>
```

**Exemple d'analyse :**
```
Requests: cpu=100m, memory=128Mi
Limits:   cpu=200m, memory=256Mi
Utilisation actuelle: cpu=150m, memory=180Mi

→ Le Pod utilise plus que ses requests (throttling possible)
→ Mais reste sous les limits (pas de kill)
```

---

## Exercice 2 - Health Checks (Probes)

### Objectif
Configurer des probes robustes pour la production.

### Types de Probes

**Liveness Probe** : "L'application fonctionne-t-elle ?"
- **Échec** → Kubernetes redémarre le conteneur
- **Utilité** : Détecter deadlocks, états zombies, panics

**Readiness Probe** : "L'application peut-elle recevoir du trafic ?"
- **Échec** → Retrait du Service (0/1 Ready, pas de trafic)
- **Ne redémarre PAS** le conteneur
- **Utilité** : Démarrage lent, dépendances temporairement indisponibles

**Startup Probe** : "L'application a-t-elle démarré ?"
- **Utilité** : Applications lentes à démarrer (>30s)
- Désactive liveness/readiness pendant le démarrage
- **Échec** → Redémarrage du conteneur

**Tableau comparatif :**

| Probe | Échec → Action | Use Case |
|-------|----------------|----------|
| Startup | Restart | Application lente à démarrer |
| Liveness | Restart | Application bloquée/zombie |
| Readiness | Remove from Service | Dépendance temporairement down |

### Instructions détaillées

**Étape 1 : Application avec toutes les probes**

Créez `manifests/app-with-probes.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthy-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: healthy-app
  template:
    metadata:
      labels:
        app: healthy-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        
        # Startup Probe (vérifie le démarrage)
        startupProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 0
          periodSeconds: 2
          failureThreshold: 30  # 30 * 2s = 60s max pour démarrer
          timeoutSeconds: 1
        
        # Liveness Probe (vérifie la santé)
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10      # Vérifier toutes les 10s
          timeoutSeconds: 5      # Timeout de 5s
          successThreshold: 1    # 1 succès = OK
          failureThreshold: 3    # 3 échecs consécutifs = redémarrage
        
        # Readiness Probe (vérifie si prêt)
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5       # Vérifier toutes les 5s
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3    # 3 échecs = retrait du Service
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

**Explications des paramètres :**

**initialDelaySeconds** : Attente avant le premier check
- Startup : 0 (commence immédiatement)
- Liveness : 10s (laisser le temps de démarrer)
- Readiness : 5s (peut être prêt rapidement)

**periodSeconds** : Fréquence des vérifications
- Startup : 2s (rapide pendant le démarrage)
- Liveness : 10s (pas besoin de vérifier trop souvent)
- Readiness : 5s (plus fréquent car impact sur le trafic)

**timeoutSeconds** : Délai d'attente de la réponse
- Si l'endpoint ne répond pas dans ce délai = échec

**successThreshold** : Nombre de succès pour être considéré OK
- Généralement 1 (un succès suffit)

**failureThreshold** : Nombre d'échecs avant action
- 3 est une bonne valeur (évite les faux positifs)
- Ex: 3 échecs × 10s = 30s avant redémarrage

```bash
kubectl apply -f manifests/app-with-probes.yaml

# Observer le démarrage
kubectl get pods -l app=healthy-app --watch
```

**Vous verrez :**
```
NAME                          READY   STATUS              RESTARTS   AGE
healthy-app-xxx               0/1     ContainerCreating   0          2s
healthy-app-xxx               0/1     Running             0          5s  ← Startup probe en cours
healthy-app-xxx               0/1     Running             0          8s  ← Readiness probe en cours
healthy-app-xxx               1/1     Running             0          12s ← Tout est OK !
```

**Étape 2 : Simuler une panne liveness**

```bash
# Obtenir un Pod
POD=$(kubectl get pod -l app=healthy-app -o jsonpath='{.items[0].metadata.name}')

echo "Pod sélectionné: $POD"

# Arrêter nginx (liveness va échouer)
kubectl exec $POD -- sh -c "killall nginx"

# Observer le redémarrage en temps réel
kubectl get pod $POD --watch
```

**Ce que vous verrez :**
```
NAME              READY   STATUS    RESTARTS   AGE
healthy-app-xxx   1/1     Running   0          2m   ← Avant
healthy-app-xxx   0/1     Running   0          2m   ← Readiness échoue (0/1)
                                                     (attend 30s pour 3 échecs liveness)
healthy-app-xxx   0/1     Running   1          2m30s ← RESTARTS augmente !
healthy-app-xxx   1/1     Running   1          2m40s ← Redémarré et prêt
```

**Étape par étape :**
1. Nginx tué → readiness échoue immédiatement (0/1 Ready)
2. Pod retiré du Service (pas de trafic)
3. Liveness échoue 3 fois (30 secondes)
4. Kubernetes redémarre le conteneur
5. Startup probe vérifie le démarrage
6. Readiness probe vérifie que c'est prêt
7. Pod redevient 1/1 Ready

```bash
# Vérifier les restarts
kubectl get pod $POD

# Voir les événements
kubectl describe pod $POD | grep -A 20 Events
```

**Événements typiques :**
```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Warning  Unhealthy  2m (x3 over 2m10s) kubelet            Liveness probe failed: Get "http://10.244.0.5:80/": dial tcp 10.244.0.5:80: connect: connection refused
  Normal   Killing    2m                 kubelet            Container app failed liveness probe, will be restarted
  Normal   Pulled     1m50s              kubelet            Container image "nginx:alpine" already present on machine
  Normal   Created    1m50s              kubelet            Created container app
  Normal   Started    1m50s              kubelet            Started container app
```

**Étape 3 : Types de probes**

**HTTP GET (le plus courant pour APIs/web)**
```yaml
livenessProbe:
  httpGet:
    path: /healthz      # Endpoint de santé
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: HealthCheck
```

**TCP Socket (pour services non-HTTP)**
```yaml
livenessProbe:
  tcpSocket:
    port: 5432          # PostgreSQL
  initialDelaySeconds: 15
  periodSeconds: 20
```

**Command (pour checks personnalisés)**
```yaml
livenessProbe:
  exec:
    command:
    - sh
    - -c
    - |
      if [ -f /tmp/healthy ]; then
        exit 0
      else
        exit 1
      fi
  initialDelaySeconds: 5
  periodSeconds: 10
```

**gRPC (pour services gRPC)**
```yaml
livenessProbe:
  grpc:
    port: 9090
    service: myservice.v1.HealthService
  initialDelaySeconds: 5
```

**Étape 4 : Exemple d'endpoint /health personnalisé**

En Python/Flask :
```python
from flask import Flask, jsonify
import psycopg2
import redis

app = Flask(__name__)

@app.route('/healthz')
def health():
    # Check simple - liveness
    return 'OK', 200

@app.route('/readyz')
def ready():
    # Check des dépendances - readiness
    errors = []
    
    # Vérifier la base de données
    try:
        conn = psycopg2.connect("dbname=mydb user=postgres")
        conn.close()
    except Exception as e:
        errors.append(f"Database: {str(e)}")
    
    # Vérifier Redis
    try:
        r = redis.Redis(host='redis-service')
        r.ping()
    except Exception as e:
        errors.append(f"Redis: {str(e)}")
    
    # Vérifier l'espace disque
    import shutil
    stat = shutil.disk_usage('/')
    if stat.free < 1024 * 1024 * 100:  # < 100MB
        errors.append("Low disk space")
    
    if errors:
        return jsonify({"status": "not ready", "errors": errors}), 503
    
    return jsonify({"status": "ready"}), 200
```

**En Go :**
```go
func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("OK"))
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
    // Vérifier la DB
    if err := db.Ping(); err != nil {
        http.Error(w, "Database not ready", http.StatusServiceUnavailable)
        return
    }
    
    // Vérifier Redis
    if _, err := redisClient.Ping(ctx).Result(); err != nil {
        http.Error(w, "Redis not ready", http.StatusServiceUnavailable)
        return
    }
    
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("Ready"))
}
```

---

## Exercice 3 - HorizontalPodAutoscaler (HPA)

### Objectif
Mettre en place l'autoscaling basé sur les métriques CPU.

### Contexte
HPA ajuste automatiquement le nombre de répliques d'un Deployment selon :
- **CPU** (utilisation moyenne)
- **Mémoire** (moins courant, moins stable)
- **Métriques personnalisées** (avec Prometheus)

**Formule de calcul :**
```
replicas_désiré = ceil(replicas_actuel × (métrique_actuelle / métrique_cible))
```

**Exemple :**
- Replicas actuels: 2
- CPU actuel: 80%
- CPU cible: 50%
- Calcul: ceil(2 × (80 / 50)) = ceil(3.2) = 4 replicas

### Instructions détaillées

**Étape 1 : Créer une application à scaler**

Créez `manifests/hpa-demo.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
      - name: php-apache
        image: registry.k8s.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m      # IMPORTANT : HPA se base sur les requests
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
spec:
  selector:
    app: php-apache
  ports:
  - port: 80
```

**Pourquoi requests est important ?**
HPA calcule le pourcentage d'utilisation par rapport aux `requests`, pas aux `limits`.

**Exemple :**
- requests.cpu = 200m
- Utilisation actuelle = 100m
- Pourcentage = 100 / 200 = 50%

```bash
kubectl apply -f manifests/hpa-demo.yaml

# Vérifier le déploiement
kubectl get deployment php-apache
kubectl get pods -l app=php-apache
kubectl get service php-apache
```

**Étape 2 : Créer le HPA**

**Méthode 1 : En ligne de commande (rapide)**

```bash
kubectl autoscale deployment php-apache \
  --cpu-percent=50 \
  --min=1 \
  --max=10

# Voir le HPA
kubectl get hpa
```

**Méthode 2 : Via YAML (recommandé pour production)**

Créez `manifests/hpa.yaml` :

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  # Scaler basé sur CPU
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Target: 50% des requests
  
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Attendre 5min avant scale down
      policies:
      - type: Percent
        value: 50  # Réduire max 50% des Pods à la fois
        periodSeconds: 60
      - type: Pods
        value: 2   # Ou max 2 Pods à la fois
        periodSeconds: 60
      selectPolicy: Min  # Prendre la valeur minimale (plus conservateur)
    
    scaleUp:
      stabilizationWindowSeconds: 0  # Scale up immédiat
      policies:
      - type: Percent
        value: 100  # Doubler max à la fois
        periodSeconds: 30
      - type: Pods
        value: 4    # Ou ajouter max 4 Pods à la fois
        periodSeconds: 30
      selectPolicy: Max  # Prendre la valeur maximale (plus réactif)
```

**Explications détaillées :**

**averageUtilization: 50** : Maintenir l'utilisation CPU moyenne à 50% des requests

**minReplicas/maxReplicas** : Limites du scaling
- min: Ne jamais descendre en dessous (haute disponibilité)
- max: Ne jamais dépasser (contrôle des coûts)

**behavior.scaleDown** : Contrôle le scale down
- `stabilizationWindowSeconds: 300` : Attendre 5 minutes avant de réduire
- Évite le "flapping" (oscillations up/down)
- Plus conservateur = plus stable

**behavior.scaleUp** : Contrôle le scale up
- `stabilizationWindowSeconds: 0` : Réagir immédiatement
- Permet de gérer rapidement les pics de charge
- Plus réactif = meilleure disponibilité

```bash
kubectl apply -f manifests/hpa.yaml

# Voir le HPA
kubectl get hpa php-apache-hpa
```

**Sortie initiale :**
```
NAME              REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
php-apache-hpa    Deployment/php-apache   0%/50%    1         10        1          10s
```

**Lecture :**
- **TARGETS** : `0%/50%` = utilisation actuelle / target
- **REPLICAS** : 1 (minimum atteint)

**Étape 3 : Générer de la charge**

**Terminal 1 : Observer le HPA**
```bash
# Surveillance continue
kubectl get hpa php-apache-hpa --watch
```

**Terminal 2 : Générer de la charge**
```bash
# Créer plusieurs générateurs de charge
kubectl run load-gen-1 --image=busybox --restart=Never -- \
  sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done" &

kubectl run load-gen-2 --image=busybox --restart=Never -- \
  sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done" &

kubectl run load-gen-3 --image=busybox --restart=Never -- \
  sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done" &
```

**Terminal 3 : Observer les Pods**
```bash
kubectl get pods -l app=php-apache --watch
```

**Observation dans Terminal 1 (HPA) :**

```
NAME              TARGETS   REPLICAS
php-apache-hpa    0%/50%    1          ← Début (pas de charge)
php-apache-hpa    25%/50%   1          ← Charge augmente
php-apache-hpa    87%/50%   1          ← Dépasse le target !
php-apache-hpa    87%/50%   2          ← Scale up à 2 (calcul: ceil(1 × 87/50) = 2)
php-apache-hpa    120%/50%  2          ← Toujours surchargé
php-apache-hpa    120%/50%  4          ← Scale up à 4 (calcul: ceil(2 × 120/50) = 5, mais policy limite à 4)
php-apache-hpa    65%/50%   4          ← Charge se répartit
php-apache-hpa    48%/50%   4          ← Stabilisation sous la cible
```

**Observation dans Terminal 3 (Pods) :**
```
NAME                          READY   STATUS              RESTARTS   AGE
php-apache-6d4cf5c99b-abc12   1/1     Running             0          5m
php-apache-6d4cf5c99b-def34   0/1     ContainerCreating   0          2s   ← Nouveau Pod
php-apache-6d4cf5c99b-def34   1/1     Running             0          5s
php-apache-6d4cf5c99b-ghi56   0/1     ContainerCreating   0          1s   ← Encore un
php-apache-6d4cf5c99b-jkl78   0/1     ContainerCreating   0          1s
```

**Étape 4 : Arrêter la charge et observer le scale down**

```bash
# Terminal 2 : Supprimer les générateurs
kubectl delete pod load-gen-1 load-gen-2 load-gen-3

# Terminal 1 : Observer le scale down (lent)
kubectl get hpa php-apache-hpa --watch
```

**Observation :**
```
php-apache-hpa    48%/50%   4
php-apache-hpa    0%/50%    4          ← Charge arrêtée, mais reste à 4
# ... attente 5 minutes (stabilizationWindow)
php-apache-hpa    0%/50%    2          ← Scale down à 2 (policy: max 50%)
# ... attente 5 minutes
php-apache-hpa    0%/50%    1          ← Retour au minimum
```

**Le scale down est intentionnellement lent pour éviter le flapping (yo-yo effect).**

**Étape 5 : HPA avec plusieurs métriques**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: multi-metric-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

**Comportement :** HPA scale si CPU > 70% **OU** mémoire > 80%
(prend la valeur qui demande le plus de répliques)

---

## Exercice 4 - Logs et événements

### Objectif
Maîtriser la consultation et l'analyse des logs pour le debugging.

### Instructions détaillées

**Étape 1 : Logs basiques**

```bash
# Logs d'un Pod
kubectl logs <pod-name>

# Logs en temps réel (tail -f)
kubectl logs <pod-name> -f

# Logs d'un conteneur spécifique (Pod multi-conteneurs)
kubectl logs <pod-name> -c <container-name>

# Logs du conteneur précédent (après crash)
kubectl logs <pod-name> --previous

# Dernières 100 lignes
kubectl logs <pod-name> --tail=100

# Depuis les 5 dernières minutes
kubectl logs <pod-name> --since=5m

# Depuis une heure
kubectl logs <pod-name> --since=1h

# Depuis un timestamp spécifique
kubectl logs <pod-name> --since-time=2024-01-01T00:00:00Z

# Timestamps dans les logs
kubectl logs <pod-name> --timestamps
```

**Étape 2 : Logs de plusieurs Pods**

```bash
# Tous les Pods avec le label app=myapp
kubectl logs -l app=myapp --all-containers=true

# Avec préfixe du nom de Pod
kubectl logs -l app=myapp --prefix=true

# Limiter à 10 Pods max
kubectl logs -l app=myapp --max-log-requests=10

# Follow logs de tous les Pods
kubectl logs -l app=myapp -f --max-log-requests=5
```

**Sortie avec --prefix :**
```
[pod/myapp-abc12/nginx] 192.168.1.1 - - [17/Oct/2024:10:00:00] "GET / HTTP/1.1" 200
[pod/myapp-def34/nginx] 192.168.1.2 - - [17/Oct/2024:10:00:01] "GET /api HTTP/1.1" 200
```

**Étape 3 : Événements Kubernetes**

Les événements montrent ce qui se passe au niveau du cluster.

```bash
# Tous les événements (cluster)
kubectl get events

# Triés par date (plus récent en dernier)
kubectl get events --sort-by=.metadata.creationTimestamp

# Événements d'un namespace
kubectl get events -n kube-system

# Événements d'une ressource spécifique
kubectl describe pod <pod-name> | grep -A 20 Events

# Filtrer par type
kubectl get events --field-selector type=Warning
kubectl get events --field-selector type=Normal

# Filtrer par raison
kubectl get events --field-selector reason=Failed
kubectl get events --field-selector reason=OOMKilled

# Format personnalisé
kubectl get events -o custom-columns=\
LAST:.lastTimestamp,\
TYPE:.type,\
REASON:.reason,\
OBJECT:.involvedObject.name,\
MESSAGE:.message

# Depuis les 10 dernières minutes
kubectl get events --sort-by=.metadata.creationTimestamp | grep "$(date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M')"
```

**Types d'événements courants :**
- `Scheduled` : Pod assigné à un nœud
- `Pulling` : Téléchargement de l'image
- `Pulled` : Image téléchargée
- `Created` : Conteneur créé
- `Started` : Conteneur démarré
- `Unhealthy` : Probe a échoué
- `Killing` : Conteneur en cours de terminaison
- `FailedScheduling` : Impossible de placer le Pod
- `BackOff` : CrashLoopBackOff
- `OOMKilled` : Tué pour manque de mémoire



