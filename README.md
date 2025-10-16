# Formation Kubernetes avec Minikube sur AlmaLinux

Formation pratique sur Kubernetes utilisant Minikube sous AlmaLinux.

## Structure du repository

```
.
├── tp01-premiers-pas/          # Introduction aux Pods
├── tp02-deployments/           # Deployments et ReplicaSets
├── tp03-services/              # Services et exposition
├── tp04-configmaps-secrets/    # Configuration et secrets
├── tp05-volumes/               # Persistance des données
├── tp06-ingress/               # Routage HTTP
├── tp07-namespaces/            # Organisation et isolation
├── tp08-monitoring/            # Observabilité
└── ressources/                 # Documentation et scripts
    ├── docs/                   # Documentation
    └── scripts/                # Scripts utilitaires
```

## Prérequis

- AlmaLinux 8 ou 9
- 2 CPU minimum
- 4 Go de RAM minimum
- 20 Go d'espace disque

## Installation

Suivez le guide d'installation dans `ressources/docs/installation-almalinux.md`

## Configuration de l'environnement

```bash
# Configurer l'environnement
./ressources/scripts/setup-environment.sh

# Vérifier que tout fonctionne
kubectl get nodes
minikube status
```

## Utilisation

Chaque TP contient :
- Un fichier `README.md` avec les instructions
- Un dossier `manifests/` pour vos fichiers YAML
- Un dossier `corrections/` avec les solutions

### Déroulement d'un TP

1. Lire le README du TP
2. Créer vos fichiers YAML dans `manifests/`
3. Tester vos déploiements
4. Vérifier avec le script de vérification
5. Comparer avec les corrections si nécessaire

### Scripts utilitaires

```bash
# Vérifier votre travail sur un TP
./ressources/scripts/check-tp.sh 01

# Nettoyer l'environnement
./ressources/scripts/cleanup.sh
```

## Ordre des TPs

1. **TP01** - Premiers pas : Comprendre les Pods
2. **TP02** - Deployments : Gérer les applications
3. **TP03** - Services : Exposer les applications
4. **TP04** - ConfigMaps et Secrets : Configuration
5. **TP05** - Volumes : Persistance des données
6. **TP06** - Ingress : Routage HTTP avancé
7. **TP07** - Namespaces : Organisation
8. **TP08** - Monitoring : Observabilité

## Commandes utiles

```bash
# Démarrer Minikube
minikube start

# Arrêter Minikube
minikube stop

# Dashboard Kubernetes
minikube dashboard

# Obtenir l'IP de Minikube
minikube ip

# Accéder à un service
minikube service <nom-service>
```

## Ressources

- Documentation Kubernetes : https://kubernetes.io/docs/
- Documentation Minikube : https://minikube.sigs.k8s.io/docs/
- Commandes essentielles : `ressources/docs/commandes-essentielles.md`

## Support

Pour toute question, consultez :
1. Le README du TP concerné
2. Les corrections dans le dossier `corrections/`
3. La documentation dans `ressources/docs/`
