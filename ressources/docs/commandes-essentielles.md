# Commandes Kubernetes essentielles

## Gestion des Pods

```bash
# Lister les pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods --all-namespaces

# Décrire un pod
kubectl describe pod <nom-pod>

# Logs d'un pod
kubectl logs <nom-pod>
kubectl logs <nom-pod> -f
kubectl logs <nom-pod> -c <nom-conteneur>

# Exécuter une commande dans un pod
kubectl exec <nom-pod> -- <commande>
kubectl exec -it <nom-pod> -- /bin/sh

# Supprimer un pod
kubectl delete pod <nom-pod>
```

## Gestion des Deployments

```bash
# Lister les deployments
kubectl get deployments

# Créer un deployment
kubectl create deployment <nom> --image=<image>

# Scaler un deployment
kubectl scale deployment <nom> --replicas=5

# Mettre à jour l'image
kubectl set image deployment/<nom> <conteneur>=<nouvelle-image>

# Voir l'historique des rollouts
kubectl rollout history deployment/<nom>

# Rollback
kubectl rollout undo deployment/<nom>

# Statut du rollout
kubectl rollout status deployment/<nom>
```

## Gestion des Services

```bash
# Lister les services
kubectl get services
kubectl get svc

# Exposer un deployment
kubectl expose deployment <nom> --type=NodePort --port=80

# Obtenir l'URL d'un service (Minikube)
minikube service <nom-service> --url
```

## Gestion des ressources

```bash
# Appliquer un fichier YAML
kubectl apply -f <fichier.yaml>
kubectl apply -f <dossier>/

# Supprimer des ressources
kubectl delete -f <fichier.yaml>
kubectl delete deployment <nom>
kubectl delete service <nom>

# Supprimer toutes les ressources d'un namespace
kubectl delete all --all -n <namespace>
```

## Gestion des Namespaces

```bash
# Lister les namespaces
kubectl get namespaces

# Créer un namespace
kubectl create namespace <nom>

# Changer de namespace par défaut
kubectl config set-context --current --namespace=<nom>

# Lister les ressources dans un namespace
kubectl get all -n <namespace>
```

## Informations et débogage

```bash
# Informations sur le cluster
kubectl cluster-info

# Voir les nodes
kubectl get nodes
kubectl describe node <nom-node>

# Voir les events
kubectl get events
kubectl get events --sort-by=.metadata.creationTimestamp

# Métriques
kubectl top nodes
kubectl top pods
```

## ConfigMaps et Secrets

```bash
# Créer un ConfigMap depuis un fichier
kubectl create configmap <nom> --from-file=<fichier>

# Créer un ConfigMap depuis des literals
kubectl create configmap <nom> --from-literal=key1=value1

# Créer un Secret
kubectl create secret generic <nom> --from-literal=password=secret

# Voir un secret (décodé)
kubectl get secret <nom> -o jsonpath='{.data.password}' | base64 -d
```

## Labels et sélecteurs

```bash
# Ajouter un label
kubectl label pod <nom> env=prod

# Sélectionner par label
kubectl get pods -l env=prod
kubectl get pods -l 'env in (prod,staging)'

# Supprimer un label
kubectl label pod <nom> env-
```

## Copier des fichiers

```bash
# Copier vers un pod
kubectl cp <fichier-local> <namespace>/<pod>:<chemin-distant>

# Copier depuis un pod
kubectl cp <namespace>/<pod>:<chemin-distant> <fichier-local>
```

## Port forwarding

```bash
# Forward un port local vers un pod
kubectl port-forward pod/<nom-pod> 8080:80

# Forward vers un service
kubectl port-forward service/<nom-service> 8080:80
```
