# TP01 - Premiers pas avec Kubernetes

## Objectifs
- Comprendre les concepts de base de Kubernetes
- Créer et gérer des Pods
- Observer l'état des ressources

## Exercice 1 - Premier Pod
Créez un Pod nginx simple.

Consignes :
1. Créez le fichier `manifests/nginx-pod.yaml`
2. Utilisez l'image `nginx:alpine`
3. Nommez le Pod `nginx-simple`
4. Appliquez le manifeste et vérifiez son état

Commandes utiles :
```bash
kubectl apply -f manifests/nginx-pod.yaml
kubectl get pods
kubectl describe pod nginx-simple
kubectl logs nginx-simple
```

## Exercice 2 - Pod avec plusieurs conteneurs
Créez un Pod avec un conteneur principal et un sidecar.

Consignes :
1. Créez `manifests/pod-multi-containers.yaml`
2. Conteneur 1 : nginx
3. Conteneur 2 : busybox qui affiche les logs nginx

## Exercice 3 - Labels et sélecteurs
Ajoutez des labels à vos Pods et pratiquez les sélecteurs.
