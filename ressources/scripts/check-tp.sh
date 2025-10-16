#!/bin/bash

# Script de vérification des TPs

TP=$1

if [ -z "$TP" ]; then
    echo "Usage: $0 <numero-tp>"
    echo "Exemple: $0 01"
    exit 1
fi

echo "=== Vérification TP$TP ==="

case $TP in
    01)
        echo "Vérification des Pods..."
        kubectl get pods
        ;;
    02)
        echo "Vérification des Deployments..."
        kubectl get deployments
        kubectl get replicasets
        kubectl get pods
        ;;
    03)
        echo "Vérification des Services..."
        kubectl get services
        kubectl get endpoints
        ;;
    04)
        echo "Vérification des ConfigMaps et Secrets..."
        kubectl get configmaps
        kubectl get secrets
        ;;
    05)
        echo "Vérification des Volumes..."
        kubectl get pv
        kubectl get pvc
        ;;
    06)
        echo "Vérification des Ingress..."
        kubectl get ingress
        ;;
    07)
        echo "Vérification des Namespaces..."
        kubectl get namespaces
        kubectl get all -n dev 2>/dev/null || echo "Namespace dev vide"
        kubectl get all -n staging 2>/dev/null || echo "Namespace staging vide"
        kubectl get all -n production 2>/dev/null || echo "Namespace production vide"
        ;;
    08)
        echo "Vérification du monitoring..."
        kubectl top nodes 2>/dev/null || echo "Metrics-server non disponible"
        kubectl top pods 2>/dev/null || echo "Pas de métriques pods"
        kubectl get hpa
        ;;
    *)
        echo "TP non reconnu"
        exit 1
        ;;
esac
