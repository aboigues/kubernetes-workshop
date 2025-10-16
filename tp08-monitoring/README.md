# TP08 - Monitoring et observabilité

## Objectifs
- Activer metrics-server
- Consulter les métriques des ressources
- Mettre en place des sondes de santé

## Exercice 1 - Metrics Server
Activez metrics-server dans Minikube :

```bash
minikube addons enable metrics-server
```

Consultez les métriques :
```bash
kubectl top nodes
kubectl top pods
```

## Exercice 2 - Probes de santé
Créez un Deployment avec des probes liveness et readiness.

## Exercice 3 - HorizontalPodAutoscaler
Créez un HPA qui scale automatiquement selon la charge CPU.

## Exercice 4 - Logs centralisés
Explorez les logs avec kubectl.
