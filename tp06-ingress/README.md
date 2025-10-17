# TP06 - Ingress et routage HTTP

## Objectifs pédagogiques
À la fin de ce TP, vous serez capable de :
- Comprendre le rôle d'un Ingress Controller
- Créer des règles de routage HTTP basées sur les chemins
- Créer des règles de routage basées sur les hôtes
- Configurer TLS/SSL sur un Ingress
- Implémenter des redirections et rewrites
- Utiliser des annotations pour personnaliser le comportement

## Concepts clés

### Pourquoi Ingress ?

**Sans Ingress (avec NodePort) :**
- Un port différent par service (30080, 30090, etc.)
- Pas de nom de domaine
- Pas de TLS centralisé
- Configuration dispersée
- Gestion manuelle des certificats

**Avec Ingress :**
- Un seul point d'entrée (port 80/443)
- Routage par nom de domaine (app1.com, app2.com)
- Routage par chemin (/api, /admin, /static)
- TLS centralisé
- Load balancing au niveau 7 (HTTP/HTTPS)
- Headers personnalisés, redirections, rewrites

### Architecture

```
Internet
   ↓
Ingress Controller (nginx, traefik, etc.)
   ↓ (routage basé sur règles HTTP)
┌──────────────┬──────────────┬──────────────┐
│   Service A  │   Service B  │   Service C  │
└──────────────┴──────────────┴──────────────┘
       ↓              ↓              ↓
    Pods A         Pods B         Pods C
```

**Composants :**
- **Ingress** : Ressource Kubernetes qui définit les règles de routage
- **Ingress Controller** : Implémentation qui applique les règles (nginx, traefik, HAProxy, etc.)

**Analogie :** Si les Services sont des "lignes téléphoniques internes", l'Ingress est le "standard téléphonique" qui route les appels externes vers la bonne personne selon des règles.

### Prérequis : Activer l'addon Ingress

```bash
# Activer Ingress dans Minikube
minikube addons enable ingress

# Vérifier que le controller est démarré
kubectl get pods -n ingress-nginx

# Attendre que le Pod soit Running
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

**Sortie attendue :**
```
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-xxxxx       0/1     Completed   0          2m
ingress-nginx-admission-patch-xxxxx        0/1     Completed   0          2m
ingress-nginx-controller-xxxxx             1/1     Running     0          2m
```

---

## Exercice 1 - Premier Ingress (routage simple)

### Objectif
Créer un Ingress basique qui route toutes les requêtes HTTP vers un service.

### Contexte
C'est le cas d'usage le plus simple : toutes les requêtes arrivent sur une application unique.

### Instructions détaillées

**Étape 1 : Déployer une application de test**

Créez `manifests/simple-app.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

**Explications :**
- **Deployment** : 2 réplicas nginx pour la haute disponibilité
- **Service ClusterIP** : Expose le Deployment en interne
- Le Service sera la cible de notre Ingress

```bash
kubectl apply -f manifests/simple-app.yaml

# Vérifier le déploiement
kubectl get pods -l app=web
kubectl get service web-service
```

**Sortie attendue :**
```
NAME                       READY   STATUS    RESTARTS   AGE
web-app-5d4f8c9b7d-abc12   1/1     Running   0          10s
web-app-5d4f8c9b7d-def34   1/1     Running   0          10s

NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
web-service   ClusterIP   10.96.123.45    <none>        80/TCP    10s
```

**Étape 2 : Créer l'Ingress**

Créez `manifests/simple-ingress.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

**Explications détaillées :**

**apiVersion: networking.k8s.io/v1** : API standard pour les ressources Ingress

**metadata.annotations** : Métadonnées pour configurer le comportement
- `rewrite-target: /` : Réécrit l'URL avant de la passer au backend
- Les annotations sont spécifiques au controller (ici nginx)

**spec.rules** : Liste de règles de routage
- Pas de `host` spécifié = accepte toutes les requêtes (wildcard)
- `http` : Règle HTTP (peut aussi être configuré avec `https`)

**paths** : Liste de chemins à matcher
- `path: /` : Match la racine et tous les sous-chemins
- `pathType: Prefix` : Match le chemin et tout ce qui commence par ce chemin

**pathType expliqué :**
- `Prefix` : `/` match `/`, `/api`, `/admin`, etc.
- `Exact` : `/api` match uniquement `/api` (pas `/api/v1`)
- `ImplementationSpecific` : Dépend du controller

**backend** : Où router le trafic
- `service.name` : Nom du Service Kubernetes
- `service.port.number` : Port du Service

```bash
kubectl apply -f manifests/simple-ingress.yaml

# Voir l'Ingress
kubectl get ingress web-ingress
```

**Sortie attendue :**
```
NAME          CLASS   HOSTS   ADDRESS        PORTS   AGE
web-ingress   nginx   *       192.168.49.2   80      30s
```

**Explications de la sortie :**
- **CLASS** : Controller utilisé (nginx dans notre cas)
- **HOSTS** : `*` signifie "accepte toutes les requêtes"
- **ADDRESS** : IP où l'Ingress est accessible
- **PORTS** : 80 (HTTP seulement pour l'instant)

**Étape 3 : Tester l'accès**

```bash
# Obtenir l'IP de Minikube
minikube ip
# Exemple : 192.168.49.2

# Accéder à l'application via curl
curl http://$(minikube ip)/

# Vous devriez voir le HTML par défaut de nginx
```

**Ou dans le navigateur :**
```
http://192.168.49.2/
```

**Étape 4 : Observer le routage**

```bash
# Voir les détails de l'Ingress
kubectl describe ingress web-ingress
```

**Chercher la section Rules :**
```
Rules:
  Host        Path  Backends
  ----        ----  --------
  *           
              /   web-service:80 (10.244.0.5:80,10.244.0.6:80)
```

**Cette section montre :**
- **Host** : `*` = tous les hôtes
- **Path** : `/` = tous les chemins
- **Backends** : Service ciblé avec les IPs des Pods derrière

---

## Exercice 2 - Routage par chemin (path-based routing)

### Objectif
Router vers différents services selon le chemin de l'URL.

### Contexte
Le routage par chemin permet d'avoir plusieurs applications/microservices derrière un seul point d'entrée, en utilisant des chemins différents.

**Cas d'usage réels :**
- `/api` → Backend API
- `/admin` → Interface d'administration
- `/docs` → Documentation
- `/static` → Fichiers statiques

### Architecture cible
```
http://minikube-ip/app1     → Service App1
http://minikube-ip/app2     → Service App2
http://minikube-ip/api      → Service API
http://minikube-ip/admin    → Service Admin
```

### Instructions détaillées

**Étape 1 : Déployer plusieurs applications**

Créez `manifests/multi-app.yaml` :

```yaml
# Application 1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  labels:
    app: app1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo
        args:
        - "-text=Bienvenue sur Application 1"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: app1-service
spec:
  selector:
    app: app1
  ports:
  - port: 80
    targetPort: 5678
---
# Application 2
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  labels:
    app: app2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo
        args:
        - "-text=Bienvenue sur Application 2"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: app2-service
spec:
  selector:
    app: app2
  ports:
  - port: 80
    targetPort: 5678
---
# API Backend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo
        args:
        - "-text=API Backend - Version 1.0"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 5678
```

**Note :** `hashicorp/http-echo` est une image de test qui répond simplement avec le texte spécifié. Idéal pour les démos.

```bash
kubectl apply -f manifests/multi-app.yaml

# Vérifier que tout est déployé
kubectl get deployments
kubectl get services
kubectl get pods
```

**Étape 2 : Créer l'Ingress avec routage par chemin**

Créez `manifests/path-based-ingress.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - http:
      paths:
      # Route pour /app1
      - path: /app1(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: app1-service
            port:
              number: 80
      
      # Route pour /app2
      - path: /app2(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: app2-service
            port:
              number: 80
      
      # Route pour /api
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: api-service
            port:
              number: 80
```

**Explication du rewrite (très important) :**

**Pattern : `/app1(/|$)(.*)`**
- `/app1` : Le préfixe à matcher
- `(/|$)` : Soit un slash `/`, soit la fin de chaîne `$`
- `(.*)` : Capture tout ce qui suit (groupe de capture $2)

**Annotation : `rewrite-target: /$2`**
- Remplace l'URL par `/$2` (le contenu du 2ème groupe de capture)
- Cela "enlève" le préfixe avant d'envoyer au service

**Exemples de transformation :**

| URL externe                      | URL reçue par le service |
|----------------------------------|--------------------------|
| `http://ip/app1`                 | `http://app1-service/`   |
| `http://ip/app1/`                | `http://app1-service/`   |
| `http://ip/app1/page`            | `http://app1-service/page` |
| `http://ip/app1/admin/users`     | `http://app1-service/admin/users` |
| `http://ip/app2/api/v1/data`     | `http://app2-service/api/v1/data` |

**Pourquoi c'est important ?**
Sans rewrite, le service recevrait l'URL complète `/app1/page` et ne saurait probablement pas comment la gérer. Le rewrite permet au service de fonctionner normalement sans connaître son préfixe d'exposition.

```bash
kubectl apply -f manifests/path-based-ingress.yaml

# Vérifier l'Ingress
kubectl get ingress path-ingress
kubectl describe ingress path-ingress
```

**Étape 3 : Tester les différents chemins**

```bash
# Tester app1
curl http://$(minikube ip)/app1
# Output: Bienvenue sur Application 1

# Tester app2
curl http://$(minikube ip)/app2
# Output: Bienvenue sur Application 2

# Tester l'API
curl http://$(minikube ip)/api
# Output: API Backend - Version 1.0

# Tester avec un sous-chemin
curl http://$(minikube ip)/app1/quelquechose
# Output: Bienvenue sur Application 1

# Tester avec un chemin invalide
curl http://$(minikube ip)/inexistant
# Output: 404 Not Found (pas de règle pour ce chemin)
```

**Étape 4 : Observer le load balancing**

```bash
# Faire plusieurs requêtes vers app1
for i in {1..10}; do
  curl http://$(minikube ip)/app1
  echo ""
done

# Le trafic est réparti entre les 2 réplicas de app1
# (vous verrez toujours le même texte car c'est une image statique,
#  mais en production le load balancing fonctionne)
```

---

## Exercice 3 - Routage par hôte (host-based routing)

### Objectif
Router vers différents services selon le nom de domaine.

### Contexte
Le routage par hôte permet d'avoir plusieurs domaines (ou sous-domaines) pointant vers des services différents sur le même cluster. C'est la façon la plus "propre" d'exposer plusieurs applications.

**Cas d'usage réels :**
- `www.example.com` → Site web principal
- `api.example.com` → API
- `admin.example.com` → Interface d'administration
- `blog.example.com` → Blog

### Architecture cible
```
http://app1.local → Service App1
http://app2.local → Service App2
http://api.local  → Service API
```

### Instructions détaillées

**Étape 1 : Créer l'Ingress avec routage par hôte**

Créez `manifests/host-based-ingress.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-ingress
spec:
  rules:
  # Règle pour app1.local
  - host: app1.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  
  # Règle pour app2.local
  - host: app2.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
  
  # Règle pour api.local
  - host: api.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

**Explications :**

**host: app1.local** : L'Ingress ne répond que si la requête HTTP contient `Host: app1.local` dans ses headers

**Avantages du routage par hôte :**
- URLs propres et professionnelles (pas de `/app1`, juste `app1.local`)
- Isolation claire entre applications
- Possibilité d'avoir des certificats TLS différents par domaine
- Correspond aux pratiques web standards
- Plus facile à mémoriser et à communiquer

```bash
kubectl apply -f manifests/host-based-ingress.yaml

# Vérifier
kubectl get ingress host-ingress
```

**Sortie :**
```
NAME           CLASS   HOSTS                            ADDRESS        PORTS   AGE
host-ingress   nginx   app1.local,app2.local,api.local  192.168.49.2   80      10s
```

**Étape 2 : Configurer le DNS local (/etc/hosts)**

Pour que votre ordinateur puisse résoudre ces domaines vers Minikube :

**Sur Linux/Mac :**
```bash
# Obtenir l'IP de Minikube
minikube ip
# Exemple : 192.168.49.2

# Éditer /etc/hosts
sudo nano /etc/hosts

# Ajouter ces lignes (remplacer 192.168.49.2 par votre IP Minikube)
192.168.49.2 app1.local
192.168.49.2 app2.local
192.168.49.2 api.local

# Sauvegarder : Ctrl+O, Enter, Ctrl+X
```

**Sur Windows :**
```
# Ouvrir en tant qu'administrateur :
notepad C:\Windows\System32\drivers\etc\hosts

# Ajouter :
192.168.49.2 app1.local
192.168.49.2 app2.local
192.168.49.2 api.local

# Sauvegarder
```

**Astuce bash :**
```bash
# Ajouter automatiquement
MINIKUBE_IP=$(minikube ip)
echo "$MINIKUBE_IP app1.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP app2.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP api.local" | sudo tee -a /etc/hosts
```

**Étape 3 : Tester les différents hôtes**

```bash
# Tester avec curl
curl http://app1.local
# Output: Bienvenue sur Application 1

curl http://app2.local
# Output: Bienvenue sur Application 2

curl http://api.local
# Output: API Backend - Version 1.0

# Tester avec un hôte non configuré
curl http://inconnu.local
# 404 Not Found (pas de règle pour cet hôte)

# Vérifier le header Host
curl -v http://app1.local 2>&1 | grep "> Host:"
# > Host: app1.local
```

**Ou dans le navigateur :**
- `http://app1.local`
- `http://app2.local`
- `http://api.local`

---

## Exercice 4 - Ingress avec TLS/SSL (HTTPS)

### Objectif
Sécuriser l'Ingress avec HTTPS pour chiffrer le trafic.

### Contexte
TLS/SSL chiffre le trafic entre le client et l'Ingress Controller. Le certificat est stocké dans un Secret Kubernetes de type `tls`.

**Flux HTTPS :**
```
Client (HTTPS) → Ingress (déchiffrement) → Service (HTTP) → Pod
```

### Instructions détaillées

**Étape 1 : Générer un certificat auto-signé**

```bash
# Générer une clé privée et un certificat pour plusieurs domaines
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=app1.local/O=Formation Kubernetes" \
  -addext "subjectAltName=DNS:app1.local,DNS:app2.local,DNS:api.local"

# Vérifier le certificat
openssl x509 -in tls.crt -text -noout | grep -A 1 "Subject Alternative Name"
```

**Étape 2 : Créer un Secret TLS**

```bash
# Créer le Secret depuis les fichiers
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key

# Vérifier le Secret
kubectl get secret myapp-tls
kubectl describe secret myapp-tls
```

**Étape 3 : Créer un Ingress avec TLS**

Créez `manifests/tls-ingress.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - app1.local
    - app2.local
    - api.local
    secretName: myapp-tls
  rules:
  - host: app1.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
  - host: api.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

```bash
kubectl apply -f manifests/tls-ingress.yaml

# Tester avec HTTPS
curl -k https://app1.local
curl -k https://app2.local
```

---

## Commandes de référence rapide

```bash
# Ingress
kubectl get ingress
kubectl describe ingress <name>
kubectl edit ingress <name>
kubectl delete ingress <name>

# Logs du controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# Tester la config nginx
kubectl exec -n ingress-nginx <pod> -- nginx -t
```

---

## Points clés à retenir

1. **Ingress = routage L7** : Basé sur HTTP/HTTPS
2. **Controller requis** : Ingress seul ne fait rien
3. **TLS centralisé** : Un seul endroit pour les certificats
4. **Annotations puissantes** : Personnalisation complète
5. **Production-ready** : Rate limiting, auth, timeouts essentiels

---

## Pour aller plus loin

### Prochaine étape
TP07 : **Namespaces** et isolation réseau

### Ressources
- Ingress : https://kubernetes.io/docs/concepts/services-networking/ingress/
- NGINX Ingress : https://kubernetes.github.io/ingress-nginx/
