# TP05 - Volumes et persistance

## Objectifs
- Comprendre les différents types de volumes
- Utiliser des PersistentVolumes
- Gérer la persistance des données

## Exercice 1 - emptyDir
Créez un Pod avec un volume emptyDir partagé entre deux conteneurs.

## Exercice 2 - hostPath
Créez un Pod qui monte un répertoire de l'hôte Minikube.

## Exercice 3 - PersistentVolume et PersistentVolumeClaim
Créez un PV et PVC pour persister des données.

Consignes :
1. Créez `manifests/pv.yaml` avec 1Gi de stockage
2. Créez `manifests/pvc.yaml` qui demande 500Mi
3. Utilisez le PVC dans un Pod

## Exercice 4 - Base de données persistante
Déployez un PostgreSQL avec stockage persistant.
