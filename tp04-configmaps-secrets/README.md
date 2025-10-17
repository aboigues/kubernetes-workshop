# TP04 - ConfigMaps et Secrets

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Séparer la configuration du code avec ConfigMaps
- Sécuriser les données sensibles avec Secrets
- Injecter la configuration dans les Pods de différentes manières
- Mettre à jour la configuration sans redéployer
- Appliquer les bonnes pratiques de gestion des secrets

## Concepts clés

### éparer la configuration ?

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
  image: monapp:v1  # Mêmge partout
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

## Exercice 1 er ConfigMap

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
    database.pool.size=cache.enabled=true
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
# Depuis des valeurs littéralestl create configmap db-config \
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

**Étape : Utiliser le ConfigMap dans un Pod (variables d'env)**

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
    ame: APP_ENV
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
kubectl exec app-with-config -- env | grep A```

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
kubectl exec app-with-all-confi env | sort
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

**Étape 1 :un ConfigMap avec un fichier de config nginx**

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
          add_heer Content-Type text/plain;
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

# Tester le servectl run test --image=busybox --rm -it --restart=Never -- wget -qO- nginx-configured
# Output: Hello from ConfigMap!

kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- nginx-configured/health
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
    - ame: config-volume
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
- Peuvent être chiffrés au repos (selon la config du cluster)ès contrôlé par RBAC
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
  # Ou utiliser strencoder automatiquement
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

# Voir le Secret (valeurs masqées)
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
kubete secret generic app-secret --from-file=api.key

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
          key: uname
    
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

# ATTENTION : Ne jamais lor les secrets !
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
  - name: secrevolume
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

### Obf
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
        "newUI":        "analytics": true,
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
        "port": 542,
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
          mountPah: /etc/config
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
kubl exec $POD_NAME -- env | grep -E 'APP_|DB_|API_'

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
minikube service webapp-service
```

---

## Exercice 5 - Mise à jour de configuration

### Objectif
Comprendre comment me à jour la configuration sans redéployer les Pods.

### Contexte
Quand vous modifiez un ConfigMap ou Secret :
- Variables d'env : **NON mises à jour** (Pod doit redémarrer)
- Fichiers montés : **Mises à jour automatiquement** (après ~60s)

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
    version=ure.enabled=false
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

# Après 30-60 secondes, vous verrez :
# Version 2.0 ed!
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
kubectl patch depl-p \
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

**5. SSH Authyaml
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

**Utilisation dans un s :**
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
kubectl create secret doc-registry regcred \
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
# Créer un fichier .htpasswd
htpasswd -c auth myuser
# Entrer le mot de passe

# CrÃe Secret
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
- **HashiCorp Vault** : Gestionnaire de secrets centrisé

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
kubectl creecret generic db-credentials-v2 --from-literal=password=NewPassword

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
kubectl create confip <name> --from-file=file.txt
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
kubectl get secrets# Voir (masqué)
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
kubectl get events --soetadata.creationTimestamp

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
6pour l'accès** : Limiter qui peut lire les secrets

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
kubectl auth secret/<secret-name>
```

### Mise à jour non prise en compte
```bash
# Pour les variables d'env : redémarrer les Pods
kubectl rollout restart deployment/<name>

# Pour les volumes : attendre ~60s ou forcer
kubectl delete pod <pod-name>
```

---

## Pour aller plus loin

### Prochaine étape
Dans le TP05, vous apprendrez à gérer la **persistance des données** avec les Volumes.

### Ressources
- ConfigMaps : https://kubernetes.io/docs/concepts/configuration/configmap/
- Secrets : https://kubernetes.io/dncepts/configuration/secret/
- Best practices : https://kubernetes.io/docs/concepts/configuration/secret/#best-practices
