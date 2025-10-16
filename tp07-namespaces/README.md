# TP07 - Namespaces et isolation

## Objectifs
- Comprendre l'utilité des Namespaces
- Organiser les ressources
- Gérer les quotas et limites

## Exercice 1 - Créer des Namespaces
Créez trois Namespaces : dev, staging, production.

```bash
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production
```

## Exercice 2 - Déployer dans un Namespace
Déployez la même application dans chaque Namespace.

## Exercice 3 - ResourceQuota
Créez des quotas pour limiter les ressources par Namespace.

## Exercice 4 - NetworkPolicy
Isolez les Namespaces avec des NetworkPolicies.
