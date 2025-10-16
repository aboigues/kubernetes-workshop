#!/bin/bash

# Script de configuration de l'environnement de formation Kubernetes

set -e

echo "=== Configuration de l'environnement Kubernetes ==="

# Vérification que Minikube est installé
if ! command -v minikube &> /dev/null; then
    echo "Erreur : Minikube n'est pas installé"
    exit 1
fi

# Vérification que kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo "Erreur : kubectl n'est pas installé"
    exit 1
fi

# Démarrage de Minikube s'il n'est pas démarré
if ! minikube status &> /dev/null; then
    echo "Démarrage de Minikube..."
    minikube start --driver=docker --cpus=2 --memory=4096
fi

echo "Statut de Minikube :"
minikube status

# Activation des addons
echo "Activation des addons..."
minikube addons enable metrics-server
minikube addons enable ingress

# Vérification de la connectivité
echo "Vérification du cluster..."
kubectl cluster-info

echo ""
echo "=== Environnement prêt ==="
echo "IP de Minikube : $(minikube ip)"
echo ""
echo "Commandes utiles :"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo "  minikube dashboard"
