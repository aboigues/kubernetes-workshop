# TP04 - ConfigMaps et Secrets

## Objectifs
- Gérer la configuration avec ConfigMaps
- Sécuriser les données sensibles avec Secrets
- Injecter la configuration dans les Pods

## Exercice 1 - ConfigMap basique
Créez une ConfigMap pour configurer une application.

Consignes :
1. Créez `manifests/app-configmap.yaml`
2. Ajoutez des variables : APP_NAME, APP_ENV, LOG_LEVEL
3. Utilisez-la dans un Pod

## Exercice 2 - ConfigMap depuis fichier
Créez une ConfigMap contenant un fichier de configuration nginx.

## Exercice 3 - Secrets
Créez un Secret pour stocker des credentials.

Consignes :
1. Créez `manifests/db-secret.yaml`
2. Stockez : username, password
3. Utilisez-le dans un Pod

## Exercice 4 - Application complète
Déployez une application utilisant ConfigMap et Secret.
