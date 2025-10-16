# TP06 - Ingress et routage HTTP

## Objectifs
- Comprendre le fonctionnement d'Ingress
- Configurer le routage basé sur les chemins
- Configurer le routage basé sur les hôtes

## Prérequis
Activer l'addon Ingress dans Minikube :
```bash
minikube addons enable ingress
```

## Exercice 1 - Ingress simple
Créez un Ingress pour exposer une application.

Consignes :
1. Déployez nginx
2. Créez un Service
3. Créez un Ingress pointant vers le Service
4. Testez avec `curl`

## Exercice 2 - Routage par chemin
Créez un Ingress qui route vers différents services selon le chemin.

- `/app1` -> service-app1
- `/app2` -> service-app2

## Exercice 3 - Routage par hôte
Créez un Ingress qui route selon le nom d'hôte.
