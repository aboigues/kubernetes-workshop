# TP02 - Deployments et ReplicaSets

## Objectifs
- Créer des Deployments
- Gérer les montées en version
- Effectuer des rollbacks

## Exercice 1 - Deployment basique
Créez un Deployment nginx avec 3 réplicas.

Consignes :
1. Créez `manifests/nginx-deployment.yaml`
2. 3 réplicas
3. Image `nginx:1.21`
4. Labels appropriés

Commandes :
```bash
kubectl apply -f manifests/nginx-deployment.yaml
kubectl get deployments
kubectl get replicasets
kubectl get pods
```

## Exercice 2 - Mise à jour rolling
Mettez à jour l'image vers `nginx:1.22`.

```bash
kubectl set image deployment/nginx nginx=nginx:1.22
kubectl rollout status deployment/nginx
kubectl rollout history deployment/nginx
```

## Exercice 3 - Rollback
Effectuez un rollback vers la version précédente.

```bash
kubectl rollout undo deployment/nginx
```

## Exercice 4 - Scaling
Scalez le Deployment à 5 réplicas.

```bash
kubectl scale deployment/nginx --replicas=5
```
