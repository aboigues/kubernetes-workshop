# TP02 - Deployments et ReplicaSets

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Comprendre la différence entre Pod, ReplicaSet et Deployment
- Créer et gérer des Deployments
- Effectuer des mises à jour progressives (rolling updates)
- Revenir à une version précédente (rollback)
- Scaler une application horizontalement

## Concepts clés

### La hiérarchie des ressources

```
Deployment (gère les versions)
    ↓
ReplicaSet (gère le nombre de répliques)
    ↓
Pod (exécute les conteneurs)
```

### Pourquoi ne pas utiliser directement des Pods ?

**Problèmes avec les Pods seuls :**
- Si un Pod meurt, il n'est pas recréé automatiquement
- Pas de gestion de plusieurs répliques
- Pas de mise à jour progressive
- Pas de rollback

**Solution : les Deployments**
- Gèrent automatiquement les Pods
- Maintiennent le nombre de répliques souhaité
- Permettent les mises à jour sans interruption
- Gardent l'historique des versions

### Qu'est-ce qu'un ReplicaSet ?

Le ReplicaSet est créé automatiquement par le Deployment. Son rôle :
- Maintenir un nombre spécifique de Pods identiques
- Recréer les Pods s'ils disparaissent
- Scaler automatiquement

**Important :** Vous ne créez jamais de ReplicaSet manuellement, le Deployment s'en charge.

---

## Exercice 1 - Premier Deployment

### Objectif
Créer un Deployment nginx avec plusieurs répliques et observer comment Kubernetes maintient l'état désiré.

### Instructions détaillées

**Étape 1 : Créer le fichier Deployment**

Créez `manifests/nginx-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

**Explication détaillée :**

**replicas: 3**
- Kubernetes maintiendra toujours 3 Pods actifs
- Si un Pod meurt, un nouveau est créé automatiquement

**selector.matchLabels**
- Le Deployment utilise ce sélecteur pour identifier ses Pods
- Doit correspondre aux labels du template

**template**
- C'est le "moule" utilisé pour créer les Pods
- Identique à la spec d'un Pod, mais dans le Deployment

**resources**
- `requests` : Minimum garanti pour le Pod
- `limits` : Maximum que le Pod peut utiliser
- Aide le scheduler à placer les Pods sur les nœuds

**Étape 2 : Déployer et observer**

```bash
# Créer le Deployment
kubectl apply -f manifests/nginx-deployment.yaml

# Observer la création des ressources
kubectl get deployments
kubectl get replicasets
kubectl get pods
```

**Sortie attendue :**

```
# Deployments
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
nginx   3/3     3            3           30s

# ReplicaSets
NAME               DESIRED   CURRENT   READY   AGE
nginx-5d59d67564   3         3         3       30s

# Pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-5d59d67564-abc12   1/1     Running   0          30s
nginx-5d59d67564-def34   1/1     Running   0          30s
nginx-5d59d67564-ghi56   1/1     Running   0          30s
```

**Explication des noms :**
- Deployment : `nginx` (le nom que vous avez donné)
- ReplicaSet : `nginx-5d59d67564` (deployment + hash)
- Pods : `nginx-5d59d67564-abc12` (replicaset + ID unique)

**Étape 3 : Tester l'auto-guérison**

```bash
# Supprimer un Pod manuellement
kubectl delete pod nginx-5d59d67564-abc12

# Observer immédiatement
kubectl get pods --watch
```

**Ce que vous verrez :**
- Le Pod supprimé passe en "Terminating"
- Un nouveau Pod est créé immédiatement
- Le compte reste toujours à 3 Pods

**C'est l'auto-guérison en action !**

**Étape 4 : Analyser le Deployment**

```bash
# Voir tous les détails
kubectl describe deployment nginx
```

**Points importants dans la sortie :**

**Replicas:** `3 desired | 3 updated | 3 total | 3 available`
- desired : Nombre souhaité (dans le YAML)
- updated : Nombre avec la dernière version
- total : Nombre total actuel
- available : Nombre prêts à recevoir du trafic

**Events:**
Historique de ce qui s'est passé (création du ReplicaSet, scaling, etc.)

**Étape 5 : Voir la hiérarchie**

```bash
# Le Deployment possède le ReplicaSet
kubectl get replicaset -o wide

# Le ReplicaSet possède les Pods
kubectl get pods -l app=nginx -o wide
```

### Questions de compréhension
1. Que se passe-t-il si vous supprimez le ReplicaSet ?
2. Pourquoi y a-t-il un hash dans le nom du ReplicaSet ?
3. Que fait Kubernetes si vous créez manuellement un Pod avec les mêmes labels ?

**Réponses :**
1. Le Deployment recrée immédiatement un nouveau ReplicaSet
2. Le hash permet de gérer plusieurs versions lors des mises à jour
3. Le ReplicaSet le supprime pour maintenir exactement 3 répliques

---

## Exercice 2 - Scaling manuel

### Objectif
Apprendre à adapter le nombre de répliques selon les besoins.

### Instructions détaillées

**Méthode 1 : Via kubectl scale**

```bash
# Augmenter à 5 répliques
kubectl scale deployment nginx --replicas=5

# Vérifier immédiatement
kubectl get pods -l app=nginx --watch
```

**Ce que vous verrez :**
- 2 nouveaux Pods sont créés
- Ils passent par : Pending → ContainerCreating → Running

**Méthode 2 : Modifier le YAML**

```bash
# Éditer directement dans le cluster
kubectl edit deployment nginx

# Changer replicas: 3 en replicas: 2
# Sauvegarder et quitter

# Observer
kubectl get pods -l app=nginx
```

**Ce que vous verrez :**
- 3 Pods sont terminés pour revenir à 2
- Kubernetes choisit aléatoirement lesquels supprimer

**Méthode 3 : Mettre à jour le fichier local**

```bash
# Modifier replicas: 3 → replicas: 7 dans le fichier
vim manifests/nginx-deployment.yaml

# Réappliquer
kubectl apply -f manifests/nginx-deployment.yaml

# Vérifier
kubectl get deployment nginx
```

**Quelle méthode choisir ?**
- **kubectl scale** : Rapide pour des tests temporaires
- **kubectl edit** : Rapide mais ne met pas à jour vos fichiers locaux
- **Modifier le fichier + apply** : Méthode recommandée (Infrastructure as Code)

### Bonnes pratiques de scaling

**Quand scaler manuellement ?**
- Tests de charge
- Pic de trafic prévu (soldes, événement)
- Réduction des coûts (nuit, week-end)

**Indicateurs pour savoir combien de répliques ?**
```bash
# Voir l'utilisation actuelle des ressources
kubectl top pods -l app=nginx
```

Si les Pods sont à 80%+ de CPU/RAM → augmenter les répliques

---

## Exercice 3 - Rolling Update

### Objectif
Mettre à jour l'application sans interruption de service.

### Contexte
Une rolling update remplace progressivement les anciennes versions par les nouvelles :
1. Créer un nouveau Pod avec la nouvelle version
2. Attendre qu'il soit prêt
3. Supprimer un ancien Pod
4. Répéter jusqu'à ce que tous soient à jour

### Instructions détaillées

**Étape 1 : Vérifier la version actuelle**

```bash
# Voir l'image utilisée
kubectl describe deployment nginx | grep Image
# Devrait afficher : nginx:1.21
```

**Étape 2 : Mettre à jour l'image (méthode rapide)**

```bash
# Mettre à jour vers nginx 1.22
kubectl set image deployment/nginx nginx=nginx:1.22

# Observer le rollout en direct
kubectl rollout status deployment/nginx
```

**Ce que vous verrez :**
```
Waiting for deployment "nginx" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx" rollout to finish: 1 old replicas are pending termination...
deployment "nginx" successfully rolled out
```

**Étape 3 : Observer ce qui s'est passé**

```bash
# Voir les ReplicaSets
kubectl get replicasets
```

**Sortie :**
```
NAME               DESIRED   CURRENT   READY   AGE
nginx-5d59d67564   0         0         0       10m   ← Ancien (nginx:1.21)
nginx-7d8f9c6b5a   3         3         3       2m    ← Nouveau (nginx:1.22)
```

**Important :** L'ancien ReplicaSet est conservé (DESIRED=0) pour permettre le rollback.

**Étape 4 : Voir l'historique des déploiements**

```bash
# Afficher l'historique complet
kubectl rollout history deployment/nginx
```

**Sortie :**
```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

**Astuce :** Pour avoir des descriptions utiles, utilisez `--record` (obsolète) ou des annotations :

```bash
kubectl annotate deployment/nginx kubernetes.io/change-cause="Mise à jour vers nginx 1.22"
```

**Étape 5 : Voir les détails d'une révision**

```bash
# Détails de la révision 2
kubectl rollout history deployment/nginx --revision=2
```

### Contrôler la stratégie de rolling update

Modifiez votre fichier pour contrôler la mise à jour :

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max 1 Pod de plus que replicas pendant l'update
      maxUnavailable: 1   # Max 1 Pod indisponible pendant l'update
```

**Explication :**

**maxSurge: 1**
- Pendant l'update, on peut avoir 4 Pods (3 + 1)
- Permet une transition plus rapide

**maxUnavailable: 1**
- Minimum 2 Pods disponibles (3 - 1)
- Garantit la disponibilité

**Exemple avec replicas=10 :**
- `maxSurge: 2, maxUnavailable: 0` : Toujours 10 Pods dispo, jusqu'à 12 pendant l'update
- `maxSurge: 0, maxUnavailable: 2` : Minimum 8 Pods dispo, jamais plus de 10

---

## Exercice 4 - Rollback

### Objectif
Apprendre à revenir rapidement à une version précédente en cas de problème.

### Contexte
Un rollback annule la dernière mise à jour en restaurant la révision précédente. C'est crucial en production quand une nouvelle version cause des problèmes.

### Instructions détaillées

**Étape 1 : Simuler une mauvaise mise à jour**

```bash
# Mettre à jour vers une version inexistante
kubectl set image deployment/nginx nginx=nginx:version-inexistante

# Observer le problème
kubectl get pods -l app=nginx --watch
```

**Ce que vous verrez :**
- Nouveaux Pods en état "ImagePullBackOff"
- Anciens Pods toujours Running (grâce à maxUnavailable)
- Le rollout est bloqué

```bash
# Vérifier le statut
kubectl rollout status deployment/nginx
# Affiche : Waiting for deployment "nginx" rollout to finish...
```

**Étape 2 : Effectuer le rollback**

```bash
# Revenir à la révision précédente
kubectl rollout undo deployment/nginx

# Observer la restauration
kubectl rollout status deployment/nginx
```

**Étape 3 : Vérifier la version**

```bash
# Confirmer qu'on est revenu à nginx:1.22
kubectl describe deployment nginx | grep Image
```

**Étape 4 : Rollback vers une révision spécifique**

```bash
# Voir l'historique
kubectl rollout history deployment/nginx

# Revenir à la révision 1 (nginx:1.21)
kubectl rollout undo deployment/nginx --to-revision=1

# Vérifier
kubectl get pods -l app=nginx
```

### Bonnes pratiques pour les rollbacks

**Avant de faire un rollback :**
1. Vérifier les logs : `kubectl logs -l app=nginx`
2. Vérifier les événements : `kubectl get events --sort-by=.metadata.creationTimestamp`
3. Vérifier les métriques si disponibles

**Après un rollback :**
1. Analyser la cause du problème
2. Tester la nouvelle version en dev/staging
3. Documenter l'incident

### Limiter l'historique des révisions

Par défaut, Kubernetes garde 10 révisions. Pour changer :

```yaml
spec:
  revisionHistoryLimit: 5  # Garder seulement 5 révisions
```

---

## Exercice 5 - Deployment avec Health Checks

### Objectif
Comprendre comment Kubernetes détermine qu'un Pod est prêt et en bonne santé.

### Contexte

**Deux types de probes :**

**Liveness Probe :** "Le conteneur fonctionne-t-il ?"
- Si échoue → Kubernetes redémarre le conteneur
- Détecte les applications bloquées/zombies

**Readiness Probe :** "Le conteneur est-il prêt à recevoir du trafic ?"
- Si échoue → Le Pod est retiré du Service (pas de trafic)
- Ne redémarre pas le conteneur

### Instructions détaillées

**Étape 1 : Créer un Deployment avec probes**

Créez `manifests/deployment-with-probes.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: v1
    spec:
      containers:
      - name: app
        image: httpd:2.4-alpine
        ports:
        - containerPort: 80
        
        # Vérifie que l'application est vivante
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10    # Attendre 10s avant le 1er check
          periodSeconds: 5            # Vérifier toutes les 5s
          timeoutSeconds: 2           # Timeout après 2s
          failureThreshold: 3         # Redémarrer après 3 échecs
        
        # Vérifie que l'application est prête
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5      # Attendre 5s avant le 1er check
          periodSeconds: 3            # Vérifier toutes les 3s
          timeoutSeconds: 2           # Timeout après 2s
          failureThreshold: 3         # Retirer du Service après 3 échecs
        
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

**Explication détaillée :**

**initialDelaySeconds**
- Temps d'attente avant le premier check
- Laisse le temps à l'application de démarrer
- Liveness > Readiness généralement

**periodSeconds**
- Fréquence des vérifications
- Readiness peut être plus fréquent (trafic)
- Liveness moins fréquent (éviter trop de restarts)

**failureThreshold**
- Nombre d'échecs avant action
- 3 est une bonne valeur par défaut
- Évite les faux positifs (problème réseau temporaire)

**Types de probes disponibles :**

**1. HTTP GET (le plus courant)**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: Awesome
```

**2. TCP Socket**
```yaml
livenessProbe:
  tcpSocket:
    port: 3306
```

**3. Command**
```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
```

**Étape 2 : Déployer et observer**

```bash
# Déployer
kubectl apply -f manifests/deployment-with-probes.yaml

# Observer le démarrage
kubectl get pods -l app=webapp --watch
```

**Ce que vous verrez :**
```
NAME                     READY   STATUS    RESTARTS   AGE
webapp-xxx               0/1     Running   0          3s
webapp-xxx               1/1     Running   0          8s    ← Passe à Ready après les probes
```

**Étape 3 : Voir les détails des probes**

```bash
kubectl describe pod <nom-pod-webapp>
```

**Cherchez les sections :**
- **Liveness:** http-get http://:80/ delay=10s timeout=2s period=5s
- **Readiness:** http-get http://:80/ delay=5s timeout=2s period=3s

**Étape 4 : Tester la liveness probe**

```bash
# Entrer dans le conteneur
kubectl exec -it <nom-pod-webapp> -- sh

# Bloquer le serveur web
killall httpd

# Sortir et observer
exit
kubectl get pods -l app=webapp --watch
```

**Ce que vous verrez :**
- Le Pod passe en "Not Ready" (readiness échoue)
- Après 3 échecs de liveness → RESTARTS augmente
- Le conteneur est redémarré automatiquement

### Exercice : Créer une endpoint de santé personnalisée

Pour une vraie application, créez une route `/health` qui vérifie :
- Base de données accessible
- Services externes disponibles
- Espace disque suffisant

**Exemple en Python/Flask :**
```python
@app.route('/health')
def health():
    # Vérifier la DB
    try:
        db.execute('SELECT 1')
        return 'OK', 200
    except:
        return 'DB Error', 500
```

---

## Exercice 6 - Stratégies de déploiement avancées

### Objectif
Comprendre les différentes stratégies de mise à jour.

### 1. Rolling Update (par défaut)

**Avantages :**
- Pas d'interruption de service
- Retour arrière facile
- Détection progressive des problèmes

**Inconvénients :**
- Deux versions cohabitent temporairement
- Peut causer des incompatibilités

**Configuration :**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0  # Zero-downtime
```

### 2. Recreate (tout arrêter puis redémarrer)

**Quand l'utiliser ?**
- Base de données avec migration de schéma
- Application ne supportant pas plusieurs versions
- Tests locaux

**Avantages :**
- Simple
- Pas de cohabitation de versions

**Inconvénients :**
- Interruption de service (downtime)

**Configuration :**
```yaml
strategy:
  type: Recreate
```

**Exemple :**

Créez `manifests/deployment-recreate.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-recreate
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:1.21
```

**Test :**
```bash
kubectl apply -f manifests/deployment-recreate.yaml
kubectl set image deployment/app-recreate app=nginx:1.22
kubectl get pods -l app=myapp --watch
```

**Observation :** Tous les Pods sont supprimés avant que les nouveaux démarrent.

### 3. Blue/Green (avec deux Deployments)

**Concept :**
- Déployer la nouvelle version à côté de l'ancienne
- Basculer le trafic d'un coup
- Garder l'ancienne version pour rollback rapide

**Implémentation :**

```yaml
# Blue (version actuelle)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.21
---
# Green (nouvelle version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.22
---
# Service pointe vers blue initialement
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
    version: blue  # Changer en green pour basculer
  ports:
  - port: 80
```

**Basculement :**
```bash
# Basculer vers green
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback vers blue
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"blue"}}}'
```

---

## Commandes de référence rapide

### Gestion des Deployments
```bash
# Créer
kubectl create deployment nginx --image=nginx:1.21 --replicas=3
kubectl apply -f deployment.yaml

# Lister
kubectl get deployments
kubectl get deploy nginx -o yaml

# Mettre à jour
kubectl set image deployment/nginx nginx=nginx:1.22
kubectl edit deployment nginx

# Scaler
kubectl scale deployment nginx --replicas=5
kubectl autoscale deployment nginx --min=2 --max=10 --cpu-percent=80

# Supprimer
kubectl delete deployment nginx
```

### Gestion des rollouts
```bash
# Status
kubectl rollout status deployment/nginx
kubectl rollout history deployment/nginx

# Pause/Resume (pour des updates groupées)
kubectl rollout pause deployment/nginx
kubectl set image deployment/nginx nginx=nginx:1.22
kubectl set env deployment/nginx ENV=prod
kubectl rollout resume deployment/nginx

# Rollback
kubectl rollout undo deployment/nginx
kubectl rollout undo deployment/nginx --to-revision=2

# Redémarrer
kubectl rollout restart deployment/nginx
```

### Debugging
```bash
# Voir les événements
kubectl describe deployment nginx
kubectl get events --sort-by=.metadata.creationTimestamp

# Voir les ReplicaSets
kubectl get replicasets
kubectl describe rs nginx-xxx

# Logs de tous les Pods
kubectl logs -l app=nginx --all-containers=true

# Ressources utilisées
kubectl top pods -l app=nginx
```

---

## Points clés à retenir

1. **Deployment > Pod direct** : Toujours utiliser des Deployments en production
2. **Auto-guérison** : Kubernetes maintient automatiquement le nombre de répliques
3. **Rolling Update** : Mise à jour sans interruption de service
4. **Rollback facile** : Historique des révisions conservé
5. **Health Checks essentiels** : Liveness et Readiness pour la fiabilité
6. **Scaling horizontal** : Ajouter des Pods plutôt qu'augmenter leur taille

---

## Exercice de synthèse

Créez un Deployment complet avec :
- 3 répliques minimum
- Rolling update avec zero-downtime
- Liveness et Readiness probes
- Limites de ressources
- Labels appropriés
- Strategy optimisée

**Testez :**
1. Mise à jour de version
2. Suppression d'un Pod (auto-guérison)
3. Scaling à 5 répliques
4. Rollback

---

## Pour aller plus loin

### Prochaine étape
Dans le TP03, vous apprendrez à **exposer vos Deployments** avec des Services pour permettre la communication entre applications et l'accès externe.

### Ressources
- Documentation Deployments : https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- Stratégies de déploiement : https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
