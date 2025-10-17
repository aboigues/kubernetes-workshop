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
hostPath permet d'accéder au système de fichiers du nœud. Dans un environnement Minikube, cela correspond à la machine virtuelle Minikube elle-même.

**Cas d'usage :**
- Logs système
- Développement local
- Accès à des données de la machine hôte

**Important :** hostPath est utile pour le développement avec Minikube, mais risqué en production car :
- Les données sont liées à un nœud spécifique
- Risque de sécurité (accès au système de fichiers)
- Non portable entre clusters

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

# Attendre que le Pod soit prêt
kubectl wait --for=condition=Ready pod/hostpath-pod

# Tester nginx
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- http://hostpath-pod
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
- Dans Minikube, tous les Pods sont sur le même nœud, mais ce ne serait pas le cas dans un cluster multi-nœuds
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
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/pv-data
    type: DirectoryOrCreate
```

**Explications des accessModes :**
- `ReadWriteOnce` (RWO) : Lecture/écriture par un seul nœud
- `ReadOnlyMany` (ROX) : Lecture seule par plusieurs nœuds
- `ReadWriteMany` (RWX) : Lecture/écriture par plusieurs nœuds

**Note sur Minikube :** 
- Minikube supporte principalement RWO avec hostPath
- Pour RWX, d'autres solutions comme NFS seraient nécessaires

```bash
# Créer le PV
kubectl apply -f manifests/pv.yaml

# Vérifier le PV
kubectl get pv
# STATUS devrait être "Available"
```

**Étape 2 : Créer un PersistentVolumeClaim**

Créez `manifests/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi  # On demande moins que le PV (1Gi)
```

**Important :** Le PVC demande 500Mi, le PV offre 1Gi. Kubernetes va "binder" le PVC au PV disponible.

```bash
# Créer le PVC
kubectl apply -f manifests/pvc.yaml

# Vérifier le binding
kubectl get pvc
# STATUS devrait être "Bound"

kubectl get pv
# Le PV devrait maintenant afficher STATUS "Bound" aussi
```

**Étape 3 : Utiliser le PVC dans un Pod**

Créez `manifests/pod-with-pvc.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pvc
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: storage
      mountPath: /usr/share/nginx/html
  
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: local-pvc  # Référence au PVC
```

```bash
kubectl apply -f manifests/pod-with-pvc.yaml

# Créer un fichier dans le volume
kubectl exec nginx-pvc -- sh -c 'echo "Hello from PVC" > /usr/share/nginx/html/index.html'

# Tester
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- http://nginx-pvc
# Output: Hello from PVC
```

**Étape 4 : Tester la persistance**

```bash
# Supprimer le Pod
kubectl delete pod nginx-pvc

# Recréer le Pod
kubectl apply -f manifests/pod-with-pvc.yaml

# Vérifier que les données sont toujours là
kubectl exec nginx-pvc -- cat /usr/share/nginx/html/index.html
# Output: Hello from PVC
```

**Les données persistent parce que :**
- Le PVC reste même quand le Pod est supprimé
- Le PV (et donc les données) reste tant que le PVC existe

**Étape 5 : Nettoyer**

```bash
# Ordre important pour le nettoyage !
kubectl delete pod nginx-pvc
kubectl delete pvc local-pvc
kubectl delete pv local-pv

# Vérifier
kubectl get pv,pvc
```

---

## Exercice 4 - StorageClass et provisionnement dynamique

### Objectif
Utiliser le provisionnement dynamique avec la StorageClass de Minikube.

### Contexte
Avec le provisionnement dynamique, vous n'avez plus besoin de créer manuellement les PV. La StorageClass crée automatiquement un PV quand vous créez un PVC.

### Instructions détaillées

**Étape 1 : Vérifier la StorageClass par défaut**

```bash
# Lister les StorageClass disponibles
kubectl get storageclass

# Voir les détails de la StorageClass standard
kubectl describe storageclass standard
```

**Sur Minikube, vous devriez voir :**
- `standard` : StorageClass par défaut utilisant le provisioner `k8s.io/minikube-hostpath`

**Étape 2 : Créer un PVC avec provisionnement dynamique**

Créez `manifests/pvc-dynamic.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard  # Utilise la StorageClass par défaut
  resources:
    requests:
      storage: 1Gi
```

**Note :** Pas besoin de spécifier `storageClassName` si vous voulez utiliser la classe par défaut.

```bash
# Créer le PVC
kubectl apply -f manifests/pvc-dynamic.yaml

# Observer la création automatique du PV
kubectl get pvc
kubectl get pv

# Un PV a été créé automatiquement !
```

**Étape 3 : Utiliser le PVC dans un Deployment**

Créez `manifests/deployment-with-storage.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: dynamic-pvc
```

```bash
kubectl apply -f manifests/deployment-with-storage.yaml

# Attendre que MySQL soit prêt
kubectl wait --for=condition=Ready pod -l app=mysql --timeout=120s

# Vérifier les logs
kubectl logs -l app=mysql
```

**Étape 4 : Tester la persistance des données**

```bash
# Se connecter à MySQL et créer une base de données
kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- mysql -uroot -ppassword

# Dans le shell MySQL :
# CREATE DATABASE testdb;
# USE testdb;
# CREATE TABLE users (id INT, name VARCHAR(50));
# INSERT INTO users VALUES (1, 'Alice');
# SELECT * FROM users;
# EXIT;

# Supprimer le Pod
kubectl delete pod -l app=mysql

# Attendre que le Deployment recrée le Pod
kubectl wait --for=condition=Ready pod -l app=mysql --timeout=60s

# Se reconnecter et vérifier que les données sont là
kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- mysql -uroot -ppassword -e "SELECT * FROM testdb.users;"

# Les données sont conservées !
```

**Étape 5 : Examiner où sont stockées les données**

```bash
# Trouver le chemin du volume sur le nœud Minikube
kubectl get pv -o yaml | grep "path:"

# SSH dans Minikube pour voir les fichiers
minikube ssh
sudo ls -la /tmp/hostpath-provisioner/default/dynamic-pvc
exit
```

---

## Exercice 5 - Application complète avec volumes

### Objectif
Déployer WordPress avec MySQL, chacun ayant son propre stockage persistant.

### Contexte
Architecture classique à deux tiers :
- MySQL : base de données avec stockage persistant
- WordPress : application web utilisant MySQL

### Instructions détaillées

**Étape 1 : Créer les PVCs**

Créez `manifests/wordpress-pvcs.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

```bash
kubectl apply -f manifests/wordpress-pvcs.yaml
kubectl get pvc
```

**Étape 2 : Déployer MySQL**

Créez `manifests/mysql-deployment.yaml` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
stringData:
  password: "wordpress123"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        - name: MYSQL_DATABASE
          value: wordpress
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
  clusterIP: None  # Headless service
```

```bash
kubectl apply -f manifests/mysql-deployment.yaml

# Attendre que MySQL soit prêt
kubectl wait --for=condition=Ready pod -l app=mysql --timeout=120s
```

**Étape 3 : Déployer WordPress**

Créez `manifests/wordpress-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:6.4-apache
        env:
        - name: WORDPRESS_DB_HOST
          value: mysql
        - name: WORDPRESS_DB_NAME
          value: wordpress
        - name: WORDPRESS_DB_USER
          value: root
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-data
          mountPath: /var/www/html
      volumes:
      - name: wordpress-data
        persistentVolumeClaim:
          claimName: wordpress-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
spec:
  type: NodePort
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f manifests/wordpress-deployment.yaml

# Attendre que WordPress soit prêt
kubectl wait --for=condition=Ready pod -l app=wordpress --timeout=120s
```

**Étape 4 : Accéder à WordPress**

```bash
# Obtenir l'URL de WordPress
minikube service wordpress --url

# Ouvrir l'URL dans votre navigateur
# Vous devriez voir la page d'installation de WordPress
```

**Étape 5 : Tester la persistance**

```bash
# Installer WordPress via l'interface web
# Créer quelques articles

# Supprimer les Pods
kubectl delete pod -l app=wordpress
kubectl delete pod -l app=mysql

# Attendre que les Deployments recréent les Pods
kubectl wait --for=condition=Ready pod -l app=wordpress --timeout=60s

# Rouvrir WordPress
minikube service wordpress --url

# Vos articles sont toujours là !
```

**Étape 6 : Observer les volumes**

```bash
# Voir tous les PVs et PVCs
kubectl get pv,pvc

# Voir l'utilisation du stockage
kubectl describe pvc mysql-pvc
kubectl describe pvc wordpress-pvc
```

---

## Points clés à retenir

1. **emptyDir** : Volume temporaire, parfait pour le cache ou le partage entre conteneurs d'un Pod
2. **hostPath** : Accès au système de fichiers du nœud, utile pour Minikube mais risqué en production
3. **PV/PVC** : Séparation entre provisionnement (admin) et utilisation (dev)
4. **StorageClass** : Provisionnement dynamique automatique des volumes
5. **Persistance** : Les données survivent aux redémarrages de Pods quand elles sont dans un PV

### Hiérarchie de persistance

```
emptyDir          → Durée de vie du Pod
hostPath          → Durée de vie du nœud (risqué)
PV/PVC            → Durée de vie indépendante du Pod
```

---

## Commandes de référence rapide

### Gestion des volumes

```bash
# PersistentVolumes
kubectl get pv
kubectl describe pv <nom-pv>
kubectl delete pv <nom-pv>

# PersistentVolumeClaims
kubectl get pvc
kubectl describe pvc <nom-pvc>
kubectl delete pvc <nom-pvc>

# StorageClass
kubectl get storageclass
kubectl describe storageclass standard
```

### Debugging

```bash
# Voir quel PVC est utilisé par un Pod
kubectl get pod <nom-pod> -o yaml | grep -A 5 volumes

# Voir les événements liés aux volumes
kubectl get events --sort-by='.lastTimestamp' | grep -i volume

# Vérifier l'état d'un PVC
kubectl describe pvc <nom-pvc>
```

### Minikube spécifique

```bash
# SSH dans Minikube pour voir les volumes
minikube ssh

# Voir les volumes hostpath
minikube ssh "sudo ls -la /tmp/hostpath-provisioner"
```

---

## Nettoyage complet

```bash
# Supprimer l'exercice WordPress
kubectl delete -f manifests/wordpress-deployment.yaml
kubectl delete -f manifests/mysql-deployment.yaml
kubectl delete -f manifests/wordpress-pvcs.yaml
kubectl delete secret mysql-secret

# Supprimer les autres exercices
kubectl delete -f manifests/deployment-with-storage.yaml
kubectl delete -f manifests/pvc-dynamic.yaml
kubectl delete -f manifests/emptydir-pod.yaml
kubectl delete -f manifests/hostpath-pod.yaml

# Nettoyer les volumes manuels
kubectl delete pvc local-pvc
kubectl delete pv local-pv

# Vérifier qu'il ne reste rien
kubectl get pv,pvc,pods
```

---

## Dépannage

### PVC reste en Pending

**Symptôme :** `kubectl get pvc` affiche STATUS "Pending"

**Causes possibles :**
1. Aucun PV disponible correspondant
2. StorageClass inexistante ou mal configurée
3. Pas assez d'espace sur le nœud

**Solutions :**
```bash
# Vérifier les événements
kubectl describe pvc <nom-pvc>

# Vérifier les PV disponibles
kubectl get pv

# Vérifier la StorageClass
kubectl get storageclass
```

### Pod ne peut pas monter le volume

**Symptôme :** Pod en "ContainerCreating" avec erreur de montage

**Solutions :**
```bash
# Voir les événements du Pod
kubectl describe pod <nom-pod>

# Vérifier que le PVC est bien Bound
kubectl get pvc

# Pour hostPath, vérifier que le chemin existe
minikube ssh "sudo ls -la /mnt/data"
```

### Données perdues après redémarrage

**Vérifications :**
```bash
# Le PVC existe-t-il toujours ?
kubectl get pvc

# Le PVC est-il bien utilisé par le Pod ?
kubectl describe pod <nom-pod> | grep -A 5 Volumes

# Pour hostPath, les données sont-elles sur le nœud ?
minikube ssh "sudo ls -la /mnt/pv-data"
```

---

## Pour aller plus loin

### Ressources recommandées
- Documentation officielle des volumes : https://kubernetes.io/docs/concepts/storage/volumes/
- PersistentVolumes : https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- StorageClasses : https://kubernetes.io/docs/concepts/storage/storage-classes/

### Prochaine étape
Dans le TP06, vous découvrirez **Ingress**, qui permet d'exposer vos applications HTTP/HTTPS avec un point d'entrée unique.

