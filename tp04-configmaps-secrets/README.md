# TP04 - ConfigMaps et Secrets

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Séparer la configuration du code avec ConfigMaps
- Sécuriser les données sensibles avec Secrets
- Injecter la configuration dans les Pods de différentes manières
- Mettre à jour la configuration sans redéployer
- Appliquer les bonnes pratiques de gestion des secrets

## Concepts clés

### Pourquoi séparer la configuration ?

**Principe des 12 facteurs :**
- Le code est identique dans tous les environnements
- Seule la configuration change (dev/staging/prod)
- Pas de secrets dans le code

**Sans ConfigMap/Secret :**
```yaml
containers:
- name: app
  image: monapp:v1
  env:
  - name: DATABASE_HOST
    value: "prod-db.example.com"  # Codé en dur !
```

**Problème :** Il faut une image différente par environnement.

**Avec ConfigMap/Secret :**
```yaml
containers:
- name: app
  image: monapp:v1  # Même image partout
  env:
  - name: DATABASE_HOST
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: db_host
```

### ConfigMap vs Secret

**ConfigMap :**
- Configuration non sensible
- Variables d'environnement
- Fichiers de configuration
- Stockage en clair

**Secret :**
- Données sensibles (mots de passe, tokens, clés)
- Encodé en base64
- Peut être chiffré au repos
- Accès limité via RBAC

**Important :** base64 n'est PAS du chiffrement, juste de l'encodage !

---

## Exercice 1 - Créer et utiliser un ConfigMap

### Objectif
Créer un ConfigMap et l'utiliser dans un Pod via des variables d'environnement.

### Instructions détaillées

**Étape 1 : Créer un ConfigMap via YAML**

Créez `manifests/app-config.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Clés-valeurs simples
  APP_NAME: "MonApplication"
  APP_ENV: "production"
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
  
  # Peut aussi contenir des fichiers entiers
  app.properties: |
    database.pool.size=10
    cache.enabled=true
    cache.ttl=300
    feature.new_ui=true
```

**Explications :**

**data :** Dictionnaire de paires clé-valeur
- Clés : noms des variables
- Valeurs : toujours des chaînes (entre guillemets si nombres)

**Pipe | :** Pour du contenu multiligne (fichiers de config)

```bash
kubectl apply -f manifests/app-config.yaml
kubectl get configmap app-config
kubectl describe configmap app-config
```

**Étape 2 : Créer un ConfigMap en ligne de commande**

```bash
# Depuis des valeurs littérales
kubectl create configmap db-config \
  --from-literal=host=postgres-service \
  --from-literal=port=5432 \
  --from-literal=database=mydb

# Depuis un fichier
echo "log_level=debug" > config.txt
kubectl create configmap file-config --from-file=config.txt

# Depuis un dossier entier
mkdir configs
echo "param1=value1" > configs/config1.txt
echo "param2=value2" > configs/config2.txt
kubectl create configmap dir-config --from-file=configs/

# Voir le résultat
kubectl get configmap file-config -o yaml
```

**Étape 3 : Utiliser le ConfigMap dans un Pod (variables d'env)**

Créez `manifests/pod-with-configmap.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-config
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "App: $APP_NAME, Env: $APP_ENV, Log: $LOG_LEVEL" && sleep 3600']
    env:
    # Injecter une seule clé
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_NAME
    
    # Injecter une autre clé
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    
    # Injecter une troisième clé
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: LOG_LEVEL
```

```bash
kubectl apply -f manifests/pod-with-configmap.yaml

# Voir les logs
kubectl logs app-with-config
# Output: App: MonApplication, Env: production, Log: info

# Vérifier les variables dans le Pod
kubectl exec app-with-config -- env | grep APP

```

**Étape 4 : Injecter toutes les clés d'un coup (envFrom)**

Créez `manifests/pod-with-configmap-all.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-all-config
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'env && sleep 3600']
    envFrom:
    # Toutes les clés du ConfigMap deviennent des variables d'env
    - configMapRef:
        name: app-config
```

```bash
kubectl apply -f manifests/pod-with-configmap-all.yaml
kubectl exec app-with-all-config -- env | sort
```

**Vous verrez APP_NAME, APP_ENV, LOG_LEVEL, MAX_CONNECTIONS, etc.**

**Avantage :** Moins verbeux
**Inconvénient :** Tous les noms de clés doivent être des noms de variables valides

---

## Exercice 2 - ConfigMap comme fichier

### Objectif
Monter un ConfigMap comme un fichier dans le système de fichiers du conteneur.

### Contexte
Certaines applications lisent leur configuration depuis des fichiers (nginx.conf, application.properties, etc.)

### Instructions détaillées

**Étape 1 : Créer un ConfigMap avec un fichier de config nginx**

Créez `manifests/nginx-configmap.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  # Configuration complète de nginx
  nginx.conf: |
    events {
      worker_connections 1024;
    }
    http {
      server {
        listen 80;
        location / {
          return 200 'Hello from ConfigMap!\n';
          add_header Content-Type text/plain;
        }
        location /health {
          return 200 'OK\n';
          add_header Content-Type text/plain;
        }
      }
    }
  
  # Page HTML personnalisée
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>ConfigMap Demo</title></head>
    <body>
      <h1>Configuration chargée depuis ConfigMap</h1>
      <p>Environnement: Production</p>
    </body>
    </html>
```

```bash
kubectl apply -f manifests/nginx-configmap.yaml
```

**Étape 2 : Utiliser le ConfigMap comme volume**

Créez `manifests/nginx-with-configmap-volume.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-configured
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    # Monter le fichier nginx.conf
    - name: config-volume
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf  # Important : remplacer un fichier, pas tout le dossier
    
    # Monter index.html
    - name: config-volume
      mountPath: /usr/share/nginx/html/index.html
      subPath: index.html
  
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
```

**Explications importantes :**

**mountPath :** Où monter dans le conteneur
**subPath :** Monte seulement ce fichier (pas tout le ConfigMap)
- Sans subPath : tout le dossier est remplacé
- Avec subPath : seul le fichier spécifié est remplacé

```bash
kubectl apply -f manifests/nginx-with-configmap-volume.yaml

# Vérifier que nginx démarre bien
kubectl get pod nginx-configured

# Tester la config
kubectl exec nginx-configured -- cat /etc/nginx/nginx.conf

# Tester le serveur
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- http://nginx-configured
# Output: Hello from ConfigMap!

kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- http://nginx-configured/health
# Output: OK
```

**Étape 3 : Monter un ConfigMap comme dossier complet**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-config-dir
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'ls -la /config/ && cat /config/* && sleep 3600']
    volumeMounts:
    - name: config-volume
      mountPath: /config  # Tout le ConfigMap dans /config/
  
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
```

**Résultat :** Tous les fichiers du ConfigMap sont dans `/config/`
- `/config/nginx.conf`
- `/config/index.html`

---

## Exercice 3 - Secrets

### Objectif
Gérer des données sensibles avec Secrets.

### Contexte
Les Secrets sont similaires aux ConfigMaps mais :
- Encodés en base64
- Peuvent être chiffrés au repos (selon la config du cluster)
- Accès contrôlé par RBAC
- Ne sont pas affichés en clair dans `kubectl describe`

### Instructions détaillées

**Étape 1 : Créer un Secret via YAML**

Créez `manifests/db-secret.yaml` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque  # Type générique pour paires clé-valeur
data:
  # Valeurs encodées en base64
  username: YWRtaW4=              # "admin" en base64
  password: TW9uU3VwZXJNb3REZVBhc3Nl  # "MonSuperMotDePasse" en base64
stringData:
  # Ou utiliser stringData pour encoder automatiquement
  connection-string: "postgresql://admin:MonSuperMotDePasse@db-service:5432/mydb"
```

**Différence data vs stringData :**
- `data` : Vous devez encoder en base64 manuellement
- `stringData` : Kubernetes encode automatiquement (plus pratique !)

**Pour encoder en base64 :**
```bash
echo -n "admin" | base64
# Output: YWRtaW4=

echo -n "MonSuperMotDePasse" | base64
# Output: TW9uU3VwZXJNb3REZVBhc3Nl
```

```bash
kubectl apply -f manifests/db-secret.yaml

# Voir le Secret (valeurs masquées)
kubectl describe secret db-credentials

# Voir les données (encodées)
kubectl get secret db-credentials -o yaml

# Décoder une valeur
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
# Output: MonSuperMotDePasse
```

**Étape 2 : Créer un Secret en ligne de commande**

```bash
# Depuis des valeurs littérales
kubectl create secret generic api-key \
  --from-literal=key=sk-abc123xyz789

# Depuis un fichier (clé SSH, certificat, etc.)
echo "ma-cle-secrete" > api.key
kubectl create secret generic app-secret --from-file=api.key

# Voir le résultat
kubectl get secret api-key -o yaml
```

**Étape 3 : Utiliser un Secret dans un Pod**

Créez `manifests/pod-with-secret.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets
spec:
  containers:
  - name: app
    image: postgres:15-alpine
    env:
    # Injecter des secrets comme variables d'environnement
    - name: POSTGRES_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: connection-string
```

```bash
kubectl apply -f manifests/pod-with-secret.yaml

# Vérifier que les variables sont injectées (mais pas affichées)
kubectl exec app-with-secrets -- env | grep POSTGRES_USER
# Output: POSTGRES_USER=admin

# ATTENTION : Ne jamais logger les secrets !
kubectl logs app-with-secrets
```

**Étape 4 : Monter un Secret comme fichier**

Créez `manifests/pod-with-secret-file.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secret-file
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /secrets/username && cat /secrets/password && sleep 3600']
    volumeMounts:
    - name: secret-volume
      mountPath: /secrets
      readOnly: true  # Toujours en lecture seule !
  
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
      defaultMode: 0400  # Permissions restrictives
```

**defaultMode: 0400** = lecture seule pour le propriétaire

```bash
kubectl apply -f manifests/pod-with-secret-file.yaml

# Vérifier les fichiers
kubectl exec app-with-secret-file -- ls -la /secrets/

# Lire le contenu (décodé automatiquement)
kubectl exec app-with-secret-file -- cat /secrets/username
# Output: admin
```

---

## Exercice 4 - Application complète avec ConfigMap et Secret

### Objectif
Créer une application web qui utilise à la fois ConfigMaps et Secrets.

### Instructions détaillées

**Étape 1 : Créer toute la configuration**

Créez `manifests/complete-app.yaml` :

```yaml
# ConfigMap pour la configuration non sensible
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
data:
  APP_NAME: "My Web Application"
  APP_ENV: "production"
  LOG_LEVEL: "info"
  CACHE_ENABLED: "true"
  MAX_UPLOAD_SIZE: "10M"
  
  app-settings.json: |
    {
      "features": {
        "newUI": true,
        "analytics": true,
        "debugMode": false
      },
      "limits": {
        "requestsPerMinute": 100,
        "maxConnections": 1000
      }
    }
---
# Secret pour les données sensibles
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secret
type: Opaque
stringData:
  DB_PASSWORD: "SuperSecretPassword123"
  API_KEY: "sk-1234567890abcdef"
  JWT_SECRET: "my-super-secret-jwt-key-change-in-prod"
  
  credentials.json: |
    {
      "database": {
        "host": "db-service",
        "port": 5432,
        "username": "webapp_user",
        "password": "SuperSecretPassword123"
      },
      "redis": {
        "host": "redis-service",
        "password": "redis-secret-password"
      }
    }
---
# Deployment utilisant ConfigMap et Secret
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        
        # Variables d'environnement depuis ConfigMap
        env:
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: APP_NAME
        
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: APP_ENV
        
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: LOG_LEVEL
        
        # Variables d'environnement depuis Secret
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: webapp-secret
              key: DB_PASSWORD
        
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: webapp-secret
              key: API_KEY
        
        # Volumes montés
        volumeMounts:
        # ConfigMap comme fichiers
        - name: config-volume
          mountPath: /etc/config
          readOnly: true
        
        # Secret comme fichiers
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
      
      volumes:
      - name: config-volume
        configMap:
          name: webapp-config
      
      - name: secret-volume
        secret:
          secretName: webapp-secret
          defaultMode: 0400
---
# Service pour exposer l'application
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30100
```

```bash
kubectl apply -f manifests/complete-app.yaml

# Vérifier les ressources
kubectl get configmap webapp-config
kubectl get secret webapp-secret
kubectl get deployment webapp
kubectl get pods -l app=webapp
```

**Étape 2 : Vérifier la configuration dans le Pod**

```bash
# Obtenir le nom d'un Pod
POD_NAME=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')

# Variables d'environnement
kubectl exec $POD_NAME -- env | grep -E 'APP_|DB_|API_'

# Fichiers de configuration
kubectl exec $POD_NAME -- ls -la /etc/config/
kubectl exec $POD_NAME -- cat /etc/config/app-settings.json

# Fichiers secrets
kubectl exec $POD_NAME -- ls -la /etc/secrets/
kubectl exec $POD_NAME -- cat /etc/secrets/credentials.json
```

**Étape 3 : Tester l'application**

```bash
# Accéder à l'application
minikube service webapp-service --url

# Ou utiliser curl
curl $(minikube service webapp-service --url)
```

---

## Exercice 5 - Mise à jour de configuration

### Objectif
Comprendre comment mettre à jour la configuration sans redéployer les Pods.

### Contexte
Quand vous modifiez un ConfigMap ou Secret :
- Variables d'env : **NON mises à jour** (Pod doit redémarrer)
- Fichiers montés : **Mises à jour automatiquement** (propagation sous quelques instants)

### Instructions détaillées

**Étape 1 : Créer une config avec fichier**

Créez `manifests/config-update-test.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: update-test
data:
  config.txt: "Version 1.0"
  settings.properties: |
    version=1.0
    feature.enabled=false
---
apiVersion: v1
kind: Pod
metadata:
  name: config-reader
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do cat /config/config.txt; cat /config/settings.properties; sleep 5; done']
    volumeMounts:
    - name: config-volume
      mountPath: /config
  volumes:
  - name: config-volume
    configMap:
      name: update-test
```

```bash
kubectl apply -f manifests/config-update-test.yaml

# Observer les logs
kubectl logs config-reader -f
# Vous voyez : Version 1.0 et feature.enabled=false
```

**Étape 2 : Mettre à jour le ConfigMap**

```bash
# Éditer le ConfigMap
kubectl edit configmap update-test

# Changer :
# config.txt: "Version 1.0"
# en
# config.txt: "Version 2.0 - Updated!"

# Et
# feature.enabled=false
# en
# feature.enabled=true

# Sauvegarder et quitter
```

**Étape 3 : Observer la mise à jour automatique**

```bash
# Continuer à observer les logs
kubectl logs config-reader -f

# Les fichiers montés sont mis à jour automatiquement
# Vous verrez :
# Version 2.0 - Updated!
# feature.enabled=true
```

**La configuration a été mise à jour sans redémarrer le Pod !**

**Étape 4 : Forcer une mise à jour immédiate (variables d'env)**

Pour les variables d'environnement, il faut redémarrer les Pods :

```bash
# Méthode 1 : Rollout restart (pour Deployments)
kubectl rollout restart deployment webapp

# Méthode 2 : Supprimer les Pods (ils seront recréés)
kubectl delete pod -l app=webapp

# Méthode 3 : Modifier une annotation (force une mise à jour)
kubectl patch deployment webapp -p \
  '{"spec":{"template":{"metadata":{"annotations":{"configmap-version":"v2"}}}}}'
```

---

## Exercice 6 - Secrets pour différents types

### Objectif
Découvrir les types spécialisés de Secrets.

### Types de Secrets disponibles

**1. Opaque (générique)**
```yaml
type: Opaque
```

**2. Service Account Token**
```yaml
type: kubernetes.io/service-account-token
```

**3. Docker Registry**
```yaml
type: kubernetes.io/dockerconfigjson
```

**4. TLS**
```yaml
type: kubernetes.io/tls
```

**5. SSH Auth**
```yaml
type: kubernetes.io/ssh-auth
```

**6. Basic Auth**
```yaml
type: kubernetes.io/basic-auth
```

### Instructions détaillées

**Secret TLS (certificats SSL)**

```bash
# Générer un certificat auto-signé
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.local/O=myapp"

# Créer le Secret TLS
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key

# Voir le Secret
kubectl get secret myapp-tls -o yaml
```

**Utilisation dans un Ingress :**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
spec:
  tls:
  - hosts:
    - myapp.local
    secretName: myapp-tls  # Référence au Secret TLS
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-service
            port:
              number: 80
```

**Secret Docker Registry**

```bash
# Pour pull des images depuis un registry privé
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

**Utilisation :**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  containers:
  - name: app
    image: myregistry.com/myapp:v1
  imagePullSecrets:
  - name: regcred  # Référence au Secret
```

**Secret Basic Auth**

```bash
# Créer un fichier htpasswd (nécessite apache2-utils ou httpd-tools)
# Sur AlmaLinux :
sudo dnf install -y httpd-tools
htpasswd -c auth myuser
# Entrer le mot de passe

# Créer le Secret
kubectl create secret generic basic-auth --from-file=auth
```

---

## Bonnes pratiques

### Sécurité des Secrets

**1. Ne JAMAIS commiter des Secrets dans Git**

```bash
# Ajouter au .gitignore
echo "*secret*.yaml" >> .gitignore
echo "credentials.json" >> .gitignore
```

**2. Utiliser des outils de gestion de secrets**

- **Sealed Secrets** : Chiffrer les secrets pour Git
- **External Secrets Operator** : Synchroniser depuis un vault externe
- **HashiCorp Vault** : Gestionnaire de secrets centralisé

**3. Limiter l'accès avec RBAC**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-credentials"]  # Seulement ce secret
  verbs: ["get"]
```

**4. Activer le chiffrement au repos**

Dans la configuration du cluster (kube-apiserver) :
```yaml
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

**5. Rotation régulière**

```bash
# Créer un nouveau secret
kubectl create secret generic db-credentials-v2 --from-literal=password=NewPassword

# Mettre à jour les Deployments
kubectl set env deployment/webapp --from=secret/db-credentials-v2

# Supprimer l'ancien
kubectl delete secret db-credentials
```

### Configuration des ConfigMaps

**1. Organiser par environnement**

```yaml
# configmap-dev.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "debug"
  DATABASE_HOST: "dev-db"
---
# configmap-prod.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "warn"
  DATABASE_HOST: "prod-db"
```

**2. Versionner les ConfigMaps**

```yaml
metadata:
  name: app-config-v1  # Inclure la version dans le nom
```

**3. Utiliser des outils de templating**

- **Helm** : Gestionnaire de packages Kubernetes
- **Kustomize** : Gestion de configurations
- **Jsonnet** : Langage de templating

---

## Commandes de référence rapide

### ConfigMaps
```bash
# Créer
kubectl create configmap <name> --from-literal=key=value
kubectl create configmap <name> --from-file=file.txt
kubectl apply -f configmap.yaml

# Lister
kubectl get configmaps
kubectl get cm  # Alias

# Voir le contenu
kubectl describe configmap <name>
kubectl get configmap <name> -o yaml

# Éditer
kubectl edit configmap <name>

# Supprimer
kubectl delete configmap <name>
```

### Secrets
```bash
# Créer
kubectl create secret generic <name> --from-literal=key=value
kubectl create secret tls <name> --cert=cert.crt --key=key.key
kubectl apply -f secret.yaml

# Lister
kubectl get secrets

# Voir (masqué)
kubectl describe secret <name>

# Voir les données
kubectl get secret <name> -o yaml
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d

# Éditer
kubectl edit secret <name>

# Supprimer
kubectl delete secret <name>
```

### Debugging
```bash
# Vérifier les variables d'env dans un Pod
kubectl exec <pod> -- env

# Vérifier les fichiers montés
kubectl exec <pod> -- ls -la /config/
kubectl exec <pod> -- cat /config/file.txt

# Voir les événements
kubectl get events --sort-by=.metadata.creationTimestamp

# Logs
kubectl logs <pod> | grep CONFIG
```

---

## Points clés à retenir

1. **Séparer config et code** : Les ConfigMaps permettent la même image partout
2. **Secrets ne sont pas du chiffrement** : Base64 n'est que de l'encodage
3. **Variables vs fichiers** : Variables = statiques, Fichiers = peuvent être mis à jour
4. **Montages avec subPath** : Remplacer un fichier sans écraser tout le dossier
5. **Jamais de secrets dans Git** : Utiliser des outils de gestion dédiés
6. **RBAC pour l'accès** : Limiter qui peut lire les secrets

---

## Troubleshooting commun

### ConfigMap non trouvé
```bash
# Erreur : configmap "app-config" not found

# Vérifier qu'il existe
kubectl get configmap app-config

# Vérifier le bon namespace
kubectl get configmap app-config -n <namespace>
```

### Secret non monté
```bash
# Vérifier les événements du Pod
kubectl describe pod <pod-name>

# Vérifier que le secret existe
kubectl get secret <secret-name>

# Vérifier les permissions
kubectl auth can-i get secret/<secret-name>
```

### Mise à jour non prise en compte
```bash
# Pour les variables d'env : redémarrer les Pods
kubectl rollout restart deployment/<name>

# Pour les volumes : la mise à jour est automatique
# mais peut prendre quelques instants
```

---

## Nettoyage

```bash
# Supprimer tous les exercices
kubectl delete -f manifests/config-update-test.yaml
kubectl delete -f manifests/complete-app.yaml
kubectl delete -f manifests/pod-with-secret-file.yaml
kubectl delete -f manifests/pod-with-secret.yaml
kubectl delete -f manifests/nginx-with-configmap-volume.yaml
kubectl delete -f manifests/pod-with-configmap-all.yaml
kubectl delete -f manifests/pod-with-configmap.yaml
kubectl delete pod app-with-config-dir --ignore-not-found

# Supprimer les ConfigMaps
kubectl delete configmap app-config
kubectl delete configmap nginx-config
kubectl delete configmap db-config
kubectl delete configmap file-config
kubectl delete configmap dir-config
kubectl delete configmap update-test
kubectl delete configmap webapp-config

# Supprimer les Secrets
kubectl delete secret db-credentials
kubectl delete secret api-key
kubectl delete secret app-secret
kubectl delete secret webapp-secret
kubectl delete secret myapp-tls --ignore-not-found
kubectl delete secret regcred --ignore-not-found
kubectl delete secret basic-auth --ignore-not-found

# Nettoyer les fichiers temporaires
rm -f config.txt api.key tls.key tls.crt auth
rm -rf configs/

# Vérifier qu'il ne reste rien
kubectl get configmaps
kubectl get secrets
kubectl get pods
```

---

## Pour aller plus loin

### Outils avancés

**1. Kustomize**

Kustomize est intégré à kubectl et permet de gérer plusieurs environnements :

```bash
# Structure d'un projet avec Kustomize
project/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── configmap.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── configmap.yaml
    └── prod/
        ├── kustomization.yaml
        └── configmap.yaml

# Déployer pour dev
kubectl apply -k overlays/dev/

# Déployer pour prod
kubectl apply -k overlays/prod/
```

**2. Helm**

Helm est un gestionnaire de packages pour Kubernetes :

```bash
# Installer Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Exemple de values.yaml
config:
  appName: "MyApp"
  logLevel: "info"

secrets:
  dbPassword: "changeme"

# Installer avec Helm
helm install myapp ./mychart --values values-prod.yaml
```

**3. Sealed Secrets**

Pour chiffrer les secrets avant de les commiter dans Git :

```bash
# Installer le contrôleur Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Installer kubeseal (client)
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar xfz kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Créer un SealedSecret
kubectl create secret generic mysecret \
  --from-literal=password=mypassword \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Ce fichier peut être commité dans Git en toute sécurité
kubectl apply -f sealed-secret.yaml
```

**4. External Secrets Operator**

Pour synchroniser les secrets depuis un vault externe (AWS Secrets Manager, HashiCorp Vault, etc.) :

```bash
# Installer External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Exemple avec un SecretStore local (pour test)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.default.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: "vault-token"
          key: "token"
```

---

## Cas d'usage avancés

### 1. Configuration par environnement avec Kustomize

Créez une structure de projet :

```bash
mkdir -p kustomize-example/{base,overlays/{dev,prod}}
cd kustomize-example
```

**base/kustomization.yaml :**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

configMapGenerator:
- name: app-config
  literals:
  - APP_NAME=MyApp
  - LOG_LEVEL=info
```

**base/deployment.yaml :**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
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
        image: nginx:alpine
        envFrom:
        - configMapRef:
            name: app-config
```

**overlays/dev/kustomization.yaml :**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - LOG_LEVEL=debug
  - APP_ENV=development

replicas:
- name: myapp
  count: 1
```

**overlays/prod/kustomization.yaml :**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - LOG_LEVEL=warn
  - APP_ENV=production

replicas:
- name: myapp
  count: 3
```

**Déploiement :**
```bash
# Dev
kubectl apply -k overlays/dev/

# Prod
kubectl apply -k overlays/prod/

# Prévisualiser sans appliquer
kubectl kustomize overlays/prod/
```

### 2. Injection de secrets dans des applications

**Pour une application Node.js :**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nodejs-config
data:
  NODE_ENV: "production"
  PORT: "3000"
---
apiVersion: v1
kind: Secret
metadata:
  name: nodejs-secret
stringData:
  DATABASE_URL: "postgresql://user:pass@postgres:5432/db"
  API_SECRET: "my-secret-key"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodejs
  template:
    metadata:
      labels:
        app: nodejs
    spec:
      containers:
      - name: app
        image: node:18-alpine
        envFrom:
        - configMapRef:
            name: nodejs-config
        - secretRef:
            name: nodejs-secret
        ports:
        - containerPort: 3000
```

**Pour une application Java Spring Boot :**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: spring-config
data:
  application.properties: |
    server.port=8080
    spring.application.name=myapp
    logging.level.root=INFO
---
apiVersion: v1
kind: Secret
metadata:
  name: spring-secret
stringData:
  application-secrets.properties: |
    spring.datasource.url=jdbc:postgresql://postgres:5432/db
    spring.datasource.username=user
    spring.datasource.password=secretpass
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring
  template:
    metadata:
      labels:
        app: spring
    spec:
      containers:
      - name: app
        image: openjdk:17-jdk-slim
        volumeMounts:
        - name: config
          mountPath: /config
          readOnly: true
        env:
        - name: SPRING_CONFIG_LOCATION
          value: "file:/config/"
      volumes:
      - name: config
        projected:
          sources:
          - configMap:
              name: spring-config
          - secret:
              name: spring-secret
```

### 3. Configuration dynamique avec un ConfigMap monté

Pour des applications qui rechargent automatiquement leur configuration :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dynamic-config
data:
  config.json: |
    {
      "refreshInterval": 10,
      "features": {
        "featureA": true,
        "featureB": false
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dynamic-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dynamic
  template:
    metadata:
      labels:
        app: dynamic
      annotations:
        # Cette annotation change à chaque modification du ConfigMap
        # forçant un rollout si nécessaire
        configmap/checksum: "{{ checksum }}"
    spec:
      containers:
      - name: app
        image: busybox
        command:
        - sh
        - -c
        - |
          while true; do
            echo "Reading config at $(date)"
            cat /config/config.json
            sleep 10
          done
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: dynamic-config
```

---

## Exercices pratiques supplémentaires

### Exercice bonus 1 : Application multi-tiers

Créez une stack complète WordPress + MySQL avec configuration séparée :

```yaml
# mysql-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  MYSQL_DATABASE: wordpress
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
stringData:
  MYSQL_ROOT_PASSWORD: rootpassword
  MYSQL_PASSWORD: wordpresspassword
  MYSQL_USER: wordpress
---
# wordpress-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: wordpress-config
data:
  WORDPRESS_DB_HOST: mysql
  WORDPRESS_DB_NAME: wordpress
  WORDPRESS_DB_USER: wordpress
---
apiVersion: v1
kind: Secret
metadata:
  name: wordpress-secret
stringData:
  WORDPRESS_DB_PASSWORD: wordpresspassword
```

**Défi :** Déployez cette stack et testez que WordPress fonctionne avec la configuration injectée.

### Exercice bonus 2 : Rotation de secrets

Simulez une rotation de mot de passe de base de données :

1. Créez un secret v1
2. Déployez une application qui l'utilise
3. Créez un secret v2 avec un nouveau mot de passe
4. Mettez à jour l'application pour utiliser v2
5. Vérifiez qu'il n'y a pas d'interruption de service

### Exercice bonus 3 : Configuration par fichier

Créez une application nginx avec :
- Configuration nginx personnalisée
- Pages HTML depuis ConfigMap
- Certificats TLS depuis Secret
- Variables d'environnement pour le logging

---

## Quiz de compréhension

Testez vos connaissances :

**Question 1 :** Quelle est la différence entre `data` et `stringData` dans un Secret ?
- a) data est en base64, stringData en clair (encodage auto)
- b) Aucune différence
- c) stringData est plus sécurisé
- d) data est pour les fichiers, stringData pour les variables

**Question 2 :** Comment mettre à jour une variable d'environnement issue d'un ConfigMap sans modifier le YAML du Deployment ?
- a) kubectl edit configmap et attendre
- b) kubectl edit configmap puis kubectl rollout restart
- c) Impossible, il faut modifier le Deployment
- d) La mise à jour est automatique

**Question 3 :** Que fait `subPath` dans un volumeMount ?
- a) Monte un sous-dossier du volume
- b) Monte un fichier spécifique sans écraser le dossier parent
- c) Crée un sous-chemin dans le conteneur
- d) Définit le chemin relatif du volume

**Question 4 :** Les Secrets Kubernetes sont-ils chiffrés par défaut ?
- a) Oui, toujours
- b) Non, seulement encodés en base64
- c) Oui, mais seulement en transit
- d) Dépend de la configuration du cluster

**Question 5 :** Comment injecter toutes les clés d'un ConfigMap comme variables d'environnement ?
- a) env: avec configMapKeyRef pour chaque clé
- b) envFrom: avec configMapRef
- c) volumes: avec configMap
- d) Impossible, il faut les lister une par une

**Réponses :**
1. a) data nécessite encodage base64 manuel, stringData encode automatiquement
2. b) Modifier le ConfigMap puis forcer un redémarrage avec rollout restart
3. b) Monte un fichier spécifique du volume sans remplacer tout le dossier
4. d) Par défaut non (juste base64), mais peut être activé via encryption-provider-config
5. b) envFrom avec configMapRef injecte toutes les clés d'un coup

---

## Antisèches (Cheat Sheet)

### Création rapide

```bash
# ConfigMap depuis littéraux
kubectl create cm myconfig --from-literal=key=value

# ConfigMap depuis fichier
kubectl create cm myconfig --from-file=config.txt

# Secret depuis littéraux
kubectl create secret generic mysecret --from-literal=password=pass

# Secret TLS
kubectl create secret tls mytls --cert=tls.crt --key=tls.key

# Secret Docker
kubectl create secret docker-registry regcred \
  --docker-server=registry.io \
  --docker-username=user \
  --docker-password=pass
```

### Inspection

```bash
# Voir un ConfigMap
kubectl get cm myconfig -o yaml

# Décoder un Secret
kubectl get secret mysecret -o jsonpath='{.data.password}' | base64 -d

# Voir tous les Secrets (masqués)
kubectl get secrets

# Décrire (valeurs masquées pour secrets)
kubectl describe cm myconfig
kubectl describe secret mysecret
```

### Utilisation dans les Pods

```bash
# Variable depuis ConfigMap
env:
- name: KEY
  valueFrom:
    configMapKeyRef:
      name: myconfig
      key: key

# Toutes les clés
envFrom:
- configMapRef:
    name: myconfig

# Volume depuis ConfigMap
volumes:
- name: config
  configMap:
    name: myconfig

# Montage
volumeMounts:
- name: config
  mountPath: /config
  subPath: file.txt  # Pour un seul fichier
```

### Mise à jour

```bash
# Éditer
kubectl edit cm myconfig

# Patcher
kubectl patch cm myconfig -p '{"data":{"key":"newvalue"}}'

# Remplacer
kubectl create cm myconfig --from-literal=key=newvalue \
  --dry-run=client -o yaml | kubectl apply -f -

# Forcer le redémarrage
kubectl rollout restart deployment myapp
```

---

## Ressources complémentaires

### Documentation officielle
- ConfigMaps : https://kubernetes.io/docs/concepts/configuration/configmap/
- Secrets : https://kubernetes.io/docs/concepts/configuration/secret/
- Bonnes pratiques : https://kubernetes.io/docs/concepts/configuration/secret/#best-practices
- Kustomize : https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/

### Outils
- Sealed Secrets : https://github.com/bitnami-labs/sealed-secrets
- External Secrets : https://external-secrets.io/
- Helm : https://helm.sh/
- Kustomize : https://kustomize.io/

### Articles et tutoriels
- 12 Factor App : https://12factor.net/config
- Kubernetes Patterns : https://k8spatterns.io/

---

## Prochaine étape

Dans le TP05, vous découvrirez la **gestion des volumes et de la persistance** pour stocker des données au-delà du cycle de vie des Pods.

