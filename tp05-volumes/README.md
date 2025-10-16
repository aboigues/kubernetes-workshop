# TP05 - Volumes et persistance

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Comprendre les différents types de volumes dans Kubernetes
- Utiliser des volumes temporaires (emptyDir)
- Créer et utiliser des PersistentVolumes et PersistentVolumeClaims
- Déployer une application avec stockage persistant
- Gérer le cycle de vie des données

## Concepts clés

### Pourquoi les volumes ?

**Problème sans volumes :**
- Les conteneurs sont éphémères
- Les données disparaissent quand le Pod redémarre
- Impossible de partager des données entre conteneurs

**Solution : les volumes**
- Persistent au-delà du cycle de vie d'un conteneur
- Peuvent être partagés entre conteneurs d'un même Pod
- Différents types selon les besoins (temporaire, persistant, distant)

### Hiérarchie du stockage

```
PersistentVolume (PV)         ← Administrateur crée
       ↓
PersistentVolumeClaim (PVC)   ← Développeur demande
       ↓
Pod utilise le PVC            ← Application utilise
```

---

## Exercice 1 - emptyDir (volume temporaire)

### Objectif
Créer un volume partagé entre deux conteneurs dans le même Pod.

### Contexte
emptyDir est créé quand un Pod démarre et détruit quand le Pod est supprimé. Parfait pour :
- Cache temporaire
- Partage de données entre conteneurs
- Espace de travail temporaire

### Instructions détaillées

**Étape 1 : Pod avec emptyDir**

Créez `manifests/emptydir-pod.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-pod
  labels:
    app: volume-demo
spec:
  containers:
  # Conteneur qui écrit des données
  - name: writer
    image: busybox
    command: ['sh', '-c', 'while true; do echo "$(date): Message from writer" >> /data/log.txt; sleep 3; done']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  
  # Conteneur qui lit les données
  - name: reader
    image: busybox
    command: ['sh', '-c', 'tail -f /data/log.txt']
    volumeMounts:
    - name: shared-data
      mountPath: /data  # Même volume, même path
  
  # Volume partagé
  volumes:
  - name: shared-data
    emptyDir: {}  # Volume temporaire vide
```

**Explications :**
- Le volume `shared-data` est créé vide quand le Pod démarre
- Les deux conteneurs le montent sur `/data`
- Les modifications de l'un sont visibles par l'autre

```bash
kubectl apply -f manifests/emptydir-pod.yaml

# Voir les logs du writer
kubectl logs shared-volume-pod -c writer

# Voir les logs du reader (il lit le fichier partagé)
kubectl logs shared-volume-pod -c reader -f
```

**Étape 2 : Tester la persistance au niveau conteneur**

```bash
# Tuer le conteneur writer
kubectl exec shared-volume-pod -c writer -- killall sh

# Observer que le conteneur redémarre
kubectl get pod shared-volume-pod --watch

# Vérifier que les données sont toujours là
kubectl logs shared-volume-pod -c reader
# Les anciennes données sont préservées (le volume persiste)
```

**Étape 3 : Tester la perte de données au niveau Pod**

```bash
# Supprimer le Pod entier
kubectl delete pod shared-volume-pod

# Recréer
kubectl apply -f manifests/emptydir-pod.yaml

# Les données sont perdues (nouveau volume vide)
kubectl logs shared-volume-pod -c reader
```

**emptyDir avec RAM (plus rapide)**

```yaml
volumes:
- name: cache
  emptyDir:
    medium: Memory  # Utilise la RAM au lieu du disque
    sizeLimit: 128Mi
```

---

## Exercice 2 - hostPath (accès au système de fichiers de l'hôte)

### Objectif
Monter un répertoire du nœud dans un Pod.

### Contexte
hostPath permet d'accéder au système de fichiers du nœud. **Attention** : c'est risqué en production !

**Cas d'usage :**
- Logs système
- Configuration Docker (pour DinD)
- Développement local (Minikube)

### Instructions détaillées

**Étape 1 : Créer un dossier sur le nœud Minikube**

```bash
# SSH dans Minikube
minikube ssh

# Créer un dossier et un fichier
sudo mkdir -p /mnt/data
echo "Hello from host" | sudo tee /mnt/data/hostfile.txt

# Sortir
exit
```

**Étape 2 : Créer un Pod qui utilise hostPath**

Créez `manifests/hostpath-pod.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: host-volume
      mountPath: /usr/share/nginx/html
  
  volumes:
  - name: host-volume
    hostPath:
      path: /mnt/data
      type: DirectoryOrCreate  # Crée si n'existe pas
```

**Types de hostPath :**
- `DirectoryOrCreate` : Crée un dossier s'il n'existe pas
- `Directory` : Doit être un dossier existant (erreur sinon)
- `FileOrCreate` : Crée un fichier s'il n'existe pas
- `File` : Doit être un fichier existant

```bash
kubectl apply -f manifests/hostpath-pod.yaml

# Tester nginx
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- hostpath-pod
# Output: Hello from host
```

**Étape 3 : Modifier le fichier et observer**

```bash
# Modifier le fichier sur l'hôte
minikube ssh
echo "Updated content" | sudo tee /mnt/data/hostfile.txt
exit

# Vérifier dans le Pod
kubectl exec hostpath-pod -- cat /usr/share/nginx/html/hostfile.txt
# Output: Updated content
```

**Attention avec hostPath :**
- Lié à un nœud spécifique (si le Pod change de nœud, données différentes)
- Risque de sécurité (accès au système de fichiers)
- Non portable entre clusters

---

## Exercice 3 - PersistentVolume et PersistentVolumeClaim

### Objectif
Créer un stockage persistant découplé des Pods.

### Contexte
Le modèle PV/PVC sépare :
- **PV** : Administrateur provisionne le stockage
- **PVC** : Développeur demande du stockage
- **Pod** : Utilise le PVC

### Instructions détaillées

**Étape 1 : Créer un PersistentVolume**

Créez `manifests/pv.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:#!/bin/bash

# Script de génération des fichiers pour la formation Kubernetes avec Minikube sur AlmaLinux
# Version avec explications détaillées pour les participants

set -e

echo "=== Génération de la structure des TPs Kubernetes ==="

# Création de l'arborescence principale
mkdir -p tp01-premiers-pas/{manifests,corrections}
mkdir -p tp02-deployments/{manifests,corrections}
mkdir -p tp03-services/{manifests,corrections}
mkdir -p tp04-configmaps-secrets/{manifests,corrections}
mkdir -p tp05-volumes/{manifests,corrections}
mkdir -p tp06-ingress/{manifests,corrections}
mkdir -p tp07-namespaces/{manifests,corrections}
mkdir -p tp08-monitoring/{manifests,corrections}
mkdir -p ressources/{scripts,docs,exemples}

echo "Structure créée avec succès"

# ===== TP01 - PREMIERS PAS =====
cat > tp01-premiers-pas/README.md << 'EOF'
# TP01 - Premiers pas avec Kubernetes

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Comprendre ce qu'est un Pod et son rôle dans Kubernetes
- Créer et gérer des Pods à partir de fichiers YAML
- Observer l'état d'un Pod et consulter ses logs
- Utiliser les labels pour organiser vos ressources

## Concepts clés

### Qu'est-ce qu'un Pod ?
Un Pod est la plus petite unité déployable dans Kubernetes. C'est un groupe d'un ou plusieurs conteneurs qui :
- Partagent le même espace réseau (même IP)
- Partagent les mêmes volumes de stockage
- Sont toujours déployés ensemble sur le même nœud

### Structure d'un fichier YAML Kubernetes
Chaque ressource Kubernetes suit cette structure :
```yaml
apiVersion: v1              # Version de l'API Kubernetes
kind: Pod                   # Type de ressource
metadata:                   # Métadonnées (nom, labels, etc.)
  name: mon-pod
spec:                       # Spécification de la ressource
  containers:
  - name: mon-conteneur
    image: nginx:alpine
```

---

## Exercice 1 - Votre premier Pod

### Objectif
Créer un Pod simple contenant un serveur web nginx.

### Contexte
Nginx est un serveur web léger, parfait pour débuter. L'image `nginx:alpine` est une version minimale basée sur Alpine Linux.

### Instructions détaillées

**Étape 1 : Créer le fichier YAML**

Dans le dossier `manifests/`, créez un fichier `nginx-pod.yaml` avec ce contenu :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-simple
  labels:
    app: nginx
    env: demo
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
```

**Explication ligne par ligne :**
- `apiVersion: v1` : Pour un Pod, on utilise l'API v1
- `kind: Pod` : On déclare qu'on veut créer un Pod
- `metadata.name` : Nom unique du Pod dans le namespace
- `labels` : Étiquettes pour organiser et filtrer les ressources
- `spec.containers` : Liste des conteneurs dans le Pod
- `image` : Image Docker à utiliser
- `ports.containerPort` : Port sur lequel le conteneur écoute

**Étape 2 : Appliquer le manifeste**

```bash
# Déployer le Pod
kubectl apply -f manifests/nginx-pod.yaml

# Vérifier que le Pod est créé
kubectl get pods
```

**Ce que vous devriez voir :**
```
NAME           READY   STATUS    RESTARTS   AGE
nginx-simple   1/1     Running   0          10s
```

**Explication des colonnes :**
- `READY` : 1/1 signifie 1 conteneur prêt sur 1 total
- `STATUS` : Running = le Pod fonctionne correctement
- `RESTARTS` : Nombre de redémarrages (0 = stable)
- `AGE` : Temps depuis la création

**Étape 3 : Observer le Pod en détail**

```bash
# Voir tous les détails du Pod
kubectl describe pod nginx-simple
```

**Points importants dans la sortie :**
- **Events** : Historique de ce qui s'est passé (pull image, création conteneur, etc.)
- **Status** : État actuel du Pod
- **IP** : Adresse IP interne du Pod
- **Node** : Sur quel nœud le Pod s'exécute

**Étape 4 : Consulter les logs**

```bash
# Voir les logs du serveur nginx
kubectl logs nginx-simple

# Suivre les logs en temps réel
kubectl logs nginx-simple -f
```

**Étape 5 : Tester le serveur web**

```bash
# Créer un Pod temporaire pour tester nginx
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- nginx-simple

# Si cela fonctionne, vous verrez le HTML par défaut de nginx
```

**Explication de la commande :**
- `--rm` : Supprimer le Pod après utilisation
- `-it` : Mode interactif
- `--restart=Never` : Ne pas recréer le Pod s'il s'arrête

**Étape 6 : Nettoyer**

```bash
# Supprimer le Pod
kubectl delete pod nginx-simple

# Ou supprimer via le fichier
kubectl delete -f manifests/nginx-pod.yaml
```

### Questions de compréhension
1. Pourquoi le Pod a-t-il besoin de quelques secondes avant d'être "Running" ?
2. Que signifie un STATUS "ImagePullBackOff" ?
3. Comment filtrer les Pods ayant le label `app=nginx` ?

**Réponses :**
1. Kubernetes doit télécharger l'image, créer le conteneur, puis attendre qu'il soit prêt
2. Kubernetes n'arrive pas à télécharger l'image (nom incorrect ou réseau)
3. `kubectl get pods -l app=nginx`

---

## Exercice 2 - Pod avec plusieurs conteneurs

### Objectif
Comprendre comment plusieurs conteneurs peuvent cohabiter dans un même Pod et partager des ressources.

### Contexte
Un pattern courant est le "sidecar" : un conteneur secondaire qui aide le conteneur principal. Ici, nous allons créer un Pod où :
- Le conteneur principal est nginx qui génère des logs
- Le conteneur sidecar lit ces logs en continu

### Pourquoi plusieurs conteneurs dans un Pod ?
- Ils partagent la même IP (peuvent communiquer via localhost)
- Ils partagent les mêmes volumes (échange de fichiers)
- Ils sont déployés et scalés ensemble

### Instructions détaillées

**Étape 1 : Créer le fichier YAML**

Créez `manifests/pod-multi-containers.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-sidecar
  labels:
    app: web
spec:
  containers:
  # Conteneur principal : nginx
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  
  # Conteneur sidecar : lecteur de logs
  - name: log-reader
    image: busybox
    command: ['sh', '-c', 'tail -f /logs/access.log']
    volumeMounts:
    - name: shared-logs
      mountPath: /logs
  
  # Volume partagé entre les conteneurs
  volumes:
  - name: shared-logs
    emptyDir: {}
```

**Explications importantes :**

**volumeMounts :**
- Le conteneur nginx écrit ses logs dans `/var/log/nginx`
- Le conteneur log-reader lit ces logs depuis `/logs`
- C'est le même volume physique, juste monté à des endroits différents

**emptyDir :**
- Volume temporaire créé avec le Pod
- Partagé entre tous les conteneurs
- Supprimé quand le Pod est supprimé

**Étape 2 : Déployer et observer**

```bash
# Déployer le Pod
kubectl apply -f manifests/pod-multi-containers.yaml

# Vérifier : vous devriez voir 2/2 dans READY
kubectl get pod pod-sidecar
```

**Sortie attendue :**
```
NAME          READY   STATUS    RESTARTS   AGE
pod-sidecar   2/2     Running   0          15s
```

Le `2/2` signifie : 2 conteneurs prêts sur 2 total.

**Étape 3 : Consulter les logs de chaque conteneur**

```bash
# Logs du conteneur nginx
kubectl logs pod-sidecar -c nginx

# Logs du conteneur log-reader
kubectl logs pod-sidecar -c log-reader
```

**Important :** Avec plusieurs conteneurs, vous devez spécifier avec `-c` quel conteneur vous voulez observer.

**Étape 4 : Générer du trafic pour voir les logs**

```bash
# Générer des requêtes HTTP vers nginx
kubectl run test --image=busybox --rm -it --restart=Never -- sh -c "while true; do wget -qO- pod-sidecar; sleep 2; done"

# Dans un autre terminal, observer les logs
kubectl logs pod-sidecar -c log-reader -f
```

Vous verrez les logs d'accès s'afficher en temps réel.

**Étape 5 : Explorer le Pod**

```bash
# Entrer dans le conteneur nginx
kubectl exec -it pod-sidecar -c nginx -- sh

# Dans le shell du conteneur :
ls /var/log/nginx/
cat /var/log/nginx/access.log
exit
```

### Questions de compréhension
1. Que se passe-t-il si un des deux conteneurs crash ?
2. Les deux conteneurs ont-ils la même adresse IP ?
3. Pourquoi utiliser un volume emptyDir plutôt que d'autres types ?

**Réponses :**
1. Le Pod passe en état "Not Ready" jusqu'à ce que tous les conteneurs soient OK
2. Oui, ils partagent la même IP de Pod
3. emptyDir est simple et suffisant pour du partage temporaire entre conteneurs

---

## Exercice 3 - Labels et sélecteurs

### Objectif
Maîtriser l'organisation des ressources avec les labels et les sélecteurs.

### Contexte
Dans un cluster réel, vous aurez des dizaines ou centaines de Pods. Les labels permettent de les organiser et de les filtrer efficacement.

### Qu'est-ce qu'un label ?
- Une paire clé-valeur attachée à une ressource
- Exemples : `app=nginx`, `env=production`, `version=v1.2`
- Utilisé pour filtrer, grouper, et sélectionner des ressources

### Instructions détaillées

**Étape 1 : Créer plusieurs Pods avec différents labels**

Créez `manifests/pods-with-labels.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-prod
  labels:
    app: frontend
    env: production
    tier: web
spec:
  containers:
  - name: nginx
    image: nginx:alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend-dev
  labels:
    app: frontend
    env: development
    tier: web
spec:
  containers:
  - name: nginx
    image: nginx:alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: backend-prod
  labels:
    app: backend
    env: production
    tier: api
spec:
  containers:
  - name: httpd
    image: httpd:alpine
```

**Remarque :** Le `---` sépare plusieurs ressources dans le même fichier.

**Étape 2 : Déployer et lister**

```bash
# Déployer tous les Pods
kubectl apply -f manifests/pods-with-labels.yaml

# Lister tous les Pods avec leurs labels
kubectl get pods --show-labels
```

**Étape 3 : Filtrer avec des sélecteurs**

```bash
# Tous les Pods de production
kubectl get pods -l env=production

# Tous les Pods frontend
kubectl get pods -l app=frontend

# Pods frontend ET production
kubectl get pods -l app=frontend,env=production

# Pods qui ne sont PAS en production
kubectl get pods -l 'env!=production'

# Pods dont l'env est production OU development
kubectl get pods -l 'env in (production,development)'
```

**Étape 4 : Ajouter/Modifier des labels**

```bash
# Ajouter un label à un Pod existant
kubectl label pod frontend-dev version=v1.0

# Modifier un label existant (--overwrite obligatoire)
kubectl label pod frontend-dev version=v1.1 --overwrite

# Supprimer un label
kubectl label pod frontend-dev version-

# Vérifier
kubectl get pod frontend-dev --show-labels
```

**Étape 5 : Utiliser les labels pour des actions groupées**

```bash
# Supprimer tous les Pods de développement
kubectl delete pods -l env=development

# Attention : cette commande supprime TOUS les Pods avec ce label !
```

### Bonnes pratiques pour les labels

**Labels recommandés :**
- `app` : Nom de l'application (frontend, backend, database)
- `env` : Environnement (dev, staging, prod)
- `tier` : Couche applicative (web, api, database)
- `version` : Version de l'application (v1.0, v2.1)
- `owner` : Équipe propriétaire (team-platform, team-data)

**Exemple complet :**
```yaml
labels:
  app: ecommerce
  component: payment-service
  env: production
  version: v2.1.3
  tier: api
  team: payments
```

### Questions de compréhension
1. Quelle est la différence entre un label et une annotation ?
2. Peut-on avoir plusieurs Pods avec exactement les mêmes labels ?
3. Comment lister tous les labels uniques utilisés dans le cluster ?

**Réponses :**
1. Les labels sont pour filtrer/sélectionner, les annotations pour stocker des métadonnées (non utilisées pour la sélection)
2. Oui, c'est même très courant (réplicas d'une même application)
3. `kubectl get pods --show-labels | awk '{print $NF}' | tr ',' '\n' | sort -u`

---

## Exercice bonus - Debugging d'un Pod

### Objectif
Apprendre à diagnostiquer les problèmes courants.

### Scénarios de debugging

**Scénario 1 : Pod en CrashLoopBackOff**

Créez un Pod qui crash :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crasher
spec:
  containers:
  - name: bad-container
    image: busybox
    command: ['sh', '-c', 'exit 1']
```

**Diagnostic :**
```bash
# Observer le statut
kubectl get pod crasher

# Voir les événements
kubectl describe pod crasher

# Voir les logs (même si le conteneur a crashé)
kubectl logs crasher
kubectl logs crasher --previous  # Logs du conteneur précédent
```

**Scénario 2 : Image introuvable**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-image
spec:
  containers:
  - name: container
    image: nginx:version-inexistante
```

**Diagnostic :**
```bash
kubectl get pod bad-image
# STATUS: ImagePullBackOff ou ErrImagePull

kubectl describe pod bad-image
# Cherchez la section Events pour voir l'erreur exacte
```

**Scénario 3 : Pod lent à démarrer**

Parfois un Pod met du temps à être "Ready". C'est normal si :
- L'image est volumineuse à télécharger
- L'application met du temps à démarrer
- Des health checks sont configurés

```bash
# Suivre l'évolution en temps réel
kubectl get pod mon-pod --watch

# Voir exactement où on en est
kubectl describe pod mon-pod
```

---

## Commandes de référence rapide

### Création et suppression
```bash
kubectl apply -f fichier.yaml              # Créer ou mettre à jour
kubectl delete -f fichier.yaml             # Supprimer depuis fichier
kubectl delete pod nom-pod                 # Supprimer par nom
kubectl delete pods --all                  # Supprimer tous les Pods
```

### Consultation
```bash
kubectl get pods                           # Lister les Pods
kubectl get pods -o wide                   # Plus d'informations
kubectl get pod nom-pod -o yaml            # Voir le YAML complet
kubectl describe pod nom-pod               # Description détaillée
kubectl get pods --show-labels             # Afficher les labels
```

### Logs et debugging
```bash
kubectl logs nom-pod                       # Logs du Pod
kubectl logs nom-pod -c nom-conteneur      # Logs d'un conteneur spécifique
kubectl logs nom-pod -f                    # Suivre les logs (tail -f)
kubectl logs nom-pod --previous            # Logs du conteneur précédent
kubectl exec -it nom-pod -- sh             # Shell interactif
```

### Filtrage
```bash
kubectl get pods -l app=nginx              # Filtrer par label
kubectl get pods --field-selector status.phase=Running  # Par champ
kubectl get pods --all-namespaces          # Tous les namespaces
```

---

## Points clés à retenir

1. **Un Pod = unité de déploiement** : C'est la plus petite ressource déployable
2. **Les conteneurs d'un Pod partagent** : IP, volumes, et s'exécutent sur le même nœud
3. **Les labels organisent** : Utilisez-les systématiquement pour filtrer et gérer
4. **YAML est déclaratif** : Vous décrivez l'état souhaité, Kubernetes le réalise
5. **kubectl est votre ami** : `describe` et `logs` sont essentiels pour débugger

---

## Pour aller plus loin

### Ressources recommandées
- Documentation officielle des Pods : https://kubernetes.io/docs/concepts/workloads/pods/
- Interactive tutorial : https://kubernetes.io/docs/tutorials/kubernetes-basics/

### Prochaine étape
Dans le TP02, vous découvrirez les **Deployments**, qui gèrent automatiquement plusieurs répliques de Pods et leurs mises à jour.
